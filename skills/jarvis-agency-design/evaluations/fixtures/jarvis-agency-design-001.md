# STORY-100 — Fleet compliance manager view of the duty-status log retention setting

Status: Refined
Type label: frontend
Parent: PROJ-100

## Acceptance criteria
- Given a fleet compliance manager on the settings page, when it loads, then the current retention value for their fleet is shown.
- Given the value is loading, then a loading state is shown, not a blank screen.
- Given the request fails, then a readable backend error message is shown and the page recovers.
- Given no value is set, then the documented default is shown, noted as the default.

## Design tokens (project)
- Color, type, and spacing tokens are defined in the project design system; use them, do not introduce new ones.
