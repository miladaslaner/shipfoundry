---
type: governance
title: Run counter
updated: 2026-07-21
runs_since_drift_sweep: 0
total_runs: 0
---

# Run counter

Feeds the law's periodic drift sweep: every 10th run, before other work, a light three-way diff
(Jira status+changelog ⇄ working-tree code ⇄ vault).

**Inert in this repo, deliberately.** `jira_project_key` is `UNSET` (see `repo-config.md`), so per
the law both reconciliation triggers are **skipped** — there is no execution ledger to reconcile
against. The platform's ledger is GitHub: branches, PRs, and the CI gate.

The counter is still maintained so the mechanism goes live the moment a Jira key is set, with no
re-bootstrap. Code contradicting a claim remains a hard stop here regardless, wherever code exists.

Increment `total_runs` and `runs_since_drift_sweep` each run; when `runs_since_drift_sweep`
reaches 10, run the sweep before other work and reset it to 0.

Code contradicting a claim remains a hard stop here regardless, wherever code exists.
