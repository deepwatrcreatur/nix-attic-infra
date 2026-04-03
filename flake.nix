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
              cat > "$out" <<'NIX_ATTIC_INFRA_EVAL_CHECK_EOF'
              ${builtins.toJSON value}
              NIX_ATTIC_INFRA_EVAL_CHECK_EOF
            '';

          # Assertion helper that fails the build if the condition is false
          mkAssert = name: condition: msg:
            if condition then
              pkgs.runCommand "assertion-${name}" { } "touch $out"
            else
              pkgs.runCommand "assertion-${name}-failed" { } ''
                echo "Assertion failed for ${name}: ${msg}" >&2
                exit 1
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
                    servers = {
                      "cache-prod" = {
                        endpoint = "https://cache.example.com";
                        tokenPath = "/run/user/1000/attic-token";
                        aliases = [
                          "main"
                          "dev"
                        ];
                      };
                      "cache-personal" = {
                        endpoint = "https://personal.attic.rs";
                        tokenPath = "/home/ci/.config/attic/personal-token";
                        aliases = [ "pers" ];
                      };
                      "cache.dot" = {
                        endpoint = "https://dot.example.com";
                        tokenPath = "/run/user/1000/dot-token";
                        aliases = [ "dot" ];
                      };
                      "cache_dot" = {
                        endpoint = "https://underscore.example.com";
                        tokenPath = "/run/user/1000/underscore-token";
                        aliases = [ "underscore" ];
                      };
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

              nixos-attic-client-upload-script =
                let
                  scriptText = nixosAtticClient.config.environment.etc."nix/attic-upload.sh".text;
                in
                mkAssert "nixos-attic-client-upload-script"
                  (lib.hasInfix ''[servers."cache-prod"]'' scriptText &&
                    lib.hasInfix ''endpoint = "https://cache.example.com"'' scriptText &&
                    lib.hasInfix ''token = "$token"'' scriptText)
                  "The NixOS post-build hook script should correctly generate config.toml";

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

              home-manager-attic-client-config-toml =
                let
                  configTomlText = homeManagerAtticClient.config.home.file.".config/attic/config.toml".text;
                  tokenPlaceholder = name: "@ATTIC_CLIENT_TOKEN_${lib.toUpper (builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name)}_${builtins.substring 0 8 (builtins.hashString "sha256" name)}@";
                in
                mkAssert "home-manager-attic-client-config-toml"
                  (lib.hasInfix ''[servers."cache-prod"]'' configTomlText &&
                    lib.hasInfix ''endpoint = "https://cache.example.com"'' configTomlText &&
                    lib.hasInfix "token = \"${tokenPlaceholder "cache-prod"}\"" configTomlText &&
                    lib.hasInfix ''[servers."cache-personal"]'' configTomlText &&
                    lib.hasInfix ''endpoint = "https://personal.attic.rs"'' configTomlText &&
                    lib.hasInfix "token = \"${tokenPlaceholder "cache-personal"}\"" configTomlText &&
                    lib.hasInfix ''[servers."cache.dot"]'' configTomlText &&
                    lib.hasInfix "token = \"${tokenPlaceholder "cache.dot"}\"" configTomlText &&
                    lib.hasInfix ''[servers."cache_dot"]'' configTomlText &&
                    lib.hasInfix "token = \"${tokenPlaceholder "cache_dot"}\"" configTomlText &&
                    tokenPlaceholder "cache.dot" != tokenPlaceholder "cache_dot")
                  "The generated config.toml should contain all configured servers and tokens";

              home-manager-attic-client-aliases =
                let
                  aliases = homeManagerAtticClient.config.home.shellAliases;
                in
                mkAssert "home-manager-attic-client-aliases"
                  (aliases."attic-push-main" == "attic push cache-prod:main" &&
                    aliases."attic-pull-main" == "attic pull cache-prod:main" &&
                    aliases."attic-push-dev" == "attic push cache-prod:dev" &&
                    aliases."attic-pull-dev" == "attic pull cache-prod:dev" &&
                    aliases."attic-push-pers" == "attic push cache-personal:pers" &&
                    aliases."attic-pull-pers" == "attic pull cache-personal:pers" &&
                    aliases."attic-push-dot" == "attic push cache.dot:dot" &&
                    aliases."attic-pull-dot" == "attic pull cache.dot:dot" &&
                    aliases."attic-push-underscore" == "attic push cache_dot:underscore" &&
                    aliases."attic-pull-underscore" == "attic pull cache_dot:underscore")
                  "The generated shell aliases should match the server:alias format";

              home-manager-attic-client-activation =
                let
                  activationScript = homeManagerAtticClient.config.home.activation.attic-config.data;
                  tokenPlaceholder = name: "@ATTIC_CLIENT_TOKEN_${lib.toUpper (builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name)}_${builtins.substring 0 8 (builtins.hashString "sha256" name)}@";
                in
                mkAssert "home-manager-attic-client-activation"
                  (lib.hasInfix "# Substitute token for cache-prod" activationScript &&
                    lib.hasInfix "placeholder=${tokenPlaceholder "cache-prod"}" activationScript &&
                    lib.hasInfix "# Substitute token for cache-personal" activationScript &&
                    lib.hasInfix "placeholder=${tokenPlaceholder "cache-personal"}" activationScript &&
                    lib.hasInfix "# Substitute token for cache.dot" activationScript &&
                    lib.hasInfix "placeholder=${tokenPlaceholder "cache.dot"}" activationScript &&
                    lib.hasInfix "# Substitute token for cache_dot" activationScript &&
                    lib.hasInfix "placeholder=${tokenPlaceholder "cache_dot"}" activationScript)
                  "The activation script should include substitution logic for all servers";

              home-manager-attic-client-darwin-eval = mkEvalCheck "home-manager-attic-client-darwin-eval" {
                atticEnable = homeManagerAtticClientDarwin.config.programs.attic-client.enable;
                nixUserConfigEnable = homeManagerAtticClientDarwin.config.services.nix-user-config.enable;
                hasPermissionsActivation = builtins.hasAttr "attic-darwin-permissions" homeManagerAtticClientDarwin.config.home.activation;
              };

              activation-harness = import ./tests/activation-harness.nix {
                inherit pkgs lib homeManagerAtticClient homeManagerAtticClientDarwin;
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
