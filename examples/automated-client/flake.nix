{
  description = "Automated Attic client with post-build hooks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-attic-infra.url = "github:deepwatrcreatur/nix-attic-infra";
  };

  outputs = { self, nixpkgs, nix-attic-infra }:
    {
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Import the post-build hook module
          nix-attic-infra.nixosModules.attic-post-build-hook

          # Your hardware configuration would go here
          # ./hardware-configuration.nix

          {
            # Enable automated cache uploads
            services.attic-post-build-hook = {
              enable = true;
              cacheName = "my-team-cache";
              user = "builder";

              # Optional: customize server hostnames to exclude
              serverHostnames = [ "atticd" "cache-server" "my-cache-server" ];
            };

            # Basic system configuration
            system.stateVersion = "24.11";

            # Example: Create a builder user for the post-build hooks
            users.users.builder = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
            };

            # Ensure the builder user has access to attic-client
            # This would typically be configured via Home Manager:
            # home-manager.users.builder = {
            #   imports = [ nix-attic-infra.homeManagerModules.attic-client ];
            #   programs.attic-client = {
            #     enable = true;
            #     servers.my-team-cache = {
            #       endpoint = "https://cache.example.com";
            #       tokenPath = "/home/builder/.config/sops/attic-token";
            #     };
            #   };
            # };
          }
        ];
      };
    };
}