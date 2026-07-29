# The gates the orchestrator enforces (detail)

These are the contract's orchestrator-side backlog items. The orchestrator is their enforcer
(a soft control) until a Jira-level hard control exists. Backlog items 5–8 and 11 are **SOFT DONE** —
the orchestrator-side control is fully specified; only the Jira-level hard control remains, and that
is blocked on item 9 (a company-managed project). Read the backlog table in the contract's internal
config for the current per-item status rather than trusting a number quoted here. The SKILL.md lists
the gate names; this file carries the mechanism and honesty of each.

- **Claim, serialized.** Entering In Progress sets the owner; act only if currently unclaimed. On
  the team-managed home project the claim is **not** atomic at Jira, so: run claim checks for a
  given story on a single dispatch path, and after writing the owner, **re-read the issue and
  confirm self-ownership before dispatching the producer**. If the re-read shows another owner,
  abort and do not dispatch. The re-read confirm is what closes the read-check-then-write window.
- **AC and constraints change-control, by stored snapshot.** At the Refined to In Progress
  transition, write the **full AC text and the epic's architecture constraints** into the
  AC-snapshot lane (config), not just a hash, so producer and verifier work against the frozen
  baseline. Before In Review to RC, compare the live AC and the live constraints to the snapshot;
  any difference in either bounces the story back to Refined and re-gates it. The AC-snapshot
  location is a config precondition.
- **RC gate on every governance verdict.** Each governance verifier **dispatched for the story's
  tier** writes its own lane beginning with a `VERDICT: PASS` or `VERDICT: FAIL` token — for a
  **code** story that is every installed verifier the config names (the trio); for a **`docs`-tier**
  story it is the single docs gate (review-code, docs mode), whose one lane is the whole gate (the
  contract's docs tier; run-tests and redteam lanes are absent **by design**, not missing).
  Transition In Review to RC only when **every** lane so dispatched shows `VERDICT: PASS` **and** the
  live AC and constraints still equal the stored snapshot (the change-control check above); any
  `VERDICT: FAIL`, a missing dispatched verdict, or AC/constraint drift bounces to In Progress with
  the consolidated findings; absence of an explicit PASS in any dispatched lane is not-pass. Verdict lanes are append-only comments, so on bounce **read by round** — the
  RC check considers only the **current round's** verdict comment per lane, never a stale prior-round
  PASS. The producer's self-review lane is advisory input, never a gate.
  **Test-only-delta security carry-forward (founder-approved; strict, narrow):** on a
  bounce round whose **entire** delta is test-only, the orchestrator may carry the prior round's
  Security Verdict PASS forward instead of re-dispatching redteam-security — only when the
  current round's **review-code verdict explicitly states the round's diff contains no
  production-code hunk**, and the carry is recorded as a one-line note in the Security lane naming
  the carried round and the certifying review comment. Any production-code hunk, however small,
  voids the exception and the full trio re-runs; `run-tests` always re-runs regardless (evidence:
  a live round-2 test-only delta, named in that epic's Run Report as proposal 3).
- **Max-bounce escalation (no infinite loop).** Increment the story's verification-round count
  (config lane) **only on a producer-attributable bounce** — a verifier `VERDICT: FAIL` or a missing
  verdict. An **AC/constraint drift bounce does not count** (it is the human's edit; it routes to
  Refined to re-snapshot and **resets** the count). When the count reaches the configured ceiling
  (config; default 3), stop re-dispatching the producer and **transition the story to Blocked**
  (record the pre-Blocked origin), flag the human queue, and write the consolidated findings and
  round history. Blocked is a stop-state, so a later loop pass leaves it rather than re-dispatching —
  this is what makes the park durable against the orchestrator's own next pass. The human clears it
  to **Refined** to re-scope (re-snapshots, resets the count) or to Rejected; it is not auto-returned
  to In Progress. The count also resets at RC. A story the agents cannot converge after a few honest
  attempts is a PM decision (re-scope the AC, fix it by hand, or reject), not work to churn on
  unattended. This matters under unattended or bypass-permissions runs, where there is no per-action
  human checkpoint to notice a story thrashing; it bounds the thrash and surfaces it to the PM. Soft
  control (orchestrator + compliance), like the rest — not a hard kill; an agent that ignored the
  ceiling is bounded only by the runner spend cap (backlog item 14).
- **Cost checkpoint fires, not eyeballed — and it is checkable.** Invoke `jarvis-agency-watch-cost`
  at the checkpoints in The loop (story reaches RC; epic boundary), act on its status (`warn` → note
  and continue, `over` → stop-and-park the run and flag the human queue), and never start another
  story once a per-run `over` is returned. The `Cost` note is a **precondition of the next artifact**:
  no RC advisory without the story's RC `Cost` note, no GA-DECISION/epic-close without the epic `Cost`
  note — so a record reaching RC/GA with no `Cost` marker is a visibly skipped checkpoint (the sim
  retro caught exactly this). In the first live run the orchestrator estimated spend by eye and never invoked
  the watcher; that is exactly what fails an unattended run, where no human is watching the burn. The
  hard backstop remains the runner spend cap (item 14, yours to set); this is the soft brake that
  makes the budget real.
- **Distinct verifier identities.** Per the dispatch discipline; every verifier differs from
  the producer and they run independently. This includes the functional-QA verifier.
- **Bug fix-scope confirmation, before building.** A Bug does not enter the build loop until triage has
  reproduced and scoped it and the **founder has confirmed the fix scope** (a marker comment, the lighter
  counterpart to the intake approval). Do not dispatch a fix producer on an unreproduced or unconfirmed
  Bug. The producer that fixes a Bug is a distinct identity from triage, and the verifiers are distinct
  from both — producer-never-verifies holds across the bug path too.
  **Delegated-proceed exception (small fixes):** where the founder granted a standing
  `BUG-FIX-DELEGATED-PROCEED` (per-project config) and the fix is low-regret on every criterion in
  contract work-tiers ("Delegated-proceed on the bug path" — not high/critical severity; scope narrow
  and touching no security/auth/tenant/data-migration/payment code; reproduced cleanly; fixed-shape AC
  holds), triage records `FIX-SCOPE-CONFIRMED: … (delegated-proceed)` and the loop proceeds without the
  per-bug founder confirmation — the marker the orchestrator already keys on is present, so no routing
  change is needed. The fix is accepted at the human GA sign-off via the RC advisory (whose steps are
  the original reproduction now showing the fixed behaviour). Any unmet criterion, high severity, scope
  widening, or unreproduced bug takes the explicit gate exactly as before. Revocable at any time;
  `feature`-sized work mis-filed as a Bug is re-tiered first, never delegated-proceeded.
- **ID-collision guard, concretely.** The RC **status** id and the Story **issue-type** id are
  the same number on this instance. Never pass a bare number to a call that accepts either: status
  ids appear only in transition calls, issue-type ids only in create and JQL. Assert the namespace
  at every call site.
- **GA-ceiling refusal.** Never transition RC to GA Signed. The hard control is a least-privilege
  credential (backlog item 1, open); until it exists the orchestrator's refusal is the only line,
  so the refusal is not optional.
- **`STATUS-ACTOR:` on every status move.** Mechanism: the orchestrator remains the **single writer**
  of every transition — the marker changes nothing about who performs the write. Immediately after
  each move it writes a one-line `STATUS-ACTOR: {role it wrote for} — {issue} {from} → {to}` marker
  comment, so a later pass or an audit can read *on whose behalf* a move was made instead of inferring
  it from timing. Delegating the transition itself to the named role is a violation, not a shortcut.
  **Honest standing: compliance-only.** No check fails on a missing `STATUS-ACTOR:` marker; Jira's own
  changelog records the account, never the role. The marker is an audit convenience the orchestrator
  and agent compliance hold, and its absence is visible only to a reader who goes looking.
- **PM walkthrough before the Epic GA package (user-facing epics).** Mechanism: the `Epic GA package`
  is not assembled until the epic carries **one of three** recorded values —
  (a) a human-recorded `PM Acceptance` verdict (the walkthrough happened, verdict recorded verbatim
  and attributed); (b) `PM-ACCEPTANCE: skipped — no user-facing surface` (the work has nothing for a
  person to click); or (c) the **environment release valve** below. Mandatory to **RUN**, advisory in
  **OUTCOME**: the presence of a record is the precondition; the *content* of the verdict never gates —
  a gaps verdict informs the founder's GA decision and never bounces merged work. The trigger is
  readiness + a user-facing surface, never the presence of a PRFAQ artifact (epic-completion.md).
  **Honest standing: compliance-only**, the same shape as the `Cost` note. Nothing fails a package
  posted with none of the three; it is simply a self-evident missed step in the record, and the hard
  control behind the whole gate is unchanged — the changelog-verified **human** GA signature.
- **Environment release valve — the named exit at `tier=none` (a founder decision).** A user-facing
  epic whose environment resolved to `ENVIRONMENT: … tier=none` can produce neither a walkthrough
  verdict (no running product for a human to exercise) nor the no-user-facing-surface skip (it *has*
  a surface). Without a valve the Epic GA package is held with **no documented exit**. The valve is a
  third accepted precondition value:
  `PM-ACCEPTANCE: walkthrough performed out-of-band — {what the founder did, and where the evidence is}`.
  It records that the **human exercised the product outside the agency's environment** (their own
  laptop, a staging system the agency cannot reach, a demo they ran). Rules, in order of importance:
  **the agent writes it ONLY on the founder's explicit say-so**, verbatim as to what they did, and
  **never on its own initiative** — not speculatively, not inferred from a founder's passing remark,
  and never to unblock itself. It is an explicit, auditable human override of the same shape as
  `BUG-FIX-DELEGATED-PROCEED`: a human takes responsibility on the record, in a greppable marker.
  With `tier=none` and **none** of the three values recorded, the package **stays held**, and the
  hold is **surfaced to the founder every pass** naming the out-of-band route as theirs to take — the
  hold is the correct behaviour, it now simply has a named exit rather than a dead end.
  **Honest standing: compliance-only.** The agent physically can write this marker unprompted; nothing
  stops it. That is precisely why it is written as a founder-attributed record and why the hard
  control stays the human GA signature.
- **Blocked-on-environment is never reported as passed.** Mechanism: the RC row resolves the
  environment per the contract's environment rule and records the `ENVIRONMENT:` marker with its tier.
  At `tier=none`, QA, perf, and the PM walkthrough are recorded as **blocked-on-environment** and
  surfaced to the founder — never as `PASS`, never as "no findings", never silently omitted. Building,
  code review, unit tests, and the security pass are **unaffected**: they need no running product and
  run as normal, so a missing environment narrows the checks, it does not stall the story. The agency
  **never provisions infrastructure** to clear the block; standing up real resources is a gated human
  or pipeline step. **Honest standing: compliance-only.** Nothing detects a blocked check written up
  as a clean one; the guard is the orchestrator's own record-keeping plus the founder reading the
  surfaced block.

- **Interrupted-loop resume.** On restart, an In Progress story that is claimed but carries no
  producer completion artifact is re-inspected, never blindly re-dispatched: the orchestrator cannot
  tell a crashed producer from a finished one by status alone, so it reads the issue for the
  producer's recorded result (or a mis-tier report) before deciding to re-dispatch, advance, or flag.
  Under wave dispatch add the liveness preference: a claimed story with a produced-by record but no
  result may belong to another live pass — treat it as **possibly live, not dead**, and wait a full
  pass interval before re-dispatching. A stalled story costs one pass of latency; a duplicate
  producer breaks one-producer-per-story. (One runner per project is the standing rule.)
  **Session refresh (the hosting-session corollary).** The same statelessness that makes a pass safe
  to re-run makes the *hosting session* safe to kill. The **ENFORCED, VALIDATED** mechanism that keeps
  the host sub-cliff is a **sub-cliff auto-compact backstop** set by two harness env vars
  (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=225000` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=95`), firing ~192K — the
  reduced window minus the ~33K autocompact buffer — **below the 200K premium cliff**, so context is
  compacted before it ever pays 2×. It is self-enforcing (harness-level, independent of the
  orchestrator) and it alone carried the cost win. The review of 2026-07-06
  (an internal context-hygiene review) found this session is the system's single longest
  context lifetime with nothing watching it — the backstop is what now watches it. **Live-validated
  2026-07-16 (session 1271e446, a full day, 1026 turns): median context 161K, peak 191K, 0% of turns
  >200K (was 88–93%), ~82.5% cost-per-turn cut.**
  Three claims, kept strictly separate (do not collapse to one "proven"): **(1) cost sub-cliff —
  PROVEN** (the numbers above). **(2) compaction state-safety — OBSERVABLY CLEAN, SCOPED**: across the
  14 compactions that day, 38 unique dispatches with 0 re-dos and 42 transitions with 0 repeated
  (issue,transition) pairs — but on MIXED investigation+Jira work, explicitly **NOT** the formal
  round-tracked pipeline, and it is a re-do proxy, not proof of an optimal pick. **(3) refresh
  (eval-030) state-safety — UNEXERCISED**: the pass-count refresh never fired, so eval-030's derivation
  holds on paper but its live path is still untested.
  The **`passes_since_refresh ≥ K` pass-count refresh** (config; default 2) is therefore **OPTIONAL
  and UNEXERCISED — not load-bearing.** It is a proxy (the loop cannot read its own context size) for a
  cleaner, *lossless* reconstruction — a fresh session re-reads Jira rather than trusting a lossy
  compaction summary — but under plain `/loop` it does **not** fire: the host does not self-restart,
  and the validating run was one continuous 9-hour session. **Retained demoted-not-deleted, as the
  optional fallback for the formal round-tracked pipeline — the one path compaction state-safety was
  NOT validated on (a compaction dropping a bounce round-count or verdict-lane state mid-`r1→r2`).
  Delete it once the formal pipeline confirms compaction holds there too.** Killing mid-pass is
  recovered by the interrupted-loop rule above; for genuinely long unattended grinds prefer a
  **Routine**, which gets a fresh session per firing for free (independent of K).

## The intent gate — the Backlog ladder

Take **exactly one** branch, in order. The ordering is the point: (c) before (d) is what keeps the
pipeline's front door open.

**(a) Quarantined** (`quarantine_list`) → blocked from everything, drafting included. Note the
carve-out in the run summary; move on.

**(b) No owning vault note at all** → the intent exists only in Jira, which is invalid under the law.
Do not action it: route it back for a note to be authored (`pending`), queue it, surface it, move on.

**(c) Requirement note `pending`, and no scope note yet** → **dispatch `intake`.** The law permits
pending intent to be *drafted*, and this drafting is exactly how the founder gets a decision package
to approve. Blocking here would leave them nothing to confirm and stall the pipeline at its front
door — the failure this branch exists to prevent. Intake drafts the scope note (`pending`) and
presents the gate. **Do not** dispatch a producer or advance toward the build path.

**(d) Intent `pending` and the drafting already done** (a scope note exists, awaiting the founder) →
there is nothing further to draft. Queue it into `{vault_root}/_governance/founder-decision-queue.md`,
surface it, and move on to other unblocked work — never stall the wave, never silently proceed on
unconfirmed intent.

**(e) `founder-confirmed` or `founder-delegated`** → actionable; continue with the normal Backlog
routing. Name any delegation in the run summary so it is not mistaken for a reviewed decision.

**The distinction that makes this work:** pending intent blocks **building**, not the **drafting**
that produces the thing being approved. Conflating the two reads as safe and is not — it closes the
front door instead of the build path.
