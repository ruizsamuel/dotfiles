# Dotfiles

This repository contains my personal environment configuration managed using **Nix Flakes** and **Home Manager**.

## Features Included

* **Shell**: Zsh (custom settings sourced from `dotfiles/zshrc`).

* **Terminal Multiplexer**: Tmux (with minimal-tmux-status plugin and custom settings from `dotfiles/tmux`).

* **Editor**: Neovim (linked to external configuration via the nvim-config input).

* **Prompt**: Starship (`dotfiles/starship.toml`).

* **Packages**: Docker, Node.js, Python 3 environment, Git, GCC, and development utilities.

## Setup Instructions

1. Prerequisites (Nix Installation)

The Nix installation must support Flakes. If you don't have Nix, install it using the multi-user script:
```bash
curl -L https://nixos.org/nix/install | sh
```

After installation, ensure Flakes are enabled in your Nix configuration file (`/etc/nix/nix.conf` or `~/.config/nix/nix.conf`):
```
experimental-features = nix-command flakes
```

2. Install Configuration

Clone the repository:
```bash
git clone https://github.com/ruizsamuel/dotfiles.git
cd dotfiles
```

Apply the configuration using Home Manager:

```bash
nix run github:nix-community/home-manager -- switch --flake .
```
