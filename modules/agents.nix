# Coding agents and the skills that travel with this repository.
{ pkgs, lib, ... }:
{
  home.packages = [ pkgs.claude-code ];

  # Personal skills, versioned here so they follow any machine with a
  # `home-manager switch`. Orca's own skills are deliberately NOT versioned:
  # they belong to the app and are installed with `orca skills install --all`,
  # landing in ~/.agents/skills and symlinked into ~/.claude/skills. Linking
  # specific paths lets both sets coexist without clobbering each other.
  home.file = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".claude/skills/${name}" {
      source = ../skills + "/${name}";
    }
  ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../skills));
}
