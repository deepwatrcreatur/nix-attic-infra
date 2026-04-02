# macOS-specific Attic client enhancements for Home Manager
#
# This module provides macOS-specific optimizations for the Attic client,
# including Determinate Nix integration and Darwin-specific configuration.
{ config, lib, ... }:

{
  # Enable user Nix configuration for Determinate Nix systems
  # This is commonly used on macOS for enhanced Nix functionality
  services.nix-user-config.enable = lib.mkDefault true;

  # macOS-specific configuration optimizations
  programs.attic-client = {
    # Enable attic-client by default on macOS systems.
    enable = lib.mkDefault true;

    # Keep aliases enabled unless the consumer overrides them.
    enableShellAliases = lib.mkDefault true;

    # Token substitution works well with macOS keychain-backed secret flows.
    tokenSubstitution = lib.mkDefault true;
  };

  # Ensure attic configuration directory has proper permissions on macOS
  home.activation.attic-darwin-permissions = lib.mkIf config.programs.attic-client.enable (
    lib.hm.dag.entryBefore [ "attic-config" ] ''
      $DRY_RUN_CMD mkdir -p -- "${config.home.homeDirectory}/.config/attic"
      $DRY_RUN_CMD chmod 700 -- "${config.home.homeDirectory}/.config/attic"
    ''
  );
}
