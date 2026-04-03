# Agent Prompts

Read [`START-HERE.md`](./START-HERE.md) first.

## Prompt 1: Generated Artifact Behavior Tests

Work on [`01-generated-artifact-behavior-tests.md`](./01-generated-artifact-behavior-tests.md).

Create a branch named `test/generated-artifact-behavior`.

Task:
- add fast checks for generated Home Manager artifacts and alias outputs
- validate quoted server keys, `<server>:<cache>` aliases, and token
  substitution edge cases

Deliver:
- branch commit(s)
- summary of artifact behaviors now covered

## Prompt 2: Linux/Darwin Activation Harness

Work on [`02-linux-darwin-activation-harness.md`](./02-linux-darwin-activation-harness.md).

Create a branch named `test/linux-darwin-activation-harness`.

Task:
- add a minimal activation test harness for Linux and Darwin
- verify output files/permissions from representative activation flows

Deliver:
- branch commit(s)
- summary of what the harness validates

## Prompt 3: Lib Contract Checks

Work on [`03-lib-contract-checks.md`](./03-lib-contract-checks.md).

Create a branch named `test/lib-contract-checks`.

Task:
- add checks around `lib.mkAtticClient` and `lib.mkPostBuildHook`
- prevent silent interface regressions in helper outputs and arguments

Deliver:
- branch commit(s)
- summary of helper contracts now encoded

## Prompt 4: Docs Consistency Guardrails

Work on [`04-docs-consistency-guardrails.md`](./04-docs-consistency-guardrails.md).

Create a branch named `docs/docs-consistency-guardrails`.

Task:
- make README/integration examples more executable or continuously evaluated
- document what docs examples are validated and how

Deliver:
- branch commit(s)
- summary of new docs guardrails

## Prompt 5: CI Helper Extraction

Work on [`05-ci-helper-extraction.md`](./05-ci-helper-extraction.md).

Create a branch named `refactor/ci-helper-extraction`.

Task:
- move growing CI/eval helper logic out of `flake.nix`
- keep flake outputs readable while preserving current coverage

Deliver:
- branch commit(s)
- summary of the extracted structure

## Prompt 6: Observatory Optional atticd Dependency

Work on [`06-observatory-optional-atticd-dependency.md`](./06-observatory-optional-atticd-dependency.md).

Create a branch named `feat/observatory-optional-atticd-dependency`.

Task:
- make the `atticd.service` dependency optional or configurable for
  `services.attic-observatory`
- keep the co-located deployment path safe by default

Deliver:
- branch commit(s)
- summary of the new observatory dependency behavior
