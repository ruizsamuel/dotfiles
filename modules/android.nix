# Android SDK, NDK and emulator.
{ pkgs, ... }:
let
  identity = import ../identity.nix { inherit pkgs; };

  ndkVersion = "27.1.12297006";
  buildToolsVersion = "36.0.0";

  # The only per-platform difference: arm64-v8a on Apple Silicon, x86_64
  # everywhere else.
  androidAbi = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64-v8a" else "x86_64";

  androidComposition = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "latest";
    platformVersions = [
      "35"
      "36"
    ];
    buildToolsVersions = [
      "35.0.0"
      buildToolsVersion
    ];
    includeNDK = true;
    ndkVersions = [ ndkVersion ];
    cmakeVersions = [ "3.22.1" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ androidAbi ];
  };

  # A stable runtime path: the profile symlink follows the current generation
  # without the string changing, so the environment does not break on switch.
  androidRoot = "${identity.homeDirectory}/.nix-profile/libexec/android-sdk";
in
{
  nixpkgs.config.android_sdk.accept_license = true;

  home.packages = [ androidComposition.androidsdk ];

  home.sessionVariables = {
    ANDROID_HOME = androidRoot;
    ANDROID_SDK_ROOT = androidRoot;
    ANDROID_NDK_HOME = "${androidRoot}/ndk/${ndkVersion}";
  };

  home.sessionPath = [
    "${androidRoot}/platform-tools"
    "${androidRoot}/build-tools/${buildToolsVersion}"
    "${androidRoot}/cmdline-tools/latest/bin"
    "${androidRoot}/emulator"
  ];
}
