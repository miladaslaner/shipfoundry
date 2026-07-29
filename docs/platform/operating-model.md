# Operating model — how to work on this platform

This is the **repo-resident operating contract** for shipfoundry. It lives here so any contributor — or any fresh Claude session — honours it without prior context.

Treat this repo as a **long-lived product**, not a pile of prompts. Optimise for platform integrity over local cleverness. The reflexes:

> Read first · Understand first · Reuse before creating · Simplify before adding · Propose before implementing · Validate before claiming done — prove it works (run it; diff behaviour against `main` when relevant); the bar is "would a staff engineer approve this?"

## The four work types

Almost everything is one of four. Each has a **process** (the playbook you follow) and a **gate** (the executable proof it's honoured). Do not skip either. **The fastest way to start any of these correctly is the matching slash command** — `/new-skill` (A), `/improve-skill` (B), `/new-workbench` (C) in `.claude/commands/` — which loads this contract + the right playbook automatically.

### A — New skill
1. **Justify it.** Why a new skill, not an extension of the closest existing one? Reuse before creating.
2. Decide its **class** (foundation / orchestrator / registered pattern / standalone) — see [`skill-taxonomy.md`](./skill-taxonomy.md). Class determines eval priority and dispatcher registration.
3. Follow [`new-skill-playbook.md`](./new-skill-playbook.md). `./new-skill.sh <name> <class>` scaffolds the skeleton correct-by-construction.
4. Write **3 eval scenarios** before extensive docs.
5. **Gate:** `./lint-platform.sh <skill>` exits 0 · `./build-dist.sh <skill>` · update CLAUDE.md counts/tree.

### B — Improve an existing skill
1. Read the whole skill — SKILL.md, every `reference/`, the `evaluations/`, and the relevant slice of [`../../lessons.md`](../../lessons.md).
2. Assess blast radius (shared convention? cited failure-mode ID? foundation skill? ≥3 skills?). If yes → plan first (CLAUDE.md "When to plan first").
3. Follow [`skill-optimization-playbook.md`](./skill-optimization-playbook.md): minimal-impact change → version bump (semver) + changelog + eval update + `./build-dist.sh <skill>`.
4. **Gate:** `./lint-platform.sh <skill>` exits 0; run `./eval-runner.sh <skill>` if behaviour changed.

### C — New workbench
1. **Do not start building.** Justify the workbench (default = extend an existing one).
2. Produce a full architecture proposal first — taxonomy, orchestration, governance, evaluation, distribution, maintenance — per [`workbench-creation-playbook.md`](./workbench-creation-playbook.md).
3. **Gate:** extend `lint-platform.sh` if the workbench introduces a new invariant; add the foundation skill's eval.

### D — Platform improvement
1. Think platform-first; avoid local fixes that raise complexity.
2. Change the **executable check first**, then the doc that explains *why* — see [`governance-model.md`](./governance-model.md).
3. **Gate:** `./lint-platform.sh --strict` exits 0.

## The gates (what enforces the above)

| Tool | Enforces |
|---|---|
| `lint-platform.sh` | **structural** invariants (36 checks) — run before declaring any edit done; `--strict` for CI; `--versions` for the authoritative version table |
| `eval-runner.sh` | **behavioural** baselines — replays each skill's `baseline-evals.json` against the model (run outside a Claude Code session) |
| `build-dist.sh` | builds dist zips from each `.distignore` (single source) + regenerates `dist/MANIFEST.json` |
| `install-hooks.sh` / `hooks/` / `ci/` | activate the lint as a git pre-commit hook + CI once the repo is under git |

## Required output for any non-trivial change

**Before:** Findings · Assumptions · Risks · Proposed approach · Affected files · Validation plan.
**After:** Summary · Assumptions · Risks · Files touched · Validation · Versioning · Documentation impact · Lessons (append to `lessons.md` if cross-cutting).

## Decisions made in conversation (the unclosed gap)

Vault-first closed *"a decision born in a Jira comment"*. It did **not** close **a decision born in
chat and never written anywhere**. That hole is wider than the one that was closed, and nothing
mechanical detects it: no check can see a decision that does not exist in any file.

**The discipline.** Before a working session ends, every decision reached in it is either

1. written as a stamped vault note (`authored_by`, `decision_type`, `review`), or
2. **named in the session's closing summary as undocumented**, with what it was.

Option 2 is the point. The failure mode is not "we didn't write it down" — it is "we didn't write it
down *and nobody noticed*". An explicit list of undocumented decisions is a bad outcome you can act
on; silence is a bad outcome you cannot.

**Honest standing: this is compliance, not enforcement**, and weaker than every other rule in this
document. A check can verify a note is well-formed (lint check 23) or that a mirror is unedited
(check 21). Nothing can verify that a conversation produced no unrecorded decision, because the
evidence of the omission is the absence of evidence.

Two things follow. Treat a long session as the risk case — the more decided in one sitting, the more
that can evaporate. And when a decision changes something already written, prefer amending the note
in the same breath as agreeing it: the gap opens in the delay, not in the disagreement.

Promoting this to the universal law (`jarvis-vault-governance`) is a founder decision, since the law
is founder-owned and the bar for it is a rule worth applying to every repo, not only this one.

## The meta-principle

Every recurring incident traces to an invariant enforced by memory instead of by a command. So: **when you catch yourself writing "remember to also update X", build the check instead.** Documentation explains; the gate enforces.
