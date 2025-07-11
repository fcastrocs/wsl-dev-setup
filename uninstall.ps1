$restartRequired = $false
$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host "Uninstalling WSL..."

wsl --shutdown *> $null
wsl --unregister Ubuntu *> $null

# Remove Ubuntu from Microsoft Store (if installed via Store)
$ubuntuPackages = Get-AppxPackage | Where-Object { $_.Name -like "*Ubuntu*" }
if ($ubuntuPackages) {
    foreach ($package in $ubuntuPackages) {
        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
    }
}

# Disable WSL features
dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart > $null 2>&1
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart > $null 2>&1
if ($LASTEXITCODE -eq 3010) {
    $restartRequired = $true
} elseif ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to disable WSL (exit code $LASTEXITCODE)" -ForegroundColor Red
}

# Remove Ubuntu profiles from Windows Terminal
if (Test-Path $terminalSettingsPath) {
    try {
        $settings = Get-Content $terminalSettingsPath -Raw | ConvertFrom-Json

        # Remove Ubuntu/WSL profiles
        if ($settings.profiles -and $settings.profiles.list) {
            $settings.profiles.list = $settings.profiles.list | Where-Object {
                $_.name -ne "Ubuntu" -and $_.source -ne "Microsoft.WSL"
            }
        }

        # Remove the defaultProfile property
        $settings.PSObject.Properties.Remove("defaultProfile")

        # Write the modified settings back to the file
        $settings | ConvertTo-Json -Depth 10 | Set-Content $terminalSettingsPath -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "Failed to modify Windows Terminal settings: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($restartRequired) {
    Write-Host "Restart required to completely disable WSL" -ForegroundColor Yellow
}