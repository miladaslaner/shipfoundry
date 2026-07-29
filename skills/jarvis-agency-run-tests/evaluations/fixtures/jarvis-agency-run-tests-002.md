# STORY-64 — Endpoint to list a fleet's duty-status records

Status: In Review
Type label: api
Produced-by run: run-9dd4
PR: repo/pull/SIM-264

## AC Snapshot (frozen at Refined, hash a1d0-9f33)
- Given a fleet compliance manager, when they list duty-status records, then only their fleet's records return, paginated.
- Given another fleet's caller, when they list, then they receive none of the first fleet's records.

## Test inventory (from the PR)
- `returns a page of the fleet's records` -> covers criterion 1
- `paginates with offset and limit` -> covers criterion 1
- `returns an empty page when the fleet has no records` -> covers criterion 1
- Suite: 11 passed, 0 failed.
