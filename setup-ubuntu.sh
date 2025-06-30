#!/bin/bash
# ================================
# WSL Dev Environment Setup Script
# ================================
set -e

echo "Updating system packages..."
sudo apt update -qq && sudo apt upgrade -y -qq > /dev/null 2>&1

echo "Installing APT dependencies..."
sudo apt install -y -qq build-essential procps file > /dev/null 2>&1

echo "Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null > /dev/null 2>&1
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "Installing development tools..."
brew install -q git zsh openjdk@21 maven node gh awscli kubectl k9s starship docker > /dev/null 2>&1

echo "Setting up Zsh..."
BREW_ZSH="$(brew --prefix)/bin/zsh"
# Only add zsh to /etc/shells if not present
if ! grep -q "^$BREW_ZSH$" /etc/shells; then
    echo "$BREW_ZSH" | sudo tee -a /etc/shells > /dev/null 2>&1
fi
# Avoid sudo chsh – it causes a second prompt; let user manually run chsh if needed

echo "Installing Oh-My-Zsh..."
export RUNZSH=no KEEP_ZSHRC=yes CHSH=no
rm -rf "$HOME/.oh-my-zsh" > /dev/null 2>&1
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended > /dev/null 2>&1

echo "Installing Zsh plugins..."
git clone -q https://github.com/zsh-users/zsh-autosuggestions \
    ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions > /dev/null 2>&1

echo "Creating .zshrc..."
cat > ~/.zshrc << 'EOF'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git docker kubectl zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh
export PATH="$(brew --prefix)/opt/openjdk@21/bin:$PATH"
eval "$(starship init zsh)"
EOF

echo "Installing kubetail..."
curl -sLo /tmp/kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
sudo mv /tmp/kubetail /usr/local/bin/kubetail
sudo chmod +x /usr/local/bin/kubetail

echo "Cleaning up..."
brew cleanup -q > /dev/null 2>&1

exec zsh -c "
source ~/.zshrc
echo '\n\nInstalled versions:'
echo -n 'Node.js: ' && node -v
echo -n 'npm: ' && npm -v
echo -n 'Java: ' && java -version 2>&1 | head -n 1
echo -n 'Maven: ' && mvn -v | head -n 1
echo -n 'Docker: ' && docker --version
echo -n 'kubectl: ' && kubectl version --client 2>/dev/null | head -n 1 || echo 'kubectl installed (cluster needed for version)'
echo -n 'GitHub CLI: ' && gh --version | head -n 1
echo -n 'AWS CLI: ' && aws --version
exit
"