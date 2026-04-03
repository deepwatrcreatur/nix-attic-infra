# Dry Run Verification

Status: `in-progress`
Suggested branch: `test/dry-run-verification`
Priority: `medium`

## Goal

Verify that Home Manager activation scripts correctly respect the `$DRY_RUN`
environment variable and perform no side effects when it is set.

## Scope

- Update `tests/activation-harness.nix` to include dry-run tests.
- Assert that no files are modified or created when `DRY_RUN=1`.
- Verify that the output correctly reports what *would* have happened.
