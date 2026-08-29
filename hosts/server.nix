# Headless Linux server: an always-on Orca runtime to attach to remotely.
# No Android SDK — several GB for nothing on a machine with no emulator.
{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/shell.nix
    ../modules/tmux.nix
    ../modules/git.nix
    ../modules/neovim.nix
    ../modules/dev.nix
    ../modules/agents.nix
    ../modules/orca.nix
  ];

  # nginx terminates TLS for this subdomain and proxies to the port the runtime
  # listens on. An address containing "://" is embedded in the pairing code
  # verbatim: no port is appended, so clients get exactly this.
  local.orca.pairingAddress = "wss://dev.ruizsamuel.es";
}
