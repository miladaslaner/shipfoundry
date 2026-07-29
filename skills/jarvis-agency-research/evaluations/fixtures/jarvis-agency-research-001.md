# PROJ-EP1 — Fleet-scoped duty-status log (epic)

Type: Epic
Status: Backlog

## Intent
Regulated customers need a per-fleet, tamper-evident duty-status log of duty-status changes, queryable by fleet compliance managers and exportable for compliance.

## Open questions (for research)
- Which compliance regimes do current and target customers need to satisfy, and what do they require of an duty-status log?
- What retention and export formats do fleet compliance managers actually use today?
- What is the expected event volume per fleet at the high end?
- What tamper-evidence approach is proportionate (hash chain vs signed records vs external anchoring)?

## Requirements Brief (locked at intake) — extract
- Deployment model: cloud-native multi-tenant SaaS; fleet isolation hard requirement.
- Users: fleet compliance managers (query, export); audit inspectors consume exports.
- Non-goals: no route optimisation, no driver-behaviour scoring.
- Open unknowns routed to research: the four open questions above — answer them first.
