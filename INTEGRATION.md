# Integration Guide

This guide demonstrates how to integrate nix-attic-infra into various Nix setups and common usage patterns.

## Quick Start

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-attic-infra.url = "github:deepwatrcreatur/nix-attic-infra";
  };
}
```

## Integration Patterns

### 1. NixOS with Automated Post-Build Hooks

Perfect for build servers that should automatically populate caches:

```nix
{
  imports = [ nix-attic-infra.nixosModules.attic-post-build-hook ];

  services.attic-post-build-hook = {
    enable = true;
    cacheName = "my-org-cache";
    user = "builder";
    # Excludes hosts running atticd to prevent circular uploads
    serverHostnames = [ "cache-server" "atticd" ];
  };

  users.users.builder = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
```

### 2. Multi-Environment Client Setup

For organizations with multiple cache environments:

```nix
{
  imports = [ nix-attic-infra.homeManagerModules.attic-client ];

  programs.attic-client = {
    enable = true;
    enableShellAliases = true;
    servers = {
      production = {
        endpoint = "https://cache.company.com";
        tokenPath = "/run/secrets/attic-prod-token";
        aliases = [ "prod" "main" ];
      };
      staging = {
        endpoint = "https://staging-cache.company.com";
        tokenPath = "/run/secrets/attic-staging-token";
        aliases = [ "staging" "test" ];
      };
      local = nix-attic-infra.lib.commonServers.local;
    };
  };
}
```

### 3. Darwin (macOS) Integration

With enhanced macOS application support:

```nix
{
  imports = [ nix-attic-infra.homeManagerModules.attic-client-darwin ];

  programs.attic-client = {
    enable = true;
    servers.company-cache = {
      endpoint = "https://cache.company.com";
      tokenPath = "/Users/username/.config/attic-token";
      aliases = [ "company" ];
    };
  };
}
```

### 4. Using Helper Functions

Simplify configuration with built-in helpers:

```nix
{
  imports = [
    nix-attic-infra.nixosModules.attic-post-build-hook
    (nix-attic-infra.lib.mkPostBuildHook {
      cacheName = "team-cache";
      user = "builder";
    })
    (nix-attic-infra.lib.mkAtticClient {
      servers = {
        main = nix-attic-infra.lib.commonServers.local;
      };
      enableShellAliases = true;
    })
  ];
}
```

## Advanced Usage Patterns

### SOPS Integration for Secure Tokens

```nix
{
  # SOPS configuration
  sops.secrets.attic-token = {
    sopsFile = ./secrets.yaml;
    path = "/run/secrets/attic-token";
    mode = "0400";
    owner = config.users.users.attic-user.name;
  };

  # Attic client using SOPS-managed token
  programs.attic-client = {
    enable = true;
    servers.secure-cache = {
      endpoint = "https://cache.example.com";
      tokenPath = config.sops.secrets.attic-token.path;
    };
  };
}
```

### CI/CD Pipeline Integration

For GitHub Actions with Nix:

```yaml
name: Build and Cache
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Setup Attic
        run: |
          nix profile install github:deepwatrcreatur/nix-attic-infra#attic-client
          attic login ci https://cache.company.com ${{ secrets.ATTIC_TOKEN }}

      - name: Build and push
        run: |
          nix build .#my-package
          attic push ci result
```

### Multi-Host Configuration

For managing multiple machines with different roles:

```nix
# flake.nix
{
  nixosConfigurations = {
    # Build server - automatically pushes builds
    builder = nixpkgs.lib.nixosSystem {
      modules = [
        nix-attic-infra.nixosModules.attic-post-build-hook
        {
          services.attic-post-build-hook = {
            enable = true;
            cacheName = "team-builds";
          };
        }
      ];
    };

    # Developer workstation - only consumes cache
    workstation = nixpkgs.lib.nixosSystem {
      modules = [
        nix-attic-infra.nixosModules.attic-client
        {
          services.attic-client = {
            enable = true;
            server = "https://cache.company.com";
            cache = "team-builds";
          };
        }
      ];
    };

    # Cache server - no hooks to prevent recursion
    cache-server = nixpkgs.lib.nixosSystem {
      modules = [
        # No attic modules - this host runs atticd
        {
          services.atticd.enable = true;
          networking.hostName = "cache-server"; # Excluded by default
        }
      ];
    };
  };
}
```

## Migration from Other Solutions

### From Manual Attic Setup

Replace manual configuration:

```nix
# Before: Manual setup
environment.systemPackages = [ pkgs.attic-client ];
# Manual token management, no automation

# After: Using nix-attic-infra
imports = [ nix-attic-infra.nixosModules.attic-client ];
services.attic-client = {
  enable = true;
  server = "https://cache.example.com";
  cache = "main";
  # Automatic token management, shell aliases included
};
```

### From Cachix

```nix
# Before: Cachix
nix.settings.substituters = [ "https://cache.nixos.org/" "https://mycache.cachix.org" ];
nix.settings.trusted-public-keys = [ "mycache.cachix.org-1:..." ];

# After: Attic with nix-attic-infra
imports = [ nix-attic-infra.nixosModules.attic-client ];
services.attic-client = {
  enable = true;
  server = "https://attic.example.com";
  cache = "main";
  # Better token management, post-build automation available
};
```

## Security Best Practices

### Token Management

```nix
# Secure token storage with proper permissions
sops.secrets.attic-token = {
  mode = "0400";
  owner = "attic-user";
  group = "attic-group";
};

# Use SOPS paths, never hardcode tokens
programs.attic-client.servers.prod.tokenPath = config.sops.secrets.attic-token.path;
```

### Network Security

```nix
# Use HTTPS endpoints in production
programs.attic-client.servers.prod = {
  endpoint = "https://cache.example.com";  # Never HTTP in production
  # Consider certificate pinning for high-security environments
};

# Firewall configuration for cache servers
networking.firewall.allowedTCPPorts = [ 8080 ];  # Atticd default port
```

### Access Control

```nix
# Separate tokens for different access levels
programs.attic-client.servers = {
  read-only = {
    endpoint = "https://cache.example.com";
    tokenPath = "/run/secrets/attic-read-token";    # Read-only token
  };
  ci-push = {
    endpoint = "https://cache.example.com";
    tokenPath = "/run/secrets/attic-push-token";    # Push permissions
  };
};
```

## Troubleshooting

### Common Issues

1. **Build hooks not triggering**
   - Check that `serverHostnames` excludes the current host
   - Verify user permissions for token access

2. **Token authentication failures**
   - Ensure token file exists and has correct permissions
   - Verify SOPS decryption is working
   - Check token hasn't expired

3. **Module conflicts**
   - Don't mix NixOS and Home Manager modules in the same configuration
   - Use appropriate module for your context

### Debug Commands

```bash
# Check token access
sudo -u builder cat /run/secrets/attic-token

# Test attic connectivity
attic login test https://cache.example.com $(cat /run/secrets/attic-token)
attic cache list

# Verify post-build hook
nix-build '<nixpkgs>' -A hello  # Should trigger hook if configured
```