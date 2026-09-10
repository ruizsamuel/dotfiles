# Coding agents, and the skills that travel with this repository.
{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Skill directories become symlinks under ~/.claude/skills, one attribute per
  # directory, so nothing has to be listed by hand.
  linkSkills =
    root:
    lib.mapAttrs' (
      name: _:
      lib.nameValuePair ".claude/skills/${name}" {
        source = root + "/${name}";
      }
    ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));

  # The upstream SessionStart hook does one thing: read this file and inject it
  # as additional context. Reproducing the hook itself is not an option — it
  # would have to live in ~/.claude/settings.json, which Orca rewrites to wire
  # its own eleven hooks and which Claude Code rewrites for /config. Putting the
  # same content in CLAUDE.md, a file nothing else owns, gets the same result
  # declaratively.
  #
  # It also sidesteps a trap: the hook script branches on CLAUDE_PLUGIN_ROOT and,
  # unset, emits a field its own comments say Claude Code does not read. Run from
  # a store path rather than as a plugin, it would fail silently.
  usingSuperpowers = builtins.readFile "${inputs.superpowers}/skills/using-superpowers/SKILL.md";

  # Copilot CLI can load a plugin straight from a directory, so it gets the real
  # thing — skills and the upstream SessionStart hook — from the pinned store
  # path. Verified: the hook fires and the skills resolve. Claude Code cannot do
  # this, hence the CLAUDE.md reimplementation below.
  copilot = pkgs.symlinkJoin {
    name = "copilot-with-superpowers";
    paths = [ pkgs.github-copilot-cli ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/copilot \
        --add-flags "--plugin-dir ${inputs.superpowers}"
    '';
  };

  # Same framing the upstream hook emits.
  bootstrap = ''
    <EXTREMELY_IMPORTANT>
    You have superpowers.

    **Below is the full content of your 'superpowers:using-superpowers' skill -
    your introduction to using skills. For all other skills, use the 'Skill'
    tool:**

    ${usingSuperpowers}
    </EXTREMELY_IMPORTANT>
  '';
in
{
  home.packages = [
    pkgs.claude-code
    copilot
  ];

  # Personal skills, versioned in this repository. Orca's own skills are
  # deliberately NOT here — see the README for why that one step stays manual.
  home.file =
    linkSkills ../skills
    // linkSkills "${inputs.superpowers}/skills"
    // {
      # Only Claude Code needs this: Copilot gets the same content from the
      # plugin's own hook, so writing it to ~/.copilot/copilot-instructions.md
      # would put the identical text in context twice.
      ".claude/CLAUDE.md".text = bootstrap;
    };
}
