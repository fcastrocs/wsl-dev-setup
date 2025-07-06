#!/bin/bash
set -e

# ----------------------------------------
# Utility Functions
# ----------------------------------------
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

# ----------------------------------------
# System Update & Prerequisites
# ----------------------------------------
echo -e "\tGetting things ready..."
silent_run sudo apt update -y
silent_run sudo apt upgrade -y

PREREQ_PACKAGES=(
	zsh
	git
	curl
	wget
	unzip
	command-not-found
	build-essential
	procps
	file
)

PACKAGES_TO_INSTALL=()
for pkg in "${PREREQ_PACKAGES[@]}"; do
	if ! is_apt_installed "$pkg"; then
		PACKAGES_TO_INSTALL+=("$pkg")
	fi
done

if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
	silent_run sudo apt install -y "${PACKAGES_TO_INSTALL[@]}"
fi

# ----------------------------------------
# Install Homebrew
# ----------------------------------------
BREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"

if [ ! -x "$BREW_PATH" ]; then
	echo -e "\tInstalling Homebrew..."
	silent_run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
else
  echo -e "\tHomebrew already installed."
fi

if [ ! -x "$BREW_PATH" ]; then
	echo -e "\tHomebrew not found at expected location: $BREW_PATH" >&2
	exit 1
fi

# Make brew available in current shell
eval "$($BREW_PATH shellenv)"

# ----------------------------------------
# Install CLI Tools via Homebrew
# ----------------------------------------
echo -e "\tChecking Homebrew packages..."
BREW_PACKAGES=(
	git
	zsh
	openjdk@21
	maven
	node
	gh
	awscli
	kubectl
	k9s
	starship
	docker
)

BREW_TO_INSTALL=()
for pkg in "${BREW_PACKAGES[@]}"; do
	if ! brew list "$pkg" &>/dev/null; then
		echo -e "\tInstalling $pkg..."
		BREW_TO_INSTALL+=("$pkg")
	else
		echo -e "\t$pkg already installed."
	fi
done

if [ ${#BREW_TO_INSTALL[@]} -gt 0 ]; then
	silent_run brew install "${BREW_TO_INSTALL[@]}"
fi

echo -e "\tCleaning up Homebrew cache..."
silent_run brew cleanup

# ----------------------------------------
# Install Telepresence
# ----------------------------------------

TELEP_BIN="/usr/local/bin/telepresence"

if [ ! -x "$TELEP_BIN" ]; then
    echo -e "\tInstalling Telepresence..."
    silent_run sudo curl -fL https://github.com/telepresenceio/telepresence/releases/latest/download/telepresence-linux-amd64 -o "$TELEP_BIN"
    silent_run sudo chmod a+x "$TELEP_BIN"
else
    echo -e "\tTelepresence already installed"
fi

# ----------------------------------------
# Install kubetail
# ----------------------------------------
if ! command_exists kubetail; then
	echo -e "\tInstalling kubetail..."
	silent_run bash -c "curl -sLo /tmp/kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail && \
		sudo mv /tmp/kubetail /usr/local/bin/kubetail && \
		sudo chmod +x /usr/local/bin/kubetail"
else
	echo -e "\tkubetail already installed."
fi

# ----------------------------------------
# Set Zsh as Default Shell
# ----------------------------------------
echo -e "\tSetting zsh as default shell..."
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

# ----------------------------------------
# Install Oh My Zsh
# ----------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	echo -e "\tInstalling Oh My Zsh..."
	export RUNZSH=no KEEP_ZSHRC=yes
	silent_run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
	echo -e "\tOh My Zsh already installed."
fi

# ----------------------------------------
# Install Zsh Plugins
# ----------------------------------------
echo -e "\tInstalling Zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"

declare -A ZSH_PLUGINS=(
	[zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
	[zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
	[zsh-completions]="https://github.com/zsh-users/zsh-completions"
)

for plugin in "${!ZSH_PLUGINS[@]}"; do
	if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
		echo -e "\tInstalling $plugin plugin..."
		silent_run git clone "${ZSH_PLUGINS[$plugin]}" "$ZSH_CUSTOM/plugins/$plugin"
	else
		echo -e "\t$plugin plugin already installed."
	fi
done

# ----------------------------------------
# Install Starship Prompt
# ----------------------------------------
if ! command_exists starship; then
	echo -e "\tInstalling Starship prompt..."
	silent_run curl -sS https://starship.rs/install.sh | sh -s -- -y
else
	echo -e "\tStarship already installed."
fi

# ----------------------------------------
# Final Output
# ----------------------------------------
echo
echo -e "\tSetup complete."
echo
echo -e "\tInstalled versions:" 

source "$HOME/.zshrc" 2>/dev/null || true

# if command_exists node;    then echo -e "\tNode.js: $(node --version)"; fi
# if command_exists java;    then echo -e "\tJava: $(java -version 2>&1 | head -n 1)"; fi
# if command_exists mvn;     then echo -e "\tMaven: $(mvn --version | head -n 1)"; fi
# if command_exists docker;  then echo -e "\tDocker: $(docker --version)"; fi
# if command_exists kubectl; then echo -e "\tkubectl: $(kubectl version --client 2>/dev/null | head -n 1 || echo 'kubectl installed')"; fi
# if command_exists gh;      then echo -e "\tGitHub CLI: $(gh --version | head -n 1)"; fi
# if command_exists aws;     then echo -e "\tAWS CLI: $(aws --version)"; fi