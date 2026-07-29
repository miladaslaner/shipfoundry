# Wave dispatch — parallel units per pass (mechanism)

One pass used to dispatch one unit and block on it, so an epic of four independent stories ran as
four sequential build+verify cycles even though the decomposition made them independent on purpose.
A pass now dispatches **every independently-actionable unit concurrently, bounded**, and collects
results as they land. Nothing about *what checks a story* changes — only *when work runs*.

## Eligibility — what a wave may contain

Walk the board once and collect every unit the routing table marks actionable **now**:

- **Refined stories** → claim + snapshot + producer dispatch (one producer per story, unchanged).
- **In Review stories** → the tier's verifier dispatch (the trio, or the docs gate) — these already
  fan out internally; different stories' verifications also run side by side.
- **Upstream artifacts** stay in dependency order — research → architect → PRD → design — because
  each reads the prior's lane (the architect reads the research findings; overlapping them freezes
  constraints derived from an empty Research lane). Never overlap a stage with one it reads from;
  upstream parallelism comes from pipelining *across epics and stories*, not within one epic's chain.
- Different **stages pipeline freely**: story A's verifiers run while story B's producer builds.
- **A dependency-blocked epic contributes no units (product tier).** An epic whose native
  `is blocked by` epics are not all **Done** is ineligible wholesale — not its epic intake, not its
  stories (contract work-tiers, "Cross-epic sequencing"). An expected wait-state noted in the pass
  summary, never an error; it clears mechanically when the blocker epics reach Done. Agents never
  add or remove the links (founder-owned post-approval).

Everything else (Blocked, RC awaiting GA, unapproved epics, dependency-blocked epics, the human
queue) is untouched — the gates and stop-states are exactly as sequential dispatch left them.

## The bounds (what keeps a wave safe and affordable)

1. **Concurrency cap** (config; default 4). The cap counts **orchestrator-dispatched units** — a
   producer, a trio verification, a docs gate, an upstream stage. Internal fan-out lives *inside*
   its unit and is not double-counted: one In Review unit's trio is three verifier agents but one
   unit; a `fast`-pace producer's sub-implementers are inside its unit. Worst case, cap 4 is
   therefore roughly 12–16 concurrent agents — the default is chosen with that multiplication in
   mind; if rate limits or the budget bite, **lower the cap, don't reinterpret it** (a mid-run
   rate-limit-killed subagent is the concrete signal to drop back to 3 or below; raise to 5 only on
   a hydrated repo whose `touches:` hints keep the wave demonstrably disjoint). Excess eligible
   units queue, highest-status-first (In Review before Refined, so in-flight work finishes before
   new work starts — this also drains the board in dependency order).
2. **Working-tree isolation — one git worktree per concurrent repo-touching subagent.** Two
   branches cannot be checked out in one working tree: without isolation, producer B's
   `git checkout` rides producer A's uncommitted work into B's commits and the trio verifies
   cross-contaminated diffs. So the orchestrator creates a **`git worktree add`** (own branch, own
   build dir; own port if it runs the app) per concurrent producer — and per any concurrent unit
   that runs the app (a per-story QA smoke) — and removes it after the PR opens. If worktrees are
   unavailable (tooling, disk), the cap for repo-touching units in that repo is **1**; never run two
   producers in one checkout. Merge order follows the stacked-merge rule (merge bottom-up or
   retarget, verify main builds); a cross-story conflict surfacing at merge is handled by the later
   PR rebasing — the trio gates the post-rebase result like any other push.
3. **File-surface conflict guard.** Two stories whose scope overlaps on the same module/files do
   **not** build concurrently even in separate worktrees — the second waits for the first's PR, so
   they don't ship semantically colliding changes. How overlap is judged, concretely:
   **disjoint stack labels are presumed disjoint** (a `backend` and an `ios` story don't collide) —
   **except** the backend/api ↔ frontend/web seam of the *same feature*, which shares the API
   contract and is treated as overlapping unless the decomposition says otherwise; same-label
   stories in the same epic use the decomposition's **`touches:` hint** (author-prd records a
   one-line module/dir-level surface hint per story at decomposition) and the codebase digest on a
   hydrated repo; **when overlap is still unclear, treat it as overlapping** — on a greenfield repo
   with no hints this honestly degrades same-label pairs to sequential rather than guessing.
4. **Claims are serialized and taken at dispatch time, never at selection time.** A queued unit is
   **never claimed while it waits**: when a slot frees, the orchestrator claims *that unit* (claim →
   re-read → confirm, the claim gate — one at a time), then dispatches it. So at every instant the
   set of claimed stories equals the set with a live producer, a cost `over` can never strand
   claimed-but-undispatched stories, and parallel dispatch never means parallel claiming.
5. **Budget unchanged, checkpoints re-anchored for waves.** (a) Each story reaching RC fires the
   checkpoint **before any freed slot is refilled** — no new dispatch until it returns. (b) The
   epic-boundary check becomes an **epic-entry** check: before the first unit of an epic not yet
   represented in this run is dispatched (waves are board-wide, so two epics can be in flight; the
   check fires as each epic *enters* the run). On a per-run **`over`**: stop filling slots and stop
   all new dispatches (bounce re-dispatches included); let in-flight subagents finish, collect and
   write back their results (never abandon a finished PR unrecorded, never kill mid-build), then
   park and flag the human queue. Honest caveat: the first RC checkpoint lands after up to *cap*
   stories of committed spend, coarser than sequential's one-story granularity — the cap bounds the
   overshoot; total spend is unchanged, it just lands sooner.
6. **The kill-switch is the existing pace.** `thorough` pace forces sequential single-unit dispatch
   (cap = 1), same as it forces producers inline. One knob turns all speed features off.

## Collect as results land (no blocking on the slowest)

Dispatch is asynchronous: the pass does not block on one subagent before routing the next unit. As
each subagent finishes, the orchestrator collects from the **issue** (never the subagent's context),
writes back status, and fills the freed slot from the queue. A pass ends when no eligible unit
remains un-dispatched and all in-flight work has been collected — or at a stop condition (cost
`over`, the ceiling, the human queue).

**Failure isolation.** One story's verifier FAIL bounces *that story* (normal round rules) and does
not stall the rest of the wave. A subagent that dies with no result is the interrupted-loop case:
re-inspect the issue, never blindly re-dispatch.

**One runner per project (cross-pass safety).** A wave-shaped pass lasts as long as its slowest
in-flight build, so overlapping passes (a re-fired `/loop`, a cron Routine) are likelier than under
sequential dispatch. The rule: **run one loop instance per project at a time** — that is what the
`/loop` and Routine guidance already assume. If a second pass fires anyway: the claim gate still
prevents double-claiming *new* work, and for an already-claimed In Progress story that has a
produced-by record but no completion artifact, the second pass treats it as **possibly live, not
dead** — it waits a full pass interval before the interrupted-loop re-inspection may re-dispatch.
Prefer waiting over a duplicate producer: a stalled story costs one pass of latency; a duplicate
producer breaks one-producer-per-story.

**Write-back is serialized by the orchestrator.** Subagents still never transition status; all
status moves happen in the collecting orchestrator, one at a time, so concurrent completion cannot
race a status write.

## What this changes and what it cannot touch

Wall-clock for an epic's build phase drops from `N × (build + verify)` toward
`1 × (build + verify)` plus merge overhead. It compounds with `/loop` (each pass drains more).
It does **not** touch: any verifier or gate, producer-never-verifies (identities were always
per-dispatch), the founder approval, the GA ceiling, max-bounce, or change-control. The queue simply
moves to the human gates faster — that is the design working, not a problem to fix.

UNVALIDATED — the first multi-story epic under wave dispatch is its proving ground. If parallel
stories bounce for cross-story incoherence the trio caught, tighten the conflict guard (or drop the
cap) before blaming the producers.
