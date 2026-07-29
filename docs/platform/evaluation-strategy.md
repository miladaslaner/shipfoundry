# Evaluation strategy

How the platform measures skill effectiveness across model changes (Haiku/Sonnet/Opus) and version bumps. Grounded in Anthropic's evaluation-driven-development best practice.

## Current coverage (don't hard-code it — it drifts)

Evals live at `skills/<skill>/evaluations/baseline-evals.json`, format `{schema_version, skill, scenarios: [{id, query, expected_behavior: [...]}]}`. For the live coverage list, run:

```bash
for d in skills/*/; do
  [ -f "$d/evaluations/baseline-evals.json" ] && echo "EVAL $(basename $d)" || echo "----  $(basename $d)"
done
```

## Coverage by leverage, not by count

The goal is never a coverage *count* — it's *order*: evaluate the highest-leverage skills first.

1. **The global foundation skill** — every other skill depends on it, so a regression here propagates platform-wide. Cover it first.
2. **Skills that gate other work** (reviewers, approval gates) — they decide whether downstream work proceeds.
3. **The remaining lifecycle/domain skills** — each with happy-path + a trigger/bounce gate + a signature failure-mode.

Maintenance mode: a new skill ships with evals as part of its close-out (it's a new-skill-playbook step).

### `inline_references` (per-skill flag, schema 1.1)

Reference-heavy skills (progressive disclosure into `reference/*.md`) set `"inline_references": true` at the top of `baseline-evals.json` so the runner inlines their reference files into the EXECUTE context automatically — without it, the model can't apply rules that live outside SKILL.md. Equivalent to passing `--with-references`, but per-skill and standing.

## Wiring evals into the gate

[`eval-runner.sh`](../../eval-runner.sh) replays each skill's scenarios against the model and scores them. Where `lint-platform.sh` enforces *structure*, the eval-runner enforces *behaviour*.

**Mechanism:** the `claude` CLI in headless mode (`-p`) — no API key needed. Per scenario, two calls: (1) EXECUTE — the skill's SKILL.md body is inlined as the active skill and the scenario `query` is sent; (2) JUDGE — the response + the scenario's `expected_behavior` list go to a judge model that scores each assertion pass/fail (parsed as JSON). Per-scenario PASS = fraction of assertions met ≥ `--threshold` (default 1.0).

**Fixtures (schema 1.1).** Many scenarios review an artifact a user would normally paste. Fed headless, the model correctly asks for the missing artifact and scores zero. So a scenario that needs an artifact MUST be **self-contained**: add a `"fixture": "fixtures/<id>.md"` field pointing at a synthetic artifact seeded with the *exact* defect its assertions target (seeded naturally, not signposted, or the eval becomes leading). At run time the runner strips any `[PASTE …]` marker from the query and splices the fixture in under an `--- ARTIFACT UNDER REVIEW ---` block. Fixtures live in `skills/<skill>/evaluations/fixtures/` and are excluded from dist via each skill's `.distignore` (the `baseline-evals.json` still ships).

**Run it:**

```bash
./eval-runner.sh                  # all skills with evals
./eval-runner.sh jarvis-example   # one skill
./eval-runner.sh --dry-run        # assemble + inspect prompts (incl. fixture splice); no model calls
```

**Trust boundary.** The runner inlines the skill body, fixtures, and companion skill bodies into model prompts — so run it only against skill files you trust (your own repo). Do **not** run it against an unreviewed external contribution before a human has read the `SKILL.md` and its fixtures: a malicious body or fixture can attempt prompt-injection on the judge. `eval-runner.sh` guards the fixture/companion *path* fields against traversal (no absolute paths or `..`), but it cannot neutralise injection via file *contents* — human review of the skill is that control.

**Inside a Claude Code session:** headless `claude -p` subprocesses *do* run from inside a session. The runner still **refuses by default** when `CLAUDECODE` is set, because a full run nests dozens of model calls under your interactive session; pass `--allow-nested` for a bounded run, or run in a plain terminal / CI for the full suite. `--dry-run` is always safe.

**Cost controls:** built-in `--max-budget-usd` per call (default 0.50; skills with long structured outputs want ~0.75); `--exec-model` / `--judge-model` (default `sonnet`); single-skill / `--scenario` filters.

**The per-call cost floor, and the lean runner (`run-evals-lean.sh`).** On a maintainer machine
with a rich personal Claude setup, every headless `claude -p` call loads the user's global
CLAUDE.md, rules/, and skills/ — measured 2026-07-05 at **~91k tokens ≈ $0.55-equivalent per
call**, *above* the default per-call budget, which fails every scenario with "no parseable judge
output" before any real work (the first full-suite run hit exactly this). The lean baseline after
removing that overhead is **~$0.20-equivalent/call** (measured), so a full 286-scenario sweep costs
roughly $145-equivalent — deliberate spend, never casual. [`run-evals-lean.sh`](../../run-evals-lean.sh)
makes the lean run safe and one-command: it temporarily stashes the three global-config items
(plain-text RESTORE-NOTE left in place), **proves** the stash worked with a probe call gated on
health + a per-call cost ceiling + an overhead-token ceiling (aborting before any eval spend if the
stash didn't take), passes the per-call ceiling into eval-runner, enforces a **per-run spend
ceiling** between skills, and **restores on any exit** (trap: success, failure, Ctrl-C, crash).
Ceilings via env: `EVAL_LEAN_CALL_CEILING` (probe gate only, default 0.30),
`EVAL_LEAN_EXEC_BUDGET` (the real per-call eval budget, default 0.75 — **never set it at or below
the probe ceiling**: a 0.30 exec budget starved 73/85 scenarios into "no parseable judge output"
on 2026-07-06, because a real EXECUTE call carries the skill body + companion + fixture + a long
generated artifact), `EVAL_LEAN_RUN_CEILING` (default 20.00), `EVAL_LEAN_TOKEN_CEILING`
(default 60000).

**Companions (delegating / orchestrator skills).** A skill whose scenario *routes to another skill* or *cites another skill's rule IDs* needs those bodies inlined, or a single headless call reconstructs them inconsistently. Add a top-level `companions` array listing the skill names; the runner inlines each companion's body under a `----- companion skill -----` block.

**Variance / sampling.** Scenarios near a produce-vs-bounce gate boundary can flip verdict run-to-run under single-sample grading at threshold 1.0. `--samples N` runs EXECUTE+JUDGE N times and takes a **majority verdict** — the correct response to genuine model nondeterminism (don't chase it with fixture tweaks).

**Selection scenarios (`"mode": "selection"`).** Most scenarios force-load the skill body and test whether the model *applies* it — they can't test whether Claude would *select* the skill at all, because the body is always present. A scenario with `"mode": "selection"` instead feeds the model ONLY the skill's name + `description` and a query, and asks it to classify the request **IN SCOPE** / **OUT OF SCOPE**; assert the expected classification. This is the direct test of trigger discrimination — the highest-leverage property of the `description`. Body, fixtures, and companions are not used in selection mode. Pair an in-scope and an out-of-scope query to prove the boundary holds in both directions.

### Offline-mode assertions: stated intent, not artifacts (the G1 convention)

The EXECUTE call is a chat — there is no repo, no test runner, no GitHub, no Jira. The first full
sweep (2026-07-06: 286 run, 85 FAIL) showed the dominant false-failure class was assertions that
demand the **artifact** ("opens a PR", "the regression test is added", "files a Bug") — which an
offline run can never produce, however correct the skill's behaviour. The convention, binding for
all eval authoring and rewrites:

1. **Side-effecting steps are asserted as concrete stated intent, not artifacts.** Not "opens a
   PR" but "names the branch and PR it would open"; not "files a Bug" but "drafts the Bug it would
   file (title, severity, reproduction)". *Concrete* is the bar — a vague "I would open a PR" is
   still a miss; naming the specifics proves the skill drove the step.
2. **Acting on the fixture beats bouncing, unless the skill's own gate says bounce.** An assertion
   must not fail a skill for *doing the work with stated intent* where the scenario provides enough
   to act; conversely a scenario testing a defined gate (missing AC, unreproduced bug) must still
   expect the bounce. Do not reward asking-for-more-input where the skill's rules say proceed.
3. **Assert substance, not vocabulary.** A grader checklist may not require exact phrases
   ("says 'sixth QA category'") — assert the behaviour ("hands performance testing to the perf
   verifier rather than faking a load test"). Exact-token assertions are reserved for real
   contract tokens (`VERDICT: PASS`, marker prefixes) where the token *is* the interface.
4. **State the offline frame in the QUERY, not just in the assertions.** Rules 1–3 shape what the
   *checklist* demands; they do not stop the model from correctly refusing to act. A scenario that
   asks a skill to write a file, set a field, or record a decision will often get "I cannot do that
   here" — which is right behaviour and a false failure. Three scenarios hit this in one session
   (2026-07-20). The fix is one clause in the query: **"this is an offline exercise with no
   filesystem — do not attempt any writes; write out the content you would produce instead."** Pair
   it with an ask that demands the artifact's *substance* ("PRODUCE the trace", "WRITE OUT the
   script", "give the ordered list of writes"), because a query that says "say what you would do"
   invites narration and then the judge marks the narration as not-performed. Elicit the artifact;
   do not lower the bar.
5. **Never loosen an assertion that caught a genuine finding.** A rewrite pass works from the
   failure triage; anything classified a real skill defect keeps its assertion intact and gets a
   skill fix instead.

### Skill classes NOT in the automated behavioural gate (manual-verify)

Two classes can't be faithfully or safely scored by a single headless EXECUTE call:

- **Side-effecting publish skills.** Their scenarios execute live MCP calls that *create real artifacts* (tickets, pages, branches), and their assertions are execution-specific. A headless eval would either lack the MCP scope or create real artifacts. **Verify these manually** against the live instance with throwaway `[TEST]`-prefixed artifacts. Mark such scenarios `"manual_verify": true` so the runner skips them with a reason; their `baseline-evals.json` stays as intent-documentation.
- **Full orchestrator fan-out.** A dispatcher that really invokes N separate sub-skill passes in production can only be approximated by a single prompt. Write assertions to the consolidation contract and note the single-call limit inline.

**Not yet automatic.** It's a command, not a hook — run it after a load-bearing skill edit or before a model migration.

## The stall probe — the one class worth a standing, targeted eval

The full gate is expensive (~$30 for ~190 scenarios, minutes per skill, rate-limit-prone), so it runs
rarely. That is the right trade for *general* behaviour. It is the wrong trade for **one specific
failure class**, because that class recurs, is invisible to every structural check, and is cheap to
probe directly.

**The class.** A safety rule written absolutely becomes a **denial of service**. On 2026-07-21 one
clause produced seven instances across seven skills: *don't work from a stub* → don't work; *don't
improvise an environment* → don't test; *don't author the human's verdict* → write nothing; *route a
missing PRFAQ back* → refuse the whole pass. All of them passed `lint --strict`.
Two shapes:

| Shape | What it looks like |
|---|---|
| **Over-refusal** | An expected input is absent, so the skill produces nothing instead of working from what it has |
| **Over-rejection** | An artifact is imperfect *but honest*, so the verifier fails it instead of passing it |

**The probe.** You do not need a skill's twenty scenarios to catch this — you need **two**, to a fixed
template. Run them for **every skill a change touches**, not the whole roster: ~$1–2 for a typical
1–5 skill edit, versus ~$30 and an afternoon.

```
STALL PROBE (over-refusal)
  Query:  <the skill's primary task>, with <one precondition the skill's rules name> ABSENT,
          and every other input present and sufficient.
  Assert: produces its PRIMARY ARTIFACT anyway
          names the absent input as a gap
          does NOT defer, bounce, park, or route-back INSTEAD of producing
          (a skill that legitimately must stop asserts the stop AND says what it still produced)

STALL PROBE (over-rejection — verifiers only)
  Query:  an artifact that meets the bar but declares an honest unknown / an out-of-scope N/A.
  Assert: PASSES it, records the unknown as covered-and-declared
          does NOT fail it for the declaration itself
```

**Choosing the absent precondition:** take whatever the skill's own body calls required, expected, or
"routed back" when missing — the Requirements Brief, the `ENVIRONMENT:` marker, the PRFAQ, the parent
note. If removing it genuinely makes the task impossible, the probe is wrong for that skill; if the
task is still doable on the remaining inputs, the skill must do it.

**Why this and not more full sweeps:** 165 of the sweep's 192 scenarios said nothing about this class.
The probe targets the signature directly, and it would have caught six of the seven instances on its
own (the seventh was the over-rejection twin).

**Honest limit.** The probe catches over-refusal and over-rejection because they have a signature. A
skill that is subtly *wrong* rather than subtly *refusing* still needs the full gate and a human
reading the output. Do not let a green probe stand in for that.

## Authoring a new eval

Three scenarios minimum per skill, written **before** extensive documentation. Each scenario: a representative `query`, and an `expected_behavior` list of observable assertions (what the skill should surface, refuse, or structure). **If the scenario reviews an artifact, it MUST ship a `fixture` — a self-contained query is the bar, not a `[PASTE …]` stub.** The seeded defect lives in the fixture, not the query.
