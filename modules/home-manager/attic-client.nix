# Home Manager module for Attic binary cache client
#
# This module provides cross-platform Attic client configuration with:
# - SOPS integration for secure token management
# - Multi-server configuration support
# - Dynamic token substitution during activation
# - Convenient shell aliases
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.attic-client;
in
{
  options.programs.attic-client = {
    enable = lib.mkEnableOption "Attic binary cache client with SOPS-managed authentication";

    servers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            endpoint = lib.mkOption {
              type = lib.types.str;
              description = "Attic server endpoint URL";
              example = "https://cache.example.com";
            };
            tokenPath = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.config/sops/attic-token";
              description = ''
                Path to the token file (typically managed by SOPS).
                The file should contain a valid Attic authentication token.
              '';
            };
            aliases = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = ''
                List of cache names to create shell aliases for.
                Creates 'attic-push-{name}' aliases for each entry.
              '';
              example = [ "main" "dev" ];
            };
          };
        }
      );
      default = { };
      description = "Attic servers configuration";
      example = {
        production = {
          endpoint = "https://cache.prod.example.com";
          tokenPath = "/path/to/prod-token";
          aliases = [ "prod" "main" ];
        };
        development = {
          endpoint = "http://cache.dev.example.com:5001";
          tokenPath = "/path/to/dev-token";
          aliases = [ "dev" ];
        };
      };
    };

    enableShellAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create convenient shell aliases for attic push commands";
    };

    tokenSubstitution = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable automatic token substitution during home-manager activation.
        When disabled, you must manually manage the attic configuration file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Install attic-client
    home.packages = [ pkgs.attic-client ];

    # Create Attic client configuration template
    home.file.".config/attic/config.toml".text =
      let
        serverConfigs = lib.mapAttrsToList (name: server: ''
          [servers.${name}]
          endpoint = "${server.endpoint}"
          token = "@ATTIC_CLIENT_TOKEN_${lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] name)}@"
        '') cfg.servers;
      in
      lib.concatStringsSep "\n\n" serverConfigs;

    # Home activation script to substitute tokens
    home.activation.attic-config = lib.mkIf cfg.tokenSubstitution (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.config/attic

        if [[ -f ${config.home.homeDirectory}/.config/attic/config.toml ]]; then
          config_file="${config.home.homeDirectory}/.config/attic/config.toml"
          temp_file="/tmp/attic-config-$$.toml"

          # Copy the template
          cp "$config_file" "$temp_file"

          ${lib.concatStringsSep "\n          " (
            lib.mapAttrsToList (name: server: ''
              # Substitute token for ${name}
              if [[ -f "${server.tokenPath}" ]]; then
                token=$(cat "${server.tokenPath}")
                placeholder="@ATTIC_CLIENT_TOKEN_${lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] name)}@"
                $DRY_RUN_CMD sed -i "s|$placeholder|$token|g" "$temp_file"
              else
                $VERBOSE_ECHO "Warning: Token file not found for ${name}: ${server.tokenPath}"
              fi
            '') cfg.servers
          )}

          # Move the configured file into place
          $DRY_RUN_CMD mv "$temp_file" "$config_file"
          $VERBOSE_ECHO "Attic client configuration updated with tokens"
        fi
      ''
    );

    # Create shell aliases for convenient attic operations
    home.shellAliases = lib.mkIf cfg.enableShellAliases (
      lib.mkMerge [
        # Generic aliases
        {
          attic-list = "attic cache list";
          attic-info = "attic cache info";
        }

        # Server-specific aliases
        (lib.mkMerge (
          lib.flatten (
            lib.mapAttrsToList (serverName: server:
              map (aliasName: {
                "attic-push-${aliasName}" = "attic push ${aliasName}";
                "attic-pull-${aliasName}" = "attic pull ${aliasName}";
              }) server.aliases
            ) cfg.servers
          )
        ))
      ]
    );
  };
}