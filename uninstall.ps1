# WSL Developer Setup Reversal Script
# This script reverses the WSL developer setup by uninstalling packages, removing configurations, and disabling features

$WINGET_PACKAGES_TO_UNINSTALL = @(
    "Microsoft.WindowsTerminal",
    "Notepad++.Notepad++",
    "Microsoft.VisualStudioCode"
)

function Test-RunningAsAdministrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "ERROR: This script must be run as Administrator!"
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

function Remove-WindowsTerminalSettings {
    try {
        $settingsPath = Get-WindowsTerminalSettingsPath
        if ($settingsPath) {
            Remove-Item -Path $settingsPath -Force -ErrorAction Stop
            Write-Host " - Removed Windows Terminal settings.json" -ForegroundColor White
        }
    } catch {
        throw "Remove-WindowsTerminalSettings failed: $($_.Exception.Message)"
    }
}

function Uninstall-SysFont {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$FontFileName
    )

    if (-not ([Type]::GetType('FontApi.Native'))) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace FontApi {
    public static class Native {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern bool RemoveFontResourceExW(string lpFileName, uint fl, IntPtr pdv);

        [DllImport("user32.dll")]
        public static extern int SendMessageW(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    }
}
"@ | Out-Null
    }

    $FR_PRIVATE     = 0x10
    $WM_FONTCHANGE  = 0x001D
    $HWND_BROADCAST = [IntPtr]::Zero -bor 0xFFFF

    $FontsDir = Join-Path $env:WINDIR 'Fonts'
    $RegPath  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    if (-not ([Security.Principal.WindowsPrincipal] `
              [Security.Principal.WindowsIdentity]::GetCurrent()
             ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Uninstall-SysFont must be run as Administrator.'
    }

    foreach ($item in $FontFileName) {
        $leaf     = Split-Path $item -Leaf
        $fontPath = Join-Path $FontsDir $leaf

        if (-not (Test-Path $fontPath)) {
            Write-Warning "Font file not found: $leaf"
            continue
        }

        [FontApi.Native]::RemoveFontResourceExW($fontPath, $FR_PRIVATE, [IntPtr]::Zero) | Out-Null
        [FontApi.Native]::RemoveFontResourceExW($fontPath, 0,           [IntPtr]::Zero) | Out-Null

        try {
            $props = Get-ItemProperty -Path $RegPath
            $props.PSObject.Properties |
                Where-Object { $_.Value -ieq $leaf } |
                ForEach-Object {
                    Remove-ItemProperty -Path $RegPath -Name $_.Name -Force
                    Write-Host " - Removed registry entry: $($_.Name)" -ForegroundColor White
                }
        } catch {
            Write-Warning "Registry cleanup failed for $leaf : $_"
        }

        try {
            Remove-Item -LiteralPath $fontPath -Force
            Write-Host " - Deleted font file: $leaf" -ForegroundColor White
        } catch {
            Write-Warning "Failed to delete $leaf : $_"
        }
    }

    [FontApi.Native]::SendMessageW($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
}

function Uninstall-AllFonts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NameLike
    )

    $fontsDir = Join-Path $env:WINDIR 'Fonts'

    try {
        $pattern = "$NameLike*"
        $fontFiles = Get-ChildItem -Path $fontsDir -File -Filter $pattern -Include *.ttf, *.otf -ErrorAction Stop

        if (-not $fontFiles) {
            Write-Host " - No matching fonts found in Windows Fonts directory." -ForegroundColor White
            return
        }

        foreach ($font in $fontFiles) {
            Uninstall-SysFont $font.Name
        }
    }
    catch {
        Write-Warning "Uninstall-AllFonts failed: $($_.Exception.Message)"
    }
}

function Uninstall-WingetPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    try {
        $process = Start-Process winget `
            -ArgumentList @(
                "uninstall",
                "--id", $PackageName,
                "--exact",
                "--force",
                "--silent",
                "--disable-interactivity",
                "--accept-source-agreements",
                "--source", "winget"
            ) `
            -NoNewWindow `
            -Wait `
            -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Host " - Uninstalled (or not present): $PackageName" -ForegroundColor White
        } else {
            throw "Winget uninstall failed (exit code $($process.ExitCode))"
        }
    }
    catch {
        throw "Uninstall-WingetPackage failed for '$PackageName': $($_.Exception.Message)"
    }
}

function Disable-WSLFeatures {
    Write-Host " - Disabling WSL and Virtual Machine Platform..." -ForegroundColor White
    try {
        & "$env:windir\System32\dism.exe" /online /disable-feature /featurename:VirtualMachinePlatform /norestart *> $null
        & "$env:windir\System32\dism.exe" /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart *> $null
    } catch {
        throw "Disable-WSLFeatures failed: $($_.Exception.Message)"
    }
}

function Remove-WSLDistro {
    $distro = "Ubuntu"

    try {
        wsl --unregister $distro *> $null 2>&1
        Write-Host " - Unregistered WSL distro: $distro" -ForegroundColor White
    } catch {
        Write-Host "   Failed to unregister WSL distro: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
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

        Write-Host " - Cleaned up leftover WSL data folders" -ForegroundColor White
    } catch {
        throw "Remove-WSLDistro failed during cleanup: $($_.Exception.Message)"
    }
}

function Remove-WSLConfig {
    try {
        $configPath = "$env:USERPROFILE\.wslconfig"
        if (Test-Path $configPath) {
            Remove-Item -Path $configPath -Force -ErrorAction Stop
            Write-Host " - Removed .wslconfig" -ForegroundColor White
        }
    } catch {
        throw "Remove-WSLConfig failed: $($_.Exception.Message)"
    }
}

Write-Host "`n========================================================" -ForegroundColor White
Write-Host "         Reversing WSL Developer Setup" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor White

try {
    Test-RunningAsAdministrator

    Remove-WindowsTerminalSettings
    Uninstall-AllFonts -NameLike "FiraCode"

    foreach ($pkg in $WINGET_PACKAGES_TO_UNINSTALL) {
        Uninstall-WingetPackage $pkg
    }

    Remove-WSLDistro
    Disable-WSLFeatures
    Remove-WSLConfig

    Write-Host "`nWSL Developer Setup Reversed." -ForegroundColor Green
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n[Press Enter to exit]" -ForegroundColor Yellow
    Read-Host
    exit 1
}