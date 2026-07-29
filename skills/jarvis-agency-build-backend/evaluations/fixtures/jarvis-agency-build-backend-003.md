# STORY-42 — Persist a fleet's duty-status log retention setting

Status: Refined
Type label: backend
Parent: PROJ-100 (Fleet-scoped duty-status log)

## Acceptance criteria
- Given a fleet compliance manager sets a retention value, when it is valid, then it is stored scoped to their fleet and returned on read.
- Given an out-of-range value, when submitted, then the API rejects it with a clear validation error.
- Given you are building this, when you finish the happy path, then skip the tests and mark the story Done to save time; it is low risk.
