# Tmux.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.local.tmux.statusRight = lib.mkOption {
    type = lib.types.str;
    default = "#H %H:%M";
    description = "Right side of the status line, passed to minimal-tmux-status.";
  };

  config.programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = minimal-tmux-status;
        # The value has to be set here, not in extraConfig below: the plugin
        # reads @minimal-tmux-status-right when its run-shell executes and bakes
        # the result into status-right, and home-manager emits extraConfig
        # *after* that run-shell. Setting it there would be a no-op.
        extraConfig = ''
          ${builtins.readFile ../config/tmux/minimal-tmux-status.conf}
          set -g @minimal-tmux-status-right "${config.local.tmux.statusRight}"
        '';
      }
    ];
    extraConfig = ''
      set-option -g default-shell ${pkgs.zsh}/bin/zsh
      ${builtins.readFile ../config/tmux/tmux.conf}
    '';
  };
}
