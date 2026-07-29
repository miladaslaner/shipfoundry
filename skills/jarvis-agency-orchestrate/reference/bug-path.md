# Bug path — defects skip the feature upstream

Extracted from `SKILL.md` for body-line headroom. The **routing table's Backlog row** carries the
operative instruction the orchestrator executes each pass ("if the issue is a Bug, run the bug path
first"); this file is the mechanism behind it. The gate itself is also stated in
`reference/enforcement-gates.md` (Bug fix-scope confirmation).

A **Bug** does not go through intake → architect → PRD. It has its own light upstream and reuses the
build loop:

1. **Triage.** Route a Bug in Backlog to **`jarvis-agency-triage-bug`** (a distinct identity), which
   reproduces the defect, locates the root cause, scopes the fix narrowly, sets the Bug's **stack type
   label** (so the fix routes to the right producer), and drafts AC in the fixed bug shape: *the bug no
   longer reproduces, and a regression test covers it*. If it cannot reproduce, it bounces to the founder
   for detail rather than guessing — the orchestrator does not advance an unreproduced Bug.
2. **Fix-scope confirmation gate (human).** Triage stops; the orchestrator presents the reproduction,
   root cause, fix scope (and non-scope), and draft AC to the **founder** and waits for explicit
   confirmation. This is the bug's upstream human touchpoint, the lighter counterpart to the intake
   approval. Record it as a `FIX-SCOPE-CONFIRMED:` marker comment (the grep-able prefix a later loop pass
   reads to know the gate is cleared); do not advance until it is present. The founder may narrow,
   widen, or redirect the scope (re-triage), or reject the Bug.
3. **The normal build loop, in bug mode.** After confirmation the Bug runs the standard per-story path —
   AC critic gates Backlog → Refined, snapshot, In Progress, producer, the three In Review verifiers,
   RC, human GA — with **one addition to the producer brief: bug mode.** The producer must *reproduce the
   defect, add a regression test that fails before the fix and passes after, then make it pass*, so the
   fix is proven and cannot silently return. `run-tests` confirms the regression test genuinely catches
   the bug. No feature upstream (no Requirements Brief, architecture, or PRD) is required for a Bug.

## Fix-scope is execution, not new intent

A Bug's fix-scope confirmation gate is **not** an intent-authoring moment: it confirms the scope of a
repair to behaviour the product already claimed, against a defect that reproduced. It therefore does
not require its own vault scope note — the Bug rides the intent already founder-confirmed for the
behaviour it restores. A "fix" that would **add** behaviour the product never had is not a bug fix:
it widens scope, trips the explicit gate (contract work-tiers, "Delegated-proceed on the bug path"),
and belongs in the feature pipeline with its own vault intent.
