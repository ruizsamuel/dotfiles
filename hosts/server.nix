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

  # Reached over the tailnet by its MagicDNS name. The runtime speaks plain ws
  # (TLS is WireGuard's job here), so a bare host is enough: it is advertised
  # as ws://server:<port>. "wss://" would make clients attempt a TLS handshake
  # the runtime never answers.
  local.orca.pairingAddress = "server";
}
