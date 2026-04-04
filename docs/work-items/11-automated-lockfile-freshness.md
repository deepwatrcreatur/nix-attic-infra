# Automated Lockfile Freshness

Status: `in-progress`
Suggested branch: `feat/lockfile-freshness-check`
Priority: `low`

## Goal

Ensure that the flake inputs (attic, nixpkgs, etc.) are kept up to date and
don't drift too far from current versions.

## Scope

- Add a check to `flake.nix` that fails if the lockfile is "too old" (e.g., > 30 days).
- Provide a clear message on how to update.
- Ensure this check is easily skippable if needed.
