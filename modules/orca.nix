# Orca headless runtime server, so a desktop or mobile Orca client can attach
# to this machine. See https://www.onorca.dev/docs/remote-servers
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.local.orca;

  orca = pkgs.callPackage ../pkgs/orca.nix { };

  # The outbound source address, which is the LAN interface. Picking it from the
  # default route ignores docker0 and, on WSL, the internal loopback.
  detectIp = "${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 | ${pkgs.gawk}/bin/awk '{print $7; exit}' ";

  serveStart = pkgs.writeShellScript "orca-serve-start" ''
    set -eu
    addr='${toString cfg.pairingAddress}'
    if [ -z "$addr" ]; then
      addr=$(${detectIp})
    fi
    if [ -z "$addr" ]; then
      echo "orca-serve: could not determine this machine's IP address" >&2
      exit 1
    fi
    exec ${pkgs.xvfb-run}/bin/xvfb-run -a \
      ${orca}/bin/orca serve --port ${toString cfg.port} --pairing-address "$addr"
  '';

  # What the advertised endpoint should look like. Mirrors Orca's own
  # resolution: an address containing "://" is taken verbatim, a bare host keeps
  # the bound port. Without this the helper would compare a fixed address
  # against the detected IP, never match, and restart the service on every run.
  expectedEndpoint =
    if cfg.pairingAddress == null then
      "ws://$(${detectIp}):${toString cfg.port}"
    else if lib.hasInfix "://" cfg.pairingAddress then
      cfg.pairingAddress
    else
      "ws://${cfg.pairingAddress}:${toString cfg.port}";

  # The one command to remember when the machine's IP changes: it prints the
  # pairing URL and, if the advertised address is stale, restarts the service to
  # regenerate it. No need to touch the Nix configuration.
  pairing = pkgs.writeShellScriptBin "orca-pairing" ''
    set -eu

    # $since scopes the journal to the current run of the service: reading an
    # older line would hand out a URL for a previous address.
    since="-1 year"

    field() {
      journalctl --user -t orca-serve --since "$since" --no-pager \
        | ${pkgs.gnugrep}/bin/grep -F "$1" \
        | tail -n1 \
        | ${pkgs.gnused}/bin/sed "s|.*$1 ||"
    }
    advertised() {
      field 'Advertised endpoint:'
    }
    expected="${expectedEndpoint}"

    if [ "$(advertised)" != "$expected" ] || ! systemctl --user is-active --quiet orca-serve; then
      echo "advertising $expected; restarting orca-serve..." >&2
      since=$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')
      systemctl --user restart orca-serve
    fi

    # The runtime takes a few seconds to announce itself.
    for _ in $(${pkgs.coreutils}/bin/seq 60); do
      url=$(field 'Pairing URL:')
      if [ -n "''${url:-}" ] && [ "$(advertised)" = "$expected" ]; then
        echo "$url"
        exit 0
      fi
      sleep 1
    done

    echo "orca-pairing: the server never announced itself; see" \
      "'journalctl --user -t orca-serve -e'" >&2
    exit 1
  '';
in
{
  options.local.orca = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
      description = "Port the headless runtime listens on.";
    };
    pairingAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Address advertised to clients. "localhost" does NOT work: the client
        reads a loopback endpoint as its own runtime and refuses to pair.
        Null detects this machine's IP at service start.
      '';
    };
  };

  config = {
    home.packages = [
      orca
      pairing
    ];

    programs.zsh.initContent = lib.mkBefore ''
      # Orca prepends its own `orca` shim to PATH
      # (~/.config/orca/linux-orca-cli-shim), and that shim does NOT clear
      # LD_LIBRARY_PATH. Since the claude-code wrapper exports one containing
      # nix's alsa-lib, the shim blows up Orca's Electron with
      # "GLIBC_ABI_GNU2_TLS not found" as soon as an agent uses the CLI.
      # Ours does clear it, so it has to win.
      export PATH="$HOME/.nix-profile/bin:$PATH"
    '';

    # Electron needs an X server even headless: with no DISPLAY it exits with
    # "The platform failed to initialize", and under WSLg's display it dies with
    # SIGTRAP. Xvfb is an in-memory display that needs no graphical session.
    systemd.user.services.orca-serve = {
      Unit = {
        Description = "Orca headless runtime server";
        Documentation = "https://www.onorca.dev/docs/remote-servers";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/bin:/usr/bin:/bin"
          # Without this Orca opens bash (the shell in /etc/passwd), which execs
          # into zsh from ~/.bashrc. That exec mid-startup swallows the bash
          # wrapper's "shell ready" signal, so the command Orca injects
          # (`claude`, ...) arrives too early and fails. Pointing at zsh makes
          # it use the zsh wrapper directly.
          "SHELL=%h/.nix-profile/bin/zsh"
        ];
        ExecStart = "${serveStart}";
        # The pairing URL is printed on startup:
        #   journalctl --user -t orca-serve -e
        SyslogIdentifier = "orca-serve";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 30;
        # The real runtime is an Electron process that registers its own systemd
        # scope (app-orca-<pid>.scope), which means it LEAVES the service's
        # cgroup: stopping the service does not kill it, and the orphan keeps
        # serving the CLI with the previous generation's environment. The scopes
        # have to be swept by hand on stop and before start.
        ExecStartPre = "-${pkgs.systemd}/bin/systemctl --user stop app-orca-*.scope";
        ExecStopPost = "-${pkgs.systemd}/bin/systemctl --user stop app-orca-*.scope";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
