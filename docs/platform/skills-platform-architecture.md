# Skills platform architecture

The one-page mental model of shipfoundry. For onboarding, read [README.md](../../README.md); for project conventions, [CLAUDE.md](../../CLAUDE.md). This doc is the *architectural* view: classes, the dependency shape, and the load-bearing edges.

## Skill classes

| Class | Role |
|---|---|
| **Foundation** | Applies implicitly under other skills — defines shared rules (voice, conventions, guardrails). A workbench typically has one. |
| **Orchestrator** | Routes or fans out to other skills (a dispatcher that picks up tickets and routes by label/type; a "review all" fan-out). |
| **Domain** | Does one slice of one lifecycle — a registered pattern (driven by a dispatcher) or a standalone (invoked directly). |

Naming: `jarvis-<workbench>-<verb-noun>`. Source of truth in `skills/`; symlinked into `~/.claude/skills/` for local use; distributed as versioned zips in `dist/`.

## Dependency shape

A typical platform has a few load-bearing edges worth drawing explicitly:

```
<foundation skill> ──(implicit foundation)──────────► every other skill in its scope
<dispatcher>       ──routes by label / type─────────► its registered pattern skills
<fan-out skill>    ──invokes in parallel────────────► its sub-skills
<source artifact>  ──feeds downstream───────────────► the skills that consume it
```

Lifecycles have direction (signal → draft → review → publish → follow-up). Where a downstream skill depends on an upstream artifact's status, that status gate is part of the architecture — it both sequences the work and disambiguates triggers.

## Single points of failure (how to reason about them)

Rank your load-bearing skills by *fan-in* (how many skills depend on them) against *test coverage*:

1. **The global foundation** — every skill depends on it, so a regression propagates platform-wide. This is the highest-leverage place to have an eval, and the most expensive place to leave untested.
2. **Any dispatcher** — the routing brain for an automated loop. Watch its body-line budget (lint check 6) and its routing logic.
3. **Any artifact/pattern cited as canonical by several downstream skills** — tight coupling; lock it and monitor the upstream it depends on.
4. **CLAUDE.md** — not code, but the single live source of governance truth (counts, conventions, build pattern). Drift here misleads every fresh-session agent. Partly guarded by `lint-platform.sh`.

## Scaling posture (toward hundreds of skills)

- **Discoverability** — at scale, lean on the trigger-collision lint (check 9) and a disciplined taxonomy ([`skill-taxonomy.md`](./skill-taxonomy.md)).
- **Governance** — keep moving invariants from prose-remembered to executable (`lint-platform.sh`). This is what makes multi-maintainer growth survivable.
- **Evaluation** — fix coverage *order* (foundation + highest-leverage first) before chasing a coverage *count* — see [`evaluation-strategy.md`](./evaluation-strategy.md).

## Current state snapshot

Live counts and versions are **not** hard-coded here (that's the drift anti-pattern). Run:

```bash
./lint-platform.sh --versions   # authoritative skill -> version table
./lint-platform.sh              # parity, caps, leak checks across all skills
```

for the authoritative current state.
