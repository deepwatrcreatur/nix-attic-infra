{ pkgs, lib, self }:

let
  # The threshold in seconds (30 days = 30 * 24 * 60 * 60)
  threshold = 30 * 24 * 60 * 60;

  # Get the last modified time of a critical input (e.g., nixpkgs)
  # Inputs have a lastModified attribute (integer seconds since epoch)
  lastModified = self.inputs.nixpkgs.lastModified;

in
pkgs.runCommand "test-lockfile-freshness"
{
  buildInputs = [ pkgs.coreutils ];
  inherit lastModified threshold;
} ''
  current_time=$(date +%s)
  age=$((current_time - lastModified))
  
  echo "Current time: $current_time"
  echo "Input last modified: $lastModified"
  echo "Age in seconds: $age"
  echo "Threshold in seconds: $threshold"

  if [ "$age" -gt "$threshold" ]; then
    echo "--------------------------------------------------"
    echo "ERROR: Flake lockfile is too old (> 30 days)!"
    echo "Last updated: $(date -d @$lastModified)"
    echo ""
    echo "Please run: nix flake update"
    echo "--------------------------------------------------"
    # exit 1 # Uncomment to make it a hard failure
    echo "Warning: Lockfile is stale, but continuing for now."
  else
    echo "Lockfile is fresh (last updated $(date -d @$lastModified))."
  fi

  touch $out
''
