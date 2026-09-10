# WSL2 on Windows: main development machine.
{ lib, ... }:
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

  # WSL appends the Windows PATH itself, but a systemd user service builds its
  # environment from scratch, so everything Orca spawns loses interop: no
  # explorer.exe, no powershell.exe, and `open` (xdg-open) cannot reach the
  # Windows file manager. Appended rather than prepended so Windows binaries
  # never shadow their Linux namesakes.
  programs.zsh.initContent = lib.mkAfter ''
    if [ -d /mnt/c/Windows ]; then
      for _win in /mnt/c/Windows/System32 /mnt/c/Windows \
                  /mnt/c/Windows/System32/WindowsPowerShell/v1.0; do
        case ":$PATH:" in
          *":$_win:"*) ;;
          *) PATH="$PATH:$_win" ;;
        esac
      done
      unset _win
      export PATH
    fi
  '';
}
