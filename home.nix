{ config, pkgs, nvim-config, lib, ... }:
let
    personalConfig = import ./config.nix;

    # Única diferencia por plataforma: arm64-v8a en Apple Silicon, x86_64 en Intel/Linux/WSL
    androidAbi = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64-v8a" else "x86_64";

    androidComposition = pkgs.androidenv.composeAndroidPackages {
        cmdLineToolsVersion = "latest";
        platformVersions = [ "35" "36" ];
        buildToolsVersions = [ "35.0.0" "36.0.0" ];
        includeNDK = true;
        ndkVersions = [ "27.1.12297006" ];
        cmakeVersions = [ "3.22.1" ];
        includeEmulator = true;
        includeSystemImages = true;
        systemImageTypes = [ "google_apis" ];
        abiVersions = [ androidAbi ];
    };
    androidSdk = androidComposition.androidsdk;
    # Ruta ESTABLE de runtime: el symlink del perfil sigue a la generación actual
    # sin cambiar de string, así que el entorno no se rompe en cada switch.
    androidRootStable = "${personalConfig.homeDirectory}/.nix-profile/libexec/android-sdk";
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
        jdk
        androidSdk
        ruff
        unzip
        gnupg
        pinentry-curses
        openssh
        typescript-language-server
        typescript
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
        ANDROID_HOME = androidRootStable;
        ANDROID_SDK_ROOT = androidRootStable;
        ANDROID_NDK_HOME = "${androidRootStable}/ndk/27.1.12297006";
        # Gradle (builds nativos de Android) necesita JAVA_HOME apuntando al JDK.
        JAVA_HOME = pkgs.jdk.home;
    };
    home.sessionPath = [
        "${androidRootStable}/platform-tools"
        "${androidRootStable}/build-tools/36.0.0"
        "${androidRootStable}/cmdline-tools/latest/bin"
        "${androidRootStable}/emulator"
    ];
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
    nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
    };
}
