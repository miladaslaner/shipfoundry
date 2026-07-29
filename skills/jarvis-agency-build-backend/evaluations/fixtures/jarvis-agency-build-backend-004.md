# STORY-43 — Endpoint to read a fleet's ingestion rate limit

Status: Refined
Type label: backend
Parent: PROJ-100

## Acceptance criteria (snapshot)
- Given an authenticated fleet compliance manager, when they request their ingestion rate limit, then the API returns the current value scoped to their fleet.
- Given no limit is configured, when requested, then the documented default is returned.
