# STORY-110 — Persist per-fleet duty-status retention settings

Status: Refined
Type label: data
Parent: PROJ-100

## Acceptance criteria (snapshot)
- Given a fleet, when a retention setting is stored, then it is persisted scoped to that fleet and readable by fleet id.
- Given a setting is deleted, when read again, then it is treated as absent (soft delete), not removed from the table.
- Given two fleets, when each stores a setting, then neither can read the other's row.
