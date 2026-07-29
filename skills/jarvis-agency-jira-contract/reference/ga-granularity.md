# GA granularity — story-level vs epic-level human sign-off (per-project mode)

The human GA gate (invariant 4) can sit at the **story** or at the **epic**, set per project in the
internal config (`ga-granularity`; **default `epic`** since the PM↔EM alignment — one PRFAQ, one
epic, one GA). Epic mode is the norm for a non-technical founder:
the meaningful unit a founder can validate is the capability ("event ingestion works"), not the
slice ("the retry logic") — and the founder-grade evidence (QA on the running product, perf vs
SLOs, PM acceptance vs intent) already lands at epic completion. Story mode asks for the signature
where the evidence is thinnest for a non-engineer; epic mode asks for it where the evidence is
strongest. The gate **moves**; it does not vanish (the delegated-proceed precedent).

**VALIDATED 2026-07-15** on the first epic-mode epic to reach a human-signed GA: the signature was
changelog-verified against the human account and the story cascaded RC → Done stamping `GA-VIA-EPIC`.
(This file previously still read UNVALIDATED — a stale marker corrected 2026-07-20 when the default
flipped, since anyone judging whether epic mode is safe reads *this* file, not the internal config
that recorded the validation.)

## One PRFAQ = one GA (the rule the default serves)

A PRFAQ describes one launch, so it maps to **one epic and one signature**. Story-level GA is not a
lighter alternative to that rule — it is a **carve-out for risk**, and only for the surfaces listed
below. Deferred scope does not get a second signature on the same PRFAQ; it gets its **own** PRFAQ,
its own epic, and its own GA (contract work-tiers, deferred scope).

**Severity carve-out — these keep story-level sign-off regardless of mode:** security, auth,
tenant-boundary, data-migration, and payment surfaces. The reasoning is unchanged: these are where a
per-story signature genuinely buys risk reduction rather than ceremony.

**In-flight work is not re-moded silently.** An epic already running when the default changed keeps
the mode it started under until the founder says otherwise; the orchestrator's one-time
reconciliation pass (`GA-MODE-RECONCILED:`) enumerates them and asks per item.

## Story mode (the severity carve-out, and any project explicitly set to it)

Every story: RC → human GA Signed → merge → Done; none of the epic mechanics below apply. This is
**no longer the default** — it is the path a severity-carved-out story takes regardless of mode, and
the path a project takes only when its config row sets `ga-granularity: story` on purpose.

## Epic mode — the mechanics

- **Stories merge at RC.** When every governance verdict lane shows `VERDICT: PASS` and the live
  AC + constraints equal the snapshot, the orchestrator runs the merge train **then**, not after
  GA — producer pre-flight, branch protection, the stacked-merge rules, and the `Merge Record` are
  all unchanged; only the timing moves. The story then **waits at RC**. Without merge-at-RC the
  epic-completion checks would have no assembled product to drive.
- **Stories never enter GA Signed** (carve-outs below excepted). Invariant 4 is untouched in the
  direction that matters: agents still never transition **anything** into GA Signed, and the
  GA-guard automation stays armed. What changes is where the human's signature sits.
- **The Epic GA package** replaces N per-story asks with one epic-level decision. When every story
  is at RC + merged and the epic-completion checks (QA, perf, PM acceptance) have run, the
  orchestrator posts a `## Epic GA package` heading comment on the epic: the job-to-be-done, a
  consolidated per-story validation guide (each story's per-AC open-X/do-Y/expect-Z steps, in the
  founder's language), the QA / Perf / PM Acceptance verdicts, the Merge Record, the cost summary,
  and the explicit non-goals. The founder signs one thing, informed.
- **The human signs the EPIC** RC → GA Signed — the one GA click. The orchestrator verifies the
  transition actor from the Jira changelog (human, never an agent-written field), then **cascades
  the stories RC → Done**, stamping each with a `GA-VIA-EPIC: <epic-key>` marker comment so the
  audit trail is greppable per story, transitions the epic to Done, and dispatches retro.
- **Severity carve-out.** A story whose AC or constraints touch security, auth, tenant-boundary,
  data-migration, or payment surfaces (the same list as the bug-path delegated-proceed carve-out)
  takes the **story-mode path even under epic mode**: explicit story-level human GA before its
  merge. The orchestrator flags these at Refined from the AC + constraints; when in doubt, carve
  out. Epic mode never becomes a door around the human gate for the highest-stakes changes.
- **Bugs.** A Bug fixing a defect inside an epic still in flight rides that epic's mode. A
  standalone Bug against an already-GA'd product is its own unit and takes explicit story-level GA
  (or the founder's bug-path delegated-proceed where granted).

## The honest cost: rejection after merge

Under epic mode, code is in `main` before the founder's signature. `main` is pre-release — the
GA signature governs release-readiness, not the merge — but if the founder **rejects at epic GA**,
the merged code does not un-merge itself: the founder names the gaps, they become rework stories or
Bugs in the same epic, and the epic returns to the loop; reverting merged code is a founder
decision surfaced to the human queue, never an automatic rollback. A founder who wants nothing in
`main` without a signature should keep `story` mode. This trade-off is the mode's price and is
stated here so it is chosen, not discovered.

## Enforcement honesty

Same standing as the rest of the gates: the hard controls are the GA-guard on GA Signed
(empirically verified across live projects) and branch protection on merges; the mode's routing —
merge-at-RC, the package precondition, the actor check before the cascade, the carve-out — is
orchestrator + agent compliance, named alongside the other soft controls.
