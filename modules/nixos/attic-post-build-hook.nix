# NixOS module for Attic post-build hook automation
#
# This module provides zero-touch binary cache population by automatically
# pushing build outputs to your Attic cache after successful builds.
#
# IMPORTANT: Do NOT enable this on the host running atticd to avoid circular dependencies!
{ config, lib, pkgs, ... }:

let
  cfg = config.services.attic-post-build-hook;
  postBuildScript = pkgs.writeShellScript "attic-post-build-hook" ''
    set -eu
    set -f # disable globbing
    export IFS=' '

    echo "Post-build hook triggered with:" >&2
    echo "  DRV_PATH: $DRV_PATH" >&2
    echo "  OUT_PATHS: $OUT_PATHS" >&2

    # Check if this is a package we want to push (avoid pushing temporary builds)
    if [[ "$DRV_PATH" == *"-source.drv" ]] || [[ "$DRV_PATH" == *"tmp"* ]]; then
      echo "Skipping source/temporary derivation: $DRV_PATH" >&2
      exit 0
    fi

    # Push to attic using the configured cache
    for path in $OUT_PATHS; do
      echo "Pushing $path to attic cache: ${cfg.cacheName}" >&2
      if ${pkgs.attic-client}/bin/attic push ${cfg.cacheName} "$path" 2>&1; then
        echo "Successfully pushed $path" >&2
      else
        echo "Failed to push $path (non-fatal)" >&2
      fi
    done
  '';
in
{
  options.services.attic-post-build-hook = {
    enable = lib.mkEnableOption "Attic post-build hook for automatic cache uploads";

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = ''
        Name of the attic cache to push builds to.
        This must match a cache configured in your attic-client setup.
      '';
      example = "my-team-cache";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "builder";
      description = ''
        User account that has attic-client configured with appropriate tokens.
        This user must have push access to the specified cache.
      '';
      example = "builduser";
    };

    serverHostnames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "atticd" "cache-server" "cache-build-server" ];
      description = ''
        List of hostnames running atticd that should not have post-build hooks enabled
        to prevent circular dependencies.
      '';
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

    # Ensure the hook runs as the user with attic access
    nix.settings.allowed-users = [ cfg.user ];

    # Trust the user to modify the nix store (needed for post-build hooks)
    nix.settings.trusted-users = [ cfg.user ];

    # Ensure attic-client is available system-wide
    environment.systemPackages = [ pkgs.attic-client ];
  };
}