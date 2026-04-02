{
  description = "Production-ready Attic binary cache infrastructure with automated post-build hooks, SOPS/agenix secrets integration, and cross-platform client management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    attic-observatory = {
      url = "github:deepwatrcreatur/attic-observatory";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Canonical upstream Attic flake (server + client + nixos module)
    attic.url = "github:zhaofengli/attic";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , home-manager
    , attic
    , attic-observatory
    ,
    }:
    flake-utils.lib.eachDefaultSystem
      (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          evalNixos =
            modules:
            lib.nixosSystem {
              inherit system;
              modules = modules ++ [{ nixpkgs.hostPlatform = system; }];
            };
          evalHomeManager =
            modules:
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = modules ++ [
                {
                  home.username = "ci";
                  home.homeDirectory = "/home/ci";
                  home.stateVersion = "25.11";
                }
              ];
            };
          mkEvalCheck =
            name: value:
            pkgs.runCommand name { } ''
              cat > "$out" <<'EOF'
              ${builtins.toJSON value}
              EOF
            '';
        in
        {
          packages = {
            # Re-export canonical upstream packages.
            attic = attic.packages.${system}.attic;
            attic-client = attic.packages.${system}.attic-client;
            attic-server = attic.packages.${system}.attic-server;
            attic-observatory = attic-observatory.packages.${system}.default;
            default = attic.packages.${system}.attic;
          };

          # Development shell for working on this flake
          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.nixpkgs-fmt
              attic.packages.${system}.attic-client
            ];

            shellHook = ''
              echo "nix-attic-infra development environment"
              echo "Available commands:"
              echo "  nix flake check    - Check flake validity"
              echo "  nix flake show     - Show flake outputs"
              echo "  nixpkgs-fmt .      - Format Nix files"
            '';
          };

          # Formatter for nix fmt
          formatter = pkgs.nixpkgs-fmt;

          checks =
            let
              nixosAtticClient = evalNixos [
                self.nixosModules.attic-client
                {
                  networking.hostName = "builder";
                  system.stateVersion = "25.11";
                  services.attic-client = {
                    enable = true;
                    secretsBackend = "none";
                    manualTokenPath = "/run/secrets/attic-client-token";
                    server = "https://cache.example.com";
                    serverName = "cache-prod";
                    cache = "main";
                    configureNixSubstituter = true;
                    trustedPublicKeys = [ "cache.example.com-1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=" ];
                    enablePostBuildHook = true;
                  };
                }
              ];
              nixosPostBuildHook = evalNixos [
                self.nixosModules.attic-post-build-hook
                {
                  networking.hostName = "builder";
                  system.stateVersion = "25.11";
                  services.attic-post-build-hook = {
                    enable = true;
                    serverName = "cache-prod";
                    cacheName = "main";
                    serverEndpoint = "https://cache.example.com";
                    tokenFile = "/run/secrets/attic-client-token";
                  };
                }
              ];
              nixosAtticObservatory = evalNixos [
                self.nixosModules.attic-observatory
                {
                  system.stateVersion = "25.11";
                  services.attic-observatory = {
                    enable = true;
                    theme = "nord";
                    openFirewall = true;
                    nginx.virtualHost = "attic-observability";
                    nginx.port = 8082;
                  };
                }
              ];
              homeManagerAtticClient = evalHomeManager [
                self.homeManagerModules.attic-client
                {
                  programs.attic-client = {
                    enable = true;
                    servers."cache-prod" = {
                      endpoint = "https://cache.example.com";
                      tokenPath = "/run/user/1000/attic-token";
                      aliases = [
                        "main"
                        "dev"
                      ];
                    };
                  };
                }
              ];
              homeManagerAtticClientDarwin = evalHomeManager [
                self.homeManagerModules.attic-client
                self.homeManagerModules.attic-client-darwin
                {
                  options.services.nix-user-config.enable = lib.mkEnableOption "stub nix-user-config option for module evaluation";
                  config.programs.attic-client.servers."cache-prod" = {
                    endpoint = "https://cache.example.com";
                    tokenPath = "/Users/ci/.config/attic/token";
                    aliases = [ "main" ];
                  };
                }
              ];
            in
            {
              nixos-attic-client-eval = mkEvalCheck "nixos-attic-client-eval" {
                packageCount = builtins.length nixosAtticClient.config.environment.systemPackages;
                substituters = nixosAtticClient.config.nix.settings.substituters;
                postBuildHook = nixosAtticClient.config.nix.settings.post-build-hook;
              };

              nixos-post-build-hook-eval = mkEvalCheck "nixos-post-build-hook-eval" {
                postBuildHook = nixosPostBuildHook.config.nix.settings.post-build-hook;
                packageCount = builtins.length nixosPostBuildHook.config.environment.systemPackages;
              };

              nixos-attic-observatory-eval = mkEvalCheck "nixos-attic-observatory-eval" {
                firewallPorts = nixosAtticObservatory.config.networking.firewall.allowedTCPPorts;
                nginxHost = builtins.attrNames nixosAtticObservatory.config.services.nginx.virtualHosts;
                timerExists = builtins.hasAttr "attic-observatory-db-sync" nixosAtticObservatory.config.systemd.timers;
              };

              home-manager-attic-client-eval = mkEvalCheck "home-manager-attic-client-eval" {
                packageCount = builtins.length homeManagerAtticClient.config.home.packages;
                aliasNames = builtins.attrNames homeManagerAtticClient.config.home.shellAliases;
                atticConfigTarget = homeManagerAtticClient.config.home.file.".config/attic/config.toml".target;
              };

              home-manager-attic-client-darwin-eval = mkEvalCheck "home-manager-attic-client-darwin-eval" {
                atticEnable = homeManagerAtticClientDarwin.config.programs.attic-client.enable;
                nixUserConfigEnable = homeManagerAtticClientDarwin.config.services.nix-user-config.enable;
                hasPermissionsActivation = builtins.hasAttr "attic-darwin-permissions" homeManagerAtticClientDarwin.config.home.activation;
              };
            };
        }
      )
    // {
      # NixOS modules for system-level integration
      nixosModules = {
        # Canonical upstream server module
        atticd = attic.nixosModules.atticd;

        # nix-attic-infra additions
        attic-post-build-hook = import ./modules/nixos/attic-post-build-hook.nix;
        attic-client = import ./modules/nixos/attic-client.nix;
        attic-observatory = import ./modules/nixos/attic-observatory.nix { atticObservatory = attic-observatory; };

        default = self.nixosModules.attic-post-build-hook;
      };

      # Home Manager modules for user-level configuration
      homeManagerModules = {
        attic-client = import ./modules/home-manager/attic-client.nix;
        attic-client-darwin = import ./modules/home-manager/attic-client-darwin.nix;
        default = self.homeManagerModules.attic-client;
      };

      # Templates for easy setup
      templates = {
        automated-client = {
          path = ./examples/automated-client;
          description = "Automated Attic client with post-build hooks";
        };
        secure-enterprise = {
          path = ./examples/secure-enterprise;
          description = "Enterprise setup with SOPS and multi-server configuration";
        };
        basic-client = {
          path = ./examples/basic-client;
          description = "Simple Attic client configuration";
        };
        default = self.templates.automated-client;
      };

      # Library functions for advanced usage
      lib = {
        # Helper to create attic client configuration
        mkAtticClient =
          { servers
          , enableShellAliases ? true
          , tokenSubstitution ? true
          ,
          }:
          {
            programs.attic-client = {
              enable = true;
              inherit servers enableShellAliases tokenSubstitution;
            };
          };

        # Helper to create post-build hook configuration
        mkPostBuildHook =
          { cacheName
          , serverHostnames ? [
              "atticd"
              "attic-cache"
              "cache-server"
            ]
          ,
          }:
          {
            services.attic-post-build-hook = {
              enable = true;
              inherit cacheName serverHostnames;
            };
          };

        # Common server configurations
        commonServers = {
          local = {
            endpoint = "http://localhost:8080";
            aliases = [ "local" ];
          };
          localhost = {
            endpoint = "http://127.0.0.1:8080";
            aliases = [ "localhost" ];
          };
        };
      };
    };
}
