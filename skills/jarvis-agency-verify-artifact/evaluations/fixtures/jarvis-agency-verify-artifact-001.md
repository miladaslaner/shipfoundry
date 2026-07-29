# STORY-90 — Architecture brief: multi-tenant duty-status-log service

Status: Backlog
Type label: architecture
Artifact-authored-by run: run-a3

## Architecture

Scope: a service that records and serves per-fleet duty events for the security console.

### Deployment model (set first)

Cloud-native multi-tenant SaaS: one shared deployment and one shared duty-status store serve all
fleets, matching the product's existing model. The customers are regulated security teams who use
the duty-status log as compliance evidence. Every constraint below is shaped by these two facts — shared
infrastructure holding per-fleet evidence.

### Constraints (binding on every producer)

- **Fleet isolation.** Every duty-status row carries a `tenant_id`. The `tenant_id` used on any read or
  write is taken from the authenticated principal's claims, never from a request parameter, body,
  or path. A query that does not filter by the principal's `tenant_id` is a defect; reviewers
  reject any repository method on this service that omits the filter. *Why here:* under the shared
  deployment model all fleets share one store, so the principal's claims are the only trustworthy
  fleet scope.
- **Data boundary.** The duty-status store is write-once from the application's perspective: the service
  exposes append and read, no update or delete endpoint. Retention deletion runs only as an
  internal scheduled job under a separate service principal, never via a request-facing path.
  *Why here:* regulated customers use this log as compliance evidence; a request-mutable log is
  worthless as evidence.
- **Authn/authz.** All endpoints require an authenticated principal. Reading another fleet's
  events requires the `platform-auditor` role; absent it, a cross-fleet read returns 404 (not 403)
  so existence is not disclosed.
- **Shared contracts.** Audit events are emitted to the bus as `google.protobuf.Timestamp` UTC and
  consumed by the console read model; the event schema is versioned and additive-only. *Why here:*
  the console read model is a separately deployed consumer; a breaking schema change would silently
  corrupt the view auditors rely on.

### Verification notes for downstream

- A reviewer can check each constraint against code: principal-derived `tenant_id`, no
  update/delete path, role check on cross-fleet read, additive schema.
- Open dependency: the principal claim format is owned by the auth service; confirmed stable as of
  this brief.
