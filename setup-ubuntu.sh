#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------------------------
function silent_run {
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

function command_exists {
	command -v "$1" >/dev/null 2>&1
}

function is_apt_installed {
	dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

function install_packages {
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

# Add Docker repository
if ! command_exists docker; then
	silent_run sudo install -m 0755 -d /etc/apt/keyrings
	silent_run sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	silent_run sudo chmod a+r /etc/apt/keyrings/docker.asc
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# Add GitHub CLI repository
if ! command_exists gh; then
	silent_run sudo mkdir -p -m 755 /etc/apt/keyrings
	silent_run curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /tmp/githubcli-archive-keyring.gpg
	silent_run sudo install -m 644 /tmp/githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
	silent_run rm /tmp/githubcli-archive-keyring.gpg
	silent_run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
		sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
fi

# Add Kubernetes repository for kubectl
if ! command_exists kubectl; then
	silent_run sudo mkdir -p -m 755 /etc/apt/keyrings
	silent_run curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key -o /tmp/kubernetes-release.key
	silent_run sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg /tmp/kubernetes-release.key
	silent_run rm /tmp/kubernetes-release.key
	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
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
# Configure Docker
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
# Configure shell
# ------------------------------------------------------------------------------------------------
echo -e "\tConfiguring shell..."
if [[ "$SHELL" != *"zsh" ]]; then
	ZSH_PATH=$(which zsh)
	if ! grep -q "$ZSH_PATH" /etc/shells; then
		echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
	fi
	if silent_run sudo chsh -s "$ZSH_PATH" "$USER"; then
		echo -e "\tZsh set as default shell. You may need to log out and back in."
	else
		echo -e "\tFailed to set zsh as default shell. You can do this manually with: chsh -s $ZSH_PATH"
	fi
else
	echo -e "\tZsh is already the default shell."
fi

# ------------------------------------------------------------------------------------------------
# Install dev packages from source
# ------------------------------------------------------------------------------------------------
# Install k9s
if ! command_exists k9s; then
	echo -e "\tInstalling k9s..."
	K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
	silent_run curl -L -o k9s_linux_amd64.deb "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.deb"
	silent_run sudo apt-get install -y ./k9s_linux_amd64.deb
	rm -f k9s_linux_amd64.deb
else
	echo -e "\tk9s already installed."
fi

# Install Telepresence
TELEP_BIN="/usr/local/bin/telepresence"
if [ ! -x "$TELEP_BIN" ]; then
	echo -e "\tInstalling Telepresence..."
	silent_run sudo curl -fL https://github.com/telepresenceio/telepresence/releases/latest/download/telepresence-linux-amd64 -o "$TELEP_BIN"
	silent_run sudo chmod a+x "$TELEP_BIN"
else
	echo -e "\tTelepresence already installed"
fi

# # Install kubetail
# if ! command_exists kubetail; then
# 	echo -e "\tInstalling kubetail..."
# 	silent_run bash -c "curl -sLo $HOME/.local/bin/kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail && chmod +x $HOME/.local/bin/kubetail"
# else
# 	echo -e "\tkubetail already installed."
# fi

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
	tmpfile=$(mktemp)
	silent_run curl -sL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz -o "$tmpfile"
	silent_run tar -xzf "$tmpfile" -C /tmp
	silent_run sudo mv /tmp/starship /usr/local/bin
	silent_run sudo chmod +x /usr/local/bin/starship
	silent_run rm "$tmpfile"
else
	echo -e "\tStarship already installed."
fi

# ------------------------------------------------------------------------------------------------
# Final Output
# ------------------------------------------------------------------------------------------------
echo
echo -e "\tSetup complete."