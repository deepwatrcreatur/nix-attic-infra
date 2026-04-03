{ pkgs, lib, home-manager, system }:

rec {
  # Evaluate a NixOS configuration for testing
  evalNixos =
    modules:
    lib.nixosSystem {
      inherit system;
      modules = modules ++ [{ nixpkgs.hostPlatform = system; }];
    };

  # Evaluate a Home Manager configuration for testing
  evalHomeManager =
    modules:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = modules ++ [
        {
          home.username = "ci";
          home.homeDirectory = "/home/ci";
          home.stateVersion = "25.11";
        }
      ];
    };

  # Create a check that stores evaluated JSON data
  mkEvalCheck =
    name: value:
    pkgs.runCommand name { } ''
      cat > "$out" <<'NIX_ATTIC_INFRA_EVAL_CHECK_EOF'
      ${builtins.toJSON value}
      NIX_ATTIC_INFRA_EVAL_CHECK_EOF
    '';

  # Assertion helper that fails the build if the condition is false
  mkAssert = name: condition: msg:
    if condition then
      pkgs.runCommand "assertion-${name}" { } "touch $out"
    else
      pkgs.runCommand "assertion-${name}-failed" { } ''
        echo "Assertion failed for ${name}: ${msg}" >&2
        exit 1
      '';
}
