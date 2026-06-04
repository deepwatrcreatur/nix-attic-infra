# Discussion: Garnix Shutdown / Open-Sourcing and the Homelab Decision

## Question

Given the reported announcement that Garnix is shutting down its hosted service
and releasing the source code, what should this homelab do?

Current baseline:

- a local `attic-cache` VM serves Nix packages and binary cache content;
- `nix-ci.com` is currently used for CI-style build validation and provides a
  useful build dashboard;
- this repo already treats Attic as a long-lived cache/distribution layer rather
  than as a full CI orchestration product.

Required decisions:

1. Is self-hosted Garnix a substitute for Attic, for `nix-ci.com`, for both, or
   mainly a complement?
2. If adopted, can it safely live on the existing `attic-cache` VM, or should it
   be placed behind a separate service/VM boundary?
3. Would the self-hosted dashboard likely be good enough to replace the role
   currently played by `nix-ci.com`?
4. What should the homelab do next?

## Note on evidence

At time of writing, the public Garnix website and blog still presented the
service as active from the directly fetched pages available during this round.
This discussion therefore treats the shutdown/open-source announcement as a user
provided premise and focuses on the architectural decision implied by that
premise.

## Roundtable

### Seat 1 - Codex

Codex argued that open-sourced Garnix should be treated primarily as a CI/control
plane candidate rather than as a cache replacement.

Its main conclusions were:

- Attic remains the right binary cache/distribution layer.
- Garnix is much closer to a replacement candidate for `nix-ci.com` than for
  Attic.
- The safest homelab shape is a separate VM or service boundary for self-hosted
  Garnix because build workloads are spiky and higher risk than a boring cache
  server.
- The dashboard will likely be "good enough for internal use" before it is as
  polished or as low-maintenance as an existing hosted service.

Codex recommended a limited pilot on a separate VM before any migration.

### Seat 2 - Claude

Claude pushed hardest on the role distinction between build orchestration and
artifact distribution.

Its most important points were:

- Garnix bundles CI orchestration, build status, cache behavior, and dashboard
  UX into one product shape.
- Attic is still a simpler and more stable long-lived artifact cache and should
  remain the canonical homelab cache.
- Self-hosted Garnix is best understood as a near-replacement candidate for the
  `nix-ci.com` role, while staying complementary to Attic.
- Co-locating Garnix with the Attic VM is a bad default because CI/build
  workloads have very different resource, trust, and blast-radius properties.

Claude also emphasized a practical unknown: whether the self-hosted dashboard
experience will actually match the hosted product well enough to justify
replacing `nix-ci.com`.

### Seat 3 - GPT-5.4 mini

The mini seat largely converged with the others:

- do not retire Attic because Garnix is a broader system than a simple cache;
- evaluate Garnix primarily as a self-hosted CI and build-status layer;
- prefer a separate VM;
- expect the dashboard to be usable, but do not assume it will instantly exceed
  the current `nix-ci.com` experience.

The mini seat framed the right next move as a side-by-side pilot rather than a
migration.

## Main distinctions

### 1. Garnix is closer to a `nix-ci.com` substitute than an Attic substitute

For this homelab, Attic and Garnix solve related but different problems.

Attic is still the simpler answer to:

- serve binary cache artifacts to many machines;
- retain those artifacts as stable homelab infrastructure;
- keep cache responsibilities boring and predictable.

Garnix is more naturally aimed at:

- driving Nix builds;
- showing build and check status;
- attaching a nicer CI-oriented dashboard to those builds;
- potentially pushing resulting outputs onward into a cache.

That makes self-hosted Garnix:

- **not a clean replacement for Attic**;
- **a plausible replacement candidate for `nix-ci.com`**;
- **mostly complementary to Attic**.

### 2. The Attic VM should stay boring

The discussion strongly rejected the idea of putting self-hosted Garnix directly
onto the existing `attic-cache` VM as the default design.

Reasons:

- CI/build workloads are CPU-, memory-, and disk-intensive in ways a cache
  service should not need to be.
- Build systems execute more complex and potentially less trusted workloads than
  a cache server.
- A CI failure or resource spike should not threaten the reliability of the
  binary cache relied on by the rest of the homelab.
- Operationally, cache uptime and CI experimentation are different concerns.

Conclusion:

- **Use a separate VM or similarly strong service boundary** for Garnix if it is
  adopted.
- Only co-locate under real resource pressure, and then only as a deliberate
  temporary compromise.

### 3. The dashboard question is the main practical uncertainty

The most attractive thing about the current `nix-ci.com` usage is not just that
builds happen somewhere else, but that the service provides a nice dashboard and
pleasant visibility into build outcomes.

The round judged that self-hosted Garnix will likely be:

- good enough to provide a usable internal dashboard;
- potentially strong enough to approximate the current `nix-ci.com` role;
- but not something that should be assumed to match the polish and maintenance
  profile of the hosted service on day one.

So the real unknown is not "can Garnix build?" but "how much operational burden
and UX roughness will self-hosting introduce compared to what is already
working?"

## Homelab decision

The roundtable recommends the following decision:

1. **Keep Attic as the canonical homelab cache.**
2. **Treat self-hosted Garnix as a candidate replacement for `nix-ci.com`, not
   for Attic.**
3. **Do not place Garnix on the existing `attic-cache` VM.**
4. **Evaluate Garnix on a separate VM first.**

In plain terms:

- Attic remains the artifact-distribution layer.
- Garnix, if adopted, becomes a CI/build-control layer that can feed Attic.
- `nix-ci.com` is the role most likely to be reduced or replaced if the Garnix
  self-hosted dashboard proves good enough.

## Recommended next move

Run a bounded pilot instead of migrating immediately.

Suggested shape:

- create a separate Garnix evaluation VM;
- point it at one or two representative repositories;
- keep Attic unchanged as the downstream cache;
- compare self-hosted Garnix and `nix-ci.com` on:
  - build success and stability,
  - dashboard usefulness,
  - operator effort,
  - whether cache outputs integrate cleanly with the existing Attic pattern.

## Verdict

Self-hosted Garnix should be treated as **mostly a complement to Attic** and
**the strongest candidate substitute for the current `nix-ci.com` role**.

For this homelab, the right move is:

- **keep Attic**,
- **pilot Garnix separately**,
- **replace `nix-ci.com` only if the self-hosted dashboard and maintenance story
  prove good enough**.
