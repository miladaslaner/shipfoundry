# STORY-12 — Duty-status log write path from existing services

Status: RC
Type label: backend
Parent: PROJ-100 (Fleet-scoped duty-status log)

## Acceptance criteria
- Given a duty-status change in any service, when it occurs, then an append-only duty-status record is written, scoped to the acting fleet.
- Records are tamper-evident via a per-fleet hash chain.
- A dropped write is retried and surfaced, never silently lost.

## Test results
142 passed, 0 failed. Line coverage 88%. Run on commit a1b2c3d.

## Security scan
0 critical, 0 high, 2 low (documented, accepted). Scanner: clean for release.
