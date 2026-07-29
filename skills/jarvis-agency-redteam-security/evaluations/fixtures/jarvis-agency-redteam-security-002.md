# STORY-67 — Endpoint to list a fleet's duty-status records

Status: In Review
Type label: api
Produced-by run: run-9ff6
PR: repo/pull/SIM-267

## AC Snapshot (frozen at Refined, hash a1d0-9f33)
- Given a fleet admin, when they list duty-status records, then only their fleet's records return.
- Given another fleet's caller, when they list, then they receive none of the first fleet's records.

## PR diff excerpt
```
@Post("/duty-status/list")
suspend fun list(@Body request: DutyStatusListRequest): PaginatedResponse<DutyStatusRecord> =
  dutyStatusManager.list(request.fleetId, request.offset, request.limit).throwOrValue()

@Serdeable
data class DutyStatusListRequest(val fleetId: UUID, val offset: Long = 0, val limit: Int = 50)
```
Suite: 11 passed, 0 failed.
