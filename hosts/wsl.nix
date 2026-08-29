# WSL2 on Windows: main development machine.
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
    ../modules/orca.nix
  ];
}
