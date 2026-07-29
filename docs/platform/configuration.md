# Configuration reference

Every setting the agency reads, in one place. Grouped by scope: **instance** (once, shared),
**per project** (once per product), and **per run** (chosen when you start the loop).

Values you set live in two files: the **vault governance slots** (`{vault_root}/_governance/repo-config.md`,
committed to your repo) and the **internal config** (`skills/jarvis-agency-jira-contract/reference/_internal/`,
**gitignored — instance bindings never enter version control**). `jarvis-agency-onboard` writes the
internal config for you; you rarely edit it by hand.

> **Every value carries a rationale.** A setting recorded without one is treated as a defect —
> a stale value must never be mistaken for an intentional one.

## Instance — set once, shared by every project

| Setting | What it is | Where |
|---|---|---|
| Atlassian cloud id | Your Jira site | internal config |
| Agent account id | The **dedicated** account the agency acts as. Distinct from your human account — the GA guard identifies the agent by actor, so a shared account defeats it. | internal config |
| Human signer account id | The account whose GA transitions are legitimate | internal config |
| MCP tool names | Which Atlassian/GitHub/Chrome tools are wired | internal config |

## Per project — one row per product

Written by `jarvis-agency-onboard` during setup; a project is not handed to the loop until its row is green.

| Setting | Values | Default | Notes |
|---|---|---|---|
| Project key / id | your Jira project | — | one project per product |
| Epic type id · Story type id | read live from the project | — | never guessed; read from Jira |
| Paired repo | `github.com/<org>/<repo>` | — | where producers open PRs |
| Configured | date + confirmation | — | set only when every precondition validates |
| Hydrated | anchor commit, or `n/a` | `n/a` | set when `jarvis-agency-hydrate` has produced a verified codebase digest; `n/a` for greenfield |
| `ga-granularity` | `epic` \| `story` | **`epic`** | where the human signature sits — see below |
| `CI: {check-name}` | a check name, or `CI: none` | — | read live, never guessed. The orchestrator's pre-trio CI gate keys on it; `CI: none` is a recorded gap, not a failure |
| Status mapping | the nine canonical status names → ids | — | names matched literally (`RC`, not `Release Candidate`) |
| Standing grants | e.g. `CAPTURE-AUTO-CREATE`, `BUG-FIX-DELEGATED-PROCEED` | none | opt-in per project; each pre-authorizes a *class* of action, never a specific item |

### `ga-granularity` — where the human signs

- **`epic` (default)** — one PRFAQ, one epic, one signature. The founder validates a working
  capability, not a code slice, and the founder-grade evidence (QA on the running product, perf
  vs SLOs, PM acceptance) already lands at epic completion.
- **`story`** — every story takes its own signature. Opt in deliberately, with a dated rationale.
- **Severity carve-out, regardless of mode:** security, auth, tenant-boundary, data-migration and
  payment surfaces always take a per-story signature.
- **In-flight epics are never silently re-moded** — an epic keeps the mode it started under.

Full rules: [ga-granularity.md](../../skills/jarvis-agency-jira-contract/reference/ga-granularity.md)

## Vault governance slots

In `{vault_root}/_governance/repo-config.md`, committed to your product repo.

| Slot | What it is | Default |
|---|---|---|
| `vault_root` | Where intent notes live | `./docs` |
| `jira_project_key` | This repo's Jira project, or `UNSET` | — |
| `quarantine_list` | Items parked by reality drift (code contradicts a claim); leave only by founder decision | empty |

`UNSET` is legal: the repo stays fully governed (intent, provenance, pending-intent-inert) but
performs no Jira writes and skips both reconciliation triggers.

## Per run — chosen when you start the loop

| Setting | Values | Default | Effect |
|---|---|---|---|
| pace | `fast` \| `thorough` | **`fast`** | `fast` lets a producer fan out sub-implementers across ≥3 independent file-units. `thorough` is the kill-switch for every speed feature: producers build inline **and** the wave concurrency cap drops to 1 |
| concurrency cap | integer | **4** units | how many units dispatch at once; `thorough` forces 1 |
| Cost budgets | warn / cap, per story and per run | see cost-metering | the watcher classifies `within` / `warn` / `over`; `over` parks the run |

> A per-run budget is a **soft** brake — real, but compliance-level. The one hard limit a
> misbehaving loop cannot talk past is your **Anthropic account spend limit**. Set it before
> leaving a loop unattended.

## Derived, not configured

These are decided per unit rather than set by you:

| Thing | How it's chosen |
|---|---|
| Work tier — `docs` \| `small` \| `feature` \| `product` | `intake` picks it from the ask's altitude; it drives which upstream stages run and which verifiers gate |
| Producer routing | the stack label on the story → the producer registry ([agency-registry.md](../../config/agency-registry.md)) |
| Model tier — strongest \| mid \| cheap | per role: judgment and adversarial work run strongest, mechanical work cheap, no gate below mid |

## Platform defaults under gate

Three canonical values are registered in [`config/stated-defaults.md`](../../config/stated-defaults.md)
and enforced by lint check 23 — any doc that contradicts one fails the build:
`ga-granularity` · `prfaq-owner` · `review-states`.

See also: [operator's guide](../jarvis-agency-operator-guide.md) ·
[cost metering](cost-metering.md) · [governance model](governance-model.md)
