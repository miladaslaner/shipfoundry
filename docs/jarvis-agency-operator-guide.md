# Jarvis Agency Workbench — Operator's Guide

The Jarvis Agency Workbench is a set of skills that together run a near-autonomous product agency.
You are the only standing human. You work in Jira. The agents translate Jira down into real
backend, frontend, web, data, Go, native, mobile, and ML work, and write status and artifacts back
up to you. This guide is how you set it up and run it. It is also the source for the Confluence version.

---

## 1. The idea in one paragraph

You author intent in the **vault** — the notes under `docs/` in the product repo — and Jira carries
the pointer to it plus the execution record. The orchestrator reads both, decides what to do, and
dispatches a fresh subagent per unit of work, each loaded with one skill and a narrow brief.
Producers write code and open pull requests. Independent verifiers check that code. State lives in
those two durable stores, never in agent memory. The agents take work only to release candidate. A human signs GA. You show up at two
moments: approving the locked requirements, and the GA sign-off. You can also just talk: describe a
feature or a bug in chat, or think an idea through with the PM, and the agency turns that into the
right Jira work.

---

## 2. Setup — getting it running

Four things, once.

1. **Install the skills.** The skills live in `skills/` in the repo (the source of truth) and are
   symlinked into `~/.claude/skills/` so Claude Code loads them. The repo has a one-liner that
   symlinks every skill folder. Built distribution zips live in `dist/` for the claude.ai org Skills
   panel.
2. **Connect the tools (MCP).**
   - **Atlassian**, authenticated as the **dedicated AI Agent account**, not your human account.
     This is what makes the changelog actor read as the agent, which the GA guard keys on.
   - **GitHub**, so producers can open real pull requests. Connected — the first live slices opened
     and merged real PRs. The `main` branch of every agency repo carries a **protection ruleset**
     (GitHub Pro): merging requires a PR, and — where the repo has CI — that CI must be green; direct
     pushes and force-pushes to `main` are refused by GitHub itself. A hard wall behind the producers'
     pre-flight (the CI-less sandbox repo is PR-only until it grows a CI). You keep
     an admin bypass for emergencies; onboarding checks (and offers to set) this on new repos.
   - **Confluence**, for the docs (already connected).
3. **Confirm the Jira contract.** Your home project, the nine workflow statuses (Backlog,
   Refined, In Progress, In Review, RC, GA Signed, Done, Rejected, Blocked), the dedicated agent
   account, the GA-guard Automation rule, and the cost budgets all live in the contract's internal
   config. These are in place and verified.
4. **Point it at a product repo.** The loop runs from a Claude session in the product's repo; the
   producers build there and open real PRs. The home project is paired with a sandbox repo and
   has run live end to end. For a new product, see "Onboarding a new Jira project" below.

### Onboarding a new Jira project (one project per product)

You can point the agency at a different Jira project for each product you build, all on the same
Atlassian instance. Create the project in Jira, then — from a Claude session in that product's repo —
say `set up the agency for <project>` (e.g. "LogBench"). The `jarvis-agency-onboard` preflight
resolves the project, validates it against the contract (the nine workflow statuses, Story/Epic types,
the GA-guard automation, that you're acting as the agent account), and reports what's missing. It
configures the gaps for you: the status and automation setup are driven in your browser (the Atlassian
API can't edit workflows or automation rules), everything else is automatic. It also validates the
repo — including the default branch's protection ruleset, which it offers to set up where missing.
Once the checklist is green it records the project so `run the agency loop on <project>` just works from then on. A project is never
handed to the loop until it's fully set up, so a half-configured project (like a freshly created one)
gets caught and walked through setup rather than failing mid-run.

### Existing products: the agency learns the codebase first

Onboarding a greenfield repo is enough on its own. But when you point the agency at an **existing
product**, it must understand that codebase before it builds — otherwise the architect would invent
constraints that contradict the real architecture, and the producers would impose generic conventions
that clash with your actual patterns. So onboarding an existing repo triggers a one-time **hydration**
(`jarvis-agency-hydrate`): it scans the repo, fanning out parallel readers, and produces a verified
**codebase digest** (`.agency/codebase-map.md`) — the architecture and module map, your real
conventions, the domain model, the build/test/deploy commands, the design system, do-not-touch zones,
and an honest list of what it could not determine. It folds the binding conventions into the repo's
`CLAUDE.md`/`AGENTS.md` (appending, never overwriting your rules) via a PR you review. A second, distinct
agent verifies the digest against the actual code, and **you approve it** before the agency relies on it
— the same shape as the requirements approval gate. From then on the architect, the design step, and the
producers all build from the real codebase instead of house defaults. The digest is refreshed when the
code moves materially (a new module, a changed build or dependency manifest, edited conventions), not on
every run. A project on an existing repo is loop-ready only when it is both configured and hydrated.

---

## 3. Running it — Code sessions, Loops, Routines

The orchestrator skill defines **one pass** of the loop: read the board, route, and dispatch **every
independently-actionable unit concurrently** (a wave, capped at 4 at a time — dropped when API rate
limits bite; stories that overlap on the same files never build in parallel, and a product's child
epics build in the founder-approved dependency order — an epic `is blocked by` one not yet Done
waits, and only you add or remove those links after approval), collect results as
they land, write state back, stop. An epic of independent stories builds in roughly the time of one
story instead of one after another. Three further speed disciplines hold per pass: **upstream stages
skip by default** (research and architecture run only on a named trigger — an unknown the repo can't
answer, a genuinely cross-cutting decision — instead of every stage running by reflex), **producers
pre-flight** (a producer runs the repo's own build/tests/lint before opening any PR — no PR on red,
so verifier rounds stop burning on mechanical failures), and the `thorough` pace stays the one
kill-switch that makes everything sequential again. No gate changes — speed changes when work runs,
never what checks it; expect the queue to reach your approval and GA gates faster. It does not run
forever on its own. How you make that pass happen, and
repeat, is the choice below. It all works because the durable state lives outside the session —
Jira holds the execution truth, the vault the intent — so every pass is stateless and safe to
re-run.

| Mode | What it is | Runs where | Use it for |
|---|---|---|---|
| **Interactive Code session** | You type the trigger in Claude Code and watch | Your machine, your session | First runs, the approval gate, anything you want to supervise. Start here. |
| **/loop** | Wraps the trigger to re-fire on an interval or self-paced | Your machine, your session, while it is on | Keeping the board advancing while you are around |
| **Routine (scheduled cloud agent)** | A cron-scheduled cloud run of the orchestrator | Anthropic cloud, on a schedule, laptop off | A genuinely unattended agency, once credentials and a repo are wired |
| **Prompts / slash commands** | The trigger phrases that route to a skill | Wherever you run | Triggering the orchestrator, or one skill directly |

### Interactive Code session (start here)

In Claude Code: `run the agency loop on {YOUR-PROJECT}`. The orchestrator does one pass and reports. You watch
it work and you are present for the founder-approval gate. This is the mode for your first runs and
any run you want to supervise.

### /loop (semi-unattended, while you are at the machine)

Wrap the trigger so it repeats: `/loop 10m run the agency loop on {YOUR-PROJECT}` re-fires the orchestrator
every ten minutes, picking up newly ready stories; omit the interval to let it self-pace. It runs
locally in your session, so your machine has to stay on. Use it to keep the board moving without
re-typing the trigger.

**Before you leave a `/loop` unattended (especially in bypass-permissions mode), set the hard
backstop.** There is no perfect per-run token kill switch inside local Claude Code that an agent
cannot talk past. The genuine hard limit under your control is your **Anthropic account usage/spend
limit** (the Console billing usage limit on API billing; the plan's own rate cap on a Max
subscription). It is coarse — account-wide — but it is the one thing a misbehaving loop cannot
override. The workbench's own per-run budget (the cost watcher parks the run at the cap) is a soft
brake on top, real but compliance-level. Also know what unattended actually advances: the human
gates are behavioural, so even in bypass the loop will not self-approve a brief or self-sign GA — it
stops and flags. So approve the epic and its stories while you are present, then let `/loop` grind
the build → verify → RC pipeline unattended; it parks at GA, at a max-bounce, or at a cost `over`.
Your dashboard is the Jira board.

### Session hygiene for long runs

Every pass is stateless — Jira holds the execution truth, the vault the intent — so the *session hosting* a `/loop` run is the one
long-lived context in the whole system, and it accumulates every pass's board reads, collections,
and advisories for as long as the loop runs. **Set a sub-cliff auto-compact backstop in the project's `.claude/settings.json` env** (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=225000` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=95`) so context compacts at ~192K, below the 200K premium cliff; after relaunch confirm it bound via `/context` ("Auto-compact window: 225k"). **This backstop is the enforced mechanism — live-validated 2026-07-16 to hold a full day sub-cliff (0% of turns >200K, ~82.5% cost-per-turn cut).** An optional pass-count restart every ~2 passes (`refresh_soft_passes`, default 2) is a cleaner path but did **not** fire in the validating run — do not rely on it. For long unattended runs prefer a Routine (fresh session per firing).
It costs nothing (the next pass re-reads the board and resumes exactly where the last one ended, and
even a kill mid-pass is recovered by the orchestrator's interrupted-loop rule) and it is the whole
defense against a long session's attention quietly degrading before anything visibly fails. A cloud
Routine gets this for free — a fresh session per firing — which is one more reason it is the right
shape for genuinely long unattended runs.

Second, know what your machine adds to every session. On a maintainer machine with a rich global
`~/.claude` setup, each model call silently carries that global config — measured at ~91k tokens per
call when the eval harness first ran here (a known eval-harness limitation), which is why
`run-evals-lean.sh` stashes it. The loop host inherits the same ambient load (unmeasured for the
loop so far). For long unattended runs, consider a dedicated lean profile (`CLAUDE_CONFIG_DIR`) the
way the eval path already does — or at least know the overhead is there when you size budgets.

### Routine (fully unattended, in the cloud)

Schedule the orchestrator to run on a cron in the cloud. It survives your laptop being off. This is
the path to an agency that runs without you babysitting a terminal. **Prerequisite:** headless
credentials. An interactively authenticated MCP connection does not carry into a headless cron run,
so the AI Agent's Atlassian API token and the GitHub access must be provisioned in the cloud runner
itself. Wire those first, or the scheduled run will have no Jira or GitHub.

### Prompts and slash commands

The trigger phrases ("run the agency loop", "pick up the next story", "route this epic", "advance
this story") route to the orchestrator. You normally only ever invoke the orchestrator; it dispatches
every other skill itself. You can invoke a single skill directly when you want just that step.

### Not Workflows

The orchestrator already dispatches a subagent per unit of work and handles the fan-out to the three
verifiers. You do not need the separate multi-agent Workflow layer for the agency loop.

### The recommended progression

1. **Interactive**, until you trust the gates and have seen a slice go to RC.
2. **/loop while you are around**, once you are comfortable letting it advance the board semi-attended.
3. **A Routine**, only after the headless credentials and a real repo are wired and you trust the
   loop unattended.

The human gates hold in every mode. Even an unattended Routine stops and waits at the founder
approval and the GA sign-off. It will not self-approve a brief or self-sign GA, and the GA guard
reverts it if the agent account ever tries.

### Cost: the loop sizes each model to the work

One story fans out into many subagents. Each one runs on a model tier matched to its job, not the
strongest model by default. Judgment and security work (intake, architecture, red-team, audit) run
on the strongest model. Structured work and the code gates run mid. Mechanical steps (classify a
chat ask, arithmetic against the budget) run cheap. This is what stops a trivial change from paying
the top tier across a dozen subagents. The per-role tiers live in the orchestrator, and the cost
watcher still parks any run that breaches its budget.

The ceremony scales too. A **docs** ask (a README or guide change touching no code at all) runs a
light pipeline: one story, the docs producer, and **one** adversarial content-accuracy gate instead
of the three-verifier trio — a prose diff has no test suite to re-run, and its content is its whole
attack surface, which that gate reviews (command and link tampering included). If the work turns out
to touch anything executable, it bounces into the full code path — the single gate never verifies
code. A documentation *defect* ("the README command is wrong") also runs as docs, not as a Bug. And
for a truly trivial **prose** ask (a typo), capture will offer to just do it in a plain session with
no Jira record — your choice; that offer is never available for anything executable. Your approval
and the human GA gate never change. All of this is v1 and not yet validated on a real run.

**Where to see the tier.** Every ask carries a `TIER:` comment on the issue intake classified — for
a product, that is the **parent** epic, and each **child epic also carries its own** breadcrumb tier
(`TIER: small (child of {PARENT}, product decomposition) — …`) that you confirm with the one intake
approval. Stories never carry one (they inherit their epic's). A child epic with no marker runs as
`feature`; the loop will offer you a one-time batch backfill for products decomposed before per-epic
tiers existed — one list, one confirmation, nothing re-validated.

---

## 4. Your two touchpoints

There is no separate dashboard. Jira is the cockpit. Your job is two decisions.

1. **Approve the locked requirements.** Intake interrogates you and writes a Requirements Brief into
   the **vault** — the notes under `docs/` in the product repo, which is where intent (requirements,
   scope, design decisions, GA decisions) is authored and kept. Jira carries a pointer to it and the
   execution record: status, worklog, PR links, progress. A requirement that exists only in a Jira
   comment is not a requirement and the agents will not act on it.
   You approve the brief before anything is built. (Gate one.) On an existing product you also approve the
   codebase digest hydration produces.
2. **Sign GA.** Stories reach RC, fully verified. A human signs RC to GA Signed. That is you, or a
   named engineer, signing as your own account, not the agent. (Gate two.) **Where you sign is a
   per-project choice**, and the default is now **`epic` mode**: one PRFAQ, one epic, one GA. It asks
   for one signature per epic, against an Epic GA package that consolidates every story's validation
   guide plus the QA/perf/PM-acceptance verdicts — built for a non-technical founder, since the
   capability is what you can actually validate. Under epic mode stories merge at RC (before your
   signature; a rejection becomes rework, not an automatic revert). **`story` mode** — a signature per
   story — survives as the severity carve-out: stories touching security/auth/tenant-boundary/
   data-migration/payment surfaces always ask for an explicit story-level signature, and a project
   explicitly set to story mode runs that way throughout.

Everything between those two moments is the agents writing to the Jira issues. You watch the board.

**What you actually validate at RC.** The agents already proved the code meets the frozen
acceptance criteria, the tests cover them, and the security pass is clean. You do not re-audit that.
Your layer is the one a machine cannot own: did the criteria capture what you meant, do the product
decisions still feel right seeing them live, and are you willing to put your name on the release.
When a story hits RC the orchestrator posts an advisory comment that states the job-to-be-done, what
you can validate now, what is explicitly out of scope this slice, and how to see it running — so you
are never left asking what you are signing off on. (Added after the first live run, where exactly
that question came up.)

**Product acceptance is part of that advisory now — and a human performs it.** When an epic's
stories reach RC, the PM (a fresh run, not the producer) confirms the build is reachable in a
running environment and writes a **walkthrough script** from the PRFAQ: per promised outcome, what
to open, what to do, what you should see if it holds, and what failure looks like. **A human then
performs that walkthrough** and gives the verdict; the agent records it verbatim into the **PM
Acceptance** lane. The agent's own document-level read still runs, but it is labelled as a
pre-screen — it is never the walkthrough verdict. Presence of a verdict (or a recorded skip, for an
epic with no user-facing surface) is a **precondition of the Epic GA package**; the verdict itself
stays advisory. Functional **QA** and **performance** run at the same point. All three are advisory
reporters: they file Bugs on real defects and feed your GA decision, but none of them gate RC or
sign GA. You still own the sign-off.

---

## 5. The skills, by line

Six lines: the spine, the upstream delivery stages, the bug path, the producers, the governance
checks, and — added since the first live run — a conversational front door and a discovery role.
(For the exact roster, `ls skills/jarvis-agency-*/`; the tables below list every skill by line.)

### How the seats map (PM ↔ EM)

If you run a PM/EM split with people, the agency maps onto it directly — but the seats are made of
*several* skills, not one each:

| Seat | Who fills it here | Owns |
|---|---|---|
| **PM** | `jarvis-agency-pm` | The **WHAT**: the PRFAQ in the requirement note, and the walkthrough at the end. Requests status changes; never moves a story. |
| **EM** | `jarvis-agency-orchestrate` + `jarvis-agency-architect` + `jarvis-agency-author-prd` | The **HOW** and the flow: cross-cutting constraints, the PRD and its decomposition, and every status transition. |
| **Dev** | the `build-*` producers | The change, test-first, and the PR. |
| **QA** | `jarvis-agency-qa`, `jarvis-agency-perf` | Functional, exploratory, regression, and load — on the running product. |

**The EM seat is deliberately three skills, not one.** A single "EM agent" would author the tech spec
*and* decide when work built from it may proceed — the producer-never-verifies boundary at epic
scale. Splitting authorship (architect, author-prd) from flow (orchestrate) keeps the person who
wrote the plan from being the one who waves it through.

**One writer, recorded actor.** Every status move is performed by the orchestrator — a wave runs
several units at once, so a distributed writer would reintroduce status races. Each move records a
`STATUS-ACTOR:` marker naming the role it was made *for*, so "who moved this to testing" stays
answerable without changing the mechanism.

### Front door and discovery

| Skill | What it is |
|---|---|
| jarvis-agency-capture | The conversational front door. You drop a feature idea or a bug in chat; it classifies the ask, confirms it, and creates the right Jira issue (an Epic or a Bug) — then offers to run the loop now or leave it for the next pass. It only creates and routes; every downstream gate still applies. |
| jarvis-agency-pm | The product manager, at **both ends**. Up front it is a discovery partner: frames the problem, challenges whether to build at all, shapes the smallest slice, and writes the **PRFAQ** — the future press release and customer FAQ — into the vault requirement note, which is what seeds capture and intake. At RC it runs product acceptance as a three-act walkthrough: the agent prepares the environment and the script, **you (or the PM seat) perform it**, and the agent records your verdict verbatim. Advisory in outcome — never gates RC, never signs GA — but it must have run before the Epic GA package exists. |

### Spine

| Skill | What it is |
|---|---|
| jarvis-agency-jira-contract | The foundation. How work lives in Jira: statuses, the RC ceiling, the Definition of GA-ready, decomposition, the four invariants, comment-first storage, the per-project registry. Every skill obeys it. |
| jarvis-agency-onboard | The first-run preflight. Validates a Jira project against the contract, configures the gaps (statuses + GA-guard via the browser), validates the repo — including the branch-protection ruleset, which it offers to set — and records the project so the loop can run. |
| jarvis-agency-orchestrate | The dispatcher. The only skill you trigger for delivery. Reads Jira, routes work, spawns subagents, writes state back, stops at RC. |

### Delivery — upstream (turn intent into a buildable spec)

| Skill | What it does |
|---|---|
| jarvis-agency-intake | The requirements-lock gate (not the opening conversation — an unshaped idea goes to the PM first). **Reads** the PM's PRFAQ from the vault requirement note and derives scope backwards from it — it never writes its own launch narrative. Interrogates you on the gaps, runs first principles, locks the Requirements Brief (a requirement tracing to no PRFAQ line is scope creep; a PRFAQ promise with no requirement is a gap), decomposes to epics, maps coverage, stops at your approval. |
| jarvis-agency-hydrate | On an existing product, scans the repo once into a verified codebase digest the architect, design, and producers build from. Greenfield skips it. |
| jarvis-agency-research | Answers the epic's open questions with evidence. Runs only when the locked brief has questions the repo can't answer. |
| jarvis-agency-architect | Sets the cross-cutting constraints, deployment model first. On an existing product, grounds them in the codebase digest. Runs only for genuinely cross-cutting work; otherwise the orchestrator records a one-line "fits the existing architecture" note. |
| jarvis-agency-author-prd | Writes the PRD, decomposes to stories, drafts the acceptance criteria. |
| jarvis-agency-design | UX and screen states for stories with a UI. |

### The bug path

| Skill | What it does |
|---|---|
| jarvis-agency-triage-bug | A Bug skips the feature pipeline. Triage reproduces it (or records that it can't), root-causes it, scopes a narrow fix, drafts fixed-shape acceptance criteria (the bug no longer reproduces, plus a regression test), and stops at your **fix-scope confirmation** before a producer builds. |

### Delivery — producers (write the code)

Every code producer **pre-flights** before opening its PR: it runs the repo's own build, full test
suite, and lint, and attaches the evidence. No PR opens on red — mechanical failures are the
producer's to catch, so the independent verifiers spend their rounds on judgment.

| Skill | Stack |
|---|---|
| jarvis-agency-build-backend | Kotlin / Micronaut, JVM services and APIs |
| jarvis-agency-build-frontend | React / Next.js web UI |
| jarvis-agency-build-web | Framework-less web: plain HTML/CSS/JS, Web Components, non-React SPAs |
| jarvis-agency-build-data | SQL migrations, schema, repositories |
| jarvis-agency-build-go | Go services, CLIs, HTTP handlers, libraries |
| jarvis-agency-build-stream | Streaming / data pipelines: Kafka/Flink/Spark/Beam stream processors, ingestion/ETL (delivery-semantics, bounded state, dead-letter) |
| jarvis-agency-build-analytics | Analytical / search / time-series stores: Elasticsearch/OpenSearch, ClickHouse, data lakes (mappings, ILM/retention, bounded queries) |
| jarvis-agency-build-detection | Detection-as-code: Sigma/YARA/Suricata/correlation rules, ATT&CK-mapped, fires-on-malicious/silent-on-benign corpus |
| jarvis-agency-build-agent | Agentic / LLM-application: agent orchestration, tool-use, RAG, eval harnesses, guardrails |
| jarvis-agency-build-integration | Third-party connectors + SOAR playbooks: resilient normalized connectors, idempotent bounded workflows |
| jarvis-agency-build-infra | Infrastructure / platform: Terraform/OpenTofu, Kubernetes/Helm, CI/CD (least-privilege, plan+policy-checked, never applies) |
| jarvis-agency-build-docs | Documentation only — the docs tier: README, guides, wording; claims verified against the source; single adversarial content gate |
| jarvis-agency-build-native | C / C++ / Rust kernel modules, drivers, agents (the EDR/sensor sharp end) |
| jarvis-agency-build-ios | Swift / SwiftUI / UIKit apps |
| jarvis-agency-build-ml | Python training and evaluation pipelines |

### Governance (the checks that let you stop inspecting everything)

| Skill | What it gates |
|---|---|
| jarvis-agency-critique-acceptance | AC quality, Backlog to Refined |
| jarvis-agency-verify-artifact | The upstream artifacts (brief, research, PRD, design, architecture, codebase digest) |
| jarvis-agency-review-code | Code review at In Review |
| jarvis-agency-run-tests | Independent test re-run and coverage against the coverage policy at In Review |
| jarvis-agency-redteam-security | Adversarial security at In Review |
| jarvis-agency-qa | Functional and exploratory QA on the running product — at epic completion, and per story when the story is independently runnable. Files a Bug per defect. Advisory. |
| jarvis-agency-perf | Load and stress testing against SLOs at epic completion on a representative non-prod env. Files a Bug per breach. Advisory. |
| jarvis-agency-verify-detection | Detection efficacy at In Review: replays the attack corpus + evasion variants against a detection rule — the fourth RC gate for a `detection` story (does it actually catch the attack, silent on benign, ATT&CK-honest); epic-level coverage reporter. |
| jarvis-agency-audit | On-demand whole-product reality audit: hunts placeholders, stubs, and scaffolding, and cross-checks claims against reality across every stack. Files a Bug per gap. Founder- or PM-invoked, not tied to a story. |
| jarvis-agency-watch-cost | Cost and token guardrail; parks the run at the budget cap, never blocks RC |
| jarvis-agency-retro | The learning organ: after an epic closes past your GA, it harvests the run — what bounced and why, what each verifier caught, cost vs budget — into a Run Report on the epic, and where a pattern repeats it drafts improvement proposals **you** approve. It never edits a skill, never re-grades, never gates. Every run makes the next one better. |

---

## 6. The loop, end to end

```
(chat) capture ─▶ creates an Epic or a Bug          (optional) PM discovery ─▶ PRFAQ (vault) ─▶ capture

Intent (Epic) ─▶ intake ─▶ [brief verified by an independent agent] ─▶ YOU APPROVE
   └▶ per epic: research ─▶ architect ─▶ PRD + stories + AC ─▶ design   (each artifact verified; research/architect only when triggered)
      └▶ per story: Backlog ─▶ (AC critic) ─▶ Refined ─▶ snapshot ─▶ In Progress
            └▶ producer builds + pre-flights ─▶ In Review ─▶ (review-code + run-tests + redteam-security)
                  └▶ RC ─▶ [epic done: QA + perf + PM acceptance, all advisory] ─▶ HUMAN SIGNS GA ─▶ Done

Bug ─▶ triage-bug ─▶ YOU CONFIRM FIX SCOPE ─▶ producer (bug mode) ─▶ In Review ─▶ RC ─▶ HUMAN SIGNS GA
```

A failing verifier bounces the story back to In Progress. RC requires every verifier verdict to
pass and the live acceptance criteria to still equal the frozen snapshot. QA, performance, and PM
acceptance run at epic completion; they file Bugs and feed your GA decision, but they do not gate RC.
The whole-product audit is on-demand — you or the PM invoke it when you want a reality check across
the product.

A story cannot bounce forever. The orchestrator tracks a verification-round count on the Jira issue.
Only a producer-attributable failure counts; an acceptance-criteria edit you make routes to Refined,
re-snapshots, and resets the count. After three producer failures on the same story the orchestrator
parks it: it transitions the story to Blocked, flags your queue, and writes the consolidated findings
and round history. You clear a parked story by choice, to Refined to re-scope or to Rejected. It is
never auto-returned. Separately, the cost watcher parks the whole run (without a status change) if
cumulative spend passes the per-run budget cap. Both are soft controls bounded by agent compliance.
The one hard backstop for a runaway run is the account spend limit, which is yours to set.

The core rule, enforced by run-ids: **a producer never verifies its own work.** Every verifier is a
different identity in a fresh context. In the first live run this caught a vacuous test and a
flaky-gate regression that the producer and two other lenses read past.

---

## 7. Producer coverage and maturity

The workbench builds only what it has a producer for. Anything else is flagged and routed to a human.

| Stack | Producer | Maturity |
|---|---|---|
| backend / api, frontend, data | build-backend / build-frontend / build-data | **PROVEN** — frontend exercised end to end on a real repo (the first live slices) |
| web (framework-less) | build-web | **GENERAL / UNVALIDATED** — gated, not yet on a real repo |
| go | build-go | **GENERAL / UNVALIDATED** — gated, not yet on a real repo |
| native (C/C++/Rust) | build-native | **GENERAL / UNVALIDATED** — gated, not yet on a real repo |
| ios (Swift) | build-ios | **GENERAL / UNVALIDATED** — gated, not yet on a real repo |
| ml (Python) | build-ml | **GENERAL / UNVALIDATED** — gated, not yet on a real repo |
| docs (documentation-only) | build-docs | **GENERAL / UNVALIDATED** — single-gate docs tier, not yet on a real repo |
| anything else (streaming, Android, ...) | none yet | **NEEDS-PRODUCER** — routed to a human |

`covered` means the workbench can take the work on and gate it with the verification shape its tier defines — the full trio for every code stack, the single adversarial content gate for docs. It does not
mean production-proven. The web, Go, native, iOS, and ML producers encode general stack conventions
and need tuning against the first real project in their stack before you rely on them for regulated GA.

The front door (capture), the discovery and acceptance role (PM), the bug path (triage-bug), and the
epic-level governance (QA, performance, audit) are all **designed, gated, and reviewed, but not yet
validated on a real run.** Their first real exercise on a real epic is the next step, not
more building.

---

## 8. The GA control

GA sign-off is human-only. The agents stop at RC.

- The agent runs Jira as a dedicated agent account, distinct from your human account.
- A Jira Automation rule reverts any GA transition performed by the agent account back to RC and
  flags it. You verified this live.
- The authorized signer is your human account. When you sign GA, sign as yourself, not the agent.

This is a revert-after compensating control, not a hard pre-block. A hard pre-block needs a
company-managed Jira project and is not worth it until you have real GA traffic. On the **GitHub**
side the equivalent control is now a hard pre-block: the protection rulesets refuse direct pushes to
`main` and refuse merging a PR whose CI is red — verified empirically (a probe push died with GH013).

---

## 9. What is next

The first live slices shipped on a real repo (an IP-allowlist screen and a follow-on, taken to
merged, GA-signed PRs), so the web/back-end producers are proven and the loop is validated end to
end. Everything added since — the capture front door, the PM role at both ends, the bug path, the
web, Go, and docs producers, the docs tier, the model tiering, the QA / performance / audit
governance line, the wave dispatch, the retro learning loop, and the speed disciplines (producer
pre-flight, upstream skip rules, cap 4) — is designed, gated, and reviewed but **unvalidated.** The single highest-value next move is to point the agency at a real
epic, ideally starting at the PM discovery door, and tune against what breaks — not to
build more. The rest is operational and yours: the account spend cap, and the headless credentials
if you move to a cloud Routine.

## 10. Rebuilding the internal config on a fresh machine (bus-factor bootstrap)

The whole agency routes through one file that is deliberately **never committed**:
`skills/jarvis-agency-jira-contract/reference/_internal/jira-config-internal.md` (gitignored via
`**/_internal/`). If the machine holding it is lost, this section is the recovery map. Keep the
file in whatever personal backup you already run (Time Machine or equivalent) — that is the whole
backup policy; an encrypted in-repo copy was considered and rejected (it would put exactly the
content the secret scanner exists to keep out back into the repo).

**What the file holds, in four kinds:**

1. **Instance wiring (regenerable by reading the live instance):** the Atlassian site/cloud id,
   the MCP tool mapping, project keys/ids, Story/Epic type ids, status/transition-id tables. A
   fresh session with the Atlassian MCP connected can re-derive all of it — this is exactly what
   `jarvis-agency-onboard` does; re-onboarding each project rebuilds its registry row from live
   reads (never placeholders).
2. **Identity decisions (re-record, do not guess):** which account is the dedicated AI Agent and
   which human account is the authorized GA signer. Re-record from the live Jira user list; the
   GA-guard automation rule in each project names the agent account and can be read in the Jira UI
   as a cross-check.
3. **Policy decisions (founder-set; re-record from this guide and the contract):** cost budgets
   and their band rules (per-label baselines, per-bounce-round adjustment), the max-bounce
   ceiling, wave-dispatch cap and pace default, coverage policy, the runner spend-cap decision
   (subscription plan = the hard bound; REVISIT on API-key billing). Defaults and rationale live
   in the contract body and its references; the config holds the currently-chosen numbers.
4. **History that cannot be regenerated (the real loss in a disaster):** the enforcement-backlog
   table with its per-item status and dated decisions, validation/maturity annotations with their
   epic-key evidence, and lesson notes folded into rows. Mitigation: the load-bearing decisions
   are mirrored in committed surfaces — the contract changelog, `lessons.md`, and the
   the internal fix record — so a rebuild loses convenience, not truth. After any rebuild,
   walk the contract changelog newest-first and re-record still-open backlog items.

**Rebuild order on a fresh machine:** clone the repo → connect the Atlassian MCP and re-auth as
the AI Agent account → run `jarvis-agency-onboard` per project (rebuilds kind 1, validates kind 2)
→ re-record kinds 2–3 from this section's pointers → reconstruct kind 4 from the committed
mirrors. `lint-platform.sh` check 13 goes from self-skipping to active the moment the file exists
again — its pass is the signal the rebuild is structurally complete.
