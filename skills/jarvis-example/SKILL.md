---
name: jarvis-example
description: Worked reference example for the shipfoundry skills platform. Use when you want to see how a skill in this repo is structured before authoring your own — the frontmatter shape, the SKILL.md body conventions, progressive disclosure into reference/ files, the evaluations stub, and the .distignore that keeps internal-only content out of the distribution bundle. Copy this folder (or run ./new-skill.sh) as the starting point for a new skill. Triggers on phrases like "show me the example skill", "how is a shipfoundry skill structured", "scaffold a skill like the example". Does not trigger for real domain work — replace this skill with your own content before shipping.
version: 1.0.2
owner: Platform maintainer
updated: 2026-07-29
source: Reference example shipped with the shipfoundry starter kit.
changelog: |
  1.0.2 — Description says "the shipfoundry skills platform" rather than bare "shipfoundry", restoring an explicit skill-authoring cue as a common noun. This was written to test whether dropping that cue in 1.0.1 explained two description-only selection evals failing; re-running showed it did not — the marginal justification assertions shuffle between runs (005 recovered and 003 broke with nothing relevant changed between them). Kept for clarity, NOT as a fix. The one reproducible failure is 002, which fails in every run and predates both versions.
  1.0.1 — Platform name in the description and source updated to shipfoundry; the example-skill trigger phrase follows. No change to what the skill demonstrates.
  1.0.0 — Initial example skill shipped with the starter kit. Demonstrates frontmatter, body conventions, a reference file with a table of contents, the evaluations stub, and internal-content handling via .distignore.
---

# jarvis-example

This is a worked example skill. It exists to show the structure every skill in this
repo follows so you can author your own correctly by construction. Replace it (or copy
it) when you build something real.

## What a skill is

A skill is a folder under `skills/` containing a `SKILL.md` and any supporting files.
The `SKILL.md` frontmatter is the discovery signal — Claude reads the `description` to
decide whether the skill applies. The body is loaded into context when the skill fires,
so every line competes with the conversation; keep it tight.

## Authoring conventions (enforced by lint-platform.sh)

- **Description** — third person, opens with "Use when …", describes *triggers and
  symptoms* (not the step-by-step workflow), and includes a "Does not trigger" clause.
  Max 1024 characters; use `{braces}` for placeholders, never angle-bracket tags (the
  uploader parses `<Product>` as XML and rejects the bundle).
- **Body under 500 lines** — hard cap; soft target 380–450. Split heavy sections into
  `reference/<name>.md` and link to them. See [the example reference](reference/example-reference.md).
- **Progressive disclosure, one level deep** — `SKILL.md` links to `reference/` files; a
  reference file must NOT link to another reference file.
- **Reference files over 100 lines need a table of contents** at the top.
- **Frontmatter is strict YAML** — quote any scalar containing a colon-space.

## When to use it

Read this skill when you are about to write a new skill and want a concrete template.
For the full process, see [the new-skill playbook](../../docs/platform/new-skill-playbook.md)
or run `./new-skill.sh jarvis-<workbench>-<verb-noun>`.

## Internal-only content

Anything that must never leave the building goes in a file named `*-internal.md` or a
path containing `_internal`, and is listed in the skill's `.distignore`. This skill ships
`reference/notes-internal.md` as a demonstration — `build-dist.sh` excludes it and
`lint-platform.sh` fails the build if it ever leaks into a dist zip.

## Files in this skill

- `SKILL.md` (this file)
- `reference/example-reference.md` — a reference file with a table of contents
- `reference/notes-internal.md` — internal-only, excluded from the dist bundle
- `evaluations/baseline-evals.json` — three baseline scenarios
- `.distignore` — the single source of distribution exclusions for this skill
