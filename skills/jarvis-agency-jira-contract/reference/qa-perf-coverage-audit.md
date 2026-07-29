# Governance beyond the diff — QA, Performance, Coverage, Audit, Retro (detail)

Reference detail for the contract's governance-sweep line. The three code verifiers check the diff
and re-run the producer's tests; none drives the **running product**, and none sweeps the whole
product on demand. These five capabilities close those gaps (the fifth, retro, learns from a finished run), each a governance identity distinct
from the producer and the code trio.

## Functional QA (`jarvis-agency-qa`)

- **What it covers:** **Smoke** (the AC flows on a fresh build), **running-app Regression** (older
  flows the change touched, beyond the unit suite), and **Exploratory** testing (disciplined
  heuristics, not a substitute for human creativity). Security is the `redteam-security` verifier plus
  the human at GA; User Acceptance is the founder's own **RC → GA** sign-off (the RC advisory guide).
- **When:** at **epic completion** on the assembled product (the agency's first **epic-level** check
  — a real user flow only exists once the stories integrate), and **per story when the story is
  independently runnable** (a smoke pass beside the code trio). A non-runnable slice defers to the
  epic pass rather than faking a per-story result.
- **Reporter, not a new hard gate.** QA **files a Bug per defect** (the first-class defect unit; the
  bug path fixes it — QA never fixes, the mirror of producer-never-verifies) and writes a **QA
  Verdict** listing the flows exercised. A **blocker-severity** finding is `VERDICT: FAIL`: per story
  it bounces to In Progress; at the epic it does not bounce merged work — it **surfaces the summary +
  filed Bugs to the human** for the delivery decision. It needs a runnable app and an E2E harness (the
  architect provisions it as an epic prerequisite); with none it reports NEEDS_CONTEXT, never a faked
  pass.

## Performance (`jarvis-agency-perf`)

The sixth QA category and its own governance identity: at **epic completion**, against a
**performance-representative non-prod environment** (never production, never per story), it
load/stress-tests the assembled product against the **SLO targets** (the architect's SLO
constraints, written into AC by author-prd) — latency **percentiles** (p50/p95/p99, not the mean),
throughput, error rate under load, saturation — and files a Bug per breach, writing a **Perf
Verdict** that states the environment. It reports (a breach surfaces to the human at the epic); it
needs a defined SLO + a representative environment + a load harness, else NEEDS_CONTEXT, never a
faked pass. A non-prod number is indicative, not authoritative.

## Product reality audit (`jarvis-agency-audit`)

A **founder-invoked, on-demand, whole-product** sweep that uncovers placeholders, stubs, scaffolding,
and features that look done but do not actually work, across backend, API, frontend, web, and data.
It is a governance identity distinct from the producer, the code trio, QA, and perf, and it **does
not trust the per-story or per-epic record** — that independence is its whole point. It has four
parts: (1) a **static reality sweep** of the repo per stack for placeholder tells (unimplemented
panics, TODO/FIXME, empty handlers, stubbed returns, mocked-never-realized integrations, dead flags,
assertion-free tests); (2) a **behavioral reality sweep** driving the running product across every
advertised feature to confirm each actually works (reuses QA's technique; NEEDS_CONTEXT for this part
alone if the product cannot be run); (3) a **claims-vs-reality** check comparing what the product
claims (README, PRDs, RC advisories, the digest, user docs) against what actually works; (4) it
**files a Bug per gap** (severity-tagged, via the bug path) and writes a **product-health Audit
Report** that states honestly what it swept and what it could not. Reporter, never fixes; on demand,
not tied to a story or an epic; states its coverage limits (a clean audit is not proof of
perfection).

## Coverage targets (benchmarkable)

Numeric coverage is a config policy, the same as the cost budgets and the fan-out threshold:

- **Default in the config** — a **patch-coverage floor** on the story's changed lines plus
  **critical-path 100%** (auth, tenant-isolation, data-boundary, money/security paths). The single
  baseline everything is measured against.
- **Raised per epic by the architect** where the domain demands it (regulated/security-critical),
  recorded as a constraint frozen in the snapshot.
- **Turned into AC by `author-prd`** (like the SLOs), so it enters the snapshot the verifiers read —
  but the **numeric** floor is written as AC **only where the repo can measure it** (a coverage
  provider + script exist, per the codebase digest's coverage-measurability record). Where the digest
  flags coverage as a known repo gap, the behavioral-coverage AC stands alone; no unmeasurable number
  is written (a verifier must never be handed a percentage it structurally cannot check).
- **Measured and recorded by `run-tests`** — **where the snapshot carries a numeric criterion**: it
  runs the stack's coverage tool, compares actual vs target, FAILs under the floor, and **writes the
  actual number into the Test Verdict lane** so there are per-story data points to trend. Where the
  digest flagged coverage unmeasurable (no numeric AC), run-tests skips the number and relies on
  AC-coverage — it never fabricates or falls back to a default. Target in config, actuals in the lanes.
- **Honest caveat:** AC-coverage (every AC, negative, edge, and cross-tenant case has a test that
  fails on regression) is the **primary** gate; the numeric floor is a **secondary guard** that
  catches paths the AC list missed. Use **patch** coverage, not a repo-wide %, and beware Goodhart —
  100% line coverage with assertion-free tests is worthless. The number fails low; it is not the
  headline target.


## Retro — the learning organ (`jarvis-agency-retro`)

Dispatched by the orchestrator when it **closes the epic** (the GA Signed row transitions the epic
to Done after its last story and the epic-completion checks; nothing else closes an epic), or
founder-invoked on any closed epic. It harvests the run's record — verification-round counts and
each round's verdict lanes, `TIER:`/pace markers, Cost notes vs the config budgets, QA/Perf/PM
verdicts and the Bugs they filed, max-bounce parks, re-tier bounces, and the status-transition
timestamps — into a `## Run Report` heading comment on the epic (bounce causes classified, verifier
catches named, cost/wall-clock vs budget, human interventions, what went well; any still-open Bug
tail noted, not waited on). Where the same defect class repeats — across the epic's stories, or
across runs — it drafts **evidence-cited improvement proposals** to the `## Improvement Proposals`
lane: target skill, concrete change, and the primary evidence.

Boundaries: **proposals only** — retro never edits a skill, config, or budget (an approved proposal
lands via the platform repo's improve-skill playbook and gates); never re-grades or reopens a
verdict; never bounces merged work; never gates RC or GA; no evidence, no proposal; and it **never
proposes weakening the four invariants, the human gates, verifier independence, or the trust
boundary** — a concern touching those is surfaced to the founder as a question, never packaged as an
evidence-formatted proposal.
