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
	# prerequisite packages
	curl
	ca-certificates
	wget
	gnupg
	unzip
	# dev packages
	command-not-found
	zsh
	git
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

# Add GitHub CLI repository
if ! command_exists gh; then
	silent_run curl -fsSLO https://cli.github.com/packages/githubcli-archive-keyring.gpg
	silent_run sudo install -m 644 githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
	silent_run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
		sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

# Add Kubernetes repository for kubectl
if ! command_exists kubectl; then
	silent_run curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key -o kubernetes-release.key
	silent_run sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg kubernetes-release.key
	silent_run sudo chmod go+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' |
		sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
fi

# Update package lists after adding repositories
silent_run sudo apt-get update -y

REPO_PACKAGES=(
	docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	gh
	kubectl
)

install_packages "${REPO_PACKAGES[@]}"

# ------------------------------------------------------------------------------------------------
# Install packages from source
# ------------------------------------------------------------------------------------------------

# Install AWS CLI v2
if ! command_exists aws; then
	echo -e "\tInstalling AWS CLI v2..."
	silent_run curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	silent_run unzip awscliv2.zip
	silent_run sudo ./aws/install
else
	echo -e "\tAWS CLI v2 already installed."
fi

# Install k9s
if ! command_exists k9s; then
	echo -e "\tInstalling k9s..."
	silent_run curl -fsSLO https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.tar.gz
	silent_run tar -xzf k9s_linux_amd64.tar.gz
	silent_run chmod a+x k9s
	silent_run sudo mv k9s /usr/local/bin/
else
	echo -e "\tk9s already installed."
fi

# Install Telepresence
if ! command_exists telepresence; then
	echo -e "\tInstalling Telepresence..."
	silent_run curl -fsSL https://github.com/telepresenceio/telepresence/releases/latest/download/telepresence-linux-amd64 -o telepresence
	silent_run chmod a+x telepresence
	silent_run sudo mv telepresence /usr/local/bin/
else
	echo -e "\tTelepresence already installed"
fi

# Install kubetail
if ! command_exists kubetail; then
	echo -e "\tInstalling kubetail..."
	silent_run bash -c 'curl -sS https://www.kubetail.com/install.sh | bash'
else
	echo -e "\tkubetail already installed."
fi

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
silent_run git clone https://github.com/zsh-users/zsh-autosuggestions \
	"$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
silent_run git clone https://github.com/zsh-users/zsh-syntax-highlighting \
	"$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
silent_run git clone https://github.com/zsh-users/zsh-completions \
	"$HOME/.oh-my-zsh/custom/plugins/zsh-completions"

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
rm ~/.motd_shown ~/.sudo_as_admin_successful ~/.zshrc
rm -- "$0" # remove this script

# end of script
echo
echo -e "\tUbuntu setup complete."
