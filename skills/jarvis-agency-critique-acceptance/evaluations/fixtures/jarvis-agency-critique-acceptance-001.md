# STORY-80 — Endpoint to fetch a fleet's retention setting

Status: Backlog
Type label: backend
AC-authored-by run: run-p8

## Draft acceptance criteria
- Given an authenticated fleet compliance manager, when they request their retention setting, then the API returns the current integer value scoped to their fleet.
- Given a caller whose fleet differs from the requested record, when they request it, then the API returns 404 and no value.
- Given no setting exists for the fleet, when requested, then the API returns the documented default of 90 days.
- Given an unauthenticated request, when received, then the API returns 401.
- Given an authenticated non-admin member of the fleet, when they request the setting, then the API returns 403 and no value.
- Given a request with a malformed setting identifier, when received, then the API returns 400 with a validation error and no value.

## Requirements Brief — docs/intent/EPIC-79-scope.md (vault scope note, review: founder-confirmed)
Summary: fleet compliance managers can read and set their own data-retention window.

Resolved note content (reproduced here for this offline exercise):
- Users: fleet compliance managers. Auditors read exports; they never write settings.
- Locked answers: retention is a per-fleet integer in days; the documented default is 90; a fleet
  may never read or write another fleet's value.
- Failure modes: on a malformed identifier the API rejects rather than guessing; no value is ever
  returned on an authorization failure.
- Non-goals: no bulk/multi-tenant read, no retention enforcement job (this slice is the setting
  only), no UI.
