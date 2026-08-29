# The only file you need to edit after forking this repository.
#
# Nothing here is secret: the email is already public in the author field of
# every commit, and a GPG key ID identifies a *public* key. It lives in git
# because Nix reads it at evaluation time, so it cannot be gitignored.
{ pkgs }:
{
  username = "samuel";

  # macOS puts homes under /Users, Linux under /home. Hardcoding either breaks
  # the other platform.
  homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/samuel" else "/home/samuel";

  git = {
    userName = "Samuel Ruiz";
    userEmail = "samuel@ruizsamuel.es";

    signing = {
      enable = true;
      key = "6B50E0FDEA729EB7";
    };
  };
}
