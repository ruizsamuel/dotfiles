{ config, pkgs, nvim-config, lib, ... }:

{
    imports = [
    ];

    home.username = "samuel";
    home.homeDirectory = "/home/samuel";
    home.stateVersion = "25.05";
    nixpkgs.config.allowUnfree = true;

    home.packages = with pkgs; [
        neovim
        nodejs
        docker
        docker-compose
        git
        gcc
        cmake
        gnumake
        ripgrep
        python3
        python3.pkgs.pip
        python3.pkgs.python-lsp-server
        ruff
        unzip
        gnupg
        pinentry-curses
    ];

    programs.zsh = {
        enable = true;
        initContent = builtins.readFile ./dotfiles/zshrc;
    };

    programs.tmux = {
        enable = true;
        plugins = with pkgs.tmuxPlugins; [
            {
                plugin = minimal-tmux-status;
                extraConfig = builtins.readFile ./dotfiles/tmux/minimal-tmux-status.conf;
            }
        ];
        extraConfig = ''
            set-option -g default-shell ${pkgs.zsh}/bin/zsh
            ${builtins.readFile ./dotfiles/tmux/tmux.conf}
        '';
    };

    home.file.".config/nvim" = {
        source = nvim-config;
        recursive = true;
    };

    programs.starship = {
        enable = true;
        settings = builtins.fromTOML (builtins.readFile ./dotfiles/starship.toml);
    };

    services.gpg-agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-curses;
    };

    home.activation.restartTmux = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v tmux >/dev/null; then
      tmux kill-server 2>/dev/null || true
    fi
    '';

    programs.home-manager.enable = true;
}
