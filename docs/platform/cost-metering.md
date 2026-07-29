# Cost metering — measured spend, not self-estimates

*Status: rails landed, live extraction is a flagged spike (2026-07-06). Addresses
an internal review finding — the agency's cost numbers are today the
orchestrator's own self-estimates ("Pass it the run's spend so far"), which watch-cost then
classifies and retro harvests as "actuals". The numbers a budget guardrail and a learning organ act
on should be **measured**, not transcribed estimates.*

## What landed now (the honest rails)

`jarvis-agency-watch-cost` 0.2.0 no longer presents an estimate as if it were a measurement. It
**prefers a measured figure from a run journal** when one exists, and otherwise **labels its number
`[estimated]`** in the Cost note. Until the run journal is wired, every Cost note reads
`[estimated]` — which is the honest state of affairs, and exactly the signal that tells you the
metering spike below is still open. Nothing about the budget bands, the checkpoints, or the
`over → stop-and-park` behaviour changes; only the number's provenance is now truthful.

## The run-journal format (the contract the spike writes to)

A run journal is a newline-delimited JSON file the **runner** appends one record to per dispatch —
outside any skill, at the layer that actually spawns subagents. watch-cost reads it; it never writes
it. One record per dispatch:

```json
{"schema": 1, "run": "<loop-run-id>", "issue": "PROJ-53", "unit": "story",
 "role": "redteam-security", "dispatch_run_id": "redteam-proj53-r1",
 "input_tokens": 41200, "output_tokens": 8800, "usd": 0.42, "source": "transcript"}
```

- Keyed so watch-cost can sum by **`issue`** (per-story spend) and by **`run`** (per-run spend) —
  the two units it is asked about — with `role` giving the per-role breakdown retro wants.
- `source` records where the numbers came from (`transcript` = parsed from the Claude Code session
  transcript's per-message `usage`; `api` = a billing/usage API; `estimate` = a fallback the runner
  itself could not measure). watch-cost surfaces `[measured]` for `transcript`/`api` and
  `[estimated]` for `estimate` or a missing journal.
- The journal is a **local telemetry artifact**, not Jira state. The Jira `Cost` note stays the
  durable record the contract's comment-first storage requires; it becomes a *derived view* of the
  journal's measured numbers rather than the primary record. This keeps invariant 1 intact: cost is
  **execution** data, which is exactly what Jira is the ledger for (the vault is the source of truth
  for intent, not for spend), and the journal is only a measurement input feeding that ledger.

## The spike (still open — needs a live test)

Turning `[estimated]` into `[measured]` needs a runner-side extractor, and that is where the
uncertainty is honestly located:

1. **Extract per-dispatch usage** from the Claude Code session transcript (the per-message `usage`
   records, including subagent sidechains) or an OTel/usage export, and append the journal record
   above. This is buildable but **must be verified against a real transcript** — the exact schema
   and the subagent-attribution path are runtime properties this repo cannot confirm statically.
2. **Attribute to the Jira story.** Each dispatch already carries a `dispatch_run_id` (the
   produced-by / verifier run-id machinery); the extractor keys the journal record on it, and the
   orchestrator's existing run-id records map it to the issue. Per-dispatch → per-story attribution
   is therefore mechanical *if* the transcript exposes the run-id per sidechain — the thing the live
   test confirms.
3. **Subscription vs API billing.** On a subscription plan the token counts are exact but the
   dollar figure is an allocation, not an invoice line; the journal records tokens as authoritative
   and `usd` as indicative, and the deployment states which it is. On API billing the usage API
   gives both. The claude.ai org-upload surface has **no** such access — there the journal is absent
   and watch-cost stays `[estimated]` by design.

**Sequence (from the review):** metering first, *then* consider folding watch-cost's classification
inline (2.4b) — that fold is a separate founder decision on the Inline-lite boundary and is **not**
done here. Do not remove the watch-cost dispatch until the journal is proven to feed it.

## Why this ordering is safe

The runaway-spend safety tail is **already bounded outside the repo** — the runner is on a
subscription plan, so total spend is hard-capped by the payment model itself (an internal spend-cap decision,
CLOSED). So accurate metering is an **accounting-fidelity and learning-quality** improvement, not a
safety fix — which is why the honest-labelling rails can land now and the extractor can take the
careful, live-tested pass it needs without leaving a safety gap open in the meantime.
