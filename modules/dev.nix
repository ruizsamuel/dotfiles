# General development toolchain shared by every host.
{ pkgs, lib, ... }:
let
  # Pinned to the LTS instead of `pkgs.jdk`: Gradle only supports up to Java 24
  # and AGP recommends 21, so letting the default JDK follow nixpkgs would
  # eventually break every Android build with "Unsupported class file major
  # version".
  jdk = pkgs.jdk21;

  # On darwin nixpkgs ships Zulu, which already contains a proper macOS JVM
  # bundle inside the store path.
  jdkBundle = "${jdk}/Library/Java/JavaVirtualMachines/zulu-21.jdk";
in
{
  home.packages = with pkgs; [
    # Languages and runtimes
    nodejs
    python3
    jdk21
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
  home.sessionVariables.JAVA_HOME = jdk.home;

  # macOS build scripts locate the JDK with `/usr/libexec/java_home -v 21`,
  # which only scans the JavaVirtualMachines directories and is blind to a Nix
  # profile — so a Mac with a perfectly good JDK 21 on PATH still reports
  # "Unable to locate a Java Runtime". Linking the bundle into the *user*
  # directory registers it without touching /Library (no sudo, no leftovers
  # when the generation is rolled back).
  home.file = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    "Library/Java/JavaVirtualMachines/zulu-21.jdk".source = jdkBundle;
  };
}
