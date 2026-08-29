# Shared by every host: identity, state version and Nix housekeeping.
{
  config,
  pkgs,
  lib,
  ...
}:
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
    options = "--delete-older-than 14d";
  };

  # Deduplication, written by hand because home-manager's nix module exposes
  # nix.gc but not nix.optimise. It hard-links identical files across store
  # paths, which matters a lot here: bumping nixpkgs rebuilds the Android system
  # images under new hashes while their contents are the same upstream zip, so
  # each bump would otherwise cost another ~10 GB. Unlike GC this deletes
  # nothing and costs no rollback.
  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.nix-optimise = {
      Unit.Description = "Deduplicate the Nix store";
      Service = {
        Type = "oneshot";
        # nix.package defaults to null (meaning "whatever nix is on PATH"), and a
        # systemd unit needs an absolute path, so fall back to the pinned one.
        ExecStart = "${
          lib.getExe' (if config.nix.package != null then config.nix.package else pkgs.nix) "nix-store"
        } --optimise";
        # Hard-linking a large store is IO-bound; keep it out of the way.
        IOSchedulingClass = "idle";
        Nice = 19;
      };
    };
    timers.nix-optimise = {
      Unit.Description = "Weekly Nix store deduplication";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
