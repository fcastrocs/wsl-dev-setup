# Reverse WSL Full Developer Setup Script

# Helper: Confirm running as Administrator
function Test-RunningAsAdministrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
        exit 1
    }
}

# Remove Windows Terminal settings
function Remove-WindowsTerminalSettings {
    $settingsPath = Get-WindowsTerminalSettingsPath
    if ($settingsPath) {
        Remove-Item -Path $settingsPath -Force -ErrorAction SilentlyContinue
        Write-Host " - Removed Windows Terminal settings.json" -ForegroundColor DarkGray
    }
}

# Get Windows Terminal settings path
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

# Remove installed fonts
function Remove-FiraCodeFont {
    Write-Host " - Removing FiraCode Nerd Fonts..." -ForegroundColor DarkGray
    $fontsPath = Join-Path $env:WINDIR 'Fonts'
    $fontFiles = Get-ChildItem -Path $fontsPath -Filter "FiraCode*" -Include *.ttf, *.otf -ErrorAction SilentlyContinue

    foreach ($font in $fontFiles) {
        try {
            Remove-Item -Path $font.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "   Removed: $($font.Name)" -ForegroundColor DarkGray
        } catch {
            Write-Host "   Failed to remove font: $($font.Name)" -ForegroundColor Yellow
        }
    }
}

# Uninstall applications via winget
function Uninstall-WingetPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageName
    )
    
    try {
        $wingetList = winget list --id $PackageName --exact *>$null 2>$null
        if ($LASTEXITCODE -eq 0) {
            winget uninstall --id $PackageName --silent --force --accept-source-agreements *>$null 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Winget uninstall failed with exit code $LASTEXITCODE"
            }
        }
    }
    catch {
        Write-Error "Failed to uninstall $PackageName`: $($_.Exception.Message)"
    }
}

# Disable WSL features
function Disable-WSLFeatures {
    Write-Host " - Disabling WSL and Virtual Machine Platform..." -ForegroundColor DarkGray

    & "$env:windir\\System32\\dism.exe" /online /disable-feature /featurename:VirtualMachinePlatform /norestart *> $null
    & "$env:windir\\System32\\dism.exe" /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart *> $null
}

# Unregister and clean WSL
function Remove-WSLDistro {
    $distro = "Ubuntu"
    try {
        wsl --unregister $distro *>$null 2>&1
        Write-Host " - Unregistered WSL distro: $distro" -ForegroundColor DarkGray
    } catch {
        Write-Host "   Failed to unregister WSL distro: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $paths = @(
        "$env:USERPROFILE\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu*",
        "$env:USERPROFILE\AppData\Local\Packages\CanonicalGroupLimited.UbuntuonWindows*",
        "$env:LOCALAPPDATA\lxss"
    )

    foreach ($p in $paths) {
        Get-ChildItem -Path (Split-Path $p -Parent) -Filter (Split-Path $p -Leaf) -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host " - Cleaned up leftover WSL data folders" -ForegroundColor DarkGray
}

# Uninstall Chocolatey
function Uninstall-Chocolatey {
    $chocoPath = "$env:ProgramData\chocolatey"
    if (Test-Path $chocoPath) {
        try {
            Remove-Item -Path $chocoPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host " - Chocolatey directory removed" -ForegroundColor DarkGray
        } catch {
            Write-Host "   Failed to remove Chocolatey directory" -ForegroundColor Yellow
        }
    }

    $envPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    if ($envPath -like "*chocolatey*") {
        $newPath = ($envPath -split ";" | Where-Object { $_ -notmatch "chocolatey" }) -join ";"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)
    }
}

# Entry
Write-Host "`n========================================================" -ForegroundColor DarkYellow
Write-Host "         Reversing WSL Developer Setup" -ForegroundColor DarkYellow
Write-Host "========================================================" -ForegroundColor DarkYellow

Test-RunningAsAdministrator

# Revert actions
Remove-WindowsTerminalSettings
Remove-FiraCodeFont

Uninstall-WingetPackage "Microsoft.WindowsTerminal"
Uninstall-WingetPackage "Notepad++.Notepad++"
# Uninstall-WingetPackage "Microsoft.VisualStudioCode"
Uninstall-WingetPackage "Anysphere.Cursor"
Uninstall-WingetPackage "JetBrains.IntelliJIDEA.Ultimate"

Uninstall-Chocolatey
Remove-WSLDistro
Disable-WSLFeatures

Write-Host "`nWSL Developer Setup Reversed." -ForegroundColor Green
