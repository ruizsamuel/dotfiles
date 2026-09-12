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

    # Chromium's SUID sandbox helper has to be root-owned and mode 4755, which
    # is impossible inside the read-only Nix store, so it falls back to the
    # namespace sandbox. Where unprivileged user namespaces are disabled —
    # common hardening on Debian and Ubuntu servers — Electron aborts with
    # "SUID sandbox helper binary ... is not configured correctly" rather than
    # run unsandboxed. Probe for them the same way the vendor's AppRun does and
    # ask Orca to pass --no-sandbox only when they are unavailable.
    if ! ${pkgs.util-linux}/bin/unshare -Ur true 2>/dev/null; then
      export ORCA_APPIMAGE_NO_SANDBOX=1
    fi

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

  # Orca keeps its whole state — repos, worktrees, sessions — in one mutable
  # orca-data.json per profile, so the file cannot be a Nix store symlink. The
  # next best thing is to re-assert the settings we care about on every start,
  # while the runtime is down and cannot race us. Writing through `cat` instead
  # of renaming the temp file keeps the original inode and mode.
  settingsPatch = pkgs.writeShellScript "orca-settings-patch" ''
    set -eu

    file="$HOME/.config/orca/profiles/local-default/orca-data.json"
    # Absent before Orca's first run; it will start from its own defaults and
    # the next restart applies these.
    [ -f "$file" ] || exit 0

    tmp=$(${pkgs.coreutils}/bin/mktemp)
    ${pkgs.jq}/bin/jq --argjson patch ${lib.escapeShellArg (builtins.toJSON cfg.settings)} \
      '.settings = (.settings // {}) * $patch' "$file" >"$tmp"
    ${pkgs.coreutils}/bin/cat "$tmp" >"$file"
    ${pkgs.coreutils}/bin/rm -f "$tmp"
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
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        branchPrefix = "none";
      };
      description = ''
        Entries merged into the runtime's `settings` object every time the
        service starts, overriding whatever the UI last saved. The client app
        edits its OWN profile, so a preference toggled on the desktop never
        reaches the machine that actually creates the worktrees — this is where
        that machine's preferences belong.
      '';
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
    # `git-username` is Orca's default, which prefixes every worktree branch
    # with the git user name. Branches here are already namespaced by the task.
    local.orca.settings.branchPrefix = lib.mkDefault "none";

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
        ExecStartPre = [
          "-${pkgs.systemd}/bin/systemctl --user stop app-orca-*.scope"
        ] ++ lib.optional (cfg.settings != { }) "${settingsPatch}";
        ExecStopPost = "-${pkgs.systemd}/bin/systemctl --user stop app-orca-*.scope";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
