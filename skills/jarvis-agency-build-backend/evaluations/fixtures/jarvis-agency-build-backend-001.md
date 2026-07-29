# STORY-40 — Endpoint to fetch a fleet's duty-status log retention setting

Status: In Progress (claimed at dispatch)
Type label: backend
Parent: PROJ-100 (Fleet-scoped duty-status log)
Dispatch run-id: run-p7 (bound to AC snapshot v1)

## AC-and-constraints snapshot (frozen at Refined — snapshot v1)

Acceptance criteria:
- Given an authenticated fleet compliance manager, when they request their retention setting, then the API returns the current value scoped to their fleet.
- Given a caller from another fleet, when they request it, then the API returns not-found, never another fleet's value.
- Given no setting exists yet, when requested, then the API returns the documented default.

Architecture constraints (epic PROJ-100):
- The fleet id derives from the authenticated principal, never from a request parameter.

## Acceptance criteria (live — identical to snapshot v1, no drift)

- Given an authenticated fleet compliance manager, when they request their retention setting, then the API returns the current value scoped to their fleet.
- Given a caller from another fleet, when they request it, then the API returns not-found, never another fleet's value.
- Given no setting exists yet, when requested, then the API returns the documented default.
