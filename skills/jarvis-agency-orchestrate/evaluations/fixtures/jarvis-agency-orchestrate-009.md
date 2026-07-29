# STORY-36 — Admin UI for fleet duty-status log

Status: In Review
Type label: frontend
Parent: PROJ-100 (Fleet-scoped duty-status log)
Producer run: agent-run c2d1 (recorded on the issue)

## Acceptance criteria
- Given a fleet compliance manager, when they open the duty-status log view, then records page and filter by date and actor.
- The view never shows another fleet's records.

## Verifier report (run d8e2)
- 3 tests failed: cross-fleet filter leaks records from a sibling fleet under a crafted date range.
- Security: 1 high — the export button calls an endpoint without the fleet scope check.
- Verdict: FAIL. Do not advance.
