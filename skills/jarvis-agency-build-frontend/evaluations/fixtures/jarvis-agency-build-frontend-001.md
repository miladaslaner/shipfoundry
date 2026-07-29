# STORY-100 — Fleet compliance manager view of the duty-status log retention setting

Status: Refined
Type label: frontend
Parent: PROJ-100

## Acceptance criteria (snapshot)
- Given a fleet compliance manager on the settings page, when it loads, then the current retention value for their fleet is shown.
- Given the value is still loading, then a loading state is shown, not a blank screen.
- Given the request fails, then a readable error message from the backend is shown and the page recovers.
- Given no value is set, then the documented default is shown with a note that it is the default.
