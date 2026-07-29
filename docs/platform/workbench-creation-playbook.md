# Workbench-creation playbook

When to create a new workbench, and what must be decided before any implementation. Operating-mode Category C. **Do not start building a workbench from a one-line request** — produce a full architecture proposal first.

## First: is a new workbench justified?

A workbench is a heavyweight unit (its own foundation skill, optional orchestration, governance surface, dist set). Default answer is **extend an existing workbench**. A new one is justified only when:

- The audience and lifecycle are genuinely distinct from the existing workbenches (different owners, different artifacts, different platforms).
- The skills would not naturally trigger alongside the existing skills (no shared trigger space).
- The maintenance burden of a separate governance surface is worth the separation.

If the work is a few skills that share an existing workbench's conventions, it's an extension, not a workbench.

## Then: the architecture proposal (before implementation)

Decide and document all of:

| Dimension | Question |
|---|---|
| **Taxonomy** | Naming prefix; skill classes; which is the foundation skill |
| **Orchestration** | Does it get its own dispatcher, or none? |
| **Governance** | Which lint invariants apply; any new ones; does `lint-platform.sh` need extending? |
| **Evaluation** | Eval coverage plan (foundation-first, per [`evaluation-strategy.md`](./evaluation-strategy.md)) |
| **Distribution** | Dist zip set; any new internal-content exclusions |
| **Maintenance** | Who owns final wording; added burden on the maintainer |

A workbench is just a naming-and-grouping convention plus, usually, a foundation skill that applies implicitly under the others. There is nothing the platform tooling needs beyond the `<prefix>-<workbench>-<verb-noun>` naming and (optionally) a new lint check if the workbench introduces an invariant worth enforcing.
