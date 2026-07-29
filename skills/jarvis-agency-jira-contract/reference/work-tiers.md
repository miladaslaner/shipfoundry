# Work tiers — the altitude-aware pipeline matrix

The tier governs how much ceremony runs. Intake classifies (capture pre-classifies an obvious docs
ask), records the `TIER:` marker, and the founder confirms or overrides at the approval gate.

## Contents

- [The four tiers](#the-four-tiers) — the ceremony matrix
- [Cross-epic sequencing](#cross-epic-sequencing-product-tier) — product tier: `Blocks` links + phases, founder-approved order
- [Per-child-epic tiers](#per-child-epic-tiers-product-decomposition) — each child epic carries its own tier; fallback + the one-time backfill
- [Upstream skip rules](#upstream-skip-rules-by-the-units-governing-tier) — when research/architect run at all, and who writes the one-liner when they don't
- [Producer pre-flight](#producer-pre-flight-every-code-tier) — repo gates pass before any PR opens
- [The docs tier](#the-docs-tier) — prose-only pipeline, one gate
- [A documentation defect is not a Bug](#a-documentation-defect-is-not-a-bug)
- [Below the floor](#below-the-floor-not-every-ask-should-become-an-issue)
- [Mid-epic scope change](#mid-epic-scope-change-cut-added-or-neither) — cut supersedes, added gets its own PRFAQ, AC edits are not scope changes
- [Never cut, at any tier](#never-cut-at-any-tier) · [The honesty guard](#the-honesty-guard)

## The four tiers

| Stage | **docs** (prose-only) | **small** (1–2 stories, well-understood) | **feature** (an epic) | **product** (multiple epics) |
|---|---|---|---|---|
| Working-Backwards press release + FAQ | skip | skip | short | full |
| 12-dimension GA-readiness checklist | skip (one-line intent lock) | relevant subset, terse | full | full |
| First-principles register | skip | skip | yes | full |
| Research | skip | skip unless a real unknown | only for unknowns the repo cannot answer (skip rules below) | yes |
| Architect | skip | skip, or a one-line "fits the existing architecture" from the digest | only if genuinely cross-cutting (skip rules below) | yes |
| PRD | skip (AC only) | folded into the brief (no separate heavy PRD) | yes | per epic |
| Decomposition | 1 story | 1–2 stories | as needed | epics → stories |
| Design | skip | only if the story has a UI | if UI | if UI |
| Brief verification (`verify-artifact`) | skip (the AC critic is the upstream gate) | **light** (concrete + key unknowns covered; not failed for lacking a press release) | full bar | full bar |
| Producer pre-flight (repo gates before the PR) | n/a (prose has no repo gates) | required | required | required |
| In Review verification | **one gate**: `review-code`, docs mode | the three-verifier trio | the trio | the trio |

## Cross-epic sequencing (product tier)

A `product` decomposes into child Epics that rarely ship in an arbitrary order — the console
consumes the backend's API, the rules engine consumes ingestion. So at `product` tier intake
also **sequences** the set it decomposes. **UNVALIDATED until a multi-epic product-tier run
exercises the sequencing.**

- **Dependencies are native issue links.** A capability-level dependency (epic B consumes a surface
  epic A ships) is recorded as a native **`Blocks` / `is blocked by`** link between the child Epics —
  the same rule as the parent field: a structural relation uses a native Jira structure, never
  free-text. Each link carries a one-line justification in the Decomposition comment, which also
  groups the epics into **phases** (smallest launchable slice first, derived from the
  working-backwards launch). A **cycle is a decomposition defect** — intake re-slices;
  `verify-artifact`'s brief bar grades the decomposition, a cyclic sequence included.
- **The founder approves the sequence, not just the set.** Intake's decision package presents the
  phase list and the dependency edges; the approval covers both.
- **The gate: blockers Done.** An epic whose `is blocked by` epics are not all **Done** is not
  routable — the orchestrator does not start its epic intake or dispatch any of its units. Done,
  not RC, because dependent epics build on code merged to `main`. The founder unblocks early by
  removing the link.
- **Post-approval link edits are founder-owned.** No agent adds or removes a dependency link after
  the approval gate. A downstream stage (the architect, a producer) that discovers a **missed**
  cross-epic dependency surfaces it to the human queue for the founder to add — it never silently
  re-orders the run. Intake sequences at the capability level only; technical dependencies
  discovered later take this route.
- **Fail-safe under the trust boundary.** Issue links are issue content and therefore
  attacker-controllable — but they gate dispatch *order* only: a malicious link can delay an epic
  (visible as a wait-state in the orchestrator's pass summary), never advance work or skip a gate.

Below `product` there is nothing to sequence: `feature`, `small`, and `docs` are unchanged.

## Per-child-epic tiers (product decomposition)

A `product` ask's own `TIER: product` marker sizes the parent-level ceremony, but the child epics it
decomposes into are not all the same size — one is a cross-cutting platform capability, another a
one-story operational chore, and running the full upstream stack on both is the small-feature cost
problem reborn one level down. So at `product` tier intake also classifies **each child epic** with
its own tier, written on the child epic as a breadcrumb marker:
`TIER: small (child of {PARENT-KEY}, product decomposition) — {one-line justification}`.
**UNVALIDATED until a product-tier run exercises per-epic tiers end to end.**

- **Allowed child tiers: `docs`, `small`, `feature` — never `product`.** A child that is genuinely
  multiple epics is a decomposition defect: re-slice it at the parent.
- **One gate, not one per child.** The founder confirms or overrides the per-epic tiers at the
  **same product approval gate** that approves the set and the sequence — the decision package lists
  them, and the existing `INTAKE-APPROVAL` covers them. No new approval gate is created.
  Post-approval re-tiering of a child epic is **founder-owned**, like dependency-link edits.
- **The child's tier governs its own ceremony.** The upstream skip rules and the Inline-lite
  provisions apply to each child epic by its **own** tier, exactly as to a standalone ask of that
  tier. Stories carry no tier marker: a story's **governing tier is its parent epic's** (the `docs`
  type label stays the one per-story exception). When genuinely unsure how to classify a child,
  `feature` is the conservative default — more ceremony, never less.
- **Fallback: a marker-less child is `feature`.** A product child epic with no `TIER:` marker (any
  epic decomposed before this rule existed) is treated as `feature`, skip rules applying — exactly
  the prior behaviour, so nothing in flight changes; the orchestrator notes the fallback in its pass
  summary.
- **Backfill on an already-decomposed product (one-time, batch, cheap).** For a product decomposed
  before per-epic tiers existed, the orchestrator may run a single **inline batch classification**:
  read the parent's Decomposition comment (one fetch), propose a tier per **not-yet-started** child
  epic with a one-line justification each, present the list to the founder as **one batch
  decision**, and on confirmation write the per-epic markers plus a `TIER-BACKFILL:` marker comment
  on the parent recording the batch and the founder's confirmation (its presence means the offer is
  never repeated). Epics already past their epic intake are **skipped** — a tier only governs
  upstream ceremony that has not run yet, so retro-tiering completed work is waste; the `feature`
  fallback covers them. **Nothing is re-validated:** no existing artifact, verdict, or approval is
  reopened, and no `verify-artifact` dispatches — a tier marker is a routing record, not an authored
  artifact; the founder's batch confirmation is its gate.
- **Why this is safe (the honesty guard, applied to children):** a child epic's tier can only cut
  upstream thoroughness. The AC critic, the frozen snapshot, per-story verification, and both human
  gates are tier-independent, so even a mis-classified or mis-backfilled child cannot weaken
  verification — a child that proves bigger mid-build bounces and is re-tiered, like any mis-tiered
  ask.

## Upstream skip rules (by the unit's governing tier)

An upstream stage that adds nothing still costs a full dispatch — a fresh agent, a skill load, the
Jira reads, the artifact verification. The bias is therefore **skip by default, run on a named
trigger**, decided per stage when the orchestrator plans epic intake. These rules apply at `small`
and `feature` tier, and to a `product`'s child epics **by each epic's own per-epic tier** (above):

- **Research runs only when the locked brief lists open questions the repo cannot answer** —
  external, market, or product unknowns. A question answerable from the codebase digest (or a quick
  read of the repo) is **repo-local**: it routes to the architect (digest-informed) or straight into
  the producer brief, and does not warrant a research dispatch. `small` always skips.
- **Architect runs only when the epic is genuinely cross-cutting**: it crosses module boundaries,
  introduces or changes an external surface (API contract, auth, tenant or data boundary), or has a
  shared seam between two or more stories. An epic that stays inside existing module boundaries with
  no new surface skips it — **the orchestrator then writes the one-line
  "fits the existing architecture per the codebase digest" note to the Architecture lane itself**
  (citing the digest). That one-liner is a **routing record, not an authored artifact**: no
  `verify-artifact` dispatch, no `ARTIFACT-AUTHORED-BY` — but producers still find a constraints
  lane to read, so the "constraints bind every producer" contract is unchanged. Because it carries
  **no Artifact Verdict by design**, the orchestrator's dependency gate (verdict-PASS before a
  dependent step dispatches) applies to *authored* artifacts only and **must not block** on a
  routing record — otherwise the skip path would deadlock before author-prd ever runs. **Greenfield (no
  digest): the architect trigger is effectively always met** — there is no existing architecture to
  "fit" and nothing for the one-liner to cite, so the epic's first structural work runs the architect.
- **Why skipping is safe:** the AC critic, `verify-artifact` on the artifacts that *are* authored,
  the In Review trio, and both human gates are untouched. A wrong skip surfaces as an AC-critique
  bounce or a verifier FAIL — upstream thoroughness is the only thing at stake, never downstream
  safety (the honesty guard below). When genuinely unsure whether a stage is needed, run it.

## Producer pre-flight (every code tier)

**No PR opens on red.** Before opening its PR, a producer runs the repo's **own** gates — the build,
the full test suite, and lint/static checks: the commands the codebase digest records on a hydrated
repo, or the gates the producer itself scaffolded on greenfield — and attaches the command list and
results to its producer notes.

- **A PR opened with failing repo gates is a producer-attributable defect** — it bounces and counts
  a verification round exactly like a verifier FAIL. Mechanical failures are the producer's to
  catch; verifier rounds are for judgment.
- **Pre-flight is a floor, not a substitute.** `run-tests` still independently re-runs the suite in
  a fresh context — pre-flight evidence is producer-authored and therefore untrusted by the gate;
  review-code and redteam-security are unchanged. What pre-flight buys is first-pass yield: verifier
  rounds stop burning on code that never built.
- **Hard backstop on a protected repo.** Where the product repo's default branch carries the
  protection ruleset (require a PR + the repo's CI check green before merge — onboard checks and
  offers to enable it), a red PR is refused by GitHub itself: no agent, however confused, can merge
  it. Pre-flight keeps red PRs from *opening*; protection keeps them from *landing*.
- **Docs tier: n/a** — a prose diff has no repo gates to run; the mis-tier bounce guards that
  boundary.

## The docs tier

A **docs** ask is a change that is *documentation only*: README, guides, tutorials, reference docs,
code comments, wording. **No executable code, no behavior-bearing config, no schema, no build
scripts, no dependency manifests.** The test is: **can the changed file execute, route, or change any
behavior anywhere? Then it is not docs — and when in doubt, it is not docs.** Concretely NOT docs,
even though they look documentation-adjacent: MDX or notebooks containing executable code, CODEOWNERS
(changes review routing), `.github` issue/PR/workflow templates, docs-site config (`mkdocs.yml`, nav
files), `package.json` scripts, and markdown containing raw HTML/`script` (rendered unsanitized by
some site generators — that is `web`-stack risk, not prose). It exists because routing a README rewrite through the full code
pipeline costs an order of magnitude more than the change warrants (a live run measured ~913k tokens
for one README).

- **Pipeline:** capture (or intake) classifies `docs` → one story with the `docs` type label →
  AC critic gates the AC → snapshot → `jarvis-agency-build-docs` produces → **one** independent
  verifier (`review-code` in docs mode: content preservation, technical accuracy against the source,
  docs-only scope, no secrets) → RC → human GA. Founder approval and the human GA gate are unchanged.
- **AC shape (fixed, like a Bug's):** the change is made for the stated reader; existing content is
  preserved unless the AC explicitly retires it; every technical claim (commands, flags, paths,
  links) is verified against the actual source; the diff is docs-only; no secrets.
- **Why one gate is honest, not a cut corner:** the trio's other two verifiers have nothing to
  verify on a prose diff — there is no test suite to re-run (`run-tests`), and the content **is**
  the whole attack surface, so the docs gate's bar carries an explicit **adversarial-content lens**
  (below), not just proofreading. Producer-never-verifies holds unchanged: the gate is a distinct identity in a fresh
  context.
- **The adversarial-content lens (what the single gate checks because content is the surface):**
  install/setup commands are reviewed as an attack vector — a fetched-and-executed URL (`curl … | sh`)
  must point at the project's own domain/repo and match any existing canonical source, and a swap to
  an unrecognized host is an RC-blocking finding even though no "source file" exists to diff against;
  link destinations are checked for lookalike/misleading targets; raw HTML or script in markdown is a
  scope FAIL (not docs); and instruction-shaped payloads aimed at future agent readers (prompt
  injection published into the repo's own docs) are a finding — the agency defends readers with
  content-is-data, and the docs gate defends what the agency *publishes*.
- **The mis-tier bounce (the safety valve):** if building the story would require touching anything
  executable — the producer discovers a documented flag doesn't exist, say — the docs producer
  **stops and bounces** for re-tiering into the code path with the full trio. A docs diff is never
  quietly widened into a code diff, so the single gate can never end up verifying code.

## A documentation defect is not a Bug

"The README's install command is wrong" describes broken *prose*, not broken *behaviour*: no
regression test can cover a wording fix, so the Bug's fixed-shape AC cannot be satisfied and the trio
has nothing to verify. It is a **`docs`-tier change** — capture classifies it as one, and if it
arrives as a Bug anyway, triage's first check is whether the defect is documentation-only and
re-routes it to the docs tier instead of setting a stack label. The boundary is the tier's own: if
fixing the defect touches anything executable, it **is** a Bug and runs the full bug path with the
trio.

## Below the floor: not every ask should become an issue

Some asks are beneath even the docs tier: a typo, a one-line wording tweak — **prose only, the same
boundary as the docs tier.** The floor offer is **never available for anything executable**: a "tiny"
config flip or one-line code change is at minimum a story with the trio, because the plain-session
path has no verification at all — the floor is a door past Jira for trivial prose, not a door around
the trio for code. At the capture confirm step, capture **offers the choice** instead of silently
creating: *"This is below the agency's floor — want me to just do it in a plain session now (no Jira
record), or capture it as a docs-tier issue for traceability?"* The founder decides; capture never
declines work and never silently skips Jira. The cheapest pipeline for trivial work is the one it
never enters.

## Mid-epic scope change: cut, added, or neither

Scope was frozen at the approval gate, but epics meet reality mid-flight. There are exactly three
outcomes, and conflating them is how a launch quietly ships something nobody signed for
(a founder decision, 2026-07-21).

- **Scope CUT mid-epic → supersede the scope note.** Write a **new** scope note that links the
  superseded one and records **the reason and who decided**; the superseded note stays in place,
  marked superseded. **Never edit the frozen note in place, and never drop the cut silently** — one
  auditable chain, so a later reader can see what was dropped and why. The new note takes its own
  confirmation like any scope decision.
- **Scope ADDED mid-epic → its own PRFAQ, its own epic, its own GA.** This is the direct consequence
  of *one PRFAQ = one epic = one GA*: added scope cannot ride a signature for a launch that never
  promised it. Route it back to the **PM** to author the PRFAQ; it does not join the running epic
  however small it looks.
- **An AC edit within already-approved scope is NOT a scope change.** It is the existing
  **snapshot-drift** path: the live AC/constraints no longer equal the snapshot, so the story bounces
  to `Refined` and is re-snapshotted and re-gated. No new note, no new epic. Say which of the two you
  are in before acting — they are routinely confused, and treating added scope as "just an AC edit"
  is the failure this section exists to prevent.

**A scope decision with no owning vault note is invalid** (the law, invariant 1). A mid-epic change
is exactly where that rule is most often skipped, because the decision arrives in chat mid-run —
write the note first, then act.

## Inline-lite roles and delegated-proceed (codified 2026-07-05, founder-approved)

The first live small-tier runs improvised orchestrator-inline versions of specialist dispatches.
The founder blessed the pattern with rules; an inline-lite act outside these rules is a deviation
to surface, not a precedent. Throughout this section a unit's tier means its **governing tier**: an
epic's own `TIER:` marker (for a product child epic, its per-epic tier), and for a story, its
**parent epic's** — so a story under a `small` child epic of a product qualifies (see
Per-child-epic tiers above).

- **Inline cost accounting** — on a `small`/`docs`-tier **story** checkpoint, the orchestrator may
  compute the spend and write the `Cost` note itself, labeled "orchestrator inline accounting".
  Epic-level checkpoints and `feature`/`product` tiers dispatch `watch-cost`.
- **Inline intake (small tier only)** — the orchestrator may author a small-tier Requirements
  Brief inline (recorded `ARTIFACT-AUTHORED-BY: intake-inline-orchestrator …`), **provided**
  `verify-artifact` still independently checks it (the light small-tier bar) and the founder
  approval gate is unchanged. Feature/product briefs always dispatch `intake`.
  **Inline authorship never self-confirms (founder ruling 2026-07-20, settled — not a suspension).**
  Inline *authorship* continues. What is permanently closed is the path by which the authoring role
  also waves the work through: an inline-authored brief is stamped `authored_by: agency,
  review: pending` and **takes an explicit founder confirmation**, and delegated-proceed above does
  **not** apply to it. Each shortcut is defensible alone; the compound — the same role authoring its
  own scope *and* approving it — is the rubber-stamp the trust-asymmetry stamp exists to expose, and
  it is the one combination that never runs.
- **Inline Run Report** — allowed **only** for a `small`-tier epic that closed with **zero
  producer-attributable bounces and within-budget cost**, labeled "orchestrator-authored inline
  retro". Any bounce, any warn/over cost, or a founder request → dispatch the full
  distinct-identity `retro`. (The first improvised inline report had a bounce and an OVER
  cost and would **not** have qualified — the rule has teeth by design.)
- **Never inline:** any gate or verifier verdict (the AC critic, the In Review trio and docs gate,
  QA, perf, `verify-artifact`), any status the contract reserves, and GA. Inline-lite economizes
  authorship of *advisory/bookkeeping* artifacts; it never substitutes for a distinct-identity
  verdict.
- **Delegated-proceed (the founder's standing grant)** — **ACTIVE, re-expressed for vault-first
  (founder ruling 2026-07-20; law_version 1.2.0).** It sets `review: founder-delegated` on the scope
  note — never `founder-confirmed`, which only the founder writes — recording that the founder
  pre-authorized this *class* of work, not that they read this item. **Two conditions, both required:**
  (1) a recorded standing grant covers the class (small tier / low regret), and (2) the note was **not**
  authored inline by the orchestrator (`ARTIFACT-AUTHORED-BY: intake-inline-orchestrator …`) — the same
  role may not both write the intent and wave it through. A brief written by the dispatched `intake`
  identity is a different identity and qualifies; one the orchestrator wrote itself does not, and takes
  a real founder confirmation. The delegation is named in the run summary so it is never mistaken for a
  reviewed decision. (The bug-path variant below is a separate grant over *fix scope*, not intent.)
  The grant as written: the founder may grant a standing
  "proceed without per-epic sign-off" for **small-tier / low-regret** work. The orchestrator
  records `INTAKE-APPROVAL: … (delegated-proceed)` naming the standing instruction as its basis,
  and **surfaces every material decision or fork in the RC advisory** for acceptance at the human
  GA sign-off — the gate moves to GA for small work, it does not vanish. Revocable by the founder
  at any time; `feature`/`product` tiers always take explicit per-epic approval. (First exercised
  cleanly on a pair of live small-tier stories, 2026-07-04.)

### Delegated-proceed on the bug path (the founder's standing grant for small bug fixes)

The same standing-grant shape extends to a Bug's **fix-scope confirmation** gate, so a low-regret
fix does not park an unattended run waiting for the founder. Under a granted
`BUG-FIX-DELEGATED-PROCEED` (recorded in the per-project config alongside the intake grant), triage
may proceed past the fix-scope gate to the build loop **without** the per-bug founder confirmation —
recording `FIX-SCOPE-CONFIRMED: … (delegated-proceed)` with that basis — **only when the fix is
low-regret on every one of these**, else it stops and asks exactly as today:

- **Severity** is not high/critical (a data-loss, security, auth, or money-affecting defect always
  stops for explicit confirmation).
- **Scope** is narrow — the change is confined to the reported defect's root cause, touches no
  security/auth/tenant-boundary/data-migration/payment code, and does not widen scope.
- The bug **reproduced cleanly** (an unreproduced bug still bounces to the founder — that rule is
  never relaxed).
- The fixed-shape AC holds (no-longer-reproduces **and** a regression test), so the fix is
  independently checkable.

Everything else is unchanged: the AC critic, the three In Review verifiers, and the human GA
sign-off all still run, and the fix is **surfaced in the RC advisory** (the RC steps *are* the
original reproduction now showing the fixed behaviour) for acceptance at GA — the gate moves to GA
for a small fix, it does not vanish. A widening or high-severity fix, or any doubt, takes the
explicit gate. Revocable at any time; the grant never covers a `feature`-sized change mis-filed as
a Bug (triage re-tiers that first).

## Never cut, at any tier

The AC critic gate, the AC-and-constraints snapshot, the producer build, **independent verification
by a distinct identity**, producer-never-verifies, the founder approval gate, and the human GA
sign-off. For any story that touches **code**, independent verification means the **full
three-verifier trio** — the trio is never cut for code; the docs tier's single gate applies only to
diffs with no executable surface, and the mis-tier bounce enforces that boundary.

## The honesty guard

Because per-story verification and the human gates are constant, a **mis-tiered** ask costs only
upstream thoroughness, never downstream safety — a "small" that turns out complex is still verified
story-by-story, and a "docs" that turns out to touch code bounces into the code path. Intake (or
capture) justifies its tier in one line; the founder is the final word at the approval gate; a story
that proves bigger mid-build bounces and can be re-tiered.
