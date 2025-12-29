{
  description = "Enterprise Attic setup with SOPS and multi-server configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-attic-infra.url = "github:deepwatrcreatur/nix-attic-infra";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nix-attic-infra }:
    {
      nixosConfigurations.enterprise-node = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # SOPS for secrets management
          sops-nix.nixosModules.sops

          # Home Manager for user configuration
          home-manager.nixosModules.home-manager

          # Attic infrastructure modules
          nix-attic-infra.nixosModules.attic-post-build-hook

          # Your hardware configuration would go here
          # ./hardware-configuration.nix

          {
            # SOPS configuration
            sops = {
              defaultSopsFile = ./secrets.yaml;
              age.keyFile = "/var/lib/sops-nix/key.txt";

              secrets = {
                "attic/prod-token" = {
                  owner = "developer";
                  group = "users";
                };
                "attic/dev-token" = {
                  owner = "developer";
                  group = "users";
                };
              };
            };

            # Automated cache uploads
            services.attic-post-build-hook = {
              enable = true;
              cacheName = "production";
              user = "developer";
            };

            # Create developer user
            users.users.developer = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
            };

            # Home Manager configuration for the developer
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.developer = {
                imports = [
                  nix-attic-infra.homeManagerModules.attic-client
                ];

                programs.attic-client = {
                  enable = true;
                  servers = {
                    production = {
                      endpoint = "https://cache.prod.example.com";
                      tokenPath = "/run/secrets/attic/prod-token";
                      aliases = [ "prod" "main" ];
                    };
                    development = {
                      endpoint = "https://cache.dev.example.com";
                      tokenPath = "/run/secrets/attic/dev-token";
                      aliases = [ "dev" "test" ];
                    };
                    staging = {
                      endpoint = "https://cache.staging.example.com";
                      tokenPath = "/run/secrets/attic/prod-token"; # Reuse prod token
                      aliases = [ "staging" ];
                    };
                  };
                };

                home.stateVersion = "24.11";
              };
            };

            system.stateVersion = "24.11";
          }
        ];
      };

      # macOS configuration example
      darwinConfigurations.enterprise-mac = nixpkgs.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          sops-nix.darwinModules.sops

          {
            # Home Manager for macOS user
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.developer = {
                imports = [
                  nix-attic-infra.homeManagerModules.attic-client
                  nix-attic-infra.homeManagerModules.attic-client-darwin
                ];

                programs.attic-client = {
                  enable = true;
                  servers = {
                    production = {
                      endpoint = "https://cache.prod.example.com";
                      tokenPath = "/Users/developer/.config/sops/prod-token";
                    };
                  };
                };

                home.stateVersion = "24.11";
              };
            };

            system.stateVersion = 5;
          }
        ];
      };
    };
}