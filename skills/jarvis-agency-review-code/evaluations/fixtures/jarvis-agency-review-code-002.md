# STORY-61 — Endpoint to update a fleet's retention setting

Status: In Review
Type label: backend
Produced-by run: run-9bb2
PR: repo/pull/SIM-261

## AC Snapshot (frozen at Refined, hash 51c2-d0a9)
- Given a fleet admin submits a valid retention value, when stored, then it is scoped to their fleet and returned on read.
- Given an out-of-range value, when submitted, then the API rejects it with a validation error.

## PR diff excerpt
```
@Post("/retention/update")
suspend fun update(authentication: Authentication, @Body req: UpdateRetentionRequest): RetentionResponse {
  val current = repository.byFleet(authentication.fleetId())!!
  if (req.days in 1..3650) {
    val saved = repository.save(current.copy(days = req.days))
    return RetentionResponse.from(saved)
  }
  throw IllegalArgumentException("bad value")
}
```
