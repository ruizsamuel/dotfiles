# Orca (https://onorca.dev) — CLI and headless runtime only (`orca serve`).
#
# Not in nixpkgs (`pkgs.orca` is the GNOME screen reader), so we package the
# official AppImage. The CLI lives inside it and runs by reusing its bundled
# Electron in Node mode (ELECTRON_RUN_AS_NODE).
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  writeShellScriptBin,
}:

let
  version = "1.4.199";

  sources = {
    x86_64-linux = {
      file = "orca-linux.AppImage";
      hash = "sha256-rrH9Qg3IFbeanBVO26GXj4jljzmO9IUluVcF1mHrr0U=";
    };
    aarch64-linux = {
      file = "orca-linux-arm64.AppImage";
      hash = "sha256-4r5F82P5rdHjqb/wmWyXQFyNSeWqZQxnP26om5q5nTM=";
    };
  };

  system = stdenv.hostPlatform.system;
  source =
    sources.${system}
      or (throw "orca: unsupported system ${system} (have ${lib.concatStringsSep ", " (lib.attrNames sources)})");

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/${source.file}";
    inherit (source) hash;
  };

  contents = appimageTools.extract {
    pname = "orca";
    inherit version src;
  };
in
(writeShellScriptBin "orca" ''
  # Deliberately NOT buildFHSEnv, which is the usual way to run an AppImage:
  # Orca spawns terminals and agents, and they would all inherit that synthetic
  # /usr, where basics like `clear`, `ps` or `apt` are missing. The binary
  # resolves every library against the host system, so the sandbox buys nothing.
  #
  # We also bypass AppRun: it injects `--no-sandbox`, which makes Electron abort
  # with "bad option" in Node mode, and exports an LD_LIBRARY_PATH that child
  # processes would inherit.

  # A LD_LIBRARY_PATH inherited from the nix profile mixes host libraries with
  # the AppImage's and breaks the Electron binary.
  unset LD_LIBRARY_PATH

  export ELECTRON_RUN_AS_NODE=1
  exec ${contents}/orca-ide \
    ${contents}/resources/app.asar.unpacked/out/cli/index.js "$@"
'').overrideAttrs
  (old: {
    inherit version;
    passthru = { inherit contents src; };
    meta = {
      description = "Agent Development Environment for running coding agents in parallel";
      homepage = "https://onorca.dev";
      downloadPage = "https://github.com/stablyai/orca/releases";
      license = lib.licenses.mit;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = lib.attrNames sources;
      mainProgram = "orca";
    };
  })
