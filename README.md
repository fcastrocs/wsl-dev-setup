# ⚙️ WSL Dev Environment Setup

This project automates the setup of a complete and ready-to-use development environment on **Windows 11** using **WSL2** and **Ubuntu**. It includes two scripts:

- `setup-windows.ps1` – Configures Windows, installs WSL, Ubuntu, and prepares the terminal environment.
- `setup-ubuntu.sh` – Runs inside Ubuntu to install development dependencies and configure the shell environment.

Ideal for developers who want a fast, clean, and consistent Linux-like workflow on Windows.

---

## 🚀 Getting Started

### Run the Windows Setup Script

Make sure you run this in **PowerShell as Administrator**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main/setup-windows.ps1 | iex
```

- Installs **WSL2**
- Installs **Ubuntu (latest LTS)**
- Configures **Windows Terminal**:
  - Sets default profile to Ubuntu
  - Applies the *Fira Code* font and *One Half Dark* color scheme
- Creates a `.wslconfig` file to optimize WSL2 performance
- Installs developer-friendly **Fira Code** font
- Installs popular **Windows IDEs**:
  - Visual Studio Code
  - IntelliJ IDEA Ultimate
  - Cursor IDE
  - Notepad++
- Launches Ubuntu and runs `setup-ubuntu.sh` to:
  - Install developer tools: Git, Zsh, Node.js, Docker, Java, AWS CLI, and more
  - Configure shell with Starship, Oh My Zsh, plugins, etc.

---

## 🧾 Requirements

- Windows 11
- Administrator access

---

## 📜 License

MIT License – use freely, modify openly, contribute back if you’d like!

---

## 👤 Author

Created by [Francisco Castro](https://github.com/fcastrocs)
