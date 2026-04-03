# NixOS module for Attic post-build hook automation
#
# This module provides zero-touch binary cache population by automatically
# pushing build outputs to your Attic cache after successful builds.
#
# IMPORTANT: Do NOT enable this on the host running atticd to avoid circular dependencies!
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.attic-post-build-hook;

  tokenFilePath = if cfg.tokenFile == null then "" else toString cfg.tokenFile;
  runtimePathType = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);

  postBuildScript = pkgs.writeShellScript "attic-post-build-hook" ''
        # NOTE: This script must never fail a build.
        set -f # disable globbing
        export IFS=' '

        out_paths="''${OUT_PATHS-}"
        drv_path="''${DRV_PATH-}"

        if [ -z "$out_paths" ]; then
          exit 0
        fi

        log() {
          echo "Attic: \$*" >&2
        }

        verbose_log() {
          if [[ "${if cfg.verbose then "1" else ""}" == "1" ]]; then
            log "DEBUG: \$*"
          fi
        }

        verbose_log "Post-build hook triggered"
        verbose_log "  DRV_PATH: \$drv_path"
        verbose_log "  OUT_PATHS: \$out_paths"

        # Skip source/temporary derivations.
        if [[ "$drv_path" == *"-source.drv" ]] || [[ "$drv_path" == *"tmp"* ]]; then
          verbose_log "Skipping source/temporary derivation: \$drv_path"
          exit 0
        fi

        # Check if we should skip this build based on server hostnames
        # This prevents circular dependencies if the current host is a cache server
        for host in ${lib.concatStringsSep " " cfg.serverHostnames}; do
          if [[ "${config.networking.hostName}" == "$host" ]]; then
            verbose_log "Skipping push: current host ($host) is in serverHostnames list"
            exit 0
          fi
        done

        token_file="${tokenFilePath}"
        if [ -z "$token_file" ] || [ ! -f "$token_file" ]; then
          log "WARNING: token file missing (\$token_file); skipping push"
          exit 0
        fi

        if [ ! -r "$token_file" ]; then
          log "WARNING: token file not readable (\$token_file); skipping push"
          exit 0
        fi

        token="$(${pkgs.coreutils}/bin/cat "$token_file" 2>/dev/null || true)"
        if [ -z "$token" ]; then
          log "WARNING: token empty; skipping push"
          exit 0
        fi

        # Generate ephemeral config (never store token in Nix store).
        tmpdir="$(${pkgs.coreutils}/bin/mktemp -d)"
        trap '${pkgs.coreutils}/bin/rm -rf "$tmpdir"' EXIT

        export XDG_CONFIG_HOME="$tmpdir"
        ${pkgs.coreutils}/bin/mkdir -p "$XDG_CONFIG_HOME/attic"

        verbose_log "Generating ephemeral config using server: ${cfg.serverName}"

        ${pkgs.coreutils}/bin/cat > "$XDG_CONFIG_HOME/attic/config.toml" <<EOF
[servers."${cfg.serverName}"]
endpoint = "${cfg.serverEndpoint}"
token = "$token"
EOF

        log "pushing to ${cfg.serverName}:${cfg.cacheName} (${cfg.serverEndpoint})"

        # Batch push for efficiency.
        # shellcheck disable=SC2086
        if [[ "${if cfg.verbose then "1" else ""}" == "1" ]]; then
          ${pkgs.attic-client}/bin/attic push "${cfg.serverName}:${cfg.cacheName}" $out_paths 2>&1 | while read -r line; do log "CLIENT: \$line"; done
        else
          ${pkgs.attic-client}/bin/attic push "${cfg.serverName}:${cfg.cacheName}" $out_paths >/dev/null 2>&1 || true
        fi

        exit 0
  '';
in
{
  options.services.attic-post-build-hook = {
    enable = lib.mkEnableOption "Attic post-build hook for automatic cache uploads";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "attic-cache";
      description = ''
        The name used in the generated Attic config (used as a prefix for
        pushes like `serverName:cache`).
      '';
      example = "attic";
    };

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "cache-local";
      description = "The name of the cache to push to";
      example = "main";
    };

    serverEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:5001";
      description = "The URL of the Attic cache server";
      example = "https://cache.example.com";
    };

    tokenFile = lib.mkOption {
      type = runtimePathType;
      default = null;
      description = ''
        Runtime path to a plain-text file containing the Attic token.
        If set, the post-build hook reads this file at execution time and
        generates an ephemeral Attic config outside the Nix store.
      '';
      example = lib.literalExpression ''config.sops.secrets."attic-client-token".path'';
    };

    serverHostnames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "atticd"
        "attic-cache"
        "cache-server"
      ];
      description = ''
        List of hostnames running atticd that should not have post-build hooks enabled
        to prevent circular dependencies.
      '';
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable verbose diagnostic logging for the post-build hook.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Safety check: prevent enabling on cache servers
    assertions = [
      {
        assertion = !(builtins.elem config.networking.hostName cfg.serverHostnames);
        message = ''
          attic-post-build-hook should NOT be enabled on attic cache servers
          (hostnames: ${builtins.concatStringsSep ", " cfg.serverHostnames})
          to avoid circular dependencies!
        '';
      }
    ];

    # Configure the post-build hook
    nix.settings.post-build-hook = toString postBuildScript;

    # Ensure attic-client is available system-wide
    environment.systemPackages = [ pkgs.attic-client ];
  };
}
