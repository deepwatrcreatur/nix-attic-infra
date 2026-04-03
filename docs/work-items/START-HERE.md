# Agent Start Here

If you are a coding agent starting work in this repo, follow this file.

## Objective

Pick the next highest-value work item that is not already in progress, do it in
its own worktree/branch, and keep the work scoped to one PR.

## Where The Queue Lives

Read first:

- [`README.md`](./README.md)
- [`agent-prompts.md`](./agent-prompts.md)

The authoritative queue is the ordered list in [`README.md`](./README.md).

## How To Choose Work

0. Refresh remote state first: `git fetch origin`
1. Start with the ordered list in [`README.md`](./README.md).
2. Find the first item whose header says `Status: ready`.
3. If the suggested branch/worktree already exists, treat that only as a hint.
   It blocks the task only if there is evidence of active ownership:
   - recent commits
   - an open PR
   - the task file already marked `in-progress`
4. Once you take an item:
   - create/switch to the suggested branch
   - update the work-item file header from `ready` to `in-progress`
   - commit and push that claim promptly if the queue is shared through git
   - make only the changes needed for that item

## Ownership Rules

- one work item per branch
- one agent per work item unless a human explicitly says otherwise
- do not mix unrelated refactors into the same branch

## Source Of Truth

Use both:

- primary: work-item file status header
- secondary: existing branch/worktree presence

Do not rely only on worktrees, because stale worktrees may exist.

## PR Workflow

1. implement and validate locally
2. push the branch and open a PR
3. wait briefly for CI and bot review to appear
4. read GitHub comments and checks
5. fix substantive issues
6. merge only after checks are green or remaining comments are intentionally
   judged non-blocking

## Completion Rules

When your PR merges:

- update the work-item file to `done` or delete it if fully complete
- if partial work remains, leave a smaller follow-up file behind

## Planning Feedback Rule

If your work changes the plan materially:

- update the relevant work-item file in the same PR
- if you discover a new standalone follow-up, add a new numbered work-item file
- update [`README.md`](./README.md) and [`agent-prompts.md`](./agent-prompts.md)
  when you add a new item
