# STORY-97 — Requirements Brief: self-serve API key management

Status: Backlog
Artifact kind: Requirements Brief (intake, product tier)
TIER: product
Artifact-authored-by run: run-i7

Resolves against: the PRFAQ in the PM's requirement note REQ-41 (reproduced below as context; the
brief cites it rather than restating it).

## GA-readiness answers

- Users/buyers: fleet compliance managers (users); the platform reads keys to authenticate API calls.
- Launch (measurable): an admin creates a key in range, sees it once, revokes it and it stops
  working within seconds, scoped to their fleet; a cross-fleet caller cannot see or revoke another
  fleet's key.
- Non-goals: auto-rotation; service-account keys; per-key scopes (all launch non-goals).
- Deployment model: same as the product, cloud-native multi-tenant.
- Data: the key secret is shown once and stored hashed; retention follows the fleet's policy.
- Threat model: a fleet compliance manager trying to reach another fleet's keys; a stolen key.
- Compliance: inherits the product's existing ELD compliance controls; key create/revoke events are written
  to the fleet's duty-status log. No new regulatory regime at launch.
- Failure modes: key service down → existing keys still authenticate; revocation is durable.
- Operability: key create/revoke emit structured logs and metrics on the product's existing
  pipeline; a revocation-propagation failure pages the on-call.
- SLOs: a revocation stops the key working within 10 seconds; key lookup adds no measurable
  latency to API auth (it rides the existing auth path's budget).
- Open unknowns: the exact hash parameters → research (owner: intake, before the store epic starts).

## First-principles register

- "Show the secret once, store only a hash" — **fundamental**: a stored plaintext secret is a breach
  waiting to happen for a security product; the one-time reveal is the only way to never hold it.
- "A dedicated keys dashboard page" — **inherited assumption**, dropped: the console already has a
  settings area; a separate page is convention, not a need. Keys live in settings.
- "Revocation is instant (seconds), not batch" — **fundamental**: a stolen key must be killable now;
  a nightly batch would leave a stolen key live for hours.

## Decomposition (each epic traces to a line in REQ-41's PRFAQ)

- Epic: key create/list/revoke API and store → press release "create, see, revoke" + FAQ fail-safe
  answer. Coverage: covered (backend/api, data).
- Epic: console keys UI in settings → press release "from the console, without emailing support".
  Coverage: covered (frontend).

---

## Context supplied with the brief — requirement note REQ-41 (PM-authored PRFAQ, not part of this artifact)

**Press release.** Starting today, fleet compliance managers manage their own API keys from the console. They
create a key, see their keys, and revoke one instantly, without emailing support. Support tickets
for key changes drop to zero.

**Customer FAQ.**
- What does it cost me? Nothing extra; it is part of the console.
- What does it not do? It does not rotate keys automatically at launch, and it does not manage
  service-account keys, only fleet-admin keys.
- How does it fail safe? If the key service is unavailable, existing keys keep working and the admin
  sees a clear "try again" state; no key is silently lost.
- Why this over the status quo? Today admins wait hours on a support ticket; this is instant and
  self-served.
