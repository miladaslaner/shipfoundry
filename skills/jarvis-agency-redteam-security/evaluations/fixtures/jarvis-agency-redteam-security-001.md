# STORY-66 — Endpoint to fetch a fleet's retention setting

Status: In Review
Type label: backend
Produced-by run: run-9ee5
PR: repo/pull/SIM-266

## AC Snapshot (frozen at Refined, hash 7be1-04cd)
- Given a fleet admin, when they request their retention setting, then return the value scoped to their fleet.
- Given another fleet's caller, return not-found.

## PR diff excerpt
```
@Secured("FLEET_ADMIN")
@Get("/retention")
suspend fun get(authentication: Authentication): RetentionResponse =
  retentionManager.forFleet(authentication.fleetId()).throwOrValue()

// RetentionManager
suspend fun forFleet(fleetId: UUID): Either<ClientException, RetentionResponse> =
  repository.byFleet(fleetId)?.let { RetentionResponse.from(it).right() }
    ?: ClientError.NOT_FOUND.asException().left()
```
Suite: 12 passed, 0 failed.
