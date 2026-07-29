# Brief-carried rules — full text

The dispatch brief, never a per-skill edit, carries the shared rules. This is the authoritative
expansion of the body's "Brief-carried producer rules" bullet plus the all-subagent rules: the
orchestrator folds the applicable rules below into every dispatch brief verbatim-or-equivalent. A
rule that rides in the brief binds the subagent exactly as if it stood in its own skill.

## The founder-summary rule (every subagent, every artifact)

**Every `## Heading` artifact comment ends with a final paragraph beginning `**Founder summary:**`**
— one paragraph, plain, non-technical language a non-engineer founder reads in thirty seconds:

- **what this was meant to do** (the intent, in product terms — not the mechanism),
- **what was actually built / changed / decided / found**, and
- **where possible, how the founder can see or validate it themselves** (what to open, what to do,
  what they should see) — for a verdict, what was checked and what the outcome means for shipping.

No jargon, no tool names, no run-ids, no severity codes in the summary paragraph — those live in
the technical body above it. The summary never replaces the artifact's technical content and never
softens a FAIL: a bounce's summary says plainly what is broken and what happens next. Applies to
every artifact writer — upstream authors (brief, research, architecture, PRD, design), producers
(producer notes), every verifier (all verdict lanes), QA/perf/audit/PM/retro — and the orchestrator
holds its own posts (Merge Record, RC advisory, Epic GA package, epic Cost notes) to the same rule.
Founder-approved 2026-07-15: the founder reads Jira as the product record; every post must be
legible to them without a translator.

## Digest precedence (existing products)

On a `hydrated` repo, the brief points the producer at the codebase digest
(`.agency/codebase-map.md`) and the repo `CLAUDE.md`/`AGENTS.md`, and states the precedence
plainly: **the repo's real conventions and architecture win over the producer skill's house
defaults wherever they differ.** Greenfield repos have no digest; the house defaults stand.

## Bug mode (the brief for a confirmed Bug fix)

**Reproduce the defect, add a regression test that fails before the fix and passes after, then make
it pass** — fix the root cause triage identified, not the symptom, and stay inside the confirmed
fix scope. The test verifier confirms the regression test genuinely catches the bug.

## Fan-out (the brief under `fast` pace)

The loop runs at a **pace** set at start — `fast` (default) or `thorough` (kill-switch). Under
`fast`, the brief adds the contract's fan-out protocol: **≥3 genuinely independent file-units and
budget allowing** → fix the shared interfaces first, fan out one sub-implementer per disjoint unit,
integrate, open **one PR**. Below the threshold, or on a projected per-story budget breach, build
inline (a `small`-governing-tier story always is inline). `thorough` forces inline. Record the pace
in the cost note. Producer-never-verifies untouched: sub-implementers live inside the producer's
identity; the trio still gates and catches an incoherent parallel build as a normal FAIL.
UNVALIDATED — the first fan-out stories are its proving ground.

## Pre-flight (no PR on red)

Run the repo's **own** gates — build, full suite, lint/static — before opening the PR, and attach
the command list + results to producer notes. A PR opened with failing repo gates is a
**producer-attributable bounce**. (Contract Work tiers → Producer pre-flight; the repo-wide
pre-flight run is also one of the two whole-repo nets the verifiers' blast-radius scoping counts
on — the other is the merge-train green-verify.)

## The endpoint-level test rule

An AC naming an HTTP status code, an endpoint, or "the request/endpoint returns …" needs a test
driven through the **real route/handler surface**, not an internal-guard unit test alone
(run-tests gates it; founder-approved retro proposal 2026-07-05).

## The pinned-verdict-values rule

**Every value a verdict or decision reads — a threshold, a label, a flag, a comparison bar — is
pinned, integrity-bound, and boundary-tested.** Concretely: the value lives in a pinned,
hash/tamper-guarded config (never restated inline where it can drift); any comparison the verdict
depends on is symmetry-checked (both sides on the same operating point — corpus, hardware, load);
and a mechanical test pins the boundary (at-the-bar, just-under, just-over). Evidence: three
same-class RC-blocking security bounces on one live epic — an unstamped `reportable` flag made
fabricated results indistinguishable, an unpinned per-config supplement allowed a false GREEN from
mismatched operating points, and an unbound threshold survived to a third story — each caught by
redteam only after a full build+trio round (~650–900k tokens each). Build it pinned the first time.

## Commit incrementally (resumable producers)

**Push work-in-progress to the story branch as coherent chunks land** — never hold the whole build
uncommitted in the worktree. A producer that dies mid-run (API error, rate limit, crash) must be
resumable by a fresh dispatch **from the branch**, not by rebuilding from zero. Evidence: two
mid-run producer deaths on one live epic; one lost its entire uncommitted build. WIP commits are
squashed at merge (the merge train squashes), so branch hygiene costs nothing at `main`.
