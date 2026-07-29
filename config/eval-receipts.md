# Eval receipts — which skill versions the behavioural gate actually replayed

`./eval-runner.sh` is the platform's **behavioural** gate: it replays a skill's
`evaluations/baseline-evals.json` against the model and scores the assertions. It cannot run in
CI — it makes live model calls and costs real money — so nothing could enforce CLAUDE.md's "run
`./eval-runner.sh` if behaviour changed". This file is the enforceable proxy: a **receipt** that a
run happened, at a stated version.

`eval-runner.sh` writes a row here itself, on a **full single-skill run only** (one named skill, no
`--scenario` filter, not `--dry-run`, and at least one scenario actually graded). A run where every
model call was rejected grades nothing and writes nothing — a receipt from a zero-scenario run
would assert an eval that never happened.

**Do not hand-edit a row** except to record a deliberate skip, and then say why in the row.
[`lint-platform.sh`](../lint-platform.sh) check 29 compares each skill's current `version:` against
its receipt: a MINOR or MAJOR bump past the recorded version WARNs (FAIL under `--strict`); a
PATCH-only difference passes.

**What a receipt does *not* mean.** It proves a run was recorded at that version — not that the run
was good, that the scenarios were the right ones, or that the skill is correct. The `Failed` column
is recorded for exactly that reason: several rows below are receipts of runs that *found defects*,
and the fixes those runs prompted bumped the skill past its own receipt. That is the check working,
not a bookkeeping error — re-run the gate rather than editing the number.

**Run values are blanked in the published snapshot.** Each row is the version the runner
ACTUALLY replayed — deliberately *not* the version the skill reached afterwards. Most of these
runs found defects, and the fixes bumped the skill past its own receipt, so check 29 warns on
them. That warning is true: nothing has replayed the fixed versions. Recording the post-fix
version instead would have made the file assert runs that never happened.

| Skill | Version evaluated | Date | Scenarios | Failed |
|---|---|---|---|---|
| jarvis-agency-orchestrate | 0.16.1 | 2026-07-29 | 42 | 11 |
| jarvis-agency-jira-contract | 0.14.0 | — | — | — |
| jarvis-agency-intake | 0.9.1 | — | — | — |
| jarvis-agency-verify-artifact | 0.3.0 | — | — | — |
| jarvis-vault-governance | 1.2.1 | — | — | — |
| jarvis-agency-pm | 0.4.0 | — | — | — |
| jarvis-agency-architect | 0.4.1 | — | — | — |
| jarvis-agency-qa | 0.2.1 | — | — | — |
| jarvis-agency-author-prd | 0.6.1 | — | — | — |
| jarvis-agency-capture | 0.4.0 | — | — | — |
| jarvis-agency-perf | 0.2.1 | — | — | — |
| jarvis-agency-design | 0.2.0 | — | — | — |
| jarvis-agency-critique-acceptance | 0.3.0 | — | — | — |
| jarvis-agency-research | 0.2.0 | — | — | — |

**Known stale despite passing check 29.** These rows are only PATCH-behind their skill, so the
check reads them as current — but the intervening fixes were real behaviour changes that were
under-versioned as patches (see CLAUDE.md maintenance conventions #2). Nothing has replayed the
fixed bodies: `author-prd` `architect` `critique-acceptance` `design` `intake` `jira-contract`
`perf` `pm` `qa` `research` `verify-artifact` `jarvis-vault-governance`. Re-run these first when
the behavioural gate next runs.

**Known-blocked, 2026-07-21.** `jarvis-agency-intake` is at 0.10.0 against a 0.9.1 receipt, so check 29
WARNs — correctly. The front-door boundary change is a real behaviour change, versioned minor as the
sharpened convention requires, and the weekly model-call limit was reached before it could be replayed.
This is the check firing on its first genuine opportunity, not a bookkeeping error. `./run-pending-evals.sh`
clears it. Do not silence it by editing the receipt — the whole point is that the row stays behind until a
run actually happens.
| jarvis-agency-redteam-security | 0.3.0 | 2026-07-29 | 9 | 1 |
| jarvis-agency-review-code | 0.3.0 | 2026-07-29 | 10 | 1 |
| jarvis-agency-build-backend | 0.2.3 | 2026-07-29 | 10 | 3 |
| jarvis-agency-audit | 0.1.4 | 2026-07-29 | 9 | 4 |
| jarvis-agency-build-agent | 0.1.1 | 2026-07-29 | 8 | 3 |
| jarvis-agency-build-analytics | 0.1.1 | 2026-07-29 | 8 | 2 |
| jarvis-agency-build-data | 0.1.6 | 2026-07-29 | 8 | 1 |
| jarvis-agency-build-detection | 0.1.0 | 2026-07-29 | 8 | 1 |
| jarvis-agency-build-docs | 0.1.2 | 2026-07-29 | 7 | 1 |
| jarvis-agency-build-frontend | 0.1.8 | 2026-07-29 | 9 | 2 |
| jarvis-agency-build-go | 0.1.3 | 2026-07-29 | 8 | 4 |
| jarvis-agency-build-infra | 0.1.0 | 2026-07-29 | 8 | 3 |
| jarvis-agency-build-integration | 0.1.1 | 2026-07-29 | 8 | 3 |
| jarvis-agency-build-ios | 0.1.3 | 2026-07-29 | 9 | 2 |
| jarvis-agency-build-ml | 0.1.3 | 2026-07-29 | 9 | 1 |
| jarvis-agency-build-native | 0.1.4 | 2026-07-29 | 9 | 1 |
| jarvis-agency-build-stream | 0.1.0 | 2026-07-29 | 8 | 3 |
| jarvis-agency-build-web | 0.1.5 | 2026-07-29 | 9 | 4 |
| jarvis-agency-hydrate | 0.1.4 | 2026-07-29 | 6 | 2 |
| jarvis-agency-onboard | 0.3.1 | 2026-07-29 | 10 | 0 |
| jarvis-agency-retro | 0.1.3 | 2026-07-29 | 8 | 1 |
| jarvis-agency-run-tests | 0.3.0 | 2026-07-29 | 12 | 2 |
| jarvis-agency-triage-bug | 0.2.1 | 2026-07-29 | 6 | 0 |
| jarvis-agency-verify-detection | 0.1.0 | 2026-07-29 | 8 | 0 |
| jarvis-agency-watch-cost | 0.2.1 | 2026-07-29 | 7 | 0 |
| jarvis-example | 1.0.2 | 2026-07-29 | 5 | 3 |
