# Basic Attic Client Example

This example demonstrates a simple Attic client configuration for getting started quickly.

## Usage

### Standalone Home Manager

```bash
# Apply the configuration
home-manager switch --flake .#user

# Test attic access
attic-push-local /nix/store/some-path
```

### Simple NixOS

```bash
# Build and switch
sudo nixos-rebuild switch --flake .#simple

# The system will automatically have attic-client configured
```

## Setup Requirements

1. **Create a token file** (for simple setup without SOPS):
   ```bash
   sudo mkdir -p /run/secrets
   echo "your-attic-token-here" | sudo tee /run/secrets/attic-client-token
   sudo chmod 600 /run/secrets/attic-client-token
   ```

2. **Ensure your Attic server is running** on `http://localhost:8080`

3. **Create the cache** if it doesn't exist:
   ```bash
   attic cache create main
   ```

## Helper Functions Example

The `helper-example` configuration shows how to use the convenience functions from `nix-attic-infra.lib` for cleaner configuration.