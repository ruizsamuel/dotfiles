{ config, pkgs, nvim-config, lib, ... }:

let
  # Importar configuración local desde local.nix
  # Este archivo debe existir (copiar de local.nix.example)
  localConfig = import ./local.nix;
in

{
    imports = [
    ];

    home.username = localConfig.username;
    home.homeDirectory = localConfig.homeDirectory;
    home.stateVersion = localConfig.stateVersion;
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

        signing = lib.mkIf localConfig.git.signing.enable {
            key = localConfig.git.signing.key;
            signByDefault = false;
        };

        settings = {
            user.name = localConfig.git.userName;
            user.email = localConfig.git.userEmail;
            gpg.program = "gpg";
        };
    };

    services.gpg-agent = {
        enable = true;
        pinentry.package = pkgs.pinentry-curses;
    };

    home.activation.restartTmux = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v tmux >/dev/null; then
      tmux kill-server 2>/dev/null || true
    fi
    '';

    programs.home-manager.enable = true;
}
