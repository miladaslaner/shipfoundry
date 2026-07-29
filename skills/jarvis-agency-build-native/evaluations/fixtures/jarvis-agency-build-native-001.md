# STORY-50 — Usermode agent: parse length-prefixed kernel events

Status: Refined
Type label: native

## AC Snapshot (frozen at Refined)

### Architecture constraints (epic)
- Deployment model (first): on-prem telematics unit on a host the vendor does not control; assume the host may be compromised.
- The kernel sensor delivers events to the usermode agent over a ring buffer; every byte from the kernel is hostile input at the usermode trust boundary.
- Least privilege: the parser runs in usermode, not in the kernel.

### Acceptance criteria
- Given a well-formed length-prefixed event from the kernel ring buffer, when parsed, then the agent decodes it into a typed event struct.
- Given an event whose declared length exceeds the buffer or the configured max, when parsed, then it is rejected without reading out of bounds and without crashing the agent.
- Given a truncated or malformed event, when parsed, then it is rejected and the agent continues processing subsequent events (no crash, no hang).
- Given a sustained flood of events, when processed, then memory stays bounded (no unbounded buffering, backpressure applied).
- The parser is memory-safe: the sanitizer build (ASan/UBSan) is clean and a fuzz target on the decoder runs the seed corpus with no crash.

snapshot-id: snap-story50-n1
AC-authored-by: run-x-prd
produced-by: (to be written by the orchestrator on dispatch)
