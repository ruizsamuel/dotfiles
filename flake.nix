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

    outputs = { self, nixpkgs, home-manager, nvim-config, ... }@inputs:
    let
        # Define todas las arquitecturas/sistemas soportados
        systems = [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
        ];
        
        # Función auxiliar para crear configuraciones
        mkHomeConfig = system: home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages."${system}";
            extraSpecialArgs = {
                inherit nvim-config;
            };
            modules = [
                ./home.nix
            ];
        };
    in {
        # Generate homeConfigurations for each system and a default one
        homeConfigurations = (builtins.listToAttrs (
            map (system: {
                name = "samuel@${system}";
                value = mkHomeConfig system;
            }) systems
        )) // {
            # Default configuration for backwards compatibility (x86_64-linux)
            "samuel" = mkHomeConfig "x86_64-linux";
        };
    };
}

