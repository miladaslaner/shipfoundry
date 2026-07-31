# Lessons

Cross-cutting operating lessons that no single skill's changelog can fully capture —
build incidents, direction locks, drift triggers, repeated mistakes. Read this at the
start of a working session; append to it when something bites you that spans more than
one skill.

Each entry: a date, what happened, the root cause, and the rule that prevents a repeat.
When a lesson is mechanically checkable, build the check into `lint-platform.sh` instead
of (or as well as) writing it here — an invariant enforced by a command that exits
non-zero beats one enforced by memory.

---

### 2026-06-26 — Root-level governance docs are outside the executable gate

**What happened.** An external `CLAUDE.md` (Boris Cherny's general operating-principles doc) was added to the repo root as `BORIS-CLAUDE.md`. `./lint-platform.sh` exited 0 — a second, partially-conflicting operating contract entered the repo and no check noticed.

**Root cause.** The lint gates `skills/` and `dist/` only. `CLAUDE.md`, `docs/platform/*`, and any other root governance doc are ungated, so drift or a competing contract is invisible to the platform's own enforcement — the exact "invariant enforced by memory, not by a command" the governance model condemns.

**Rule.** Keep ONE active operating contract (`CLAUDE.md` + `docs/platform/operating-model.md`). External references may live in the repo but must be clearly marked reference-only and must not duplicate the active contract. The genuinely-additive reflexes from Boris's doc (prove-it-works / behaviour-diff / "would a staff engineer approve this?") were folded into the reflexes line above; the standalone file was removed rather than kept as a second source of truth.

**Mechanically checkable → build the check.** A future `lint-platform.sh` check should (a) assert CLAUDE.md's skill inventory/tree matches `skills/`, and (b) flag any unexpected root-level `*CLAUDE*.md` / governance doc that isn't an allowlisted reference. Until that check exists, this lesson is the memory-enforced stand-in.

---

### 2026-06-28 — "Produced but never read": the dangling-artifact bug class

**What happened.** Across the jarvis-agency workbench, a skill kept producing an artifact or on-issue lane that a downstream skill was *claimed* to consume but did not actually read. The author-prd skill did not read the Requirements Brief it was supposed to expand (so the PRD could silently drift from the locked launch). The same brief turned out to be read by only 2 of 7 downstream stages despite the contract asserting it was "inherited by every downstream stage." Research, design, and the AC critic ignored it; the brief's non-functional answers (failure modes, operability, data, SLOs) never reached the build because the producers read the frozen AC snapshot, not the brief. Separately, four skills carried a stale "until a dedicated artifact-quality verifier exists" note after that verifier was built. The structural lint, the test suite, and the eval dry-run were all green throughout — none of these are mechanically detectable today.

**Root cause.** Adding a new upstream artifact (a brief, a constraint set, a verifier) is a *two-sided* change: the producer side and every consumer side. It is easy to write the producer and the contract's claim of inheritance, and forget to wire each consumer to actually read it — or to leave a now-false "X does not exist yet" note when X ships. Prose claims of inheritance ("inherited by every downstream stage") drift from the code because nothing checks them.

**Rule.** When you add or change an inherited/upstream artifact or a cross-cutting capability: (1) grep every downstream `SKILL.md` for whether it actually *reads* the artifact, and wire the ones that should; (2) decide and state honestly whether each consumer reads it *raw* or *compiled* (e.g. the brief reaches producers compiled into AC + constraints via the snapshot, not raw) — do not claim universal inheritance the code does not deliver; (3) grep the whole `skills/` tree for stale "does not exist yet / backlog item" notes about the thing you just shipped. An independent E2E seam-trace (a fresh agent reading every SKILL.md for handoff gaps) catches this class; the mechanical gates do not.

**Mechanically checkable → build the check (partial).** Hard to fully automate (it is semantic), but a lint heuristic could flag a config lane that no `SKILL.md` mentions as a reader, and grep for stale "verifier … backlog"/"does not exist" phrases against the installed-skills list. Until then, the E2E seam-trace + this rule are the stand-in.

---

### 2026-06-28 — The behavioral eval harness is single-turn; interactive skills under-grade

**What happened.** A behavioral smoke (`eval-runner.sh --allow-nested`) on the intake skill kept failing a first-principles scenario even after the skill was fixed (3/5 → 4/5). The skill is a multi-turn *interrogation*: it challenges the founder, the founder answers, then it locks the brief. But `eval-runner` is single-turn (one query → one response → judge). On turn one the model correctly tags the assumptions it can see and *defers* the complete register, because finishing it would mean fabricating answers the founder has not given — which the skill explicitly forbids. The eval demanded the final locked artifact in one shot, so it scored a correct response as a partial fail. Separately, the Working-Backwards scenario failed with "no parseable judge output" twice — the judge model could not parse a very long execution (full PR/FAQ + checklist + register + decomposition).

**Root cause.** Two harness limits, neither a skill defect: (1) a single-turn eval cannot grade a skill whose correct behavior spans turns; (2) the judge chokes on very long executions. Both are invisible to the lint and the dry-run, which only check structure/assembly.

**Rule.** (a) Write eval `expected_behavior` for what is observable on the turn the harness actually feeds — for an interactive skill, assert the turn-one behavior (challenge, tag, commit to the artifact) not the end-state artifact; do not demand a multi-turn outcome from one response. (b) For variance-prone behavioral gates use `--samples N` (majority verdict) rather than trusting one sonnet-judge run, and consider a stronger judge for long outputs. (c) A behavioral *smoke* is for confirming the harness runs and surfacing gaps, not for chasing 100% — stop when the signal is clear; the runs cost ~$0.7–0.9 each. (d) Distinguish a real skill failure from a harness artifact ("no parseable judge output" = tooling, not grade) before "fixing" the skill. The dry-run validates assembly; only a real model run (in a terminal/CI, not nested in a session) validates behavior.

---

### 2026-06-29 — First live run: where Jira state lives matters as much as what it says

**What happened.** The first real end-to-end run took an epic from intent to four merged, GA-signed stories. The loop and its core invariants held (producer-never-verifies caught a vacuous test and a flaky-gate regression on Story D; the GA ceiling held on the changelog; the max-bounce escalation correctly did NOT fire under its ceiling). But three seams a simulation could not show surfaced: (1) the orchestrator tried to record the intake approval by rewriting the ~18 K description to flip a `## Intake approval` marker, and `editJiraIssue` **failed JSON parsing** — it fell back to a comment, but the contract's re-read convention pointed at the description, so a later loop pass would not have found the cleared gate; (2) the PRD **overflowed Jira's 32 K description ceiling** and landed as a comment as an unplanned deviation; (3) a naive bottom-up **stacked-PR merge landed a PR into its stacked base, not `main`**, because GitHub only auto-retargets a stacked PR when the branch below is *deleted*. Each was caught and self-corrected in the run, but only by luck and vigilance, not by the contract.

**Root cause.** The contract specified *what* each lane holds but was loose about *where* it physically lives ("description field or field"), and assumed large narrative artifacts fit in a description that has a hard 32 K ceiling and is failure-prone to rewrite. A control signal that a later pass must read (intake approval) was specified to live in the one place that could not be reliably written. This is the [[produced-but-never-read]] class one level down: not "no consumer reads it" but "the writer cannot reliably write it where the reader looks."

**Rule.** On this MCP, **storage is comment-first**: `editJiraIssue` only for the live AC + type label (description) and the assignee on claim; every narrative artifact is a `## Heading` comment and every orchestrator control signal is a one-line `MARKER:`-prefixed comment (latest matching wins), via `addCommentToJiraIssue`. Never flip a large description section to record a gate signal — append a marker comment a later pass can grep. For any multi-PR delivery, drive the merge as a deliberate train (merge-and-delete bottom-up so the next auto-retargets, or retarget each PR to `main` first) and **verify `main` actually contains each story's files and builds green** before marking Done. And at RC, the advisory comment must tell the founder the job-to-be-done, what they can validate now, and what is explicitly out of scope this slice — in the run the founder reached RC and had to ask what they were even validating.

**Mechanically checkable → build the check (partial).** A lint heuristic could flag any agency `SKILL.md` (or the config) that still routes a lane to a "description field" for the orchestrator-owned signals, and assert the marker-prefix set is the same across the contract and orchestrate. The merge-train and RC-advisory rules are behavioral; this lesson plus the skill text are the stand-in.

## Branch protection: test the wall, and never `always`-bypass (2026-07-03)

GitHub Pro enabled protect-main rulesets on all agency repos. Two lessons from the first setup:

1. **`bypass_mode: always` is a self-defeating wall.** Everything — founder and agents alike — runs
   as the repo-admin account, so an always-bypass silently exempted the only actor the rule was meant
   to stop; the empirical probe push sailed through. The correct mode is `pull_request`: direct
   pushes die with GH013 for everyone; the emergency hatch is an explicit `--admin` PR merge.
   onboard 0.1.4 bakes this into the ruleset recipe.
2. **Never trust a settings read-back — test the control empirically.** The ruleset read back as
   "active" and looked right; only an actual probe push revealed the hole (and note: a local
   pre-push hook can shadow the remote wall — the first probe was blocked by the hook, not GitHub,
   and would have passed for false comfort). Same family as the GA-guard live test: a control is
   proven by attempting the forbidden action, not by reading its config.

### 2026-07-05 — UNVALIDATED flags go stale silently; run-history claims must be checked against Jira

**What happened.** A repo-wide assessment claimed a mechanism had "never been used", based on the
repo's own `UNVALIDATED` flags. A live check of the execution ledger showed it HAD run — as had
several other flagged mechanisms. The flags were written when the mechanisms shipped and never
reconciled after the runs.

**Root cause.** A validation flag is a *claim about run history* stored in the repo, but run
history lives in Jira (invariant 1: Jira is the source of truth). Nothing — no check, no playbook
step — reconciles the two, so every flag is accurate only at the moment it is written. The same
paperwork-over-reality failure the assessment itself was built to catch, made by the assessor.

**The rule.** (1) Never assert whether an agency mechanism has run from repo text alone — grep the
Jira record (`## Run Report`, verdict lanes, `PRODUCED-BY:` markers) first; the flags are a hint,
not evidence. (2) When a run exercises a flagged mechanism, reconciling the flag (with the issue
keys as evidence) is part of closing the epic — retro's Run Report is the natural trigger: it
should name which flagged mechanisms the run exercised, and the founder-approved follow-up updates
the flags. (3) Prefer flags that state their own clearing condition ("UNVALIDATED until a
concurrent multi-story wave runs") over bare labels — the 2026-07-05 reconciliation rewrote the
surviving flags in that form.

### 2026-07-07 — A stacked platform PR merged into its stale base, silently missing `main`

**What happened.** A five-producer expansion PR (call it **B**) was opened stacked on an earlier PR's branch **A** (`feat/producer-expansion-stream`) so B's diff showed only the new waves. Both were squash-merged within seconds of each other — but A's branch was not deleted first, so GitHub never retargeted B's base to `main`. B "merged" green into the stale feature branch; `main` silently lacked five skills the maintainer believed had landed. Caught only because the next session pulled `main` and found the producers absent; recovered by cherry-picking B's squash commit onto `main` (this entry ships in that re-land PR).

**Root cause.** GitHub only auto-retargets a stacked PR's base on branch *deletion*, not on merge. The agency's orchestrator documents exactly this trap for its own story merge trains (the GA-row stacked-PR rule: merge-and-delete bottom-up, or explicitly retarget before merging) — but the *platform repo's* human PR flow had no equivalent rule, so the same failure bit the maintainer instead of the agents.

**Rule.** In this repo, stack PRs only when necessary; when you do, merge bottom-up **and delete each branch on merge** (or `gh pr edit <n> --base main` before merging the upper PR), and after any multi-PR landing verify `git log origin/main` actually contains every expected change before building on it. A merged-PR state on GitHub is not evidence the change reached `main`.

**Mechanically checkable → partially.** The post-merge verification is the checkable half: after landing a stacked train, `git ls-tree origin/main` for the expected new paths. A CI check cannot see the maintainer's intent (which PRs form a train), so the merge-and-delete discipline stays memory-enforced here — same status as the orchestrator's rule, which is at least skill-encoded for agency runs.

### 2026-07-07 — An Edit anchored on a phrase that also lived in the changelog landed content in the wrong place

**What happened.** Adding the eBPF adversarial clause to `jarvis-agency-redteam-security`, the Edit anchored on "A memory-corruption or trust-boundary defect in native code is RC-blocking by default." — a phrase that appears in BOTH the operative body (the `native` branch) AND the 0.1.3 changelog entry. `Edit` replaces the FIRST occurrence, and the changelog sits above the body, so the clause appended to the changelog. Result: the changelog and the build-native producer both claimed the security verifier covered eBPF, but the verifier's operative body had only the generic native pass — an eBPF sensor PR would miss the eBPF-unique holes (unprivileged-BPF load, world-readable pinned maps, map-content exfiltration, verifier-defeat). Every structural gate was green; the adversarial `producer-expansion-review` workflow caught it (major finding), and it was moved into the body.

**Root cause.** Skill files repeat body phrasing inside changelog entries (a changelog paraphrases the edit), so a body sentence is rarely unique file-wide. `Edit` with `replace_all=false` takes the first match — the earlier changelog. The author then reads the changelog as confirmation ("Deepened the native branch with eBPF") and never re-checks the body.

**Rule.** When appending to a skill BODY via Edit, anchor on a string unique to the body — include the FOLLOWING body context (e.g. the next section header) in `old_string`, not a trailing sentence the changelog also quotes. After the edit, grep the body specifically (`sed '1,/^---$/d' file | grep`) to confirm the content landed below the frontmatter. A changelog claim is not evidence the body changed.

**Mechanically checkable → partially.** Lint check 17 now greps the verifier BODY only (not the whole file), so a per-stack LABEL branch deleted from a body while its changelog mention remains is caught. But eBPF carries no label (it rides under `native`), so sub-stack content like this stays review-caught, not lint-caught — which is why the adversarial review pass is a standing part of a producer wave, not a one-off.

### 2026-07-13 — The platform's own gates had silent-success failure modes (diagnostic scan)

**What happened.** A one-off diagnostic scan of the platform found a batch of defects. The dominant
class was silent success: a gate that reported OK without having actually checked anything.

**Root cause.** Each checker was written assuming sane input and honest sub-tools: nothing asked "what does this tool do when its target doesn't exist, its sub-command fails, or its data source changes shape?" A gate whose failure mode is silence is worse than no gate — it manufactures false confidence, which is the exact product a gate exists to prevent.

**Rule.** Every new gate, build step, or tool in this repo must have three properties on the day it lands: (1) **loud failure on nonsense** — an explicitly named target that resolves to nothing exits non-zero with a message, never a vacuous pass; (2) **a behavioural test wired into CI** the same day (a check nothing runs is a memory-enforced invariant wearing a costume); (3) **machine-readable handoffs only** — never parse another tool's human-readable output; exchange exit codes, JSON, or a stable `KEY=value` line.

**Mechanically checkable → largely built.** The findings were converted into machinery: lint checks 18 (semver), 19 (TODO placeholders), 20 (producer-skeleton parity); `tests/run-tests.sh` in CI with per-gate rc propagation; the `EVAL_COST_USD=` machine handoff; the org-key scanner pattern. The residue that stays judgment-enforced is this rule applied to FUTURE tooling — plus the same lens propagated to agency-built products via the verifiers (review-code 0.2.4 silent-success clause, run-tests 0.2.6 vacuous-test screen, audit 0.1.4 divergence + format-coupling tells).

**On `VIBE-nnn` markers.** Codebase comments cite finding IDs from the 2026-07-10 diagnostic scan.
The durable record of that scan is this file's 2026-07-13 entry; the working plan was retired once closed.

### 2026-07-13 — `| grep -q` under pipefail is a race that makes gates flake (and can silently mis-branch)

**What happened.** A required `lint` CI check failed on check 17 ("code label `infra` has no branch in jarvis-agency-run-tests") — on a file the PR never touched — while a second run of the SAME commit passed. The log had the tell: `sed: couldn't write 25 items to stdout: Broken pipe`. `grep -q` exits on its first match and closes the pipe; the upstream writer takes EPIPE; under `set -o pipefail` a SUCCESSFUL match becomes a non-zero pipeline. Whether the writer finishes before grep exits is a buffering race, so the gate flaked. The same pattern sat in eval-runner's clean-room probe (`claude --help | grep -q -- '--setting-sources'`), where the wrong branch is worse than red: it silently degrades every eval call to a bare (no clean-room) run.

**Root cause.** `-q`'s early exit is an optimization that is unsafe in a pipeline under pipefail: the pipeline's exit code stops meaning "did grep match" and starts meaning "did the writer survive grep leaving". False-red on `|| fail` sites; on `if pipeline; then` sites it can take the wrong branch in either direction. macOS/BSD locally masks it (different buffering and SIGPIPE handling), so it surfaces only in CI — the worst place for a flake.

**Rule.** In any script with `set -o pipefail`: grep in a pipeline must read its whole input — `writer | grep PATTERN >/dev/null`, never `writer | grep -q PATTERN`. (`grep -q` on a FILE argument, no pipe, stays fine.) Fixed at all 5 sites (lint-platform.sh ×4, eval-runner.sh ×1).

**Mechanically checkable → built.** tests/cases/gates-wiring.sh now asserts zero `| grep -q` pipelines in every pipefail gate script, so the pattern cannot come back.

---

## 2026-07-20 — Absence in a biased sample is not evidence of absence

**What happened.** During the first live vault-first run I checked whether the GA guard (*confirm
from the changelog that the RC → GA Signed transition was performed by a human, not an agent*) could
actually distinguish the two actors. I opened one story's changelog, saw all six entries authored by
the same "AI Agent" account, and reported that the instance had **one identity**, so the guard was
unenforceable — calling it "a compliance convention, not a control".

**It was wrong.** The instance has two accounts: `AI Agent` (dedicated to the agency) and the
founder's own. The story I sampled was an agent-driven build, so *every* transition on it was
necessarily agent-authored. I sampled a set that could not have contained the evidence I concluded
was missing. One `lookupJiraAccountId` call, or one glance at a human-closed issue, would have
settled it — a founder-actored transition shows a plainly different `accountId` and display name.

**Why the error was easy to make.** The observation was real and the sample was consistent; only the
*inference* was invalid. Worse, it was a satisfying finding — it looked like the run had uncovered
something important, which made it attractive enough that the uncertainty noted while reasoning
("I could not find a founder-actored entry to compare") got dropped from the write-up instead of
becoming the headline caveat. Sharp-sounding findings deserve *more* scrutiny before publication,
not less.

**Rule.** To claim a distinction does not exist, **enumerate the population, do not sample the
behaviour.** For identity specifically: verify with a directory lookup, never by inspecting who
happened to act on one issue. And when a claim rests on absence, either state the search that would
have found the counter-evidence, or do not make the claim.

**Mechanically checkable → worth building.** An onboarding probe asserting the configured agent
`accountId` differs from the configured human signer's would turn the GA guard's premise from an
assumption into a checked precondition. Now known to PASS on the playground instance — so the probe
is cheap insurance, not a blocker.

---

## 2026-07-20 — Never squash-merge the bottom of a stacked PR chain

**What happened.** Five PRs were stacked (`main ← A ← {B,C,D} ← E`). Merging the bottom one
with `--squash --delete-branch` did two damaging things at once: the squash **rewrote** the branch's
three commits into one new SHA, so every child branch still carried the *old* commits and instantly
conflicted; and deleting the base branch **auto-closed** the three children, which cannot be reopened
or retargeted (`Cannot change the base branch of a closed pull request`). Three PRs and their review
history were lost, and each had to be rebuilt on `main` and reopened under a new number.

**What made it recoverable.** Each branch happened to carry exactly one commit of its own on top of
the shared base, so `git checkout -B <branch> main && git cherry-pick <sha>` reconstructed each one
cleanly. Had the branches carried interleaved work, this would have been a genuine untangling job.

**The second-order damage.** An untracked planning document, created while sitting on one branch,
followed `git checkout -B` onto another and was swept in by `git add -A` during conflict resolution —
landing in a PR whose description never mentioned it. `git add -A` during a cherry-pick conflict
stages *everything*, including files that were never part of the change.

**Rule.** For a stacked chain: **merge with a merge commit, not a squash**, and **do not delete the
base branch until every child has been retargeted to `main`**. Retarget first, merge second, delete
last. If squash is required by policy, then do not stack — land each change on `main` in sequence,
rebasing the next one after each merge. And during a conflicted cherry-pick, stage the conflicted
paths by name rather than reaching for `git add -A`.

**Mechanically checkable → partly.** The repo already documents the *retarget* half of this hazard
(orchestrate 0.2.13, from a live run). The squash-and-delete half is a GitHub-side behaviour no local
lint can see. What is checkable is the second-order damage: a pre-commit hook could refuse a commit
whose staged set includes files untracked on the branch's merge-base — worth considering if it
recurs.

---

### 2026-07-21 — A rule changed where it is stated, not where it is consumed

**What happened.** A validation sweep of the agency workbench turned up 23 findings. They were not
23 different bugs — they were one bug, 23 times. In every case a rule was changed at its point of
*statement* and left untouched at every point of *consumption*:

- The **PRFAQ moved** from `intake` to `pm`, and `author-prd` still read it out of the Requirements
  Brief where it no longer lives.
- The **GA-granularity default flipped** `story` → `epic` in a reference file, while the contract
  body, the per-project registry and the operator guide all kept saying `story` is the default.
- The **law gained a third review state**, and the law's own numbered procedure still enumerated two.
- Two contradictory **`PM Acceptance`** rows sat in a single config table, both current.
- Governance slot files disagreed with each other: `repo-config.md` set a real `jira_project_key` while
  `run-counter.md` declared the repo `UNSET` and told readers to skip the drift sweep — a botched
  find/replace that turned an explanatory sentence about `UNSET` into a false claim about this repo.

`./lint-platform.sh --strict` exited **0** on all of it, as did the tests and the eval dry-run.

**Root cause.** Changing a rule feels complete when the authoritative sentence is correct. But a rule
in this system has *consumers*: every skill body that restates it, every reference file that
elaborates it, every config row that parameterises it, every eval assertion and fixture that pins it,
and every doc that teaches it to a human. A changelog entry records that the statement moved. It is
**not evidence that any consumer moved** — and nothing was checking.

**This is the third time.** The [[produced-but-never-read]] family (2026-06-28) and its follow-ups are
the same shape: an artifact or rule with a claimed reader that does not actually read it. It is also
the second appearance of changelog-claims-what-the-body-does-not (2026-07-07). Both prior entries
ended with "until that check exists, this lesson is the memory-enforced stand-in." Recurrence at this
rate is the evidence that the stand-in does not work: memory does not survive a wave of parallel
edits, and it never will.

**Rule.** **When you change a rule, enumerate its consumers and fix them in the same change.** Before
editing, grep for the rule's distinctive phrasing and for its old *value* across `skills/`,
`reference/`, the config tables, `evaluations/`, fixtures, and `docs/` — that list is the change's
scope, not follow-up work. Two corollaries: a changelog entry is never evidence a consumer moved; and
a value that appears in more than one place needs either a single source or a check that compares
them, because sooner or later a find/replace will hit one copy and not the others (or hit the wrong
sentence, as `run-counter.md` shows).

**A sibling recurrence in the same sweep.** An internal feasibility review concluded
that one product was the whole population, from a top-level `ls` that missed a nested checkout — a
second product had been running agency work all along. That is the **2026-07-20** lesson (*"to claim a distinction
does not exist, enumerate the population, do not sample the behaviour"*) repeated **nine lines of
reasoning after it was written, in the same document**, and it propagated into a deferral rationale
and a "wait for the first console epic" trigger for an epic that had already GA-signed before it was
written. Writing a lesson down does not install it. The same conclusion applies: enumerate, or do
not claim.

**Mechanically checkable → being built.** The new lint checks landing alongside this entry are the
partial mechanisation: parity checks that compare a stated default against every place that restates
it, and consumer checks that assert a named artifact's claimed readers actually reference it. They
cover the copy-divergence half. The half no lint can see — a rule whose consumer paraphrases it
rather than quoting it — stays a review obligation, which is exactly why the enumeration step belongs
in the change, not in memory.

---

## 2026-07-21 — A safety rule written absolutely becomes a denial of service

**What happened.** Closing the "produced but never read" class, I taught five upstream skills that a
Jira `## Requirements Brief` comment is a *pointer* and that "an unresolvable pointer is a stop, not
a licence to work from the stub". The rule is correct. Stated absolutely, it was applied as
refuse-by-default. Over one session the same shape surfaced **seven times, in seven skills**:

| Skill | The rule | What it became |
|---|---|---|
| author-prd, design, research, critique-acceptance, architect | don't work from a stub | produced nothing when the brief's content was present **inline**, or when no brief was referenced **at all** |
| qa, perf | don't improvise an environment | refused to test when an environment existed but no `ENVIRONMENT:` **marker** did |
| pm | don't author the human's walkthrough verdict | wrote **nothing** — blocking its own pre-screen, a document review that never needed a running product — and began declaring "gate unmet" and bouncing work, breaking advisory-only |
| verify-artifact | a digest must cover its subsystems | failed a digest for **honestly declaring** its one undetermined subsystem, punishing the exact behaviour the bar asks for |
| intake | a missing PRFAQ routes back to the PM | refused the **whole pass** — altitude, interrogation, register, decomposition, coverage map — so a founder arriving through capture with raw intent got a deferral and **nothing to approve** |

The last one is the worst placement in the system, and the skill's own body contradicted itself two
paragraphs apart: step 0 says interrogate from raw intent when no shaped intent exists; step 2 said
stop.

**Root cause.** The author writes a prohibition holding the counterexamples in mind. The agent
reading it has only the prohibition. Absent the permitted cases, the safe reading is to refuse, and
refusing always *looks* like compliance — which is why it survives review: every one of these
produced a confident, well-reasoned explanation of why it was correct not to act.

**Why nothing caught it.** `lint --strict` was 0 FAIL / 0 WARN through all seven — 27 checks, 209
tests, green before, during and after. No static check can know how a model will *interpret* a
sentence. Only running the skills found them, and the full behavioural sweep that did (~$30, ~190
scenarios) is far too expensive to be routine.

**Compounding cause: I fixed instances, not the class.** Seven times. Even after the second and
third, I never asked "where else did I write this shape?" And I had *centralised the rule* — five
skills cite the contract's canonical section rather than restating it — but each skill still carried
its **own local phrasing of the refusal**. So the central fix landed and the five local prohibitions
kept doing the damage. Centralising a rule while duplicating its prohibition centralises nothing.

**A near-miss worth recording.** Assessing the ~31 remaining sweep failures, I judged them "probably
scenario design, not defects" from their shape. That was right for 26 and **wrong for the 5 that
mattered most** — the intake stall. The inference was reasonable, well-evidenced, and would have left
the front door broken. When a pattern-match would let you skip verifying, that is exactly when the
verification is load-bearing.

**Rules.** (1) A constraint states its **permitted cases**, not only its forbidden one — write the
decision table (CLAUDE.md best practice #8). (2) A skill inheriting a shared constraint **cites it and
adds no prohibition of its own**; needing different wording means the shared rule is underspecified,
so fix it there. (3) After changing any rule that constrains behaviour, grep every skill that inherits
it for the same absolute *shape*, not just the same words.

**Mechanically checkable → partly, and honestly so.** Lint check 28 flags an absolute-refusal clause
with no permitting case nearby — a prose heuristic that cannot know intent, hence WARN. The **stall
probe** (evaluation-strategy.md) is the real mechanisation: two fixed-template scenarios per touched
skill asking "input absent — do you still do your job?" and "artifact honest-but-imperfect — do you
still pass it?", ~$1–2 per change instead of ~$30, and it would have caught six of the seven directly.
Check 29 makes the behavioural run itself auditable: a minor/major bump with no recorded eval receipt
is a warning. What none of this covers is a skill that is subtly *wrong* rather than subtly
*refusing* — that still needs the full gate and a human reading the output.

---

### 2026-07-31 — The repo documented a safety net it did not have

**What happened.** `CLAUDE.md` has told every session since the initial public release that
"a Stop hook also runs [the lint] automatically — see `.claude/settings.json`", and the project
structure tree listed `settings.json  # Stop hook → auto-runs the lint gate`. That file was `{}`.
`hooks/stop-lint.sh` existed, was executable, worked correctly when invoked — and was wired to
nothing. The automatic gate the docs promised had never once run. `./lint-platform.sh --strict`
exited 0 throughout, because no check compared the claim against the file.

**Root cause.** The hook body was stripped by the public-release scrub (the file is `{}` in the
initial public commit) while the two sentences describing it were not. Nobody re-read them together
afterwards, and nothing could: a *claim about a control* was the one kind of assertion the platform's
own 36 checks did not cover. This is the [[produced-but-never-read]] family again — a claimed reader
that does not read — but pointed at the platform's own safety net rather than at a skill, which is
why it survived three lessons about the same shape. Note the second-order cost: the docs' promise
made the missing control *invisible*, because every session that read CLAUDE.md believed the gate
was already running.

**Rule.** A document may not promise a mechanical control without the control existing. When a scrub,
a rename, or a refactor touches a hook, a gate, or any other enforcement artifact, the change's scope
includes every doc that describes it — and if the description is load-bearing, it needs a check, not
a re-read.

**Mechanically checkable → built.** Lint **check 37** now closes both directions: a doc promising a
Stop hook must find one wired in `.claude/settings.json`, and a wired hook must resolve to a file
that exists and is executable (a rename or a lost `+x` silently disarms a hook while lint stays
green). It ships adversarially tested — unwiring the hook reproduces the original failure and names
`CLAUDE.md:28` and `:152` by line. Deliberately narrow: it resolves `hooks/*.sh` references, not
arbitrary shell, so a hook invoking something exotic is out of its reach.
