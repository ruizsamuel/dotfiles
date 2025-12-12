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

**macOS Intel**:
Requires [nix-darwin](https://github.com/LnL7/nix-darwin):
```bash
nix-darwin switch --flake .#samuel@x86_64-darwin
```

**macOS Apple Silicon (M1/M2/M3/etc.)**:
Requires [nix-darwin](https://github.com/LnL7/nix-darwin):
```bash
nix-darwin switch --flake .#samuel@aarch64-darwin
```

> **Note**: The configuration is automatically portable across architectures. Nix handles dependency resolution for each platform. If you need OS-specific packages, they can be conditionally included using `lib.optionals stdenv.isLinux` or `lib.optionals stdenv.isDarwin` in `home.nix`.
