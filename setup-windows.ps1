# ================================
# WSL Full Dev Setup (PowerShell)
# ================================
# This script automates the complete setup of a full Windows Subsystem for Linux (WSL2)
# development environment. It is designed for developers who want a clean, fast,
# Linux-like setup on Windows 11. It must be run as Administrator.
#
# What this script does:
# 1. Enables WSL2 and Virtual Machine Platform features
# 2. Installs the latest WSL2 kernel
# 3. Installs Windows Terminal
# 4. Installs Ubuntu LTS via WSL
# 5. Writes a `.wslconfig` file for performance
# 6. Installs the Fira Code font
# 7. Sets Windows Terminal settings to:
#    - Default profile to Ubuntu
#    - Font set to "Fira Code"
#    - Color scheme to "One Half Dark"
# 8. Runs a `setup-ubuntu.sh` script inside Ubuntu to install developer tools
# 9. Installs Chocolatey and uses it to install key developer tools on Windows
#
# All steps are silent or minimal-interaction, making this ideal for scripting or onboarding automation.
# ================================

$linuxUser = "devuser"
$fontName = "FiraCode Nerd Font"


function Test-RunningAsAdministrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }
}

function Enable-WSLFeatures {
    Write-Host "`n - Enabling WSL and Virtual Machine Platform..."

    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable Microsoft-Windows-Subsystem-Linux (exit code $LASTEXITCODE)"
        }

        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable VirtualMachinePlatform (exit code $LASTEXITCODE)"
        }
    }
    catch {
        Write-Host "Failed to enable WSL or VM Platform: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
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

function Install-Ubuntu {
    Write-Host "`n - Installing Ubuntu LTS..."

    try {
        $ubuntuInstalled = wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq "Ubuntu" }

        if (-not $ubuntuInstalled) {
            wsl --install -d Ubuntu --no-launch *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "Ubuntu installation failed (exit code $LASTEXITCODE)"
            }
        }

        # Check if Ubuntu is initialized
        wsl -d Ubuntu -- echo "Ubuntu initialized" *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Ubuntu failed to initialize (exit code $LASTEXITCODE)"
        }
    }
    catch {
        Write-Host "Error: Failed to check, install, or initialize Ubuntu - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Add-LinuxUserWithSudo {
    Write-Host "`n - Creating user '$linuxUser' with passwordless sudo..."

    try {
        # Check if the user already exists inside Ubuntu
        $userExists = wsl -d Ubuntu -- bash -c "id -u $linuxUser >/dev/null 2>&1 && echo yes || echo no" |
        ForEach-Object { $_.Trim() }

        if ($userExists -eq "yes") {
            $command = "sudo usermod -aG sudo $linuxUser; echo '$linuxUser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$linuxUser > /dev/null; sudo chmod 0440 /etc/sudoers.d/$linuxUser"
        }
        else {
            $command = "sudo adduser --disabled-password --gecos '' $linuxUser; echo '$linuxUser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$linuxUser > /dev/null; sudo usermod -aG sudo $linuxUser; sudo chmod 0440 /etc/sudoers.d/$linuxUser"
        }

        # Pass it into WSL with proper quoting
        wsl -d Ubuntu -- bash -c "`"$command`"" *> $null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create or configure user '$linuxUser'"
        }
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Set-DefaultWSLUser {
    Write-Host "`n - Setting '$linuxUser' as default WSL user..."

    try {
        $lxssPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        $guid = (Get-ItemProperty "$lxssPath\*" |
            Where-Object { $_.DistributionName -eq "Ubuntu" }).PSChildName

        if (-not $guid) {
            throw "Ubuntu not found in registry."
        }

        $uid = wsl -d Ubuntu -- bash -c "id -u $linuxUser" 2>$null
        $uid = $uid.Trim()

        if (-not ($uid -match '^\d+$')) {
            throw "User '$linuxUser' returned invalid UID: '$uid'"
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

        Write-Host "`t.wslconfig written with $allocMem GB and $cpuCount CPUs." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to write .wslconfig: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-WSLSetupScript {
    param (
        [string]$distro = "Ubuntu",
        [string]$localScriptPath = "$PSScriptRoot\setup-ubuntu.sh",
        [string]$remoteScriptUrl = "https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main/setup-ubuntu.sh"
    )

    Write-Host "`n - Installing developer tools in WSL..."

    try {
        # Prepare setup directory in WSL
        wsl -d $distro -- bash -c "mkdir -p ~/setup && rm -f ~/setup/wsl-init.sh"

        if (Test-Path $localScriptPath) {
            Get-Content $localScriptPath -Raw | wsl -d $distro -- bash -c "cat > ~/setup/wsl-init.sh"
        }
        else {
            wsl -d $distro -- bash -c "curl -fsSL '$remoteScriptUrl' -o ~/setup/wsl-init.sh"
        }

        # Execute setup script
        wsl -d $distro -- bash -c "chmod +x ~/setup/wsl-init.sh && ~/setup/wsl-init.sh"

        # Cleanup
        wsl -d $distro -- bash -c "rm -rf ~/setup"
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
                throw "Upgrade failed for package '$PackageName'"
            }
        }
        else {
            choco install $PackageName -y *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "Install failed for package '$PackageName'"
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
                $settings = @{ editor = @{ fontFamily = $fontName; fontSize = $fontSize; fontLigatures = $true } }
            }
            else {
                $json = Get-Content $path -Raw
                $settings = $json | ConvertFrom-Json -ErrorAction Stop

                if (-not $settings.editor) { $settings | Add-Member -MemberType NoteProperty -Name editor -Value @{} }
                $settings.editor.fontFamily = $fontName
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
                    -replace 'fontName="[^"]*"', "fontName=`"$fontName`"" `
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

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

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

        $json.profiles.defaults.font.face = $fontName
        $json.profiles.defaults.colorScheme = "One Half Dark"

        # Set defaultProfile to Ubuntu if found
        $ubuntu = $json.profiles.list | Where-Object {
            $_.name -eq "Ubuntu" -or ($_.source -like "*WSL*" -and $_.name -like "*Ubuntu*")
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

Write-Host "`n==============================="
Write-Host " WSL Full Developer Setup Starting"
Write-Host "==============================="

Test-RunningAsAdministrator

# Install and setup WSL
Enable-WSLFeatures
Install-WSLKernel
Install-Ubuntu
Add-LinuxUserWithSudo
Set-DefaultWSLUser
Write-WSLConfig
Invoke-WSLSetupScript

# Install tools via Chocolatey or Winget
Install-WingetPackage -PackageId "Microsoft.WindowsTerminal"
Install-WingetPackage -PackageId "Notepad++.Notepad++"
Install-WingetPackage -PackageId "Microsoft.VisualStudioCode"
Install-WingetPackage -PackageId "Anysphere.Cursor"
Install-WingetPackage -PackageId "JetBrains.IntelliJIDEA.Ultimate"
Install-Chocolatey

# Configure Windows Terminal and editors with FiraCode font
Install-NerdFontFiraCode
Start-And-Close-EditorsWhenReady
Set-FiraCodeFontInEditors
Set-WindowsTerminalSettings

# additional packages can be added here. use Install-ChocoPackage or Install-WingetPackage



Write-Host "`nWSL Full Developer Setup Complete." -ForegroundColor Green