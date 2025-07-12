# 🚀 WSL Development Environment Setup

**One-command setup for a complete development environment on Windows 11 using WSL2 + Ubuntu.**

## ⚡ Quick Start

```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main/install.ps1 | iex
```

## 🖥️ Windows Installation
- Windows Terminal
- Visual Studio Code
- Cursor IDE
- IntelliJ IDEA Ultimate
- Notepad++
- FiraCode Nerd Font
- WSL2 + Ubuntu (latest LTS)

## 🐧 Ubuntu Installation
- Zsh + Oh My Zsh + Starship prompt
- Git + GitHub CLI
- Docker + Docker Compose
- Node.js (via NVM)
- AWS CLI v2
- kubectl + k9s
- Telepresence
- kubetail

## ✨ What It Does

- **WSL2 Setup**: Enables WSL, installs Ubuntu, creates optimized `.wslconfig`
- **User Configuration**: Creates non-root user with passwordless sudo
- **Terminal Setup**: Configures Windows Terminal with Ubuntu as default, FiraCode font, One Half Dark theme
- **Editor Setup**: Applies FiraCode font to VS Code, Cursor, and Notepad++
- **Shell Environment**: Beautiful Zsh setup with auto-suggestions, syntax highlighting, and smart completions

## 🖥️ Access Your Environment

After installation, simply open **Windows Terminal** - it will automatically launch Ubuntu with your configured Zsh shell and development tools ready to use.

## 🗑️ Uninstall

```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main/uninstall.ps1 | iex
```

## 📄 License

MIT License

## 👨‍💻 Author

**Francisco Castro** - [@fcastrocs](https://github.com/fcastrocs)