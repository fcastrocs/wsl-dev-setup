# ⚙️ WSL Dev Environment Setup

This project automates the setup of a complete and ready-to-use development environment on **Windows 11** using **WSL2** and **Ubuntu**. It includes two scripts:

- `setup-windows.ps1` – Configures Windows, installs WSL, Ubuntu, and prepares the terminal environment.
- `setup-ubuntu.sh` – Runs inside Ubuntu to install development dependencies and configure the shell environment.

Ideal for developers who want a fast, clean, and consistent Linux-like workflow on Windows.

---

## 🚀 Getting Started

### 1. Run the Windows Setup Script

Make sure you run this in **PowerShell as Administrator**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/fcastrocs/wsl-dev-setup/main/setup-windows.ps1 | iex
```

This will install WSL2, Ubuntu, and configure the terminal environment.

### 3. Ubuntu Script Runs Automatically

Once Ubuntu is installed, the `setup-ubuntu.sh` script will run inside WSL to complete the environment setup.

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
