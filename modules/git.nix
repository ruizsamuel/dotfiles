# Git, GitHub CLI and GPG signing.
{ pkgs, lib, ... }:
let
  identity = import ../identity.nix { inherit pkgs; };
in
{
  programs.git = {
    enable = true;
    signing = lib.mkIf identity.git.signing.enable {
      key = identity.git.signing.key;
      signByDefault = false;
    };
    settings = {
      user.name = identity.git.userName;
      user.email = identity.git.userEmail;
      gpg.program = "gpg";
    };
  };

  programs.gh = {
    enable = true;
    extensions = [ pkgs.github-copilot-cli ];
  };

  home.packages = with pkgs; [
    gnupg
    pinentry-curses
    openssh
  ];

  # The gpg-agent module drives a systemd user service, so it is Linux-only.
  # macOS ships its own agent lifecycle via gpgconf.
  services.gpg-agent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
