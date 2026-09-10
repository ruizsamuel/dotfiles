{
  description = "Samuel Ruiz - Home Manager dotfiles";

  inputs = {
    # nixpkgs-unstable, not nixos-unstable: the latter is gated on the NixOS
    # test suite, which is Linux-only. This repo also targets macOS.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-config = {
      url = "github:ruizsamuel/nvim";
      flake = false;
    };
    # Superpowers ships as a Claude Code plugin, but upstream is a plain git
    # repo of skill directories, so the lock can pin it exactly and
    # `nix flake update superpowers` bumps it on its own.
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Every machine this repo knows how to configure, and the system it runs
      # on. Adding a host is one line here plus a file in ./hosts.
      hosts = {
        wsl = "x86_64-linux";
        server = "x86_64-linux";
        desktop = "x86_64-linux";
        mac = "aarch64-darwin";
      };

      # Systems we produce dev outputs (formatter, devShell) for. Broader than
      # the hosts above so `nix fmt` works on any machine.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      mkHost =
        name: system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs; };
          modules = [ ./hosts/${name}.nix ];
        };
    in
    {
      homeConfigurations = nixpkgs.lib.mapAttrs' (
        name: system: nixpkgs.lib.nameValuePair "samuel@${name}" (mkHost name system)
      ) hosts;

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      # `nix run .#update-orca` — bump the pinned Orca release.
      #
      # Orca is not a flake input, so `nix flake update` cannot touch it: it is a
      # fetchurl inside pkgs/orca.nix with the version and both architecture
      # hashes written by hand. Making it an input would mean every evaluation
      # on every host downloading two 200 MB AppImages, including the Mac, which
      # has no Orca module, and CI, whose whole point is to evaluate cheaply.
      packages = forAllSystems (pkgs: {
        update-orca = pkgs.writeShellApplication {
          name = "update-orca";
          runtimeInputs = with pkgs; [
            curl
            jq
            nix
            gnused
          ];
          text = ''
            set -euo pipefail
            cd "''${1:-.}"
            [ -f pkgs/orca.nix ] || {
              echo "run this from the repository root" >&2
              exit 1
            }

            current=$(sed -n 's/^ *version = "\(.*\)";/\1/p' pkgs/orca.nix)
            latest=$(curl -fsSL https://api.github.com/repos/stablyai/orca/releases/latest \
              | jq -r .tag_name | sed 's/^v//')

            echo "pinned: $current"
            echo "latest: $latest"
            [ "$current" != "$latest" ] || { echo "already up to date"; exit 0; }

            for file in orca-linux.AppImage orca-linux-arm64.AppImage; do
              echo "hashing $file..." >&2
              raw=$(nix-prefetch-url --quiet \
                "https://github.com/stablyai/orca/releases/download/v$latest/$file")
              sri=$(nix hash convert --hash-algo sha256 --to sri "$raw")
              echo "  $sri"
              # Anchor on the file name and rewrite the hash inside that block,
              # so the substitution does not depend on line order.
              sed -i "\|file = \"$file\";|,/};/ s|hash = \"[^\"]*\"|hash = \"$sri\"|" \
                pkgs/orca.nix
            done

            sed -i "s|^\( *version = \)\"[^\"]*\";|\1\"$latest\";|" pkgs/orca.nix

            echo
            echo "pkgs/orca.nix updated to $latest. Review, then:"
            echo "  nix fmt && git commit -am \"chore: update Orca to $latest\""
          '';
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nixfmt-rfc-style
            home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];
        };
      });
    };
}
