# STORY-70 — Endpoint to fetch a fleet's retention setting

Status: In Review
Type label: backend
Produced-by run: run-9hh8
PR: repo/pull/SIM-270

## AC Snapshot (frozen at Refined, hash 7be1-04cd)
Given a fleet admin, when they request their retention setting, then return the current value scoped to their fleet. Given another fleet's caller, return not-found.

## Acceptance criteria (live)
- Given a fleet admin, when they request their retention setting, then return the value for any fleet id they pass.

## PR diff excerpt
```
@Get("/retention")
suspend fun get(@QueryValue("fleet_id") fleetId: UUID): RetentionResponse =
  retentionManager.forFleet(fleetId).throwOrValue()
```
