# Epic-completion checks — mechanism and boundaries

The SKILL.md carries the compact list; this file carries the full mechanism of each check.

Beyond the In Review code trio, the orchestrator dispatches epic-level checks (each a distinct
identity) — the contract's "Governance beyond the diff":

- **`jarvis-agency-qa`, per story at In Review when the story is independently runnable** — a smoke
  pass writing a `QA Verdict`; a blocker-severity finding is `VERDICT: FAIL` and bounces to In Progress
  like a trio fail. A non-runnable slice is **deferred** to the epic pass, not forced.
- **`jarvis-agency-qa`, at epic completion** (stories all Done/merged) — QA on the **assembled**
  product; it does not bounce merged work but **files a Bug per defect** (routed through the bug path)
  and surfaces the QA summary + filed Bug keys to the human.
- **`jarvis-agency-perf`, at epic completion** (only when the epic has a performance SLO) — load/stress
  tests the assembled product against the SLO targets on a **performance-representative non-prod
  environment** (never production, never per story), files a Bug per breach, and writes a `Perf Verdict`
  stating the environment; a breach surfaces to the human.
- **`jarvis-agency-verify-detection`, per `detection` story at In Review AND at epic completion** —
  the detection-efficacy gate. Per story it is a **fourth RC gate** alongside the trio (RC requires its
  `Detection Efficacy Verdict: PASS`; a FAIL bounces to In Progress like a trio fail): it replays the
  labeled attack corpus + generated evasion variants against the rule independently — fires on the
  malicious samples, survives reasonable evasion, silent on benign, ATT&CK mapping honest. At epic
  completion it judges the assembled detection **set's** coverage of the techniques the epic's AC
  claims (reporter — files a Bug per gap, does not gate the epic alone). Needs a replayable corpus + a
  rule-execution harness, else NEEDS_CONTEXT — never a faked pass, never a pass on the producer's word;
  a run-id collision with the producer is refused. Unlike QA/perf (epic-only reporters), this one
  **gates per story** for its stack.
- **`jarvis-agency-pm`, product acceptance at RC** (after QA/perf) — **mandatory to RUN whenever the
  epic is RC-ready and has a user-facing surface**. The trigger is **readiness + a user-facing
  surface**, *not* the presence of a `Shaped Intent`/PRFAQ artifact: a directly-captured epic that
  never went through PM discovery is **not** exempt — it is judged against whatever frozen standard
  exists (the locked scope note, the PRD, the AC), and a missing upstream artifact is reported as a
  gap, not treated as a skip.
  It is **not a document review**. It is the three-act, **human-performed** walkthrough (pm/SKILL.md
  step 3): (1) the PM **prepares** — confirms a usable `ENVIRONMENT:` and writes a per-promise
  walkthrough script in the founder's language (*what to open → what to do → what you should see →
  what failure looks like*); (2) a **human performs** it against the running build; (3) the PM
  **records their verdict verbatim and attributed** in the `PM Acceptance` lane. The PM's own read of
  the build is a **labelled pre-screen** and explicitly never the verdict. This is the built-the-
  **right**-thing lens, complementing the trio's built-it-right and QA's does-it-work; it files a Bug
  for a real gap and feeds the **RC advisory**.
  **Mandatory to RUN, advisory in OUTCOME.** The verdict — or a recorded skip/override — is a
  **precondition of the Epic GA package** (SKILL.md gate list; step 3 below), so an epic cannot be
  packaged with the walkthrough silently missing. But the *outcome* never gates: a gaps verdict
  informs the founder's GA decision, it does not bounce merged work, block RC, or sign GA.
  Producer-never-verifies holds (it judges the producers' build against the written standard, not its
  own output). Non-user-facing work records `PM-ACCEPTANCE: skipped — no user-facing surface`;
  user-facing work stuck at `ENVIRONMENT: … tier=none` has its own named exit — the **environment
  release valve** in [enforcement-gates.md](enforcement-gates.md).

QA and perf each need their prerequisite (QA: a runnable app + E2E harness; perf: a defined SLO +
representative environment + load harness). **Environment resolution belongs to the contract's
environment rule, not to any agency role** — the architect provisions nothing, and no skill in the
workbench stands one up; the RC row records what already exists. On a `NEEDS_CONTEXT` or `tier=none`
flag the human queue, never a faked pass. Neither gates RC by itself and neither
fixes — producer-never-verifies, QA-never-fixes, and perf-never-fixes all hold.

**On a founder's on-demand "full test pass / audit the product" request**, dispatch
`jarvis-agency-audit` (a distinct identity, not part of the loop, not in the RC trio) to sweep the
**whole product** for placeholders/stubs/not-actually-working across every stack. Route each Bug it
files through the bug path; surface its Audit Report to the founder. It does not trust the
per-story/epic record and never fixes; audit-never-fixes holds too.

**When an epic reaches Done (post-GA), dispatch `jarvis-agency-retro`** — the learning organ, also
founder-invokable on any closed epic. It harvests the run's record (bounce rounds + causes, verifier
catches, cost/wall-clock vs budget, human interventions) into a `## Run Report` on the epic and
drafts **evidence-cited improvement proposals** to its lane where a pattern repeats; surface both to
the founder. Proposals only — retro never edits a skill or config, never re-grades a verdict, never
bounces merged work, never gates; an approved proposal lands via the platform repo's gates.


## Epic-mode GA (GA granularity = `epic`; contract reference/ga-granularity.md)

When the project's config sets `ga-granularity: epic`, the epic — not each story — carries the
human signature. The orchestrator's mechanics:

1. **Merge at RC, per story.** A non-carved-out story whose verdict lanes all show `VERDICT: PASS`
   with live AC/constraints equal to the snapshot gets its merge train run immediately (stacked
   rules, main-builds-green verification, and the `Merge Record` exactly as the GA row specifies —
   only the timing moves). The story stays at RC. Post no per-story RC advisory ask to the founder;
   keep the per-AC validation-guide content — it folds into the package below.
2. **Carve-outs stay story-gated.** A story whose AC or constraints touch security, auth,
   tenant-boundary, data-migration, or payment surfaces takes the normal story-GA path (explicit
   human GA Signed before its merge). Flag these at Refined from the AC + constraints; when in
   doubt, carve out.
3. **Assemble the Epic GA package** when every story is at RC + merged (carve-outs GA-signed) and
   the epic-completion checks (QA, perf, PM acceptance) have run: a `## Epic GA package` heading
   comment on the epic carrying the job-to-be-done, the consolidated per-story validation guide
   (each story's per-AC open-X/do-Y/expect-Z steps, founder language), the QA/Perf/PM verdicts, the
   Merge Record, the epic cost summary, and the explicit non-goals. The package is a precondition
   of asking for the epic GA — no package, no ask.
4. **Stop.** The epic waits at RC for the human. The orchestrator never transitions the epic (or
   anything else) into GA Signed; the GA-guard stays armed.
5. **Cascade on the human's signature.** When the epic's RC → GA Signed transition appears, verify
   the actor from the Jira changelog is the human signer (never an agent-written field). Then
   transition each story RC → Done, stamping a `GA-VIA-EPIC: <epic-key>` marker comment on it (the
   greppable per-story audit trail), transition the epic to Done, and dispatch retro — the same
   closure the GA row already owns.
6. **Rejection path.** A founder who does not sign names the gaps instead: they become rework
   stories or Bugs in the same epic and the epic returns to the loop. Merged code stays merged;
   a revert is a founder decision surfaced to the human queue, never an automatic rollback.
