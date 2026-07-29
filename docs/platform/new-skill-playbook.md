# New-skill playbook

The decision flow for adding a skill. Operating-mode Category A. Most of the *how* lives in [CLAUDE.md](../../CLAUDE.md); this doc is the *decision sequence* specific to net-new skills.

## Before building: justify it

1. **Why a new skill, not an extension?** Identify the closest existing skill. If the new behaviour is a variant of an existing skill's job, extend it. Reuse before creating.
2. **Where does it belong?** Decide its class — foundation / orchestrator / registered pattern / standalone (see [`skill-taxonomy.md`](./skill-taxonomy.md)). The class determines everything below.
3. **Does its trigger collide?** Check the description against existing trigger phrases for ambiguity (taxonomy specificity rule).

## Building: reuse established patterns

- Mirror an existing same-class skill's structure (frontmatter, reference layout, eval shape). `./new-skill.sh <name> <class>` scaffolds the skeleton correct-by-construction.
- If it's a **registered pattern** orchestrated by a dispatcher, register it with that dispatcher per the dispatcher's own convention.
- Write **3 eval scenarios first** (Anthropic best-practice: evaluation-driven development).

## Closing out: the new-skill gate is the edit gate PLUS one thing

Run the standard close-out (`./lint-platform.sh`), then do the thing an *edit* doesn't trigger but a *new skill* does:

- **Update [CLAUDE.md](../../CLAUDE.md)** — skill counts, structure tree, "What this repo contains" inventory.

A new skill the project's own context file doesn't know about is under-counted and under-maintained from day one.
