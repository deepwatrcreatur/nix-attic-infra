# NixOS module for Attic client configuration
#
# This module configures the Nix daemon to use an Attic cache with
# automatic authentication token management via SOPS or agenix.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.services.attic-client;

  # Determine the token file path based on secrets backend
  tokenFilePath =
    if cfg.secretsBackend == "sops" && cfg.tokenFile != null then
      "/run/secrets/attic-client-token"
    else if cfg.secretsBackend == "agenix" && cfg.ageSecretFile != null then
      config.age.secrets."attic-client-token".path
    else if cfg.manualTokenPath != null then
      cfg.manualTokenPath
    else
      "/run/secrets/attic-client-token";

  substituterUrl = "${lib.removeSuffix "/" cfg.server}/${cfg.cache}";

  # Check if secrets modules are available by checking for their options
  hasSops = builtins.hasAttr "sops" options;
  hasAgenix = builtins.hasAttr "age" options;

in
{
  options.services.attic-client = {
    enable = lib.mkEnableOption "Attic client for NixOS with secrets management";

    secretsBackend = lib.mkOption {
      type = lib.types.enum [ "sops" "agenix" "none" ];
      default = "sops";
      description = ''
        Which secrets backend to use for managing the Attic token.
        - "sops": Use sops-nix (requires sops-nix module)
        - "agenix": Use agenix (requires agenix module)
        - "none": Manual token management (provide manualTokenPath)
      '';
      example = "agenix";
    };

    server = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:5001";
      description = "The URL of the Attic cache server";
      example = "https://cache.example.com";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "attic-cache";
      description = ''
        The name used in the generated Attic config (used as a prefix for
        pushes like `serverName:cache`).
      '';
      example = "attic";
    };

    cache = lib.mkOption {
      type = lib.types.str;
      default = "cache-local";
      description = "The name of the cache to use for pulls and pushes";
      example = "main";
    };

    # SOPS options
    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the SOPS encrypted token file. Only used when secretsBackend = "sops".
        If null with sops backend, you must ensure a token is available at /run/secrets/attic-client-token.
      '';
    };

    tokenKey = lib.mkOption {
      type = lib.types.str;
      default = "ATTIC_CLIENT_JWT_TOKEN";
      description = "The key name in the SOPS file containing the token (sops backend only)";
    };

    # Agenix options
    ageSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the age-encrypted secret file (.age). Only used when secretsBackend = "agenix".
        The file should contain the raw JWT token.
      '';
      example = lib.literalExpression "./secrets/attic-client-token.age";
    };

    ageSecretOwner = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Owner of the decrypted agenix secret file";
    };

    ageSecretGroup = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group of the decrypted agenix secret file";
    };

    # Manual token path option
    manualTokenPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the token file when using secretsBackend = "none".
        You are responsible for ensuring this file exists with the correct permissions.
      '';
      example = "/run/secrets/attic-client-token";
    };

    enablePostBuildHook = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable automatic pushing to the cache via `nix.settings.post-build-hook`.

        Prefer the dedicated `services.attic-post-build-hook` module when possible.
      '';
    };

    trustedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional trusted public keys for the configured substituter.";
    };

    configureNixSubstituter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure Nix substituters for the cache.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base configuration (always applied when enabled)
    {
      assertions = [
        {
          assertion = cfg.secretsBackend != "sops" || cfg.tokenFile != null || cfg.manualTokenPath != null;
          message = "services.attic-client: When using sops backend, tokenFile must be set (or use manualTokenPath with secretsBackend = \"none\")";
        }
        {
          assertion = cfg.secretsBackend != "agenix" || cfg.ageSecretFile != null;
          message = "services.attic-client: When using agenix backend, ageSecretFile must be set";
        }
        {
          assertion = cfg.secretsBackend != "none" || cfg.manualTokenPath != null;
          message = "services.attic-client: When using 'none' backend, manualTokenPath must be set";
        }
        {
          assertion = cfg.secretsBackend != "sops" || hasSops;
          message = "services.attic-client: secretsBackend is set to 'sops' but sops-nix module is not available. Import sops-nix or use a different backend.";
        }
        {
          assertion = cfg.secretsBackend != "agenix" || hasAgenix;
          message = "services.attic-client: secretsBackend is set to 'agenix' but agenix module is not available. Import agenix or use a different backend.";
        }
      ];

      warnings = lib.optional (cfg.configureNixSubstituter && cfg.trustedPublicKeys == [ ]) ''
        attic-client: configureNixSubstituter is enabled but trustedPublicKeys is empty.
        The trusted-public-keys attribute will be omitted from nix.settings.
        Consider adding trusted public keys to services.attic-client.trustedPublicKeys
        or configure substituters manually if signature verification is needed.
      '';

      environment.systemPackages = [ pkgs.attic-client ];

      environment.etc."nix/attic-upload.sh" = lib.mkIf cfg.enablePostBuildHook {
        mode = "0755";
        text = ''
          #!${pkgs.bash}/bin/bash
          # Fail-safe post-build hook - never blocks builds.
          set -uo pipefail

          out_paths="''${OUT_PATHS-}"
          drv_path="''${DRV_PATH-}"

          if [ -z "$out_paths" ]; then
            exit 0
          fi

          # Skip source/temporary derivations.
          if [[ "$drv_path" == *"-source.drv" ]] || [[ "$drv_path" == *"tmp"* ]]; then
            exit 0
          fi

          token_file="${tokenFilePath}"
          if [ ! -f "$token_file" ]; then
            echo "Attic: Token not available, skipping push" >&2
            exit 0
          fi

          if [ ! -r "$token_file" ]; then
            echo "Attic: Token file not readable, skipping push" >&2
            exit 0
          fi

          token=$(cat "$token_file")
          if [ -z "$token" ]; then
            echo "Attic: Token empty, skipping push" >&2
            exit 0
          fi

          tmpdir=$(mktemp -d)
          trap 'rm -rf "$tmpdir"' EXIT

          export XDG_CONFIG_HOME="$tmpdir"
          mkdir -p "$XDG_CONFIG_HOME/attic"

          cat > "$XDG_CONFIG_HOME/attic/config.toml" <<EOF
          [servers."${cfg.serverName}"]
          endpoint = "${cfg.server}"
          token = "$token"
          EOF

          {
            echo "Attic: pushing to ${cfg.serverName}:${cfg.cache}" >&2
            # shellcheck disable=SC2086
            ${pkgs.attic-client}/bin/attic push "${cfg.serverName}:${cfg.cache}" $out_paths 2>&1 || true
          }

          exit 0
        '';
      };

      nix.settings = lib.mkMerge [
        (lib.mkIf cfg.enablePostBuildHook {
          post-build-hook = "/etc/nix/attic-upload.sh";
        })
        (lib.mkIf cfg.configureNixSubstituter (
          {
            substituters = lib.mkDefault [ substituterUrl ];
          }
          // lib.optionalAttrs (cfg.trustedPublicKeys != [ ]) {
            trusted-public-keys = lib.mkDefault cfg.trustedPublicKeys;
          }
        ))
      ];

      systemd.services.nix-attic-token = lib.mkIf (cfg.secretsBackend != "none") {
        description = "Prepare Attic authentication token for Nix daemon";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          token_file="${tokenFilePath}"

          if [[ -f "$token_file" ]]; then
            if [[ ! -r "$token_file" ]]; then
              echo "Warning: Attic client token not readable. Cache pulls may fail."
            else
              token=$(cat "$token_file")
              if [[ -z "$token" ]]; then
                echo "Warning: Attic client token is empty. Cache pulls may fail."
              else
                echo "Preparing Attic token for Nix daemon cache access..."
                mkdir -p /run/nix
                umask 0077
                echo "bearer $token" > /run/nix/attic-token-bearer
                chmod 0600 /run/nix/attic-token-bearer
              fi
            fi
          else
            echo "Warning: Attic client token not found at $token_file" >&2
          fi
        '';
      };

      systemd.services.nix-daemon = lib.mkIf (cfg.secretsBackend != "none") {
        requires = [ "nix-attic-token.service" ];
        after = [ "nix-attic-token.service" ];
      };
    }

    # SOPS backend configuration
    (lib.mkIf (cfg.secretsBackend == "sops" && cfg.tokenFile != null && hasSops) {
      sops.secrets."attic-client-token" = {
        sopsFile = cfg.tokenFile;
        key = cfg.tokenKey;
        path = "/run/secrets/attic-client-token";
        owner = config.users.users.root.name;
        group = config.users.users.root.group;
        mode = "0400";
      };
    })

    # Agenix backend configuration
    (lib.mkIf (cfg.secretsBackend == "agenix" && cfg.ageSecretFile != null && hasAgenix) {
      age.secrets."attic-client-token" = {
        file = cfg.ageSecretFile;
        owner = cfg.ageSecretOwner;
        group = cfg.ageSecretGroup;
        mode = "0400";
      };
    })
  ]);
}
