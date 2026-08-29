# macOS on Apple Silicon.
#
# No Orca module: it ships a systemd service and Xvfb, neither of which exists
# here. Install the desktop app with `brew install --cask stablyai/orca/orca`.
#
# No Android module either. androidenv does support aarch64-darwin, but Android
# Studio installs and manages its own SDK under ~/Library/Android/sdk, and
# having a second one with ANDROID_HOME pointing elsewhere means duplicated
# multi-GB trees, diverging build-tools and NDK versions, and gradle behaving
# differently in the IDE and in the terminal. On macOS the desktop app wins.
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
  ];

  # macOS already shows the clock in the menu bar.
  local.tmux.statusRight = "#H";
}
