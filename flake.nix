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
