# STORY-44 — Endpoint to update a fleet's ingestion rate limit

Status: Refined
Type label: backend
Parent: PROJ-100

## Acceptance criteria (snapshot)
- Given a fleet compliance manager submits a new rate limit, when it is valid, then it is stored scoped to their fleet and returned on read.
- Given an invalid value, when submitted, then the API rejects it appropriately.
