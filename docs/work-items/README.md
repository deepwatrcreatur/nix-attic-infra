# Work Items

Start here if you are assigning another agent:

- [`START-HERE.md`](./START-HERE.md)

This folder is the agent-facing queue for `nix-attic-infra`.

## How To Use

- Treat each file in this folder as one PR-sized work stream.
- Prefer one agent per file/branch.
- Mark the file as `in-progress` in its header once an agent starts it.
- Delete the file when the work is fully merged and no longer needs tracking.
- If the work changes shape materially, update the file instead of leaving the
  plan stale.

## Status Model

- `blocked`: do not start yet
- `ready`: can be started now
- `in-progress`: owned by an active branch / agent
- `done`: merged; file can be deleted

## Ranking

Highest value first:

1. `01-generated-artifact-behavior-tests.md` (done)
2. `02-linux-darwin-activation-harness.md` (done)
3. `03-lib-contract-checks.md` (done)
4. `04-docs-consistency-guardrails.md` (done)
5. `05-ci-helper-extraction.md` (done)
6. `06-observatory-optional-atticd-dependency.md` (done)
7. `07-hardened-token-substitution.md` (done)
8. `08-dry-run-verification.md` (done)
9. `09-post-build-hook-diagnostics.md` (done)
10. `10-secrets-integration-harness.md` (done)
11. `11-automated-lockfile-freshness.md` (done)
12. `12-observatory-api-auth.md` (done)
13. `13-module-documentation-generator.md` (done)

## Why This Structure

Small files work better than one large roadmap because they:

- reduce context loading
- make ownership clearer
- map cleanly to one branch / one PR
- are easy to delete once merged
