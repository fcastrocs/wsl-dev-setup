# ~/.zshrc
# Zsh Configuration File

# ----------------------------------------
# Oh My Zsh Configuration
# ----------------------------------------
export ZSH="$HOME/.oh-my-zsh"
plugins=(
    git
    z
    command-not-found
    colored-man-pages
    docker
    kubectl
    # aws
    gh
    zsh-completions
    zsh-autosuggestions
)

# Load Oh My Zsh FIRST
source "$ZSH/oh-my-zsh.sh"

# ----------------------------------------
# PATH Configuration
# ----------------------------------------
PATH_ADDITIONS=(
    "/usr/local/bin"
    "$HOME/.local/bin"
)

for path_item in "${PATH_ADDITIONS[@]}"; do
    if [[ -n "$path_item" && -d "$path_item" && ":$PATH:" != *":$path_item:"* ]]; then
        export PATH="$path_item:$PATH"
    fi
done

# ----------------------------------------
# History Configuration
# ----------------------------------------
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

# ----------------------------------------
# Completion System
# ----------------------------------------
zcompdump="${ZSH_CACHE_DIR:-$HOME/.cache}/zcompdump"
autoload -Uz compinit
compinit -C -d "$zcompdump"

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

# ----------------------------------------
# Starship Prompt
# ----------------------------------------
eval "$(starship init zsh)"

# ----------------------------------------
# Aliases
# ----------------------------------------

## Kubernetes
alias k="kubectl"                                            # Main kubectl command
alias kgp="kubectl get pods"                                 # List all pods in the current namespace
alias kgs="kubectl get services"                             # List all services
alias kgd="kubectl get deployments"                          # List all deployments
alias kgn="kubectl get namespaces"                           # List all namespaces
alias kgi="kubectl get ingress"                              # List all ingresses
alias kgpv="kubectl get pv"                                  # List persistent volumes
alias kgpvc="kubectl get pvc"                                # List persistent volume claims

alias kns="kubectl config set-context --current --namespace" # Set the current namespace
alias kctx="kubectl config use-context"                      # Switch to another context
alias kconf="kubectl config view"                            # Show kubeconfig details

alias kdp="kubectl describe pod"                             # Show detailed pod info
alias kds="kubectl describe service"                         # Show detailed service info
alias kdd="kubectl describe deployment"                      # Show detailed deployment info

alias klogs="kubectl logs"                                   # Show logs from a pod (or container with -c)
alias kexec="kubectl exec -it"                               # Execute a command inside a container
alias kport="kubectl port-forward"                           # Forward one or more local ports to a pod

# Kubernetes tools
alias kt="kubetail"                                           # Stream logs from multiple pods
alias k9="k9s"                                               # Terminal-based Kubernetes dashboard
alias tp="telepresence"                                      # Telepresence for local development

## Docker
alias d="docker"                   # Base docker command
alias dps="docker ps"              # List running containers
alias dpa="docker ps -a"           # List all containers (including stopped)
alias di="docker images"           # List local images
alias dlog="docker logs"           # View container logs
alias dex="docker exec -it"        # Run interactive command in container
alias dstop="docker stop"          # Stop container
alias drm="docker rm"              # Remove container
alias drmi="docker rmi"            # Remove image
alias dclean="docker system prune -f"        # Clean up unused containers/images
alias dcleanall="docker system prune -a -f"  # Clean up everything unused

# Docker Compose
alias dc="docker-compose"
alias dcu="docker-compose up"
alias dcd="docker-compose down"
alias dcb="docker-compose build"
alias dcl="docker-compose logs"

## Maven
alias m="mvn"                      # Maven shorthand
alias mci="mvn clean install"      # Clean and install
alias mcp="mvn clean package"      # Clean and package
alias mct="mvn clean test"         # Clean and test
alias mcc="mvn clean compile"      # Clean and compile
alias mvnver="mvn --version"       # Show Maven version

## Node.js/npm
alias node-version="node --version && npm --version"  # Show Node and npm versions
alias npm-list="npm list -g --depth=0"                # List global packages
alias npm-update="npm update -g"                      # Update all global packages

## Git
alias gst="git status"             # Show current changes and branch info
alias gco="git checkout"           # Switch branches or restore files
alias gaa="git add -A"             # Stage all changes (tracked and untracked)
alias gcm="git commit -m"          # Commit with message
alias gp="git push"                # Push to remote
alias gl="git pull"                # Pull from remote
alias glog="git log --oneline --graph --decorate"  # Pretty git log
alias gclean="git clean -fd"       # Remove untracked files and directories

## AWS CLI
alias aws-whoami="aws sts get-caller-identity"  # Show current AWS identity

## Navigation
alias ..="cd .."           # Go up one directory
alias ...="cd ../.."       # Go up two directories
alias ....="cd ../../.."   # Go up three directories
alias la="ls -la"          # List all files with details (including hidden)
alias l="ls -l"            # Long listing format (no hidden files)
alias lt="ls -lt"          # Long list sorted by newest modified first
alias lh="ls -lh"          # Long list with human-readable file sizes

## System utils
alias grep="grep --color=auto"      # Search files or output with highlighting
alias fgrep="fgrep --color=auto"    # Fixed-string grep with color
alias egrep="egrep --color=auto"    # Extended grep with color
alias ps="ps aux"                   # View active processes
alias psg="ps aux | grep"           # Search for specific process
alias df="df -h"                    # View disk space usage
alias free="free -h"                # Show memory usage

## Quick edits
alias zshrc="$EDITOR ~/.zshrc"
alias vimrc="$EDITOR ~/.vimrc"
alias reload="source ~/.zshrc"

# ----------------------------------------
# Custom Functions
# ----------------------------------------

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
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

# Kill process by name
killp() {
    if [[ -z "$1" ]]; then
        echo "Usage: killp <process_name>"
        return 1
    fi
    pkill -f "$1"
}

# Git branch cleanup - remove merged branches
git-cleanup() {
    git branch --merged | grep -v "\*\|main\|master\|develop" | xargs -n 1 git branch -d
}

# ----------------------------------------
# Load syntax highlighting LAST
# ----------------------------------------
source "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
