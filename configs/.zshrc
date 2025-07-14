# ~/.zshrc — Zsh Configuration File

# ═══════════════════════════════════════════════════════════════
# 🧠 Core Environment Setup
# ═══════════════════════════════════════════════════════════════

export ZSH="$HOME/.oh-my-zsh"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
export EDITOR="vim"

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# PATH additions
PATH_ADDITIONS=(
  "/usr/local/bin"
  "$HOME/.local/bin"
)
for path_item in "${PATH_ADDITIONS[@]}"; do
  [[ -d "$path_item" && ":$PATH:" != *":$path_item:"* ]] && export PATH="$path_item:$PATH"
done

# ═══════════════════════════════════════════════════════════════
# ⚙️ Oh My Zsh + Plugins
# ═══════════════════════════════════════════════════════════════

plugins=(
  git
  z
  command-not-found
  colored-man-pages
  docker
  kubectl
  gh
  zsh-completions
  zsh-autosuggestions
)
source "$ZSH/oh-my-zsh.sh"

# ═══════════════════════════════════════════════════════════════
# 🧾 History Configuration
# ═══════════════════════════════════════════════════════════════

HISTSIZE=10000
SAVEHIST=10000
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"

setopt SHARE_HISTORY             # Share history across all sessions
setopt HIST_IGNORE_DUPS          # Don't record duplicate entries in a row
setopt HIST_IGNORE_ALL_DUPS      # Don't keep duplicates at all
setopt HIST_SAVE_NO_DUPS         # Don't save duplicates to file
setopt HIST_IGNORE_SPACE         # Ignore commands that start with space
setopt HIST_FIND_NO_DUPS         # Skip duplicates during search
setopt HIST_REDUCE_BLANKS        # Remove extra blanks from history
setopt HIST_VERIFY               # Show command before running with history expansion
setopt APPEND_HISTORY            # Append to history file
setopt INC_APPEND_HISTORY        # Add commands to history immediately

# ═══════════════════════════════════════════════════════════════
# 🔁 Completion System
# ═══════════════════════════════════════════════════════════════

zcompdump="${ZSH_CACHE_DIR:-$HOME/.cache}/zcompdump"
autoload -Uz compinit
compinit -C -d "$zcompdump"

# AWS CLI autocompletion
complete -C '/usr/local/bin/aws_completer' aws

# NVM completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*' rehash true

# ═══════════════════════════════════════════════════════════════
# 🌟 Prompt
# ═══════════════════════════════════════════════════════════════

eval "$(starship init zsh)"

# ═══════════════════════════════════════════════════════════════
# 📎 Aliases
# ═══════════════════════════════════════════════════════════════

## Kubernetes
alias k="kubectl"
alias kgp="kubectl get pods"
alias kgs="kubectl get services"
alias kgd="kubectl get deployments"
alias kgn="kubectl get namespaces"
alias kgi="kubectl get ingress"
alias kgpv="kubectl get pv"
alias kgpvc="kubectl get pvc"
alias kns="kubectl config set-context --current --namespace"
alias kctx="kubectl config use-context"
alias kconf="kubectl config view"
alias kdp="kubectl describe pod"
alias kds="kubectl describe service"
alias kdd="kubectl describe deployment"
alias klogs="kubectl logs"
alias kexec="kubectl exec -it"
alias kport="kubectl port-forward"
alias kt="kubetail"
alias k9="k9s"
alias tp="telepresence"

## Docker
alias d="docker"
alias dps="docker ps"
alias dpa="docker ps -a"
alias di="docker images"
alias dlog="docker logs"
alias dex="docker exec -it"
alias dstop="docker stop"
alias drm="docker rm"
alias drmi="docker rmi"
alias dclean="docker system prune -f"
alias dcleanall="docker system prune -a -f"

## Docker Compose
alias dc="docker-compose"
alias dcu="docker-compose up"
alias dcd="docker-compose down"
alias dcb="docker-compose build"
alias dcl="docker-compose logs"

## Maven
alias m="mvn"
alias mci="mvn clean install"
alias mcp="mvn clean package"
alias mct="mvn clean test"
alias mcc="mvn clean compile"
alias mvnver="mvn --version"

## Node.js/npm
alias node-version="node --version && npm --version"
alias npm-list="npm list -g --depth=0"
alias npm-update="npm update -g"

## Git
alias gst="git status"
alias gco="git checkout"
alias gaa="git add -A"
alias gcm="git commit -m"
alias gp="git push"
alias gl="git pull"
alias glog="git log --oneline --graph --decorate"
alias gclean="git clean -fd"

## AWS
alias aws-whoami="aws sts get-caller-identity"

## Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias la="ls -la"
alias l="ls -l"
alias lt="ls -lt"
alias lh="ls -lh"

## System
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias ps="ps aux"
alias psg="ps aux | grep"
alias df="df -h"
alias free="free -h"

## Quick edits
alias zshrc="$EDITOR ~/.zshrc"
alias vimrc="$EDITOR ~/.vimrc"
alias reload="source ~/.zshrc"

## Scripts
alias ekslogin="$HOME/.scripts/login-eks.sh"
alias ecrlogin="$HOME/.scripts/login-ecr.sh"

# ═══════════════════════════════════════════════════════════════
# 🔧 Custom Functions
# ═══════════════════════════════════════════════════════════════

mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
	if [ -f "$1" ]; then
		case "$1" in
			*.tar.bz2)   tar xjf "$1"     ;;
			*.tar.gz)    tar xzf "$1"     ;;
			*.bz2)       bunzip2 "$1"     ;;
			*.rar)       unrar x "$1"     ;;
			*.gz)        gunzip "$1"      ;;
			*.tar)       tar xf "$1"      ;;
			*.tbz2)      tar xjf "$1"     ;;
			*.tgz)       tar xzf "$1"     ;;
			*.zip)       unzip "$1"       ;;
			*.Z)         uncompress "$1"  ;;
			*.7z)        7z x "$1"        ;;
			*)           echo "'$1' cannot be extracted" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

killp() {
	if [[ -z "$1" ]]; then
		echo "Usage: killp <process_name>"
		return 1
	fi
	pkill -f "$1"
}

git-cleanup() {
	git branch --merged | grep -v "\*\|main\|master\|develop" | xargs -n 1 git branch -d
}

# ═══════════════════════════════════════════════════════════════
# 🎨 Load syntax highlighting LAST
# ═══════════════════════════════════════════════════════════════

source "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
