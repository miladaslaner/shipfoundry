# Run pace and producer fan-out — the full protocol and guards

Extracted from the contract body (which keeps the summary); this is the authoritative detail.

One run-level **pace** governs parallelism inside a producer and across units (the orchestrator's
wave dispatch), set at loop start and recorded in the cost note so an unattended run is auditable:

- **`fast` (default).** A producer building a story that spans **three or more genuinely independent
  file-units** (no file shared across them) **may fan out one sub-implementer per unit** — after
  first fixing the shared interfaces — then integrate the result itself and open one PR. This builds
  a chunky story's independent parts at once, cutting wall-clock.
- **`thorough` (the kill-switch for every speed feature).** Producers build inline AND the wave
  concurrency cap drops to 1 (fully sequential). One knob, all off; use to economise or de-thrash.

**The fan-out protocol** (carried into the producer brief, the way bug-mode is): (1) **interface
pass** — fix the shared contracts the units compose against; (2) **fan out** — one sub-implementer
per disjoint file-unit, each bound to those interfaces and the AC snapshot, owning non-overlapping
files; (3) **integrate** — the producer reconciles, makes the shared-file edits (router, index)
itself, runs the full build/test gate; (4) **one PR, one self-review** — the producer stays a single
identity.

**The guards, not the toggle, keep this safe.** The **threshold self-limits cost**: below three
independent file-units a producer builds inline, so a `small`-tier story (one or two files) never
fans out, fast or not — the small-feature cost discipline holds automatically. The **per-story
budget bounds it**: fan-out raises the **producer-build phase** roughly 1.5–2× (each unit re-pays its
context setup) — the three verifiers are unchanged, so the governed story moves toward the warn/cap
band, not past it — and a producer projecting a per-story-budget breach falls back to inline, with the
cost watcher still parking a run over budget. **Producer-never-verifies is untouched**: the
sub-implementers are inside the producer's identity; the three governance verifiers still run
afterward as distinct identities, and an incoherent parallel build bounces at In Review like any
other FAIL — the trio is the coherence net. **UNVALIDATED**: the first fan-out stories are its
proving ground; if parallel builds bounce for incoherence, tighten the threshold or the interface
pass. Soft control (orchestrator + the producer brief + agent compliance), bounded ultimately by the
runner spend cap.
