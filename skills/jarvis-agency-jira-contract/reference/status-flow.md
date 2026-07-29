# Status flow — the nine states, their transitions, and who acts

Extracted from `SKILL.md` for body-line headroom. This file is authoritative for the state machine;
the body carries the summary and the pointer.

The canonical states and the only legal transitions. Real Jira status names and IDs map to
these in the internal config; the names below are the contract's vocabulary.

```
Backlog ──► Refined ──► In Progress ──► In Review ──► RC ──► GA Signed ──► Done
              │  ▲             ▲              │
              │  └─────────────┼──────────────┘   (verifier bounces back to In Progress)
              ▼                │
           (failed refinement) │
            back to Backlog    │

Rejected is a terminal state reachable from any active state (PM cancels, or a defect that
cannot ship). Blocked is a side state reachable from any active state; it records the state it
left and returns only there.
```

| State | Meaning | Who may enter it |
|---|---|---|
| **Backlog** | Captured, not yet refined. No AC, no type label. | orchestrator (on the PM's request) |
| **Refined** | Has AC and a type label. Routable. | orchestrator (the gate) |
| **In Progress** | A producer subagent owns it, recorded as the claim. | orchestrator |
| **In Review** | Producer is done. Distinct verifier identities run here. | orchestrator |
| **RC** | Release candidate. Code correct, tests green, security clean: every governance verdict PASS, evidence on the issue. | orchestrator |
| **GA Signed** | A named human signed off, recorded by Jira's actor log. | **human only** |
| **Done** | Merged and closed. | orchestrator, after GA Signed |
| **Rejected** | Cancelled or unshippable. Terminal. Carries a reason. | orchestrator, on the PM's or founder's instruction |
| **Blocked** | Stalled on a dependency. Records and returns to its prior state. | any agent or human |

Gates worth stating plainly:

- **Backlog → Refined** requires AC, a type label, **and the AC critic's `VERDICT: PASS`** in the
  AC Critique lane (the acceptance-criteria critic, a distinct identity from the AC author). The
  decomposition-and-quality gate. Enforced by the orchestrator, and by a Jira validator where the
  project supports one (backlog item).
- **Refined → Backlog** is the regression for failed refinement, or for an AC change after
  Refined (see **Acceptance criteria**).
- **In Progress → In Review** is an identity handoff, not just a status change. See below.
- **In Review → In Progress** is the verifier bouncing the work back with findings. Expected.
- **In Review → RC** requires every verifier to pass and the evidence to be on the issue.
- **RC → GA Signed** is the one transition agents must never make. See **The RC ceiling**.

The status names above are the contract's fixed vocabulary. On the home project all of them,
including `Rejected` (terminal) and `Blocked` (side state), now exist as real Jira statuses — the
ids are in the internal config. The pre-Blocked origin is still recorded on the issue so an unblock
returns to the state it left.

## Who writes a status, and on whose behalf

**One writer.** Every status transition is performed by the **orchestrator**, one at a time. A wave
dispatches several units concurrently, so distributing the write across producers and verifiers
would reintroduce the status-write races the single-writer rule exists to prevent. The PM never
moves a story; it *requests*, and the orchestrator writes.

**The actor is recorded.** Owning the write is not the same as owning the decision, so each
transition carries a `STATUS-ACTOR:` marker naming the role the move was made **for** — the producer
that finished, the QA identity that tested, the human who signed. This preserves the organisational
answer to "who moved this to testing?" without moving the mechanism.

| Move | Written by | Recorded actor |
|---|---|---|
| Refined → In Progress | orchestrator | the dispatched producer |
| In Progress → In Review | orchestrator | the producer that finished |
| In Review → RC | orchestrator | the verifiers whose verdicts cleared it |
| RC → GA Signed | **the human, directly** | the human (changelog-verified; never an agent) |
| GA Signed → Done | orchestrator | the human whose signature it follows |

`RC → GA Signed` is the exception that proves the rule: it is the one transition an agent must never
perform, so there the writer and the actor are the same person.
