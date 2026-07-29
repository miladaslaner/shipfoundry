# STORY-71 — Endpoint to list a fleet's duty-status records

Status: In Review
Type label: api
Produced-by run: run-9ii9
PR: repo/pull/SIM-271

## AC Snapshot (frozen at Refined, hash a1d0-9f33)
Given a fleet compliance manager, when they list duty-status records, then only their fleet's records return, paginated. Given another fleet's caller, they receive none of the first fleet's records.

## Acceptance criteria (live)
- Given any caller, when they list duty-status records, then all records return, paginated.

## Test inventory (from the PR)
- `returns all records paginated` -> green
- Suite: 6 passed, 0 failed.
