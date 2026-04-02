# nix-attic-infra improvements

This document captures the highest-value improvements found during a quick audit of the repository on March 28, 2026. The goal is to prefer small, reviewable pull requests over a large mixed refactor.

## Priority 1: Home Manager client correctness and portability

Problem:
- `programs.attic-client` generates shell aliases like `attic push main`, but Attic targets are namespaced as `server:cache`. The aliases currently drop the server name and can point at the wrong target or fail outright.
- The generated TOML uses `[servers.${name}]`, which breaks when a server attribute contains characters that require quoted TOML keys, such as `-`.
- The activation hook uses `sed -i`, which is GNU-specific and undermines the module's cross-platform goal, especially on Darwin.

Proposed change:
- Generate aliases as `attic push <server>:<cache>` and `attic pull <server>:<cache>`.
- Quote server names in generated TOML.
- Replace the in-place `sed` editing with a portable substitution flow.

Why this matters:
- Fixes real user-facing breakage.
- Aligns the module with its documented cross-platform scope.
- Makes hyphenated server names safe.

Suggested PR:
- `fix/home-manager-attic-client-portability`

## Priority 2: Post-build hook token path ergonomics

Problem:
- `services.attic-post-build-hook.tokenFile` is typed as `nullOr path`, but the documented and most practical usage is a runtime path like `/run/secrets/...`.
- Runtime secret paths are commonly strings produced by other modules. Requiring a Nix path value is the wrong abstraction here and makes integration awkward or invalid.

Proposed change:
- Accept runtime paths as strings while preserving compatibility with existing path values.
- Tighten the option description to clearly state that this is a plaintext token path read at runtime, not a store path.
- Add a readability check before attempting to read the token file.

Why this matters:
- Matches real-world NixOS secret workflows.
- Reduces surprising type errors.
- Makes the module documentation consistent with the implementation model.

Suggested PR:
- `fix/post-build-hook-runtime-token-path`

## Priority 3: Documentation accuracy sweep

Problem:
- Some documentation examples and helper descriptions do not exactly match the current flake outputs and module interfaces.
- `lib.mkPostBuildHook` documentation examples mention arguments not accepted by the helper today.
- The current docs do not distinguish clearly between the dedicated post-build hook module and the older `services.attic-client.enablePostBuildHook` path.

Proposed change:
- Reconcile README and integration examples with the current flake API.
- Document the preferred module combinations explicitly.
- Keep examples aligned with runtime secret-path handling.

Why this matters:
- This repo is consumed primarily through copy-paste examples.
- Small documentation drift translates directly into user friction.

Suggested PR:
- `docs/align-examples-with-current-api`

## Priority 5: Observatory dependency flexibility

Problem:
- `services.attic-observatory` hard-requires `atticd.service`, even though the database source path is configurable.
- That makes the module less reusable when the snapshot source is provided by another process or service arrangement.

Proposed change:
- Make the `atticd.service` dependency optional or configurable.
- Keep the default safe for the common co-located deployment.

Why this matters:
- Improves composability without weakening the default path.

Suggested PR:
- `feat/observatory-optional-atticd-dependency`

## Recommended execution order

1. Land the Home Manager correctness/portability fix.
2. Land the post-build hook token-path fix.
3. Sweep docs so examples reflect the corrected behavior.
4. Improve CI checks once the public API is in better shape.
5. Revisit observatory flexibility as a feature PR.
