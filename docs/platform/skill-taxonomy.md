# Skill taxonomy

The naming, classification, and trigger conventions that keep the platform discoverable as it grows toward hundreds of skills.

## Naming convention

```
jarvis-<workbench>-<verb-noun>
```

- `jarvis-` — fixed prefix (the platform namespace; rename it to your own org's namespace when you adopt this template).
- `<workbench>` — the themed group a skill belongs to (e.g. a product area or a discipline). Foundation/orchestrator skills that span workbenches may omit it.
- `<verb-noun>` — what the skill *does*: `audit-page`, `publish-mr`, `triage-bug`. Prefer a verb; it disambiguates from the artifact it produces.

A rename is a **breaking change** for claude.ai org uploads (treated as a new skill, not an update) — rename atomically across the whole repo and grep-verify before declaring it done.

## Skill classes

| Class | Definition | Examples |
|---|---|---|
| **Foundation** | Applies implicitly under other skills; defines shared rules (voice, conventions, guardrails) | a brand/voice skill; a workbench style guide |
| **Orchestrator** | Routes or fans out to other skills (a dispatcher, a review fan-out) | a ticket-queue dispatcher; a "review all" fan-out |
| **Registered pattern** | A domain skill registered with a dispatcher, which routes work to it | the worker skills in an automated loop |
| **Standalone** | A domain skill invoked directly, not via a dispatcher | most single-purpose skills |

Critical distinction: **"in a workbench folder" ≠ "registered pattern."** A foundation, an orchestrator, and a standalone all live in the same `skills/` tree but play different roles. Decide the class first — it determines eval priority and whether the skill registers with a dispatcher.

## Trigger-phrase conventions

The `description` field is the single highest-leverage discovery signal. Rules (enforced by lint checks 4+5):

- Third person, "Use when …" opening. Describe **triggers and symptoms**, never the workflow steps.
- ≤ 1024 chars; no angle-bracket placeholders (use `{braces}`).
- Include an explicit **"Does not trigger"** clause to fence off neighbours.

### Specificity rule (prevents mis-routing)

Trigger phrases must be specific enough that no two skills compete. Conventions to preserve separation:

- **Role-scoped or variant skills** carry the distinguishing token in the phrase (e.g. "review as **security**"), never a bare generic ("review this").
- **Sequential pipeline skills** are gated by status, not just phrase (you can't "publish" before the artifact exists) — the gate is a second disambiguator.
- A new skill whose triggers could overlap an existing one must narrow its phrasing **before** merge. `lint-platform.sh` **check 9** enforces this: it extracts each description's "Triggers on …" phrases and warns on any exact phrase shared by ≥2 skills. WARN-level (an overlap is occasionally intentional for closely-related skills), promoted to failure under `--strict`.

## Adding to the taxonomy

When a new skill or workbench is proposed, decide its class first. See [`new-skill-playbook.md`](./new-skill-playbook.md) and [`workbench-creation-playbook.md`](./workbench-creation-playbook.md).
