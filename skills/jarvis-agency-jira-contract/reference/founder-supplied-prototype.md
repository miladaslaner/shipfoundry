# Founder-supplied prototype (design fidelity)

Reference detail for the contract's "Founder-supplied prototype" rule. The founder sometimes builds
a **high-fidelity prototype on a chosen design system first** — in Claude Design or similar — and
expects the agency's build to **match** it. The prototype is a first-class **human-authored** input
(`ARTIFACT-AUTHORED-BY: human`), authoritative for the **visual and design-system layer**. It is
attached to the epic (a `Prototype` reference in the config), and its handling follows three rules:

- **It does not replace intake.** A prototype shows the *look*, not the acceptance criteria, data,
  security, failure modes, or non-happy states. Intake still runs and locks the Requirements Brief;
  the prototype is an authoritative *input* to it, not a substitute.
- **Fidelity to it is an acceptance criterion.** For a UI story with a prototype, "the build matches
  the prototype — its design tokens, components, spacing, and the screens/states it shows" is written
  into the AC by `author-prd` (with the prototype link), gated by review-code, and covered by a
  **visual-regression test** (a screenshot compared to the prototype within tolerance) the test
  verifier re-runs. Match is *structural* — same tokens, components, layout — which a design-system
  prototype makes tractable; the visual-regression test adds the pixel-level check.
- **Design-token authority.** On a **greenfield** product the prototype's design system **becomes**
  the project's design tokens (established from it, recorded as the token-authority decision). On an
  **existing** product the prototype must **reconcile** with the already-hydrated tokens (from the
  codebase digest); if they differ, the design skill **surfaces the conflict to the founder** rather
  than silently overriding either. `jarvis-agency-design` runs its **adopt-and-reproduce** mode: it
  carries the prototype's screens/components as the authoritative Design lane, establishes or
  reconciles the tokens, and fills only the missing states/responsive/accessibility **in the
  prototype's own design language** — it never re-designs or re-tokens a design the founder expects
  reproduced. The design is still verified by `jarvis-agency-verify-artifact` (a distinct identity):
  a happy-path-only prototype is hardened to the full state/a11y bar, not shipped as-is.

The design-token authority decision is recorded in the `DESIGN-TOKEN-AUTHORITY:` marker
(`prototype` / `existing` / `reconciled` / `conflict`); the orchestrator does not build a UI story
while it reads `conflict`. The producer authors the visual-regression test and its baseline from the
prototype; the architect provisions the visual-regression harness as an epic prerequisite.
