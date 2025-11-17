{
    description = "Samuel Ruiz - Home Manager";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        nvim-config = {
            url = "github:ruizsamuel/nvim";
            flake = false;
        };
    };

    outputs = { self, nixpkgs, home-manager, nvim-config, ... }@inputs: {
        homeConfigurations."samuel" = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages."x86_64-linux";
            extraSpecialArgs = {
                inherit nvim-config;
            };
            modules = [
                ./home.nix
            ];
        };
    };
}

