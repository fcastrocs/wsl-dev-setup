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
# 8. Runs a `setup-linux.sh` script inside Ubuntu to install developer tools:
#    - Git
#    - GitHub CLI
#    - AWS CLI
#    - Zsh (shell)
#    - Oh My Zsh (Zsh framework)
#    - zsh-autosuggestions (Zsh plugin)
#    - Starship (prompt customization)
#    - OpenJDK 21
#    - Maven
#    - Node.js + NPM
#    - kubectl
#    - k9s
#    - kubetail
#    - Docker
# 9. Installs Chocolatey and uses it to install key developer tools on Windows:
#    - Notepad++
#    - Visual Studio Code
#    - IntelliJ IDEA Ultimate
#    - Cursor IDE
#
# All steps are silent or minimal-interaction, making this ideal for scripting or onboarding automation.
# ================================

# Ensure script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator!"
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
    exit 1
}

Write-Host "`n==============================="
Write-Host "WSL Full Dev Setup Starting"
Write-Host "==============================="

# Step 1: Enable WSL and VM Platform
Write-Host "`n[1/10] Enabling WSL and Virtual Machine Platform..."
try {
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart *> $null
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart *> $null
} catch {
    Write-Host "Failed to enable WSL or VM Platform" -ForegroundColor Red
    exit 1
}

# Step 2: Install latest WSL kernel
Write-Host "`n[2/10] Installing latest WSL kernel..."
try {
    $wslKernel = "$env:TEMP\wsl_update_x64.msi"
    Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile $wslKernel -UseBasicParsing
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$wslKernel`" /quiet"
    Remove-Item $wslKernel -Force
} catch {
	Write-Host "WSL lernal installation failed" -ForegroundColor Yellow
}

# Step 3: Install Windows Terminal
Write-Host "`n[3/11] Installing Windows Terminal..."
try {
    $term = winget list --id Microsoft.WindowsTerminal 2>$null
    if ($term -notmatch "Microsoft.WindowsTerminal") {
        winget install --id Microsoft.WindowsTerminal -e --source winget `
            --accept-package-agreements --accept-source-agreements `
            --silent *> $null
    }
} catch {
    Write-Host "Failed to install Windows Terminal: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Install Ubuntu if not present
Write-Host "`n[4/10] Installing Ubuntu LTS..."
$exactUbuntu = wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq "Ubuntu" }
if (-not $exactUbuntu) {
	wsl --install -d Ubuntu
} else {
	Write-Host "Ubuntu LTS already installed..." -ForegroundColor Yellow
}

# Step 5: Write .wslconfig
Write-Host "`n[5/11] Writing .wslconfig..."
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
} catch {
	Write-Host "Failed to write .wslconfig: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 6: Install Fira Code font from GitHub
Write-Host "`n[6/10] Installing Fira Code font..."
$firaCodeInstalled = $false
try {
	Add-Type -AssemblyName System.Drawing
	$fonts = [System.Drawing.FontFamily]::Families
	$firaCodeInstalled = $fonts | Where-Object { $_.Name -match "Fira.*Code" }
} catch {
	Write-Host "Could not check if Fira Font is installed: $($_.Exception.Message)" -ForegroundColor Yellow
}

if (-not $firaCodeInstalled) {
    try {
        $apiUrl = "https://api.github.com/repos/tonsky/FiraCode/releases/latest"
        $headers = @{ "User-Agent" = "PowerShell" }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing

        $zipAsset = $response.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notmatch "Windows" } | Select-Object -First 1
        if (-not $zipAsset) { throw "Zip asset not found" }

        $zipUrl = $zipAsset.browser_download_url
        $zipPath = "$env:TEMP\FiraCode.zip"
        $extractTo = "$env:TEMP\FiraCode"

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractTo -Recurse -Force -ErrorAction SilentlyContinue

        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractTo -Force

        $fontDir = Join-Path $extractTo "ttf"
        $shellApp = New-Object -ComObject Shell.Application
        Get-ChildItem -Path $fontDir -Filter '*.ttf' | ForEach-Object {
            try {
                $shellApp.Namespace(0x14).CopyHere($_.FullName)
            } catch {}
        }

        Remove-Item $zipPath -Force
        Remove-Item $extractTo -Recurse -Force
    } catch {
		Write-Host "Could not install Fira Font: $($_.Exception.Message)" -ForegroundColor Yellow
	}
} else {
	Write-Host "Fira Font is already installed." -ForegroundColor Yellow
}

# Step 7: Ensure Terminal settings.json exists and close Terminal
Write-Host "`n[7/10] Looking for Windows Terminal settings..."
try {
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $wtProcess = Start-Process wt -ArgumentList "-w", "hide" -PassThru -WindowStyle Hidden
    
    # Wait for settings file to be created
    $timeout = 0
    while (-not (Test-Path $settingsPath) -and $timeout -lt 20) {
        Start-Sleep -Milliseconds 500
        $timeout++
    }
    
    if (Test-Path $settingsPath) {
        # Wait a moment for file to be fully written
        Start-Sleep -Seconds 1
        
        # Kill the specific process we started
        if (-not $wtProcess.HasExited) {
            $wtProcess.Kill()
            $wtProcess.WaitForExit(5000)
        }
    } else {
        Write-Host "Settings file not created within timeout" -ForegroundColor Red
        if (-not $wtProcess.HasExited) {
            $wtProcess.Kill()
        }
        exit 1
    }
    
} catch {
    Write-Host "Could not initialize Windows Terminal: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 8: Modify settings.json for font and profile
Write-Host "`n[8/9] Setting Windows Terminal settings..."
try {
    $jsonText = Get-Content $settingsPath -Raw
    $json = $jsonText | ConvertFrom-Json

    if (-not $json.profiles) { $json.profiles = @{ defaults = @{} } }
    if (-not $json.profiles.defaults) { $json.profiles.defaults = @{} }
    if (-not $json.profiles.defaults.PSObject.Properties['font']) {
        $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value @{}
    }
	
	if (-not $json.profiles.defaults.PSObject.Properties['colorScheme']) {
        $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name colorScheme -Value @{}
    }

	$json.profiles.defaults.colorScheme = "One Half Dark"
    $json.profiles.defaults.font.face = "Fira Code"

    $ubuntuProfile = $json.profiles.list | Where-Object {
        $_.name -eq "Ubuntu" -or ($_.source -like "*WSL*" -and $_.name -like "*Ubuntu*")
    }

    if ($ubuntuProfile) {
        $json.defaultProfile = $ubuntuProfile.guid
    }

    $json | ConvertTo-Json -Depth 99 | Set-Content -Encoding UTF8 -Path $settingsPath
} catch {
	Write-Host "Could not apply Windows Terminal settings: $($_.Exception.Message)" -ForegroundColor Red
	exit
}

# Step 9: Run setup-linux to install developer tools
Write-Host "`n[9/10] Installing developer tools in WSL"
$scriptPath = ".\setup-linux.sh"
$distro = "Ubuntu"
if (Test-Path $scriptPath) {
    try {
        # Ensure target folder exists
        wsl --distribution $distro -- bash -c "mkdir -p ~/setup && rm -f ~/setup/wsl-init.sh"

        # Stream the file directly into WSL using standard input
        Get-Content $scriptPath -Raw | wsl --distribution $distro -- bash -c "cat > ~/setup/wsl-init.sh"

        # Make it executable and run it
        wsl --distribution $distro -- bash -c "chmod +x ~/setup/wsl-init.sh && ~/setup/wsl-init.sh"
		wsl --shutdown
    } catch {
        Write-Host "Error: $_"
    }
} else {
	Write-Host "setup-linux.sh not found: $($_.Exception.Message)" -ForegroundColor Red
	exit 1;
}

Write-Host "`n[10] Installing chocolatey, then developer tools in Windows"
$chocoInstalled = $false
try {
	Set-ExecutionPolicy Bypass -Scope Process -Force
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
	$chocoScript = "$env:TEMP\install-choco.ps1"
	Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -OutFile $chocoScript -UseBasicParsing
	powershell -NoProfile -ExecutionPolicy Bypass -File $chocoScript *> $null
	Remove-Item $chocoScript -Force
	$chocoInstalled = $true
} catch {
	Write-Host "Could not install Chocolatey: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($chocoInstalled) {
	choco install notepadplusplus.install --yes --no-progress *> $null
	Write-Host "notepad++ installed"
	choco install vscode --yes --no-progress *> $null
	Write-Host "VSCode installed"
	choco install intellijidea-ultimate --yes --no-progress *> $null
	Write-Host "IntelliJ ultimate installed"
	choco install cursoride --yes --no-progress *> $null
	Write-Host "Cursor IDE installed"
}

# Final Message
Write-Host "`nWSL Full Dev Setup Complete."