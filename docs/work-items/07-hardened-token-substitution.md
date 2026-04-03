# Hardened Token Substitution

Status: `done`
Suggested branch: `feat/hardened-token-substitution`
Priority: `medium`

## Goal

Ensure token substitution in Home Manager is collision-proof by using a strictly
namespaced prefix and potentially unique hashes for every server.

## Scope

- Update `tokenPlaceholder` logic in `modules/home-manager/attic-client.nix`.
- Ensure the placeholder is extremely unlikely to collide with user text.
- Update tests to verify the new format.
