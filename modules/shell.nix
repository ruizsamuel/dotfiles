# Zsh and the prompt.
{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      # Ctrl+Left / Ctrl+Right jump between words.
      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word

      ${builtins.readFile ../config/zshrc}
    '';
  };

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ../config/starship.toml);
  };
}
