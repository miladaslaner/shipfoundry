# STORY-63 — Endpoint to fetch a fleet's retention setting

Status: In Review
Type label: backend
Produced-by run: run-9cc3
PR: repo/pull/SIM-263

## AC Snapshot (frozen at Refined, hash 7be1-04cd)
- Given a fleet compliance manager, when they request their retention setting, then return the current value scoped to their fleet.
- Given another fleet's caller, return not-found.
- Given no setting exists, return the documented default.

## Test inventory (from the PR)
- `returns current value for the fleet` -> covers criterion 1
- `returns not-found for a different fleet` -> covers criterion 2
- `returns default when no setting exists` -> covers criterion 3
- Suite: 14 passed, 0 failed.
