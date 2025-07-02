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

function Test-RunningAsAdministrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "ERROR: This script must be run as Administrator!"
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }
}

function Enable-WSLFeatures {
    Write-Host "`n - Enabling WSL and Virtual Machine Platform..."
    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >> output.log 2>&1
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >> output.log 2>&1
    }
    catch {
        Write-Host "Failed to enable WSL or VM Platform" -ForegroundColor Red
        exit 1
    }
}

function Install-WSLKernel {
    Write-Host "`n - Installing latest WSL kernel..."
    try {
        $msi = "$env:TEMP\wsl_update_x64.msi"
        Invoke-WebRequest "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile $msi *>> output.log
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /quiet" *>> output.log
        Remove-Item $msi -Force *>> output.log
    }
    catch {
        Write-Host "WSL kernel install failed. See output.log for details." -ForegroundColor Red
    }
}

function Install-UbuntuIfMissing {
    Write-Host "`n - Checking for Ubuntu LTS installation..."
    $ubuntuInstalled = wsl -l -q 2>$null | Where-Object { $_.Trim() -eq "Ubuntu" }
    if (-not $ubuntuInstalled) {
        wsl --install -d Ubuntu --no-launch >> output.log 2>&1
    }
    else {
        Write-Host "   Ubuntu LTS already installed..." -ForegroundColor Yellow
    }
    wsl -d Ubuntu -- echo "Ubuntu initialized" >> output.log 2>&1
}

function Add-LinuxUserWithSudo {
    Write-Host " - Creating user '$linuxUser' with passwordless sudo..."

    $userExists = wsl -d Ubuntu -- bash -c "id -u $linuxUser >/dev/null 2>&1 && echo 'yes' || echo 'no'" | ForEach-Object { $_.Trim() }

    if ($userExists -eq "yes") {
        wsl -d Ubuntu -- bash -c "
            sudo usermod -aG sudo $linuxUser && \
            echo '$linuxUser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$linuxUser > /dev/null && \
            sudo chmod 0440 /etc/sudoers.d/$linuxUser
        " >> output.log 2>&1
    }
    else {
        wsl -d Ubuntu -- bash -c "
            sudo adduser --disabled-password --gecos '' $linuxUser && \
            echo '$linuxUser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$linuxUser > /dev/null && \
            sudo usermod -aG sudo $linuxUser && \
            sudo chmod 0440 /etc/sudoers.d/$linuxUser
        " >> output.log 2>&1
    }
}

function Set-DefaultWSLUser {
    Write-Host "`n - Setting '$linuxUser' as default WSL user..."
    $guid = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*" |
        Where-Object { $_.DistributionName -eq "Ubuntu" }).PSChildName

    if ($guid) {
        $uid = (wsl -d Ubuntu -- bash -c "id -u $linuxUser").Trim()
        if ($uid -match '^\d+$') {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\$guid" `
                -Name DefaultUid -Value ([int]$uid)
        }
        else {
            Write-Host "  User '$linuxUser' returned invalid UID. Cannot set default user." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Ubuntu not found in registry. Default user not set." -ForegroundColor Yellow
        "Failed to set default user: $($_.Exception.Message)" >> output.log
    }
}

function Write-WSLConfig {
    Write-Host "`n - Writing .wslconfig with performance optimizations..."
    try {
        $configPath = "$env:USERPROFILE\.wslconfig"

        $sys = Get-CimInstance Win32_ComputerSystem
        $totalMem = [math]::Floor($sys.TotalPhysicalMemory / 1GB)
        $cpuCount = $sys.NumberOfLogicalProcessors
        $allocMem = $totalMem

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
    }
    catch {
        Write-Host "Failed to write .wslconfig: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Install-Chocolatey {
    Write-Host "`n - Installing Chocolatey..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        # choco exists, this will upgrade it if needed
        Install-ChocoPackage -PackageName "chocolatey"
        return
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force >> output.log 2>&1
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        $chocoScript = "$env:TEMP\install-choco.ps1"
        Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -OutFile $chocoScript -UseBasicParsing >> output.log 2>&1
        powershell -NoProfile -ExecutionPolicy Bypass -File $chocoScript >> output.log 2>&1
        Remove-Item $chocoScript -Force >> output.log 2>&1
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

    Write-Host "`n - Installing or Upgrading Chocolatey package: $PackageName..."
    $isInstalled = choco list | Select-String -Pattern "^$PackageName" -Quiet

    if ($isInstalled) {
        choco upgrade $PackageName -y *>$null 2>> output.log
    }
    else {
        choco install $PackageName -y *>$null 2>> output.log
    }
}

function Clear-WindowsTerminalSettings {
    Write-Host "`n - Clearing Windows Terminal settings file..."

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $maxAttempts = 20
    $attempt = 0

    # Delete settings.json if it exists
    if (Test-Path $settingsPath) {
        Remove-Item $settingsPath -Force -ErrorAction SilentlyContinue
    }

    try {
        # Launch Windows Terminal in background
        $wtProcess = Start-Process wt.exe -PassThru -WindowStyle Hidden

        # Wait for settings.json to be recreated
        while (-not (Test-Path $settingsPath) -and $attempt -lt $maxAttempts) {
            Start-Sleep -Milliseconds 500
            $attempt++
        }

        if (Test-Path $settingsPath) {
            Start-Sleep -Milliseconds 500

            if ($wtProcess -and -not $wtProcess.HasExited) {
                $wtProcess.Kill()
                $wtProcess.WaitForExit(3000)
            }
        }
        else {
            Write-Host "   Settings file not created within timeout." -ForegroundColor Red
            if ($wtProcess -and -not $wtProcess.HasExited) {
                $wtProcess.Kill()
            }
        }
    }
    catch {
        Write-Host "   Failed to initialize Windows Terminal: $($_.Exception.Message)" -ForegroundColor Red
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

        $json.profiles.defaults.font.face = "Fira Code"
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

# function Set-FiraCodeFontInEditors {
#     Write-Host "`n[11/11] Setting Fira Code font in editors..." -ForegroundColor Cyan

#     $editors = @{
#         "VS Code"    = "$env:APPDATA\Code\User\settings.json"
#         "Cursor IDE" = "$env:APPDATA\Cursor\User\settings.json"
#     }

#     foreach ($name in $editors.Keys) {
#         $path = $editors[$name]
#         if (-not (Test-Path $path)) {
#             New-Item -Path (Split-Path $path) -ItemType Directory -Force | Out-Null
#             $data = @{ editor = @{ fontFamily = "Fira Code"; fontSize = 14; fontLigatures = $true } }
#         } else {
#             try {
#                 $raw = Get-Content $path -Raw | ConvertFrom-Json
#                 $data = @{}
#                 foreach ($p in $raw.PSObject.Properties) { $data[$p.Name] = $p.Value }
#                 if (-not $data.editor) { $data.editor = @{} }
#                 $data.editor.fontFamily = "Fira Code"
#                 $data.editor.fontSize = 14
#                 $data.editor.fontLigatures = $true
#             } catch {
#                 $data = @{ editor = @{ fontFamily = "Fira Code"; fontSize = 14; fontLigatures = $true } }
#             }
#         }
#         $data | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $path
#         Write-Host "   Set Fira Code font for $name"
#     }

#     $stylers = "$env:APPDATA\Notepad++\stylers.xml"
#     if (Test-Path $stylers) {
#         try {
#             [xml]$xml = Get-Content $stylers
#             $style = $xml.SelectNodes("//WidgetStyle") | Where-Object { $_.name -eq "Default Style" }
#             if ($style) {
#                 $style.SetAttribute("fontName", "Fira Code")
#                 $style.SetAttribute("fontSize", "11")
#                 $xml.Save($stylers)
#                 Write-Host "   Set Fira Code font for Notepad++"
#             } else {
#                 Write-Host "   Default Style not found in stylers.xml"
#             }
#         } catch {
#             Write-Host "   Failed to update Notepad++: $($_.Exception.Message)"
#         }
#     } else {
#         Write-Host "   Notepad++ stylers.xml not found. Skipping."
#     }
# }


# # Step 11: Set Fira Code font in editors
# Write-Host "`n[11/11] Setting Fira Code font in editors..."
# $editors = @{
#     "VS Code" = "$env:APPDATA\Code\User\settings.json"
#     "Cursor IDE" = "$env:APPDATA\Cursor\User\settings.json"
# }

# foreach ($name in $editors.Keys) {
#     $settingsPath = $editors[$name]
#     $settingsDir = Split-Path $settingsPath

#     # Ensure the directory exists
#     if (-Not (Test-Path $settingsDir)) {
#         New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
#     }

#     # If settings.json does not exist, start with an empty object
#     if (-Not (Test-Path $settingsPath)) {
#         $json = @{}
#     } else {
#         $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
#     }

#     # Modify font settings
#     $json."editor.fontFamily" = "Fira Code"
#     $json."editor.fontSize" = 14
#     $json."editor.fontLigatures" = $true

#     # Write updated settings
#     $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $settingsPath

#     Write-Host "Set Fira Font for $name"
# }


Write-Host "`n==============================="
Write-Host " WSL Full Developer Setup Starting"
Write-Host "==============================="

Test-RunningAsAdministrator
Enable-WSLFeatures
Install-WSLKernel
Install-UbuntuIfMissing
Add-LinuxUserWithSudo
Set-DefaultWSLUser
Write-WSLConfig
Invoke-WSLSetupScript

Install-Chocolatey
Install-ChocoPackage -PackageName "firacode"
Install-ChocoPackage -PackageName "Microsoft.WindowsTerminal"
Clear-WindowsTerminalSettings
Set-WindowsTerminalSettings
Install-ChocoPackage -PackageName "notepadplusplus.install"
Install-ChocoPackage -PackageName "vscode"
Install-ChocoPackage -PackageName "intellijidea-ultimate"
Install-ChocoPackage -PackageName "cursoride"
# additional packages can be added here

Write-Host "`nWSL Full Developer Setup Complete." -ForegroundColor Green