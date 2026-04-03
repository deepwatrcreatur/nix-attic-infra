{ pkgs, lib, homeManagerAtticClient, homeManagerAtticClientDarwin }:

let
  # Extract scripts
  linuxScript = homeManagerAtticClient.config.home.activation.attic-config.data;
  darwinScript = homeManagerAtticClientDarwin.config.home.activation.attic-config.data;
  darwinPermsScript = homeManagerAtticClientDarwin.config.home.activation.attic-darwin-permissions.data;

  # Template content from evaluation
  configTemplate = homeManagerAtticClient.config.home.file.".config/attic/config.toml".text;
  darwinConfigTemplate = homeManagerAtticClientDarwin.config.home.file.".config/attic/config.toml".text;

  # Token placeholder logic (must match the module)
  tokenPlaceholder = name: "@NIX_ATTIC_INFRA_TOKEN_${lib.toUpper (builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name)}_${builtins.substring 0 8 (builtins.hashString "sha256" name)}@";

in
pkgs.runCommand "test-activation-harness"
{
  nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gnused ];
} ''
  set -euo pipefail

  echo "Setting up fake home environment..."
  export HOME=$NIX_BUILD_TOP/fake-home
  mkdir -p "$HOME/.config/attic"

  # Stub HM variables
  export DRY_RUN=""
  export VERBOSE_ECHO="echo"
  export DRY_RUN_CMD="eval"

  echo "Test 1: Linux activation script"
  (
    # Create the template as Home Manager would
    cat > "$HOME/.config/attic/config.toml" <<'EOF'
${configTemplate}
EOF

    # Save original template for dry-run comparison
    cp "$HOME/.config/attic/config.toml" "$HOME/.config/attic/config.toml.orig"

    # Create fake tokens at expected paths
    mkdir -p "$HOME/tokens"
    mkdir -p "$HOME/.config/attic"
    echo "secret-prod-token" > "$HOME/tokens/attic-token"
    echo "secret-personal-token" > "$HOME/.config/attic/personal-token"
    echo "secret-dot-token" > "$HOME/tokens/dot-token"
    echo "secret-underscore-token" > "$HOME/tokens/underscore-token"

    # We need to ensure the script uses our fake paths.
    # In the eval, we used specific paths. Let's check them.
    # cache-prod: /run/user/1000/attic-token
    # cache-personal: /home/ci/.config/attic/personal-token
    # cache.dot: /run/user/1000/dot-token
    # cache_dot: /run/user/1000/underscore-token

    # Since the script has hardcoded paths from the evaluation,
    # we must create those paths or rewrite the script.
    # Creating /run/user/1000 is not possible in a derivation.
    # So we rewrite the script to use our fake home.

    fixed_script=$(cat <<'EOF' | sed "s|/run/user/1000|$HOME/tokens|g; s|/home/ci|$HOME|g"
${linuxScript}
EOF
)

    echo "1.1: Verifying Linux DRY_RUN behavior..."
    (DRY_RUN=1; bash -c "$fixed_script") | grep "DRY_RUN: Attic client configuration would be updated with tokens"
    if ! diff "$HOME/.config/attic/config.toml" "$HOME/.config/attic/config.toml.orig"; then
      echo "DRY_RUN failed: config.toml was modified"
      exit 1
    fi

    echo "1.2: Executing real activation..."
    (unset DRY_RUN; DRY_RUN_CMD='eval' bash -c "$fixed_script")

    echo "Verifying outputs..."
    grep "token = \"secret-prod-token\"" "$HOME/.config/attic/config.toml"
    grep "token = \"secret-personal-token\"" "$HOME/.config/attic/config.toml"
    grep "token = \"secret-dot-token\"" "$HOME/.config/attic/config.toml"
    grep "token = \"secret-underscore-token\"" "$HOME/.config/attic/config.toml"
  )

  echo "Test 2: Darwin activation scripts"
  (
    # Reset home for Darwin test
    rm -rf "$HOME"
    mkdir -p "$HOME"

    # Darwin script assumes home is /home/ci based on eval (due to evalHomeManager helper)
    # but we should handle both common paths just in case.
    fixed_perms_script=$(cat <<'EOF' | sed "s|/Users/ci|$HOME|g; s|/home/ci|$HOME|g"
${darwinPermsScript}
EOF
)
    fixed_darwin_script=$(cat <<'EOF' | sed "s|/Users/ci|$HOME|g; s|/home/ci|$HOME|g; s|/run/user/1000|$HOME/tokens|g"
${darwinScript}
EOF
)

    echo "2.1: Verifying Darwin DRY_RUN behavior..."
    (DRY_RUN=1; bash -c "$fixed_perms_script")
    if [ -d "$HOME/.config/attic" ]; then
      echo "DRY_RUN failed: .config/attic was created"
      exit 1
    fi

    echo "Executing Darwin permissions script..."
    (unset DRY_RUN; DRY_RUN_CMD='eval' bash -c "$fixed_perms_script")

    # Check directory permissions (chmod 700)
    # In Nix build environment, permissions might be tricky, but let's try.
    dir_perms=$(stat -c "%a" "$HOME/.config/attic")
    if [ "$dir_perms" != "700" ]; then
      echo "Darwin directory permissions incorrect: $dir_perms"
      exit 1
    fi

    # Create template and token for Darwin
    cat > "$HOME/.config/attic/config.toml" <<'EOF'
${darwinConfigTemplate}
EOF
    cp "$HOME/.config/attic/config.toml" "$HOME/.config/attic/config.toml.orig"
    mkdir -p "$HOME/.config/attic"
    echo "darwin-secret-token" > "$HOME/.config/attic/token"

    echo "2.2: Verifying Darwin DRY_RUN token substitution..."
    (DRY_RUN=1; bash -c "$fixed_darwin_script") | grep "DRY_RUN: Attic client configuration would be updated with tokens"
    if ! diff "$HOME/.config/attic/config.toml" "$HOME/.config/attic/config.toml.orig"; then
      echo "DRY_RUN failed: Darwin config.toml was modified"
      exit 1
    fi

    echo "Executing Darwin activation script..."
    (unset DRY_RUN; DRY_RUN_CMD='eval' bash -c "$fixed_darwin_script")

    grep "token = \"darwin-secret-token\"" "$HOME/.config/attic/config.toml"
  )

  touch $out
''
