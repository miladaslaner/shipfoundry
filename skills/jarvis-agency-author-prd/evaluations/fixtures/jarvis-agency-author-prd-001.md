# PROJ-EP1 — Fleet-scoped duty-status log (epic)

Type: Epic
Status: Backlog

## Intent
Per-fleet, tamper-evident duty-status log for regulated customers: write path, query API, admin UI, export.

## Research findings (summary)
- Target customers must satisfy the ELD mandate and EU tachograph rules; both require an immutable, time-ordered record of duty-status changes, retained per a configurable retention policy. [evidenced]
- Fleet compliance managers export monthly, CSV and JSON. [evidenced]
- High-end volume ~800k duty events/fleet/month. [evidenced]
- Tamper-evidence: a per-fleet hash chain is proportionate. [assumed — confirm with security]

## Architecture constraints (binding)
- Fleet id is always derived from the authenticated principal, never from request input.
- Duty-status records are append-only; no update or hard delete.

## Requirements Brief (locked at intake)
- Launch (press-release summary): "Fleet compliance managers of {Product} can now prove compliance with a tamper-evident, exportable log of every duty-status change."
- Users: fleet compliance managers (query, export); platform services (write path); audit inspectors (consume exports).
- Success measures: an admin can answer "which driver was on duty, when" for any window inside 2 minutes; monthly export completes for the largest fleet.
- Non-goals: no route optimisation, no driver-behaviour scoring, no cross-fleet benchmarking.
- Deployment model: cloud-native multi-tenant SaaS.
- Failure modes / operability: duty-status write failures must be visible (alert), never silently dropped; export retries idempotently.
- Data: retention configurable per fleet, default 8 months; records append-only.
- SLOs: query p95 < 2s at 2M records/fleet; write path non-blocking for emitting services.
- Open unknowns: none blocking — hash-chain proportionality flagged to compliance (see research).
