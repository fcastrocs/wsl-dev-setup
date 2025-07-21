param (
    [switch]$newInstance,
    [string]$distroName,
    [switch]$default
)

# Constants
$LINUX_USER = "devuser"
$GITHUB_URI = "https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main"

# Font Configuration
$FONT_NAME = "FiraCode Nerd Font"
$FONT_SIZE_VSCODE = 14
$FONT_SIZE_NOTEPAD = 11

# Windows Terminal Settings
$TERMINAL_COLOR_SCHEME = "One Half Dark"

# Application Packages
$WINGET_PACKAGES = @(
    "Microsoft.WindowsTerminal",
    "Notepad++.Notepad++",
    "Microsoft.VisualStudioCode",
    "Anysphere.Cursor",
    "JetBrains.IntelliJIDEA.Ultimate"
)

# Custom Scripts
$CUSTOM_SCRIPTS = @(
    "login-eks.sh",
    "login-ecr.sh"
    "gim"
)

$DISTRO_NAME = if ($distroName) {
    $distroName
} elseif ($newInstance) {
    "Ubuntu-24-04-$(Get-Date -Format 'MMddyyyy-HHmm')"
} else {
    "Ubuntu"
}

# Run a command in WSL as $LINUX_USER
function Invoke-Wsl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [switch]$Passthru  # Optional: show output live and suppress throw
    )

    $bashCommand = "`"$Command`""

    $wslArgs = @(
        '-d', $DISTRO_NAME,
        '-u', $LINUX_USER,
        '--', 'bash', '-c', $bashCommand
    )

    if ($Passthru) {
        # Stream output directly
        & wsl @wslArgs
        return
    }

    # Default behavior: capture output and throw on error
    $output = & wsl @wslArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Invoke-Wsl failed (exit code $LASTEXITCODE): $output"
    }

    return $output
}

# Send a file to WSL home directory
function Send-ToWslHome {
    param (
        [Parameter(Mandatory = $true)]
        [string]$localPath,
        [Parameter(Mandatory = $true)]
        [string]$remoteUrl,
        [Parameter(Mandatory = $true)]
        [string]$targetPath
    )

    # Convert to WSL user home path
    $targetPath = "/home/$LINUX_USER/$($targetPath -replace '\\', '/' -replace '^/+', '')"
    $targetDir = (Split-Path $targetPath -Parent) -replace '\\', '/'

    try {
        Invoke-Wsl "mkdir -p '$targetDir'"
        
        if (Test-Path $localPath) {
            # Copy local file into WSL using base64 to preserve Unicode characters
            $bytes = [System.IO.File]::ReadAllBytes($localPath)
            $base64 = [Convert]::ToBase64String($bytes)
            Invoke-Wsl "echo '$base64' | base64 -d > '$targetPath'"

            if (
                $targetPath -like '*/.local/bin*' -or
                $targetPath.ToLower().EndsWith(".sh")
            ) {
                Invoke-Wsl "chmod +x '$targetPath'"
            }

            Write-Host "`tLocal file copied to WSL: $targetPath" -ForegroundColor DarkGray
        }
        else {
            # Download remote file into WSL
            Invoke-Wsl "curl -fsSL '$remoteUrl' -o '$targetPath'"

            if (
                $targetPath -like '*/.local/bin*' -or
                $targetPath.ToLower().EndsWith(".sh")
            ) {
                Invoke-Wsl "chmod +x '$targetPath'"
            }

            Write-Host "`tRemote file downloaded to WSL: $targetPath" -ForegroundColor DarkGray
        }
    }
    catch {
        throw "Send-ToWslHome failed: $($_.Exception.Message)"
    }
}

function Test-RunningAsAdministrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "ERROR: This script must be run as Administrator!"
    }
}

function Install-ChocoPackage {
    param (
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    Write-Host "`n - Installing package: $PackageName..."

    # Only check locally installed packages
    $isInstalled = choco list | Select-String -Pattern "^$PackageName\s" -Quiet

    try {
        if ($isInstalled) {
            choco upgrade $PackageName -y *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "`tUpgrade failed for package '$PackageName'"
            }
            Write-Host "`tPackage '$PackageName' upgraded." -ForegroundColor DarkGray
        }
        else {
            choco install $PackageName -y *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "`tInstall failed for package '$PackageName'"
            }
        }
    }
    catch {
        throw "Install-ChocoPackage failed: $($_.Exception.Message)"
    }
}

function Get-WingetPath {
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $wingetPath) {
        return $wingetPath
    } else {
        throw "winget.exe not found in the expected location."
    }
}

function Ensure-WinGetReady {
    Write-Host "`n - Ensuring WinGet is ready..."

    try {
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop | Out-Null
        Repair-WinGetPackageManager -AllUsers
    } catch {
        throw"Ensure-WinGetReady failed: $($_.Exception.Message)"
    }
}

function Update-WingetSources {
    & (Get-WingetPath) source update > $null
}

function Install-WingetPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    Write-Host "`n - Installing package: $PackageName..."
    $winget = Get-WingetPath
    $escapedName = [Regex]::Escape($PackageName)

    try {
        # Check if the package is installed
        $installed = & $winget list --id $PackageName --exact --source winget 2>$null
        $isInstalled = $installed -and $installed -match $escapedName

        if ($isInstalled) {
            # Check if an upgrade is available
            $upgradeAvailable = & $winget upgrade --id $PackageName --exact --source winget 2>$null
            if ($upgradeAvailable -and $upgradeAvailable -match $escapedName) {
                & $winget upgrade --id $PackageName --exact --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
                Write-Host "`t$PackageName upgraded" -ForegroundColor DarkGray
            }
            else {
                Write-Host "`t$PackageName is already up to date" -ForegroundColor DarkGray
            }
        }
        else {
            # Install if not installed
            & $winget install --id $PackageName --exact --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Failed to install $PackageName" }
            Write-Host "`t$PackageName installed" -ForegroundColor DarkGray
        }
    }
    catch {
        throw "Install-WingetPackage failed: $($_.Exception.Message)"
    }
}

function Enable-WSLFeatures {
    Write-Host "`n - Enabling WSL and Virtual Machine Platform..."

    $restartRequired = $false

    # Determine correct path to dism.exe
    $dismPath = "$env:WINDIR\System32\dism.exe"
    if (-not (Test-Path $dismPath)) {
        $dismPath = "$env:WINDIR\Sysnative\dism.exe"
    }

    # Enable Microsoft-Windows-Subsystem-Linux
    $output = & $dismPath /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1
    if ($LASTEXITCODE -eq 3010) {
        $restartRequired = $true
    } elseif ($LASTEXITCODE -ne 0) {
        throw "Failed to enable Microsoft-Windows-Subsystem-Linux (exit code $LASTEXITCODE): $output"
    }

    # Enable VirtualMachinePlatform
    $output = & $dismPath /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1
    if ($LASTEXITCODE -eq 3010) {
        $restartRequired = $true
    } elseif ($LASTEXITCODE -ne 0) {
        throw "Failed to enable VirtualMachinePlatform (exit code $LASTEXITCODE): $output"
    }

    if ($restartRequired) {
        throw "Restart required to complete WSL setup."
    }
}

function Update-WSLKernel {
    Write-Host "`n - Updating WSL kernel..."

    $output = & wsl --update 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Update-WSLKernel failed (exit code $LASTEXITCODE): $output"
    }
}

function Test-WslDistroExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )

    try {
        $existingDistros = & wsl -l -q 2>&1 | ForEach-Object { $_.Trim() }
        return $existingDistros | Where-Object { $_.ToLower() -eq $DistroName.ToLower() } | Measure-Object | Select-Object -ExpandProperty Count
    }
    catch {
        throw "Test-WslDistroExists failed: $($_.Exception.Message)"
    }
}

function Install-UbuntuWslInstance {
    $downloadDir    = "$env:TEMP\UbuntuWSL"
    $installBaseDir = "C:\WSL"
    $installDir     = Join-Path $installBaseDir $DISTRO_NAME
    $tarballName    = "ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz"
    $downloadUrl    = "https://cloud-images.ubuntu.com/wsl/releases/24.04/current/$tarballName"
    $tarballPath    = Join-Path $downloadDir $tarballName

    try {
        Write-Host "`n - Installing WSL distro: $DISTRO_NAME"
        
        if ((Test-WslDistroExists -DistroName $DISTRO_NAME) -and -not $newInstance) {
            Write-Host "`tDistro '$DISTRO_NAME' already exists. Skipping." -ForegroundColor DarkGray
            return
        }

        # Ensure necessary directories exist
        New-Item -Path $downloadDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -Path $installDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

        # Download rootfs if not already present
        if (-not (Test-Path $tarballPath)) {
            Write-Host "`tDownloading '$tarballName'..." -ForegroundColor DarkGray
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tarballPath -UseBasicParsing -ErrorAction Stop
        }

        # Import new WSL distro
        Write-Host "`tImporting distro as '$DISTRO_NAME'..." -ForegroundColor DarkGray
        $result = & wsl --import $DISTRO_NAME $installDir $tarballPath --version 2 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "WSL import failed with exit code $LASTEXITCODE`: $result"
        }
        
        # Set as default if -default was passed
        if ($default) {
            Write-Host "`tSetting '$DISTRO_NAME' as the default WSL distro..." -ForegroundColor DarkGray
            & wsl --set-default $DISTRO_NAME
        }
    }
    catch {
        throw "Install-UbuntuWslInstance failed: $($_.Exception.Message)"
    }
}

function Add-LinuxUserWithSudo {
    Write-Host "`n - Creating user '$LINUX_USER' with passwordless sudo..."

    # Check if user exists
    $userExists = & wsl -d $DISTRO_NAME -- bash -c "id -u $LINUX_USER >/dev/null 2>&1 && echo yes || echo no" 2>&1 |
        ForEach-Object { $_.Trim() }

    $cmd = if ($userExists -eq "yes") {
        @(
            "sudo usermod -aG sudo $LINUX_USER",
            "echo '$LINUX_USER ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$LINUX_USER > /dev/null",
            "sudo chmod 0440 /etc/sudoers.d/$LINUX_USER"
        ) -join "; "
    } else {
        @(
            "sudo adduser --disabled-password --gecos '' $LINUX_USER",
            "echo '$LINUX_USER ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$LINUX_USER > /dev/null",
            "sudo usermod -aG sudo $LINUX_USER",
            "sudo chmod 0440 /etc/sudoers.d/$LINUX_USER"
        ) -join "; "
    }

    $output = & wsl -d $DISTRO_NAME -- bash -c "`"$cmd`"" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create/configure user '$LINUX_USER' (exit code $LASTEXITCODE): $output"
    }

    # Validate passwordless sudo
    $output = & wsl -d $DISTRO_NAME -- sudo -n true 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Passwordless sudo failed for '$LINUX_USER': $output"
    }
}

function Write-WslConfigOnWsl {
    # Set as default user via /etc/wsl.conf and enable systemd
    $wslConfContent = @"
[user]
default=$LINUX_USER

[boot]
systemd=true
"@

    # Command to write the config content to /etc/wsl.conf inside WSL
    $confCmd = "echo -e '$wslConfContent' | sudo tee /etc/wsl.conf > /dev/null"

    # Execute the command in the specified WSL distro
    $output = & wsl -d $DISTRO_NAME -- bash -c "$confCmd" 2>&1

    # Check for errors
    if ($LASTEXITCODE -ne 0) {
        throw "Write-WslConfigOnWsl failed: $output"
    }
}

function Write-WslConfigOnWindows {
    Write-Host "`n - Writing .wslconfig with performance optimizations..."

    $configPath = "$env:USERPROFILE\.wslconfig"

    try {
        $sys = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $totalMem = [math]::Floor($sys.TotalPhysicalMemory / 1GB)
        $cpuCount = $sys.NumberOfLogicalProcessors

        # Fallbacks in case of unexpected values
        $allocMem = if ($totalMem -gt 0) { $totalMem } else { 4 }
        $cpuCount = if ($cpuCount -gt 0) { $cpuCount } else { 2 }

        @"
[wsl2]
memory=${allocMem}GB
processors=${cpuCount}
swap=0
localhostForwarding=true
guiApplications=false
debugConsole=false
nestedVirtualization=false
kernelCommandLine=quiet elevator=noop
vmIdleTimeout=0
"@ | Set-Content -Encoding UTF8 -Path $configPath -Force -ErrorAction Stop

        Write-Host "`t.wslconfig written with $allocMem GB and $cpuCount CPUs." -ForegroundColor DarkGray
    }
    catch {
        throw "Write-WSLConfig failed: $($_.Exception.Message)"
    }
}

function Invoke-WSLSetupScript {
    $scriptFileName = "setup-ubuntu.sh"
    $localScriptPath = "$PSScriptRoot\scripts\$scriptFileName"
    $remoteScriptUrl = "$GITHUB_URI/scripts/$scriptFileName"

    Write-Host "`n - Installing developer tools in WSL..."

    wsl --shutdown *> $null

    try {
        Send-ToWslHome $localScriptPath $remoteScriptUrl "$scriptFileName"

        # Execute setup script
        Invoke-Wsl "/home/$LINUX_USER/$scriptFileName" -Passthru
    }
    catch {
        throw "Invoke-WSLSetupScript failed: $($_.Exception.Message)"
    }
    finally {
        wsl --shutdown *> $null
    }
}

function Install-Chocolatey {
    Write-Host "`n - Installing Chocolatey..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        # Update Chocolatey if already installed
        Install-ChocoPackage -PackageName "chocolatey"
        return
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        $chocoScript = "$env:TEMP\install-choco.ps1"
        Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -OutFile $chocoScript -UseBasicParsing -ErrorAction Stop

        $powerShellExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $output = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $chocoScript 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey install script failed (exit code $LASTEXITCODE): $output"
        }

        Remove-Item $chocoScript -Force -ErrorAction SilentlyContinue
    }
    catch {
        throw "Install-Chocolatey failed: $($_.Exception.Message)"
    }
}

function Install-NerdFontFiraCode {
    Write-Host "`n - Installing Nerd Font Fira Code"

    try {
        $fontZipName = "FiraCode.zip"
        $tempZipPath = "$env:TEMP\$fontZipName"
        $extractPath = "$env:TEMP\FiraCodeFont"

        # Cleanup previous downloads
        if (Test-Path $tempZipPath) { Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }

        # Fetch latest Nerd Fonts release
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" `
            -Headers @{ "User-Agent" = "PowerShell" }

        $asset = $release.assets | Where-Object { $_.name -like "*$fontZipName" }
        if (-not $asset) {
            throw "FiraCode.zip not found in latest Nerd Fonts release."
        }

        # Download and extract
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZipPath -ErrorAction Stop
        Expand-Archive -Path $tempZipPath -DestinationPath $extractPath -Force -ErrorAction Stop

        # Install all font files
        $fontFiles = Get-ChildItem -Path $extractPath -Recurse -Include *.ttf, *.otf -ErrorAction Stop
        $successCount = 0

        foreach ($fontFile in $fontFiles) {
            if (Install-Font -FontPath $fontFile.FullName) {
                $successCount++
            }
        }

        # Cleanup
        Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "`tInstall-NerdFontFiraCode failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Install-Font {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$FontPath
    )

    # Define native interop methods (GDI and User32) if not already loaded
    if (-not ([Type]::GetType('FontApi.Native'))) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace FontApi {
    public static class Native {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern int AddFontResourceExW(string lpFileName, uint fl, IntPtr pdv);

        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetFontResourceInfoW(string lpFileName, ref int cbBuffer, StringBuilder lpBuffer, uint dwQueryType);

        [DllImport("user32.dll")]
        public static extern int SendMessageW(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    }
}
"@ -PassThru | Out-Null
    }

    # Constants used in native API calls
    $FR_PRIVATE       = 0x10
    $GFRI_DESCRIPTION = 1
    $WM_FONTCHANGE    = 0x001D
    $HWND_BROADCAST   = [IntPtr]0xFFFF

    $FontsDir = Join-Path $env:WINDIR 'Fonts'
    $RegPath  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    # Normalize and resolve the source font path
    $src      = (Resolve-Path $FontPath -ErrorAction Stop).ProviderPath
    $fileName = Split-Path $src -Leaf
    $dst      = Join-Path $FontsDir $fileName

    # Copy font file to system fonts directory (overwrites if exists)
    Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop

    # Add font to in-memory font table so apps can see it without restart
    [void][FontApi.Native]::AddFontResourceExW($dst, $FR_PRIVATE, [IntPtr]::Zero)

    # Query Windows for the human-readable display name of the font
    $len = 0
    [void][FontApi.Native]::GetFontResourceInfoW($dst, [ref]$len, $null, $GFRI_DESCRIPTION)
    $sb  = New-Object System.Text.StringBuilder ($len)
    [void][FontApi.Native]::GetFontResourceInfoW($dst, [ref]$len, $sb, $GFRI_DESCRIPTION)
    $friendly = $sb.ToString().Trim()

    # Compose registry key name (e.g., "FiraCode Nerd Font (TrueType)")
    $suffix  = if ($fileName -match '\.tt[cf]$') { ' (TrueType)' } else { ' (OpenType)' }
    $regName = "$friendly$suffix"

    # Create or update registry entry for this font
    $existing = Get-ItemProperty -Path $RegPath -Name $regName -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ItemProperty -Path $RegPath -Name $regName -Value $fileName -PropertyType String -Force | Out-Null
    } elseif ($existing.$regName -ne $fileName) {
        Set-ItemProperty -Path $RegPath -Name $regName -Value $fileName -Force
    }

    # Notify running apps that font list has changed
    [void][FontApi.Native]::SendMessageW($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero)
}

# Open Windows terminal and Editors to generate setting files
function Open-AppsForFirstTime {
    Write-Host "`n - Getting things ready..."

    # Refresh environment variables to pick up newly installed executables
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    $apps = @(
        @{ name = "VS Code"; exe = "code"; process = "Code" },
        @{ name = "Cursor IDE"; exe = "cursor"; process = "Cursor" },
        @{ name = "Notepad++"; exe = "notepad++.exe"; process = "notepad++" },
        @{ name = "Windows Terminal"; exe = "wt.exe"; process = "WindowsTerminal" }
    )

    $jobs = @()

    foreach ($app in $apps) {
        $job = Start-Job -ScriptBlock {
            param ($app)

            try {
                $alreadyRunning = Get-Process -Name $app.process -ErrorAction SilentlyContinue
                if ($alreadyRunning) {
                    return
                }

                Start-Process -FilePath $app.exe -WindowStyle Minimized

                $timeoutMs = 10000
                $intervalMs = 200
                $elapsed = 0
                $readyProc = $null

                while ($elapsed -lt $timeoutMs) {
                    $readyProc = Get-Process -Name $app.process -ErrorAction SilentlyContinue |
                                 Where-Object { $_.MainWindowHandle -ne 0 }

                    if ($readyProc) { break }

                    Start-Sleep -Milliseconds $intervalMs
                    $elapsed += $intervalMs
                }

                if ($readyProc) {
                    $readyProc | Stop-Process -Force
                }
                else {
                    Write-Host "`t$($app.name) never showed a window. Skipping." -ForegroundColor Yellow
                }
            }
            catch {
                throw "Open-AppsForFirstTime: Failed to launch or close $($app.name): $($_.Exception.Message)"
            }
        } -ArgumentList $app

        $jobs += $job
    }

    # Wait for all jobs to finish
    $jobs | Wait-Job | ForEach-Object {
        try {
            Receive-Job $_ -ErrorAction Stop
        }
        catch {
            throw "Open-AppsForFirstTime: Job failed - $($_.Exception.Message)"
        }
        finally {
            Remove-Job $_ -Force -ErrorAction SilentlyContinue
        }
    }
}

function Set-FiraCodeFontInEditors {
    Write-Host "`n - Setting FiraCode Nerd Font in editors..."

    $editors = @{
        "VS Code"    = "$env:APPDATA\Code\User\settings.json"
        "Cursor IDE" = "$env:APPDATA\Cursor\User\settings.json"
    }

    foreach ($name in $editors.Keys) {
        $path = $editors[$name]
        try {
            if (-not (Test-Path $path)) {
                New-Item -Path (Split-Path $path) -ItemType Directory -Force | Out-Null
                $settings = @{ editor = @{ fontFamily = $FONT_NAME; fontSize = $FONT_SIZE_VSCODE; fontLigatures = $true } }
            }
            else {
                $json = Get-Content $path -Raw
                $settings = $json | ConvertFrom-Json -ErrorAction Stop

                if (-not $settings.editor) {
                    $settings | Add-Member -MemberType NoteProperty -Name editor -Value @{}
                }

                $settings.editor.fontFamily = $FONT_NAME
                $settings.editor.fontSize = $FONT_SIZE_VSCODE
                $settings.editor.fontLigatures = $true
            }

            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        }
        catch {
            throw "Set-FiraCodeFontInEditors: Failed to update $name settings ($path): $($_.Exception.Message)"
        }
    }

    $stylersPath = "$env:APPDATA\Notepad++\stylers.xml"

    if (Test-Path $stylersPath) {
        try {
            $content = Get-Content $stylersPath -Raw

            $pattern = '<WidgetStyle name="Default Style"([^>]*)>'
            if ($content -match $pattern) {
                $original = $matches[0]

                $patched = $original `
                    -replace 'fontName="[^"]*"', "fontName=`"$FONT_NAME`"" `
                    -replace 'fontSize="[^"]*"', "fontSize=`"$FONT_SIZE_NOTEPAD`""

                $newContent = $content -replace [regex]::Escape($original), $patched
                Set-Content -Path $stylersPath -Value $newContent -Encoding Default
            }
            else {
                throw "Set-FiraCodeFontInEditors: <WidgetStyle name='Default Style'> not found in stylers.xml"
            }
        }
        catch {
            throw "Set-FiraCodeFontInEditors: Failed to patch Notepad++ stylers.xml: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "`tNotepad++ stylers.xml not found. Skipping." -ForegroundColor DarkGray
    }
}

function Set-WindowsTerminalAppearance {
    Write-Host "`n - Applying Windows Terminal appearance settings..."

    $settingsPath = Get-WindowsTerminalSettingsPath
    if (-not $settingsPath) {
        Write-Host "`tWindows Terminal settings.json not found. Skipping." -ForegroundColor DarkGray
        return
    }

    try {
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop

        if (-not $json.profiles) {
            $json | Add-Member -MemberType NoteProperty -Name profiles -Value @{ defaults = @{} }
        } elseif (-not $json.profiles.defaults) {
            $json.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value @{}
        }

        if (-not $json.profiles.defaults.PSObject.Properties["font"]) {
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value @{}
        }

        if (-not $json.profiles.defaults.PSObject.Properties["colorScheme"]) {
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name colorScheme -Value ""
        }

        $json.profiles.defaults.font.face = $FONT_NAME
        $json.profiles.defaults.colorScheme = $TERMINAL_COLOR_SCHEME

        $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $settingsPath -ErrorAction Stop
    }
    catch {
        throw "Set-WindowsTerminalAppearance failed: $($_.Exception.Message)"
    }
}

function Set-WindowsTerminalDefaultProfile {
    Write-Host "`n - Setting Windows Terminal default profile..."

    # Get the path to settings.json
    $settingsPath = Get-WindowsTerminalSettingsPath
    if (-not $settingsPath) {
        Write-Host "`tWindows Terminal settings.json not found. Skipping." -ForegroundColor DarkGray
        return
    }

    try {
        # Load and parse the JSON settings file
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop

        # Extract a list of all valid profile GUIDs from the settings
        $validGuids = @()
        if ($json.profiles.list) {
            $validGuids = $json.profiles.list | ForEach-Object { $_.guid.ToString() }
        }

        # Check current defaultProfile value (if any)
        $currentDefault = $json.defaultProfile

        # Validate the default profile is Ubuntu
        $currentDefaultProfile = $json.profiles.list | Where-Object { $_.guid -eq $currentDefault }
        $isValidDefault = $currentDefaultProfile -and
                          ($validGuids -contains $currentDefault) -and
                          ($currentDefaultProfile.name -like 'Ubuntu*')

        # If defaultProfile is not valid OR --default was explicitly passed
        if (-not $isValidDefault -or $default) {
            $ubuntu = $json.profiles.list | Where-Object {
                $_.name -like 'Ubuntu*' -and (
                    $_.name -eq $DISTRO_NAME -or
                    ($_.source -like "*WSL*" -and $_.name -like "*$DISTRO_NAME*")
                )
            } | Select-Object -First 1

            if ($ubuntu -and $ubuntu.guid) {
                $json.defaultProfile = $ubuntu.guid.ToString()
                Write-Host "`tDefault profile set to '$DISTRO_NAME'" -ForegroundColor DarkGray
            } else {
                Write-Host "`tCould not find matching WSL profile for '$DISTRO_NAME'" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`tDefault profile already set and valid. Skipping." -ForegroundColor DarkGray
        }

        # Save the updated settings back to disk
        $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $settingsPath -ErrorAction Stop
    }
    catch {
        throw "Set-WindowsTerminalDefaultProfile failed: $($_.Exception.Message)"
    }
}


function Get-WindowsTerminalSettingsPath {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json",
        "$env:APPDATA\Microsoft\Windows Terminal\settings.json"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Set-WslZshEnvironment {
    $localConfigPath = "$PSScriptRoot/configs"
    $remoteZshrcUrl = "$GITHUB_URI/configs/.zshrc"
    $remoteStarshipUrl = "$GITHUB_URI/configs/starship.toml"

    Write-Host "`n - Setting .zshrc and starship.toml configs into WSL..."

    try {
        $targetDir = ".config"

        Send-ToWslHome "$localConfigPath/.zshrc" "$remoteZshrcUrl" "$targetDir/zsh/.zshrc"
        Send-ToWslHome "$localConfigPath/starship.toml" "$remoteStarshipUrl" "$targetDir/starship/starship.toml"
    }
    catch {
        throw "Set-WslZshEnvironment failed: $($_.Exception.Message)"
    }
}

function Send-CustomScripts {
    $localScriptsPath = "$PSScriptRoot/scripts"
    $remoteScriptsUrl = "$GITHUB_URI/scripts"
    $targetDir = ".local/bin"

    Write-Host "`n - Sending custom scripts to WSL..."

    try {
        foreach ($script in $CUSTOM_SCRIPTS) {
            Send-ToWslHome "$localScriptsPath/$script" "$remoteScriptsUrl/$script" "$targetDir/$script"
        }
    }
    catch {
        throw "Send-CustomScripts failed: $($_.Exception.Message)"
    }
}

Write-Host "`n========================================================" -ForegroundColor DarkYellow
Write-Host "         WSL Full Developer Setup Starting" -ForegroundColor DarkYellow
Write-Host "========================================================" -ForegroundColor DarkYellow

try {
    Test-RunningAsAdministrator

    # Install and setup WSL
    Enable-WSLFeatures
    Update-WSLKernel
    Install-UbuntuWslInstance
    Add-LinuxUserWithSudo
    Write-WslConfigOnWsl
    Write-WslConfigOnWindows
    Set-WslZshEnvironment
    Send-CustomScripts
    Invoke-WSLSetupScript

    Ensure-WinGetReady
    Update-WingetSources
    foreach ($package in $WINGET_PACKAGES) {
        Install-WingetPackage -PackageName $package
    }

    Install-NerdFontFiraCode

    # Configure Windows Terminal and editors with FiraCode font
    Open-AppsForFirstTime
    Set-FiraCodeFontInEditors
    Set-WindowsTerminalAppearance
    Set-WindowsTerminalDefaultProfile

    Write-Host "`nWSL Full Developer Setup Complete." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    
    Write-Host "`n[Press Enter to exit]" -ForegroundColor Yellow
    Read-Host
    exit 1
}
