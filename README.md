# Dotfiles

This repository contains my personal environment configuration managed using **Nix Flakes** and **Home Manager**.

## Features Included

* **Shell**: Zsh (custom settings sourced from `dotfiles/zshrc`).

* **Terminal Multiplexer**: Tmux (with minimal-tmux-status plugin and custom settings from `dotfiles/tmux`).

* **Editor**: Neovim (linked to external configuration via the nvim-config input).

* **Prompt**: Starship (`dotfiles/starship.toml`).

* **Packages**: Docker, Node.js, Python 3 environment, Git, GCC, and development utilities.

## Setup Instructions

### 1. Prerequisites (Nix Installation)

The Nix installation must support Flakes. If you don't have Nix, install it using the multi-user script:
```bash
curl -L https://nixos.org/nix/install | sh
```

After installation, ensure Flakes are enabled in your Nix configuration file (`/etc/nix/nix.conf` or `~/.config/nix/nix.conf`):
```
experimental-features = nix-command flakes
```

### 2. Personalize Your Configuration

Clone the repository:
```bash
git clone https://github.com/ruizsamuel/dotfiles.git
cd dotfiles
```

Create your personal configuration file from the example:
```bash
cp local.nix.example local.nix
```

Edit `local.nix` with your personal data:
```nix
{
  username = "your-username";           # Your username (same as `whoami`)
  homeDirectory = "/home/your-username"; # Your home directory
  stateVersion = "25.05";               # Don't change unless you know what you're doing

  git = {
    userName = "Your Name";
    userEmail = "your.email@example.com";
    
    signing = {
      enable = false;  # Change to true if you want to sign commits with GPG
      key = "";        # Your GPG fingerprint if needed
    };
  };

  development = {
    enablePython = true;
    enableNodeJs = true;
    enableRust = false;
    enableDocker = true;
  };
}
```

> **Important Note**: The file `local.nix` is ignored by git (in `.gitignore`) to prevent your personal data from being uploaded to the repository. Only `local.nix.example` is tracked.

> **macOS Users**: See [macOS-specific instructions](#macos-installation-guide) for first-time setup.

### 3. Install Configuration

Apply the configuration using Home Manager (automatically detects your system):

```bash
home-manager switch --flake .#samuel
```

## Multi-Architecture Support

This configuration supports multiple architectures and operating systems:

- **x86_64-linux**: Linux on Intel/AMD processors
- **aarch64-linux**: Linux on ARM (Raspberry Pi, etc.)
- **x86_64-darwin**: macOS on Intel
- **aarch64-darwin**: macOS on Apple Silicon (M1/M2/M3/etc.)

### Installing on Different Systems

**Linux x86_64** (default):
```bash
home-manager switch --flake .#samuel
# or explicitly:
home-manager switch --flake .#samuel@x86_64-linux
```

**Raspberry Pi / ARM Linux**:
```bash
home-manager switch --flake .#samuel@aarch64-linux
```

**macOS Intel or Apple Silicon**:
```bash
home-manager switch --flake .#samuel
```

> **Note**: This configuration works with Home Manager only on macOS. You don't need nix-darwin unless you want to manage system-level settings. See [macOS Installation Guide](#macos-installation-guide) for first-time setup.

> **Note**: The configuration is automatically portable across architectures. Nix handles dependency resolution for each platform. If you need OS-specific packages, they can be conditionally included using `lib.optionals stdenv.isLinux` or `lib.optionals stdenv.isDarwin` in `home.nix`.

---

## Appendix: macOS Installation Guide

This section provides specific instructions for setting up this configuration on macOS for the first time.

### Prerequisites

1. **Install Nix** (if not already installed):
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. **Enable Flakes** in `~/.config/nix/nix.conf` (create if it doesn't exist):
   ```
   experimental-features = nix-command flakes
   ```

3. **Restart your terminal** to apply changes.

### First-Time Setup

1. **Install Home Manager standalone**:
   ```bash
   nix run home-manager/master -- init --switch
   ```

2. **Replace the generated configuration with this repository**:
   ```bash
   cd ~/.config/home-manager
   rm -rf *  # Remove auto-generated files
   
   # Clone this repository
   git clone https://github.com/ruizsamuel/dotfiles.git .
   ```

3. **Create and edit your local configuration**:
   ```bash
   cp local.nix.example local.nix
   ```
   
   Follow the [personalization instructions](#2-personalize-your-configuration) above, but remember to use `/Users/your-username` instead of `/home/your-username` for the `homeDirectory` field.

4. **Apply the configuration**:
   ```bash
   home-manager switch --flake .#samuel
   ```

### macOS-Specific Notes

- **Home directory**: Use `/Users/username` instead of `/home/username`
- **Docker**: Install Docker Desktop separately from the official website. The `docker` package in Nix is just the CLI
- **System architecture**: The flake automatically detects if you're on Intel or Apple Silicon
- **nix-darwin**: Not required for this configuration. Home Manager is sufficient for managing user-level dotfiles

### Updating Configuration

After the initial setup, updates work the same as on Linux:

```bash
cd ~/.config/home-manager
git pull
home-manager switch --flake .#samuel
```
