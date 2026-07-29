# STORY-72 — Endpoint to delete a fleet's retention setting

Status: In Review
Type label: backend
Produced-by run: run-9jj0
PR: repo/pull/SIM-272

## AC Snapshot (frozen at Refined, hash c4f2-71ab)
Given a fleet admin deletes their retention setting, when confirmed, then it is soft-deleted, scoped to their fleet.

## Acceptance criteria (live)
- Given any caller, when they call delete with a fleet id, then that fleet's setting is removed.

## PR diff excerpt
```
@Post("/retention/delete")
suspend fun delete(@Body req: DeleteRequest): Boolean =
  retentionManager.softDelete(req.fleetId).throwOrValue()
```
