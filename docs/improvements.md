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

## April 2026 retrospective: critique of recent work

### What is going well

- **Evaluation coverage expanded in the right places.** The latest flake checks now exercise both NixOS and Home Manager module paths (including Darwin evaluation), which raises confidence that module options compose cleanly across supported platforms.
- **Recent fixes targeted user-facing correctness issues.** The Home Manager alias namespace correction and token substitution portability improvements remove concrete foot-guns that would otherwise surface during normal `attic push/pull` usage.
- **Roadmap-first delivery is helping scope.** The pattern of documenting improvement priorities before implementation is reducing random churn and has produced focused PRs.

### Main gaps still visible

1. **Checks validate evaluation shape, not behavioral outcomes.**
   - Current checks mostly assert that attributes exist and can be evaluated.
   - They do not yet validate generated file content semantics (e.g., exact shell alias commands, final rendered TOML, token substitution edge cases).

2. **Cross-platform shell execution risk remains under-tested.**
   - While GNU-specific `sed -i` usage was removed, the activation scripts still rely on non-trivial shell flows that are easy to regress differently on Linux vs Darwin.
   - There is no dedicated matrix that actually runs activation snippets in both environments.

3. **Module contract testing is not yet encoded as a stable interface.**
   - The flake exports a useful `lib` surface (`mkAtticClient`, `mkPostBuildHook`), but there are no contract-style checks to lock expected argument behavior and output structure.

4. **Documentation drift risk is still structural.**
   - Docs were recently improved, but the repo still lacks a lightweight mechanism to ensure example snippets stay synchronized with module options and helper signatures.

### Suggested direction for improvement (next 2-3 PRs)

1. **Add behavior-oriented tests for generated artifacts (highest ROI).**
   - Introduce checks that assert:
     - generated Home Manager `config.toml` contains quoted server keys;
     - alias commands always include `<server>:<cache>`;
     - token placeholder replacement is idempotent and safe for special characters.
   - Keep these as fast evaluation/build-time tests that avoid external services.

2. **Create a minimal Linux/Darwin activation test harness.**
   - Add one scriptable fixture per platform that executes the activation fragment with fake token files and verifies final file outputs/permissions.
   - This converts portability from a claim into a continuously verified property.

3. **Formalize API compatibility expectations for `lib` helpers.**
   - Add checks around `lib.mkAtticClient` and `lib.mkPostBuildHook` outputs to prevent silent interface regressions.
   - Document compatibility intent (e.g., semver-like expectations for helper arguments) in README or ARCHITECTURE.

4. **Add docs consistency guardrails.**
   - For examples, add a lightweight CI step that at least evaluates each template and key module composition shown in README/INTEGRATION.
   - Prefer "executable docs" style snippets where practical.

### Success metrics to track

- Mean time from bug report to reproducer test added.
- Number of regressions caught by CI before merge (especially Home Manager activation and Darwin compatibility).
- Ratio of docs examples that are continuously evaluated in checks.

This direction keeps the current momentum (small, reviewable PRs), while shifting quality from "it evaluates" toward "it behaves correctly under real usage patterns." 
