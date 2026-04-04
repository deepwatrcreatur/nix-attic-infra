{ pkgs, lib, self, sops-nix, agenix, evalNixos, evalHomeManager, mkAssert }:

let
  # NixOS evaluation with SOPS
  nixosSops = evalNixos [
    self.nixosModules.attic-client
    sops-nix.nixosModules.sops
    {
      networking.hostName = "sops-test";
      system.stateVersion = "25.11";
      services.attic-client = {
        enable = true;
        secretsBackend = "sops";
        tokenFile = "/etc/secrets/attic.yaml";
      };
      # Stub sops config to satisfy module
      sops.defaultSopsFile = "/etc/secrets/attic.yaml";
      sops.secrets."attic-client-token" = { };
    }
  ];

  # NixOS evaluation with Agenix
  nixosAgenix = evalNixos [
    self.nixosModules.attic-client
    agenix.nixosModules.age
    {
      networking.hostName = "agenix-test";
      system.stateVersion = "25.11";
      services.attic-client = {
        enable = true;
        secretsBackend = "agenix";
        ageSecretFile = "/etc/secrets/attic.age";
      };
      # agenix module doesn't strictly require the file to exist for evaluation
      age.secrets."attic-client-token".file = "/etc/secrets/attic.age";
    }
  ];

  # Home Manager evaluation with SOPS
  hmSops = evalHomeManager [
    self.homeManagerModules.attic-client
    sops-nix.homeManagerModules.sops
    {
      programs.attic-client = {
        enable = true;
        servers.prod = {
          endpoint = "https://cache.example.com";
          tokenPath = "/run/user/1000/secrets/attic-token";
        };
      };
      sops.secrets."attic-token" = { };
      sops.age.keyFile = "/tmp/key";
    }
  ];

in
pkgs.runCommand "test-secrets-integration" { } ''
  echo "Verifying SOPS hand-off..."
  # The module should automatically point to the sops secret path
  sops_path="${nixosSops.config.sops.secrets."attic-client-token".path}"
  echo "SOPS path: $sops_path"
  if [[ "$sops_path" != "/run/secrets/attic-client-token" ]]; then
    echo "Error: Unexpected SOPS secret path"
    exit 1
  fi

  echo "Verifying Agenix hand-off..."
  age_path="${nixosAgenix.config.age.secrets."attic-client-token".path}"
  echo "Agenix path: $age_path"
  # Agenix defaults to /run/agenix/<name>
  if [[ "$age_path" != "/run/agenix/attic-client-token" ]]; then
    echo "Error: Unexpected Agenix secret path"
    exit 1
  fi

  echo "Verifying Home Manager SOPS integration..."
  cat > hm_script <<'EOF'
${hmSops.config.home.activation.attic-config.data}
EOF
  if ! grep -q "/run/user/1000/secrets/attic-token" hm_script; then
    echo "Error: HM activation script missing secret path"
    exit 1
  fi

  touch $out
''
