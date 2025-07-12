$DISTRO = "Ubuntu"
$LINUX_USER = "devuser"
$FONT_NAME = "FiraCode Nerd Font"
$GITHUB_URI = "https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main"

# Run a command in WSL as $LINUX_USER
function Invoke-Wsl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $bashCommand = "`"$Command`""

    $wslArgs = @(
        '-d', $distro,
        '-u', $LINUX_USER,
        '--', 'bash', '-c', $bashCommand
    )

    return wsl @wslArgs
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
        $result = Invoke-Wsl "mkdir -p '$targetDir'" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create target directory: '$targetDir'. Error: $result"
        }
        
        if (Test-Path $localPath) {
            # Copy local file into WSL using base64 to preserve Unicode characters
            $bytes = [System.IO.File]::ReadAllBytes($localPath)
            $base64 = [Convert]::ToBase64String($bytes)
            $result = Invoke-Wsl "echo '$base64' | base64 -d > '$targetPath'" 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to copy local file to WSL: $localPath. Error: $result"
            }

            # Set execution permission if file is .sh
            if ($targetPath -like '*.sh') {
                Invoke-Wsl "chmod +x '$targetPath'"
            }

            Write-Host "`tLocal file copied to WSL: $targetPath" -ForegroundColor DarkGray

        }
        else {
            # Download remote file into WSL
            $result = Invoke-Wsl "curl -fsSL '$remoteUrl' -o '$targetPath'" 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to download $(Split-Path $targetPath -Leaf) from $remoteUrl. Error: $result"
            }

            # Set execution permission if file is .sh
            if ($targetPath -like '*.sh') {
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
        Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
        exit 1
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
        Write-Host "  Chocolatey command failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Install-WingetPackage {
    param (
        [Parameter(Mandatory)]
        [string]$PackageId
    )

    Write-Host "`n - Installing package: $PackageId..."

    try {
        # Escape special characters for Select-String (like +, ., etc.)
        $escapedId = [Regex]::Escape($PackageId)

        # Check if the package is already installed
        $installed = winget list --id "$PackageId" --source winget 2>$null | Select-String "$escapedId" -Quiet

        if (-not $installed) {
            # Install the package silently
            winget install --id "$PackageId" -e -h --accept-source-agreements --accept-package-agreements *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "Install failed for package '$PackageId'"
            }
        }
    }
    catch {
        Write-Host "  Winget command failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Enable-WSLFeatures {
    Write-Host "`n - Enabling WSL and Virtual Machine Platform..."

    $restartRequired = $false

    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart *> $null
    if ($LASTEXITCODE -eq 3010) {
        $restartRequired = $true
    } elseif ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to enable Microsoft-Windows-Subsystem-Linux (exit code $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }

    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart *> $null
    if ($LASTEXITCODE -eq 3010) {
        $restartRequired = $true
    } elseif ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to enable VirtualMachinePlatform (exit code $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }

    if ($restartRequired) {
        Write-Host "Restart required to complete WSL setup." -ForegroundColor Red
        exit 1
    }

    Write-Host "WSL and Virtual Machine Platform enabled successfully." -ForegroundColor Green
}

function Install-WSLKernel {
    Write-Host "`n - Updating WSL kernel..."

    try {
        wsl --update *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "WSL kernel update failed (exit code $LASTEXITCODE)"
        }
    }
    catch {
        Write-Host "Failed to update WSL kernel: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Install-Distro {
    Write-Host "`n - Installing $DISTRO..."

    try {
        $distroInstalled = wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $DISTRO }

        if (-not $distroInstalled) {
            wsl --install -d $DISTRO --no-launch *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "$DISTRO installation failed (exit code $LASTEXITCODE)"
            }
        }

        # Check if distro is initialized
        wsl -d $DISTRO -- echo "$DISTRO initialized" *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "$DISTRO failed to initialize (exit code $LASTEXITCODE)"
        }
    }
    catch {
        Write-Host "Error: Failed to check, install, or initialize $DISTRO - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Add-LinuxUserWithSudo {
    Write-Host "`n - Creating user '$LINUX_USER' with passwordless sudo..."

    try {
        # Check if the user already exists inside distro
        $userExists = wsl -d $DISTRO -- bash -c "id -u $LINUX_USER >/dev/null 2>&1 && echo yes || echo no" |
        ForEach-Object { $_.Trim() }

        if ($userExists -eq "yes") {
            $command = "sudo usermod -aG sudo $LINUX_USER; echo '$LINUX_USER ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$LINUX_USER > /dev/null; sudo chmod 0440 /etc/sudoers.d/$LINUX_USER"
        }
        else {
            $command = "sudo adduser --disabled-password --gecos '' $LINUX_USER; echo '$LINUX_USER ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$LINUX_USER > /dev/null; sudo usermod -aG sudo $LINUX_USER; sudo chmod 0440 /etc/sudoers.d/$LINUX_USER"
        }

        # Pass it into WSL with proper quoting
        wsl -d $DISTRO -- bash -c "`"$command`"" *> $null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create or configure user '$LINUX_USER'"
        }

        # Confirm NOPASSWD works
        wsl -d $DISTRO -- sudo -n true 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Passwordless sudo is NOT configured properly for '$LINUX_USER'." -ForegroundColor Red
            Write-Host "Please verify /etc/sudoers.d/$LINUX_USER exists and is correct." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Set-DefaultWSLUser {
    Write-Host "`n - Setting '$LINUX_USER' as default WSL user..."

    try {
        $lxssPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        $guid = (Get-ItemProperty "$lxssPath\*" |
            Where-Object { $_.DistributionName -eq $DISTRO }).PSChildName

        if (-not $guid) {
            throw "$DISTRO not found in registry."
        }

        $uid = wsl -d $DISTRO -- bash -c "id -u $LINUX_USER" 2>$null
        $uid = $uid.Trim()

        if (-not ($uid -match '^\d+$')) {
            throw "User '$LINUX_USER' returned invalid UID: '$uid'"
        }

        Set-ItemProperty -Path "$lxssPath\$guid" -Name DefaultUid -Value ([int]$uid) -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to set default WSL user: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Write-WSLConfig {
    Write-Host "`n - Writing .wslconfig with performance optimizations..."

    try {
        $configPath = "$env:USERPROFILE\.wslconfig"

        $sys = Get-CimInstance Win32_ComputerSystem
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
"@ | Set-Content -Encoding UTF8 -Path $configPath -Force

        Write-Host "`t.wslconfig written with $allocMem GB and $cpuCount CPUs." -ForegroundColor DarkGray
    }
    catch {
        Write-Host "Failed to write .wslconfig: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-WSLSetupScript {
    param (
        [string]$localScriptPath = "$PSScriptRoot\scripts\setup-ubuntu.sh",
        [string]$remoteScriptUrl = "$GITHUB_URI/scripts/setup-ubuntu.sh"
    )

    Write-Host "`n - Installing developer tools in WSL..."

    try {
        Send-ToWslHome $localScriptPath $remoteScriptUrl "wsl-init.sh"

        # Execute setup script
        Invoke-Wsl "/home/$LINUX_USER/wsl-init.sh"

        wsl --shutdown
    }
    catch {
        Write-Host "  Failed to execute setup-ubuntu.sh in WSL: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Install-Chocolatey {
    Write-Host "`n - Installing Chocolatey..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        # update Chocolatey if already installed
        Install-ChocoPackage -PackageName "chocolatey"
        return
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        $chocoScript = "$env:TEMP\install-choco.ps1"
        Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -OutFile $chocoScript -UseBasicParsing -ErrorAction Stop

        powershell -NoProfile -ExecutionPolicy Bypass -File $chocoScript *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey install script failed (exit code $LASTEXITCODE)"
        }

        Remove-Item $chocoScript -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "  Chocolatey installation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Install-NerdFontFiraCode {
    [CmdletBinding()]
    param ()

    $ErrorActionPreference = 'Stop'

    try {
        $fontZipName = "FiraCode.zip"
        $tempZipPath = "$env:TEMP\$fontZipName"
        $extractPath = "$env:TEMP\FiraCodeFont"
        $fontsFolder = "$env:WINDIR\Fonts"

        # Remove existing fonts matching Fira*.ttf
        Get-ChildItem -Path $fontsFolder -Include "Fira*.ttf" -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Force -ErrorAction Stop *>$null 2>&1
            }
            catch {}
        }

        # Get latest GitHub release
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" `
            -Headers @{ "User-Agent" = "PowerShell" }

        $asset = $release.assets | Where-Object { $_.name -eq $fontZipName }

        if (-not $asset) { return }

        # Download FiraCode.zip
        if (Test-Path $tempZipPath) { Remove-Item $tempZipPath -Force *>$null 2>&1 }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZipPath *>$null 2>&1

        # Extract archive
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force *>$null 2>&1 }
        Expand-Archive -Path $tempZipPath -DestinationPath $extractPath -Force *>$null 2>&1

        # Install fonts
        Get-ChildItem -Path $extractPath -Recurse -Include *.ttf -ErrorAction SilentlyContinue |
        ForEach-Object {
            $destPath = Join-Path $fontsFolder $_.Name
            if (-not (Test-Path $destPath)) {
                Copy-Item -Path $_.FullName -Destination $destPath -Force *>$null 2>&1
            }
        }
    }
    catch {
        Write-Host "FiraCode Nerd Font installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-And-Close-EditorsWhenReady {
    Write-Host "`n - Getting things ready to set FiraCode Nerd Font in editors..."

    $editors = @(
        @{ name = "VS Code"; exe = "code"; args = $null; process = "Code" },
        @{ name = "Cursor IDE"; exe = "cursor"; args = $null; process = "Cursor" },
        @{ name = "Notepad++"; exe = "notepad++.exe"; args = "$env:APPDATA\Notepad++\stylers.xml"; process = "notepad++" }
        @{ name = "Windows Terminal"; exe = "wt.exe"; args = $null; process = "WindowsTerminal" }
    )

    $jobs = @()

    foreach ($editor in $editors) {
        $job = Start-Job -ScriptBlock {
            param ($editor)

            try {
                $alreadyRunning = Get-Process -Name $editor.process -ErrorAction SilentlyContinue
                if ($alreadyRunning) {
                    return
                }

                if ($editor.args) {
                    Start-Process -FilePath $editor.exe -ArgumentList $editor.args -WindowStyle Minimized
                }
                else {
                    Start-Process -FilePath $editor.exe -WindowStyle Minimized
                }

                $timeoutMs = 10000
                $intervalMs = 200
                $elapsed = 0
                $readyProc = $null

                while ($elapsed -lt $timeoutMs) {
                    $readyProc = Get-Process -Name $editor.process -ErrorAction SilentlyContinue |
                    Where-Object { $_.MainWindowHandle -ne 0 }

                    if ($readyProc) { break }

                    Start-Sleep -Milliseconds $intervalMs
                    $elapsed += $intervalMs
                }

                if ($readyProc) {
                    $readyProc | Stop-Process -Force
                }
                else {
                    Write-Host "   $($editor.name) never showed a window. Skipping." -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "   Failed to launch or close $($editor.name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } -ArgumentList $editor

        $jobs += $job
    }

    # Wait for all jobs to finish
    $jobs | Wait-Job | ForEach-Object { Receive-Job $_; Remove-Job $_ }
}

function Set-FiraCodeFontInEditors {
    Write-Host "`n - Setting FiraCode Nerd Font in editors..."

    $editors = @{
        "VS Code"    = "$env:APPDATA\Code\User\settings.json"
        "Cursor IDE" = "$env:APPDATA\Cursor\User\settings.json"
    }

    $fontSize = 14

    foreach ($name in $editors.Keys) {
        $path = $editors[$name]
        try {
            if (-not (Test-Path $path)) {
                New-Item -Path (Split-Path $path) -ItemType Directory -Force | Out-Null
                $settings = @{ editor = @{ fontFamily = $FONT_NAME; fontSize = $fontSize; fontLigatures = $true } }
            }
            else {
                $json = Get-Content $path -Raw
                $settings = $json | ConvertFrom-Json -ErrorAction Stop

                if (-not $settings.editor) { $settings | Add-Member -MemberType NoteProperty -Name editor -Value @{} }
                $settings.editor.fontFamily = $FONT_NAME
                $settings.editor.fontSize = $fontSize
                $settings.editor.fontLigatures = $true
            }

            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        }
        catch {
            Write-Host "   Failed to update $name in $editors[$name] settings: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    $stylersPath = "$env:APPDATA\Notepad++\stylers.xml"
    if (Test-Path $stylersPath) {
        try {
            $content = Get-Content $stylersPath -Raw

            # Match only the Default Style line inside GlobalStyles
            $pattern = '<WidgetStyle name="Default Style"([^>]*)>'
            if ($content -match $pattern) {
                $original = $matches[0]

                # Replace fontName and fontSize safely
                $patched = $original `
                    -replace 'fontName="[^"]*"', "fontName=`"$FONT_NAME`"" `
                    -replace 'fontSize="[^"]*"', 'fontSize="11"'

                $newContent = $content -replace [regex]::Escape($original), [regex]::Escape($patched) -replace '\\', ''

                Set-Content -Path $stylersPath -Value $newContent -Encoding Default
            }
            else {
                Write-Host "   Default Style not found in Notepad++ stylers.xml: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "   Failed to patch Notepad++ stylers.xml: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "   Notepad++ stylers.xml not found. Skipping: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Set-WindowsTerminalSettings {
    Write-Host "`n - Setting Windows Terminal settings..."

    $settingsPath = Get-WindowsTerminalSettingsPath

    if (-not $settingsPath) {
        return
    }

    try {
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json

        # Ensure profiles and defaults exist
        if (-not $json.profiles) {
            $json | Add-Member -MemberType NoteProperty -Name profiles -Value @{ defaults = @{} }
        }
        elseif (-not $json.profiles.defaults) {
            $json.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value @{}
        }

        # Set font and color scheme safely
        if (-not $json.profiles.defaults.PSObject.Properties["font"]) {
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value @{}
        }

        if (-not $json.profiles.defaults.PSObject.Properties["colorScheme"]) {
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name colorScheme -Value ""
        }

        $json.profiles.defaults.font.face = $FONT_NAME
        $json.profiles.defaults.colorScheme = "One Half Dark"

        # Set defaultProfile to $DISTRO if found
        $ubuntu = $json.profiles.list | Where-Object {
            $_.name -eq $DISTRO -or ($_.source -like "*WSL*" -and $_.name -like "*$DISTRO*")
        } | Select-Object -First 1

        if ($ubuntu -and $ubuntu.guid) {
            $json.defaultProfile = $ubuntu.guid.ToString()
        }

        $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $settingsPath
    }
    catch {
        Write-Host "   Could not apply Windows Terminal settings: $($_.Exception.Message)" -ForegroundColor Yellow
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

    Write-Warning "`tWindows Terminal settings.json not found in known locations." -ForegroundColor Yellow
    return $null
}

function Remove-WindowsTerminalSettings {
    $settingsPath = Get-WindowsTerminalSettingsPath
    if ($settingsPath) {
        Remove-Item -Path $settingsPath -Force
    }
}

function Set-WslZshEnvironment {
    $localConfigPath = "$PSScriptRoot/configs"
    $remoteZshrcUrl = $GITHUB_URI + "/configs/.zshrc"
    $remoteStarshipUrl = $GITHUB_URI + "/configs/starship.toml"

    Write-Host "`n - Setting .zshrc and starship.toml configs into WSL..."

    try {
        $targetDir = ".config"

        Send-ToWslHome "$localConfigPath/.zshrc" "$remoteZshrcUrl" "$targetDir/zsh/.zshrc"
        Send-ToWslHome "$localConfigPath/starship.toml" "$remoteStarshipUrl" "$targetDir/starship/starship.toml"
    }
    catch {
        Write-Host "   Failed to install .zshrc: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Send-CustomScripts {
    $localScriptsPath = "$PSScriptRoot/scripts"
    $remoteScriptsUrl = $GITHUB_URI + "/scripts"

    Write-Host "`n - Sending custom scripts to WSL..."

    try {
        Send-ToWslHome "$localScriptsPath/login-eks.sh" "$remoteScriptsUrl/login-eks.sh" "scripts/login-eks.sh"
        Send-ToWslHome "$localScriptsPath/login-ecr.sh" "$remoteScriptsUrl/login-ecr.sh" "scripts/login-ecr.sh"
    }
    catch {
        Write-Host "`tFailed to send custom scripts: $($_.Exception.Message)" -ForegroundColor Red
    }
}


Write-Host "`n========================================================" -ForegroundColor DarkYellow
Write-Host "         WSL Full Developer Setup Starting" -ForegroundColor DarkYellow
Write-Host "========================================================" -ForegroundColor DarkYellow

Test-RunningAsAdministrator

# Install and setup WSL
Enable-WSLFeatures
Install-WSLKernel
Install-Distro
Add-LinuxUserWithSudo
Set-DefaultWSLUser
Write-WSLConfig
Set-WslZshEnvironment
Send-CustomScripts
Invoke-WSLSetupScript

# Install tools via Chocolatey or Winget
Install-WingetPackage -PackageId "Microsoft.WindowsTerminal"
Install-WingetPackage -PackageId "Notepad++.Notepad++"
Install-WingetPackage -PackageId "Microsoft.VisualStudioCode"
Install-WingetPackage -PackageId "Anysphere.Cursor"
Install-WingetPackage -PackageId "JetBrains.IntelliJIDEA.Ultimate"
Install-Chocolatey

# Install FiraCode font
Install-NerdFontFiraCode

# Configure Windows Terminal and editors with FiraCode font
Remove-WindowsTerminalSettings
Start-And-Close-EditorsWhenReady
Set-FiraCodeFontInEditors
Set-WindowsTerminalSettings

Write-Host "`nWSL Full Developer Setup Complete." -ForegroundColor Green