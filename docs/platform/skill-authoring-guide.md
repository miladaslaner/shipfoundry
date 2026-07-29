# Skill authoring guide

> **Pointer doc.** The canonical authoring rules live in [CLAUDE.md](../../CLAUDE.md) and the `superpowers:writing-skills` skill. This doc deliberately does not restate them — duplicated guidance drifts. It only orients you to where the rules are.

## Where the rules live

| Topic | Canonical source |
|---|---|
| Frontmatter shape, `version:`, changelog | [CLAUDE.md](../../CLAUDE.md) "Maintenance conventions" |
| The Anthropic best practices we follow (500-line cap, progressive disclosure, TOC, `<details>` for time-sensitive content, evals, description discipline, concision) | [CLAUDE.md](../../CLAUDE.md) "Anthropic best practices we follow" |
| Description field discipline (third person, "Use when", "Does not trigger") | [CLAUDE.md](../../CLAUDE.md) + [`skill-taxonomy.md`](./skill-taxonomy.md) |
| claude.ai uploader constraints (1024 chars, no angle-brackets, no brackets in filenames) | [CLAUDE.md](../../CLAUDE.md) "Claude.ai org-upload constraints" |
| **Writing a constraint** (state the permitted cases, not only the forbidden one; inherit-and-cite rather than restate a prohibition) | [CLAUDE.md](../../CLAUDE.md) "Anthropic best practices we follow" #8, and the 2026-07-21 entry in [lessons.md](../../lessons.md) for the seven-instance failure that produced it |
| **Probing for the stall class** (the two-scenario over-refusal / over-rejection template, run per touched skill) | [`evaluation-strategy.md`](./evaluation-strategy.md) "The stall probe" |
| The deep reference | `superpowers:writing-skills` skill + Anthropic's skill-authoring best-practices doc |

## Before you say "done"

Run the executable gate:

```bash
./lint-platform.sh <skill-name>   # or no arg for the whole platform
```

It enforces the close-out checklist. See [`governance-model.md`](./governance-model.md) for what each check means.
