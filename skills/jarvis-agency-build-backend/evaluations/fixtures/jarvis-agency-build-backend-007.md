# STORY-45 — Endpoint to fetch a fleet's ingestion rate limit

Status: In Progress
Type label: backend
Parent: PROJ-100
Produced-by run: this run

## Acceptance criteria (snapshot)
- Given an authenticated fleet compliance manager, when they request their ingestion rate limit, then the API returns the current value scoped to their fleet.
- Given no limit is configured, when requested, then the documented default is returned.

## Producer self-review (this run)
- PR opened: repo/pull/231.
- Tests: 16 passed, 0 failed.
