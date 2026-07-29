# PROJ-EP1 — Fleet-scoped duty-status log (epic)

Type: Epic
Status: Backlog

## Intent
Per-fleet, tamper-evident duty-status log for regulated customers: a write path from existing services, a query API, an admin UI, and a compliance export. Multiple services will emit duty events; multiple stories will read and export them.

## Research findings (summary)
- the ELD mandate / EU tachograph rules require an immutable, time-ordered, fleet-scoped record. [evidenced]
- ~800k duty events/fleet/month at the high end. [evidenced]
- Several existing services must write to the log without coupling to each other. [evidenced]

## Requirements Brief (locked at intake)
- Deployment model: cloud-native multi-tenant SaaS, single region to start; fleet isolation is a hard requirement.
- Users: fleet compliance managers (query, export) and existing platform services (write path).
- Compliance: the ELD mandate and EU tachograph rules in scope; duty-status records append-only, no update or hard delete.
- Data: retention configurable per fleet (default 8 months); no cross-fleet reads ever.
- Threat model: a compromised fleet credential must not reach another fleet's records; export artifacts carry fleet-scoped data only.
- SLOs: query p95 < 2s at 2M records/fleet; write path must not block the emitting service.
- Non-goals: no route optimisation, no driver-behaviour scoring in this epic.

## Repo state
Greenfield service — no existing codebase digest (`.agency/codebase-map.md` does not exist; nothing to hydrate).
