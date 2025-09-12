#!/usr/bin/env bash
set -euo pipefail

# ========= Config =========
MAX_ROUNDS=${MAX_ROUNDS:-10}
DRY_RUN=${DRY_RUN:-0}           # 1 = show what would be removed, but don't remove
PACMAN="sudo pacman"
PACFLAGS=" -Syyuu --noconfirm --ask=4 --overwrite '*' --disable-download-timeout "
ERRLOG="/tmp/pacman_upgrade.err"
LOG="/tmp/pacman_upgrade.log"

# Never auto-remove these (add here if you’re nervous)
PROTECT=(
  base bash coreutils filesystem glibc gcc-libs pacman systemd util-linux
  openssl libcurl zlib e2fsprogs shadow sed grep gawk tar xz xfsprogs
  linux linux-firmware
)

# ========= Helpers =========
in_protect() {
  local x="$1"
  for p in "${PROTECT[@]}"; do [[ "$x" == "$p" ]] && return 0; done
  return 1
}

uniq_words() { awk '{for(i=1;i<=NF;i++) if(!seen[$i]++){printf "%s%s", out?" ":"", $i; out=1}} END{print ""}'; }

extract_blockers() {
  # Parse common pacman failure patterns to figure out what to remove.
  # We remove the *dependent package* (the one after "required by"), because it’s the one pinning an old ABI.
  # We also grab package names from conflict lines.
  local err="$1"

  {
    # lines like:
    # :: installing libassuan (3.0.0-1) breaks dependency 'libassuan.so=0-64' required by pinentry
    sed -nE "s/.*required by ([a-z0-9@._+-]+).*/\1/p" "$err"

    # lines like:
    # error: failed to prepare transaction (conflicting dependencies)
    # :: jre-openjdk and jre17-openjdk-headless are in conflict. Remove jre17-openjdk-headless? [y/N]
    sed -nE "s/:: ([a-z0-9@._+-]+) and ([a-z0-9@._+-]+) are in conflict.*/\1 \2/p" "$err"

    # lines like:
    # :: unable to satisfy dependency 'nodejs>=20.7.0' required by npm
    sed -nE "s/.*unable to satisfy dependency '.*' required by ([a-z0-9@._+-]+).*/\1/p" "$err"
  } | tr '\n' ' ' | uniq_words
}

remove_blockers() {
  local to_remove=("$@")
  local final=()
  for p in "${to_remove[@]}"; do
    # strip trailing punctuation
    p="${p%[?.,:]}"
    # skip empties and protected
    [[ -z "$p" ]] && continue
    if in_protect "$p"; then
      echo "[skip] protected: $p"
      continue
    fi
    final+=("$p")
  done

  # special cases: if both jre-openjdk and jdk-openjdk appear, prefer removing jre-openjdk (unversioned runtime)
  # (keeping jdk-openjdk is usually safer)
  local filtered=()
  local have_jre=0 have_jdk=0
  for f in "${final[@]}"; do
    [[ "$f" == "jre-openjdk" || "$f" == "jre-openjdk-headless" ]] && have_jre=1
    [[ "$f" == "jdk-openjdk" ]] && have_jdk=1
  done
  for f in "${final[@]}"; do
    if [[ "$f" == "jdk-openjdk" && $have_jre -eq 1 ]]; then
      echo "[prefer] keeping jdk-openjdk; removing jre-openjdk* instead"
      continue
    fi
    filtered+=("$f")
  done

  # deduplicate
  mapfile -t filtered < <(printf "%s\n" "${filtered[@]}" | awk '!seen[$0]++')

  if ((${#filtered[@]}==0)); then
    echo "[info] Nothing to remove."
    return 0
  fi

  echo "[info] Will remove (Rdd): ${filtered[*]}"
  if ((DRY_RUN)); then
    echo "[dry-run] sudo pacman -Rdd --noconfirm ${filtered[*]}"
  else
    $PACMAN -Rdd --noconfirm "${filtered[@]}" || true
  fi
}

# ========= Flow =========
echo "[info] starting auto-unblock loop (max rounds: $MAX_ROUNDS)"
round=1
while (( round <= MAX_ROUNDS )); do
  echo -e "\n[info] === Round $round ==="
  # Try a full upgrade
  if $PACMAN $PACFLAGS 2> "$ERRLOG" | tee "$LOG" ; then
    echo "[success] upgrade completed in round $round"
    exit 0
  fi

  echo "[warn] pacman failed; parsing blockers…"
  blockers_str=$(extract_blockers "$ERRLOG")
  read -r -a blockers <<< "$blockers_str"

  if ((${#blockers[@]}==0)); then
    echo "[error] Could not parse blockers from pacman output."
    echo "        See $ERRLOG for details."
    exit 1
  fi

  remove_blockers "${blockers[@]}"

  (( round++ ))
done

echo "[error] Reached MAX_ROUNDS=$MAX_ROUNDS without success. Check $ERRLOG"
exit 2
