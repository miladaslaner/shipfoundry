# STORY-38 — Duty-status log ingestion rate limit

Status: In Review
Type label: api
Parent: PROJ-100 (Fleet-scoped duty-status log)
AC snapshot at Refined (hash): 9c1f-a2e7 — "reject writes above 500/s per fleet with a 429; never drop a record silently"

## Acceptance criteria (current)
- Given write volume above the fleet limit, when ingestion runs, then excess writes are dropped and counted.

## Test results
40 passed, 0 failed. Run on commit e1f2a3b.

## Security scan
0 critical, 0 high.
