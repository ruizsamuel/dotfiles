# Neovim. The configuration itself lives in its own repository, pulled in as a
# flake input so it can be updated independently of this one.
{ pkgs, inputs, ... }:
{
  home.packages = [ pkgs.neovim ];

  home.file.".config/nvim" = {
    source = inputs.nvim-config;
    recursive = true;
  };
}
