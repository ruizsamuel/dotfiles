{ config, pkgs, nvim-config, lib, ... }:

let
    personalConfig = import ./config.nix;
    androidComposition = pkgs.androidenv.composeAndroidPackages {
      cmdLineToolsVersion = "latest";
      platformVersions = [ "35" ];
      buildToolsVersions = [ "35.0.0" ];
      includeNDK = false;
      includeEmulator = false;
    };
    androidSdk = androidComposition.androidsdk;
in

    {
    imports = [
    ];

    home.username = personalConfig.username;
    home.homeDirectory = personalConfig.homeDirectory;
    home.stateVersion = "25.05";
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.android_sdk.accept_license = true;

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
        jdk17
        androidSdk
        ruff
        unzip
        gnupg
        pinentry-curses
        openssh
        nodePackages.typescript-language-server
        nodePackages.typescript
        claude-code
        gh
    ];

    programs.zsh = {
        syntaxHighlighting.enable = true;
        enable = true;
        initContent = ''
            ${builtins.readFile ./dotfiles/zshrc}
            ${builtins.readFile ./dotfiles/zshrc_extra}
        '';
    };

    programs.gh = {
        enable = true;
        extensions = [ pkgs.github-copilot-cli ];
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

    home.sessionVariables = {
        ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
        PATH = "${androidSdk}/libexec/android-sdk/platform-tools:${androidSdk}/libexec/android-sdk/build-tools/35.0.0:$PATH";
    };

    programs.starship = {
        enable = true;
        settings = builtins.fromTOML (builtins.readFile ./dotfiles/starship.toml);
    };

    programs.git = {
        enable = true;

        signing = lib.mkIf personalConfig.git.signing.enable {
            key = personalConfig.git.signing.key;
            signByDefault = false;
        };

        settings = {
            user.name = personalConfig.git.userName;
            user.email = personalConfig.git.userEmail;
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
