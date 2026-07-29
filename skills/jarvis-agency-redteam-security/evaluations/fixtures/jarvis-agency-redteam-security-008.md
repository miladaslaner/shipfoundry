# STORY-73 — Endpoint to fetch a fleet's retention setting

Status: In Review
Type label: backend
Produced-by run: run-9kk1
PR: repo/pull/SIM-273

## AC Snapshot (frozen at Refined, hash 7be1-04cd)
Given a fleet admin, when they request their retention setting, then return the value scoped to their fleet. Given another fleet's caller, return not-found.

## PR diff excerpt
```
@Secured("FLEET_ADMIN")
@Get("/retention")
suspend fun get(authentication: Authentication): RetentionResponse {
  val fleetId = authentication.fleetId()
  log.info("retention requested for fleet {} by {}", fleetId, authentication.email())
  return retentionManager.forFleet(fleetId).throwOrValue()
}
```
Suite: 13 passed, including a cross-fleet not-found case.
