---
type: governance
title: Repo governance config (local slots)
law_version: 1.2.1
updated: 2026-07-21
vault_root: ./docs
jira_project_key: UNSET
quarantine_list: []
---

# What this file is

The **only** governance file a repo owns. It holds the three local slots the universal law
is generated against. The law itself — `./docs/_governance/SOURCE-OF-TRUTH.md` — is a
read-only mirror and is never edited here.

## Slots

| Slot | Meaning | Default when unknown |
|---|---|---|
| `vault_root` | Path to this repo's vault (the intent store). | `./docs` |
| `jira_project_key` | This repo's Jira project key (execution ledger). | `UNSET` — surface a request in the run summary; never guess |
| `quarantine_list` | Items excluded from action/scope (reality-drift findings, known-broken work). | `[]` |

## Rules

- Editing a slot changes only what the mirror is generated **against**, never what the law says.
- `jira_project_key: UNSET` is a legal state: governance still applies in full, but the repo
  performs no Jira writes and skips both reconciliation triggers until the founder supplies a key.
  **This repo IS in that state, deliberately.** The platform's execution ledger is GitHub — branches,
  PRs and the CI gate — not a Jira project. It is fully governed (intent in the vault, provenance
  stamps, pending-intent-inert); it simply performs no Jira writes and skips both reconciliation
  triggers, because there is no execution ledger here to reconcile against.

  Set to `UNSET` on 2026-07-21. It previously named another repo's project, and two repos claiming
  one ledger is a real conflict under this law: the drift sweep diffs Jira against the
  **working-tree code**, so whichever repo ran it would compare the wrong checkout and report
  phantom reality-drift.
- Items enter `quarantine_list` from reality drift (code contradicts a claim) and leave it only
  by founder decision.
