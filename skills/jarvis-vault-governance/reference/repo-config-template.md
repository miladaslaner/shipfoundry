---
type: governance
title: Repo governance config (local slots)
law_version: {{LAW_VERSION}}
updated: {{TODAY}}
vault_root: {{VAULT_ROOT}}
jira_project_key: {{JIRA_PROJECT_KEY}}
quarantine_list: {{QUARANTINE_LIST}}
---

# What this file is

The **only** governance file a repo owns. It holds the three local slots the universal law
is generated against. The law itself — `{{VAULT_ROOT}}/_governance/SOURCE-OF-TRUTH.md` — is a
read-only mirror and is never edited here.

## Slots

| Slot | Meaning | Default when unknown |
|---|---|---|
| `vault_root` | Path to this repo's vault (the intent store). | `./docs` |
| `jira_project_key` | This repo's Jira project key (execution ledger). | `UNSET` — surface a request in the run summary; never guess |
| `quarantine_list` | Items excluded from action/scope (reality-drift findings, known-broken work). | `[]` |

## Rules

- Editing a slot changes only what the mirror is generated **against**, never what the law says.
- `jira_project_key: UNSET` is a legal state: governance still applies, Jira writes are blocked
  until the founder supplies the key.
- Items enter `quarantine_list` from reality drift (code contradicts a claim) and leave it only
  by founder decision.
