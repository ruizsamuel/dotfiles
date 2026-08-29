# Native Linux desktop. Same as WSL minus the Orca headless server: on a
# machine you sit at you want the Orca desktop app, not a remote runtime.
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
    ../modules/android.nix
  ];
}
