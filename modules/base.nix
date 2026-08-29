# Shared by every host: identity, state version and Nix housekeeping.
{ pkgs, lib, ... }:
let
  identity = import ../identity.nix { inherit pkgs; };
in
{
  home.username = identity.username;
  home.homeDirectory = identity.homeDirectory;
  home.stateVersion = "25.05";

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;

  # Garbage collection is driven by a systemd user timer, which only exists on
  # Linux. On macOS this would need launchd and is left to the user.
  nix.gc = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
