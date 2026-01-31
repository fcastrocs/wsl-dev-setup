# ~/.zshrc — Zsh Configuration File

# ═══════════════════════════════════════════════════════════════
# 🧠 Core Environment Setup
# ═══════════════════════════════════════════════════════════════

export ZSH="$HOME/.oh-my-zsh"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
export EDITOR="vim"
export NVM_LAZY_LOAD=true
export NVM_COMPLETION=true

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
  zsh-completions
  zsh-autosuggestions
  zsh-nvm
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
# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# ═══════════════════════════════════════════════════════════════
# 🌟 Prompt
# ═══════════════════════════════════════════════════════════════

eval "$(starship init zsh)"

# ═══════════════════════════════════════════════════════════════
# 📎 Aliases
# ═══════════════════════════════════════════════════════════════

## Node.js/npm
alias node-version="node --version && npm --version"
alias npm-list="npm list -g --depth=0"
alias npm-update="npm update -g"

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
alias zshrc="$EDITOR ${ZDOTDIR:-$HOME}/.zshrc"
alias reload="source ${ZDOTDIR:-$HOME}/.zshrc"

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

# ═══════════════════════════════════════════════════════════════
# 🎨 Load syntax highlighting LAST
# ═══════════════════════════════════════════════════════════════

source "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"