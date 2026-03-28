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
  tokenPlaceholder = name: "@ATTIC_CLIENT_TOKEN_${lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] name)}@";
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
    home.file.".config/attic/config.toml" = lib.mkIf cfg.tokenSubstitution {
      text =
      let
        serverConfigs = lib.mapAttrsToList (name: server: ''
          [servers."${name}"]
          endpoint = "${server.endpoint}"
          token = "${tokenPlaceholder name}"
        '') cfg.servers;
      in
      lib.concatStringsSep "\n\n" serverConfigs;
    };

    # Home activation script to substitute tokens
    home.activation.attic-config = lib.mkIf cfg.tokenSubstitution (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.config/attic"}
        config_file="$config_dir/config.toml"

        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$config_dir"

        if [[ -f "$config_file" ]]; then
          if [[ -n "$DRY_RUN" ]]; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/printf '%s\n' "Attic client configuration would be updated with tokens"
          else
            temp_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/config.toml.tmp.XXXXXX")"
            trap '${pkgs.coreutils}/bin/rm -f "$temp_file" "$temp_file.rendered"' EXIT

            # Copy the template
            ${pkgs.coreutils}/bin/cp "$config_file" "$temp_file"

            ${lib.concatStringsSep "\n            " (
              lib.mapAttrsToList (name: server: ''
                # Substitute token for ${name}
                if [[ -f "${server.tokenPath}" ]]; then
                  if [[ ! -r "${server.tokenPath}" ]]; then
                    $VERBOSE_ECHO "Warning: Token file not readable for ${name}: ${server.tokenPath}"
                  else
                    token="$(${pkgs.coreutils}/bin/cat "${server.tokenPath}")"
                    placeholder=${lib.escapeShellArg (tokenPlaceholder name)}
                    escaped_token=$(printf '%s' "$token" | ${pkgs.gnused}/bin/sed 's/[\\&|]/\\&/g')
                    ${pkgs.gnused}/bin/sed "s|$placeholder|$escaped_token|g" "$temp_file" > "$temp_file.rendered"
                    ${pkgs.coreutils}/bin/mv "$temp_file.rendered" "$temp_file"
                  fi
                else
                  $VERBOSE_ECHO "Warning: Token file not found for ${name}: ${server.tokenPath}"
                fi
              '') cfg.servers
            )}

            # Move the configured file into place
            ${pkgs.coreutils}/bin/mv "$temp_file" "$config_file"
            trap - EXIT
            $VERBOSE_ECHO "Attic client configuration updated with tokens"
          fi
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
                "attic-push-${aliasName}" = "attic push ${serverName}:${aliasName}";
                "attic-pull-${aliasName}" = "attic pull ${serverName}:${aliasName}";
              }) server.aliases
            ) cfg.servers
          )
        ))
      ]
    );
  };
}
