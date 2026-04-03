# CI Helper Extraction

Status: `ready`
Suggested branch: `refactor/ci-helper-extraction`
Priority: `medium`

## Goal

Move growing CI/eval helper logic out of `flake.nix` into a small `./ci/`
helper layer without reducing current coverage.
