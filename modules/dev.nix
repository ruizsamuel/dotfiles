# General development toolchain shared by every host.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Languages and runtimes
    nodejs
    python3
    jdk
    typescript

    # Build tooling
    gcc
    cmake
    gnumake

    # Language servers and linters
    python3.pkgs.python-lsp-server
    typescript-language-server
    ruff

    # Containers
    docker
    docker-compose

    # Everyday utilities (git itself comes from programs.git in git.nix)
    ripgrep
    unzip
  ];

  # Lives here rather than in the Android module because it belongs to the JDK
  # above: gradle needs it on any host, with or without the Android SDK.
  home.sessionVariables.JAVA_HOME = pkgs.jdk.home;
}
