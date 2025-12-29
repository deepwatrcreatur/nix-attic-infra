{
  description = "Simple Attic client configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-attic-infra.url = "github:deepwatrcreatur/nix-attic-infra";
  };

  outputs = { self, nixpkgs, home-manager, nix-attic-infra }:
    {
      # Standalone Home Manager configuration
      homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          nix-attic-infra.homeManagerModules.attic-client

          {
            home = {
              username = "user";
              homeDirectory = "/home/user";
              stateVersion = "24.11";
            };

            programs.attic-client = {
              enable = true;
              servers.my-cache = {
                endpoint = "http://localhost:8080";
                tokenPath = "/home/user/.config/attic-token";
                aliases = [ "local" ];
              };
            };
          }
        ];
      };

      # Simple NixOS configuration
      nixosConfigurations.simple = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nix-attic-infra.nixosModules.attic-client

          # Your hardware configuration would go here
          # ./hardware-configuration.nix

          {
            services.attic-client = {
              enable = true;
              server = "http://localhost:8080";
              cache = "main";
              # For basic setup without SOPS, manually create the token file:
              # echo "your-token-here" > /run/secrets/attic-client-token
            };

            system.stateVersion = "24.11";
          }
        ];
      };

      # Using the helper functions from nix-attic-infra.lib
      nixosConfigurations.helper-example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nix-attic-infra.nixosModules.attic-post-build-hook

          (nix-attic-infra.lib.mkPostBuildHook {
            cacheName = "my-cache";
            user = "builder";
          })

          {
            system.stateVersion = "24.11";
            users.users.builder.isNormalUser = true;
          }
        ];
      };
    };
}