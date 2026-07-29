# The environment contract — where the assembled build runs

QA drives *the running product*, performance measures it under load, and the PM walkthrough is a
person clicking through it. All three presuppose a running build; **nothing in the workbench creates
one** (`build-infra` produces reviewed IaC and never applies). This file makes that gap explicit and
measurable instead of improvised.

## The marker

An epic carries `ENVIRONMENT: {how to reach it} | tier={ci|ephemeral|none} | {note}` — recorded by
whoever obtained it. Absent, the checks that need a running product do **not** run.

## Resolution order

1. **`tier=ci`** — the project's CI published an environment for this build. Preferred: it is
   reproducible and nobody waits.
2. **`tier=ephemeral`** — the build was stood up throwaway (preview build, tunnelled instance,
   compose) and will be torn down. **It must be reachable by a person**: the PM walkthrough is
   human-performed, so an environment only an agent can reach does not satisfy this tier.
3. **`tier=none`** — no environment could be obtained, because the feature needs real infrastructure
   (a managed database, a queue, a cloud service) or the only possible stand-up is local to the
   agent. **Record the block, surface it to the founder, and continue with other work.**

**Never provision real infrastructure to satisfy this.** Standing up cloud resources is a gated human
or pipeline step, not a decision the agency makes to unblock its own check.

## What a missing environment does and does not block

| | Effect |
|---|---|
| Building, code review, unit tests, security | **Unaffected** — these need no running product |
| QA functional/exploratory, performance | Do not run; recorded as blocked-on-environment, never as passed or as "no findings" |
| PM walkthrough (user-facing epics) | Cannot happen here; the `Epic GA package` is **held and re-surfaced every pass** until the founder either supplies an environment or records `PM-ACCEPTANCE: walkthrough performed out-of-band — {evidence}` |
| Non-user-facing epics | Unaffected — the walkthrough was not required (see the PM skip rule) |

**The hold has a named exit, and it is the founder's alone.** A user-facing epic at `tier=none`
would otherwise sit forever: the skip marker covers only non-user-facing work, so neither accepted
record can be written. The out-of-band record closes that — an explicit, auditable human override of
the same shape as delegated-proceed. The agent may **never** write it on its own initiative; it
surfaces the hold and names the route.

A blocked check is **never** reported as a clean one. `perf` already behaves this way
(`NEEDS_CONTEXT` rather than a faked pass); this generalises it.

## Why the tier is recorded, not just the URL

The tier is the measurement. If most epics land on `tier=none`, the ephemeral path is not earning its
place and the evidence for building real deploy automation is a **count**, not an argument. Recording
only a URL would lose exactly the signal needed to make that decision later.
