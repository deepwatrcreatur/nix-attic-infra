# Post-Build Hook Diagnostics

Status: `ready`
Suggested branch: `feat/post-build-hook-diagnostics`
Priority: `low`

## Goal

Improve observability of the post-build hook by adding a verbose mode and
structured logging.

## Scope

- Add `services.attic-post-build-hook.verbose` option.
- Update the upload script to log diagnostic information when verbose is enabled.
- Ensure error messages are captured and can be inspected in the system journal.
