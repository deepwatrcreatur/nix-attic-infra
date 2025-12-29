# nix-attic-infra

Production-ready Attic binary cache infrastructure with automated post-build hooks, SOPS secrets integration, and cross-platform client management for NixOS and macOS.

## ✨ Features

### 🚀 Zero-Touch Automation
- **Automated post-build hooks** that push to your Attic cache after every build
- **Smart filtering** that skips temporary and source derivations
- **Non-fatal error handling** that won't break your builds

### 🔐 Enterprise Security
- **SOPS integration** for secure token management
- **Dynamic token substitution** during home-manager activation
- **Multi-server authentication** with per-server token isolation

### 🛡️ Production Safety
- **Circular dependency prevention** with built-in assertions
- **User permission management** for post-build hooks
- **Host-based safety checks** to prevent configuration conflicts

### 🌐 Cross-Platform Support
- **NixOS modules** for system-level integration
- **Home Manager modules** for user-level configuration
- **macOS support** via Darwin-specific client modules
- **Multi-architecture** compatibility

## 🎯 Use Cases

### Team Binary Caches
Perfect for development teams wanting automatic cache population without manual intervention.

### CI/CD Integration
Seamlessly integrates into build pipelines to populate shared caches across infrastructure.

### Enterprise Deployment
Production-grade security and safety features for large-scale Nix deployments.

### Multi-Host Management
Centralized cache management across multiple development and production environments.

## 🚀 Quick Start

### Basic Client Setup

```nix
{
  inputs.nix-attic-infra.url = "github:deepwatrcreatur/nix-attic-infra";

  outputs = { self, nixpkgs, nix-attic-infra }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-attic-infra.nixosModules.attic-post-build-hook
        {
          services.attic-post-build-hook = {
            enable = true;
            cacheName = "my-team-cache";
            user = "builder";
          };
        }
      ];
    };
  };
}
```

### Home Manager Integration

```nix
{
  imports = [ nix-attic-infra.homeManagerModules.attic-client ];

  programs.attic-client = {
    enable = true;
    servers.my-server = {
      endpoint = "https://cache.example.com";
      tokenPath = "/home/user/.config/sops/attic-token";
    };
  };
}
```

## 📦 What's Included

### NixOS Modules
- `attic-post-build-hook` - Automated cache uploads after builds
- `attic-client` - Client configuration with safety checks

### Home Manager Modules
- `attic-client` - Cross-platform client with SOPS integration
- `attic-client-darwin` - macOS-specific enhancements

### Templates
- `automated-client` - Post-build hook setup
- `secure-enterprise` - SOPS + multi-server configuration
- `basic-client` - Simple client configuration

## 🔧 Configuration Options

### Post-Build Hook Configuration

```nix
services.attic-post-build-hook = {
  enable = true;
  cacheName = "my-cache";           # Attic cache name
  user = "builder";                 # User with attic-client access
};
```

### Client Configuration

```nix
programs.attic-client = {
  enable = true;
  servers = {
    production = {
      endpoint = "https://cache.prod.example.com";
      tokenPath = "/path/to/sops/token";
    };
    development = {
      endpoint = "http://cache.dev.example.com:5001";
      tokenPath = "/path/to/dev/token";
    };
  };
};
```

## 🔒 Security Features

### SOPS Integration
Seamlessly integrates with SOPS-nix for secure token management:

```nix
# SOPS manages your tokens
sops.secrets."attic-token" = {
  path = "/home/user/.config/sops/attic-token";
};

# Automatically substituted during activation
programs.attic-client.servers.prod.tokenPath = config.sops.secrets."attic-token".path;
```

### Safety Assertions
Built-in checks prevent common configuration mistakes:

- Prevents post-build hooks on cache servers (circular dependencies)
- Validates user permissions for hook execution
- Ensures token files exist before activation

## 🏗️ Architecture

### Client Architecture
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│  Nix Build      │───▶│ Post-Build   │───▶│ Attic Cache │
│                 │    │ Hook         │    │ Server      │
└─────────────────┘    └──────────────┘    └─────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │ SOPS Token   │
                       │ Management   │
                       └──────────────┘
```

### Multi-Server Setup
```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│ Development │───▶│ nix-attic-infra  │───▶│ Dev Cache   │
│ Hosts       │    │                  │    └─────────────┘
└─────────────┘    │                  │    ┌─────────────┐
                   │                  │───▶│ Prod Cache  │
┌─────────────┐    │                  │    └─────────────┘
│ Production  │───▶│                  │    ┌─────────────┐
│ Hosts       │    │                  │───▶│ Team Cache  │
└─────────────┘    └──────────────────┘    └─────────────┘
```

## 🤝 Contributing

This project aims to provide production-ready Attic infrastructure. Contributions are welcome!

### Areas for Enhancement
- Additional storage backend templates
- Enhanced monitoring and logging options
- Integration examples for popular CI systems
- Performance optimization configurations

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built on top of the excellent [Attic](https://github.com/zhaofengli/attic) project by zhaofengli and the broader Nix community's infrastructure patterns.

---

*Transform your Nix builds from manual cache management to zero-touch automation* 🚀