#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
mkdir -p ~/tmp && cd ~/tmp

# ------------------------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------------------------
function silent_run() {
	local temp_file
	temp_file=$(mktemp)
	local exit_code=0

	"$@" >/dev/null 2>"$temp_file" || exit_code=$?

	if [ $exit_code -ne 0 ]; then
		echo -e "\tCommand failed (exit $exit_code): $*" >&2
		if [ -s "$temp_file" ]; then
			echo -e "\tError output:" >&2
			while IFS= read -r line; do echo -e "\t  $line" >&2; done <"$temp_file"
		fi
	fi

	rm -f "$temp_file"
	return $exit_code
}

function command_exists() {
	command -v "$1" >/dev/null 2>&1
}

function is_apt_installed() {
	dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

function install_packages() {
	local packages=("$@")
	local packages_to_install=()

	for pkg in "${packages[@]}"; do
		if ! is_apt_installed "$pkg"; then
			packages_to_install+=("$pkg")
		fi
	done

	if [ ${#packages_to_install[@]} -gt 0 ]; then
		echo -e "\tInstalling packages: ${packages_to_install[*]}..."
		silent_run sudo apt-get install -y "${packages_to_install[@]}"
	else
		echo -e "\tAll packages already installed."
	fi
}

# ------------------------------------------------------------------------------------------------
# System updates
# ------------------------------------------------------------------------------------------------
echo -e "\tUpdating system packages..."
silent_run sudo apt-get update -y
silent_run sudo apt-get upgrade -y

# ------------------------------------------------------------------------------------------------
# Install Prerequisite Packages
# ------------------------------------------------------------------------------------------------
PREREQ_PACKAGES=(
    # --- Prerequisite packages (Required by script commands) ---
    curl                # Required to download keys/files
    ca-certificates     # Required by curl/wget to verify SSL/TLS for secure (https) downloads
    wget                # Required as an alternative downloader
    gnupg               # Required to process/dearmor the PGP keys for Docker and GitHub CLI
    unzip               # Required to extract zips

    # --- Dev packages (User experience & Configuration) ---
    command-not-found   # Required by Zsh/Bash to suggest packages when a command is missing
    zsh                 # Required to set the new default shell and run Oh My Zsh
    git                 # Required to clone Oh My Zsh and its plugins (autosuggestions, etc.)
)

install_packages "${PREREQ_PACKAGES[@]}"

# ------------------------------------------------------------------------------------------------
# Install packages from repositories
# ------------------------------------------------------------------------------------------------
echo -e "\tAdding additional repositories..."

# Ensure keyrings directory exists
silent_run sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker repository
if ! command_exists docker; then
	silent_run sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	silent_run sudo chmod go+r /etc/apt/keyrings/docker.asc
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release &&
		echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

# Install packages
silent_run sudo apt-get update -y

PACKAGES=(
	docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	unrar
	7zip
)

install_packages "${PACKAGES[@]}"

# ------------------------------------------------------------------------------------------------
# Install packages from source
# ------------------------------------------------------------------------------------------------

# Install NVM for Node.js
if ! command_exists nvm; then
	echo -e "\tInstalling NVM for Node.js..."
	silent_run bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
else
	echo -e "\tNVM already installed."
fi

# ------------------------------------------------------------------------------------------------
# Configure things
# ------------------------------------------------------------------------------------------------
# Add user to docker group
if command_exists docker; then
	silent_run sudo usermod -aG docker $USER
fi

# Start and enable Docker service
if command_exists docker; then
	silent_run sudo systemctl enable docker
	silent_run sudo systemctl start docker
fi

# Load NVM, install the latest LTS version of Node.js, and set it as the default
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
silent_run nvm install --lts
silent_run nvm alias default lts/*

# ------------------------------------------------------------------------------------------------
# Install Oh My Zsh and plugins
# ------------------------------------------------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	echo -e "\tInstalling Oh My Zsh..."
	silent_run bash -c 'export RUNZSH=no; export KEEP_ZSHRC=yes; curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash'
else
	echo -e "\tOh My Zsh already installed."
fi

echo -e "\tInstalling Zsh plugins..."

# Define the custom plugins directory for cleaner code
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

echo -e "\tInstalling Zsh plugins..."

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    silent_run git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    silent_run git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
    silent_run git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-nvm" ]; then
    silent_run git clone https://github.com/lukechilds/zsh-nvm "$ZSH_CUSTOM/plugins/zsh-nvm"
fi

# ------------------------------------------------------------------------------------------------
# Install Starship Prompt
# ------------------------------------------------------------------------------------------------
if ! command_exists starship; then
	echo -e "\tInstalling Starship prompt..."
	silent_run curl -LO https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
	silent_run tar -xzf starship-x86_64-unknown-linux-gnu.tar.gz
	silent_run chmod a+x starship
	silent_run sudo mv starship /usr/local/bin/
else
	echo -e "\tStarship already installed."
fi

# ------------------------------------------------------------------------------------------------
# Set zsh as default shell
# ------------------------------------------------------------------------------------------------
echo -e "\tSetting zsh as default shell..."
if [[ "$SHELL" != *"zsh" ]]; then
	ZSH_PATH=$(which zsh)
	if ! grep -q "$ZSH_PATH" /etc/shells; then
		echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
	fi
	if ! silent_run sudo chsh -s "$ZSH_PATH" "$USER"; then
		echo -e "\tFailed to set zsh as default shell. You can do this manually with: chsh -s $ZSH_PATH"
	fi
else
	echo -e "\tZsh is already the default shell."
fi

echo 'export ZDOTDIR="$HOME/.config/zsh"' > ~/.zshenv

# ------------------------------------------------------------------------------------------------
# Clean up
# ------------------------------------------------------------------------------------------------
rm -rf ~/tmp
rm -f ~/.motd_shown ~/.sudo_as_admin_successful ~/.zshrc

# end of script
echo
echo -e "\tUbuntu setup complete."

rm -- "$0" # remove this script

