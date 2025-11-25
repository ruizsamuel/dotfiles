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
        openssh
        nodePackages.typescript-language-server
        nodePackages.typescript
    ];

    programs.zsh = {
        syntaxHighlighting.enable = true;
        enable = true;
        initContent = ''
        ${builtins.readFile ./dotfiles/zshrc}
        ${builtins.readFile ./dotfiles/zshrc_extra}
        '';
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

    programs.git = {
        enable = true;

        userName = "Samuel Ruiz";
        userEmail = "samue@ruizsamuel.es";

        signing = {
            key = "6B50E0FDEA729EB7";
            signByDefault = false;
        };

        extraConfig = {
            gpg.program = "gpg";
        };
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
