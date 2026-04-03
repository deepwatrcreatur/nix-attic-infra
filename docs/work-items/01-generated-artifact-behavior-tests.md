# Generated Artifact Behavior Tests

Status: `done`
Suggested branch: `test/generated-artifact-behavior`
Priority: `very high`

## Goal

Add fast checks that validate generated config content and alias behavior, not
just evaluation shape.

## Scope

- generated Home Manager `config.toml`
- alias outputs for representative server/cache names
- token placeholder substitution edge cases

## Validation

- `nix flake check`
- any new targeted check outputs
