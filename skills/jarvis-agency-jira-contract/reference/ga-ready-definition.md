# Definition of GA-ready

Extracted from `SKILL.md` (**The RC ceiling** → Definition of GA-ready) for body-line headroom.
This file is the authoritative statement of the bar; the body carries the summary and the pointer.

RC means **GA-ready**: the unit has cleared one universal production-safety bar, the same bar for
every product. A human engineer then signs GA on top of it. The bar is domain-agnostic; the
domain-specific contents (which compliance evidence, which SLO numbers, which data rules) enter as
**acceptance criteria** (from the Requirements Brief) and **architecture constraints**, and are
checked under items 1 and 5 below — never as a separate, skippable list.

A unit is GA-ready only when all of these hold. Items 2–3 are defined over **executable surface**:
a `docs`-tier unit (none, by its own gate) satisfies them vacuously, its docs bar standing in under
items 1, 4, and 10 — nothing else in this bar is relaxed:

1. **Acceptance criteria met**, independently verified against the frozen snapshot — the verifier's
   judgment, not the producer's word.
2. **Tests** written first, green on an independent re-run, covering the AC including the negative
   and edge cases, and the cross-tenant cases where the deployment model is multi-tenant.
3. **Security clean**: an adversarial pass against the architecture constraints, no RC-blocking
   severity, authorization enforced, tenant isolation enforced where the deployment model is
   multi-tenant, no secrets in code or config.
4. **Code correct and clean**: layered, conventions honoured, no dead or out-of-scope code,
   reviewed by an identity distinct from the producer.
5. **Architecture constraints honoured, the deployment model included** — tenancy, data boundaries,
   auth, secrets, the update path, the interface and API contracts, and the performance and scale
   SLOs, as the architect and the Requirements Brief set them.
6. **Failure handling**: failure modes handled, no silently swallowed errors, degraded behaviour
   defined where the brief requires it.
7. **Operability**: the change is observable where it matters, and has a defined rollback or upgrade
   path where it touches deployable or stored state.
8. **Data**: residency and retention from the brief honoured; migrations reversible and safe.
9. **Recorded**: the PR, the verdicts, and the changelog are on the issue, so the state is auditable.
10. **Every governance verdict PASS**, and the live AC and constraints still equal the frozen
    snapshot.

This bar is certified by the governance verifiers plus the orchestrator's RC gate — a soft control
until the enforcement backlog's hard controls land. Be honest about which items are actually gated:
the three governance verdicts directly check correctness, tests, and security (items 1–4), and
review-code checks the built code against the constraints (part of item 5). But the rest — the
non-code parts of item 5 (the deployment model, interfaces, and SLOs as honoured *in the running
system*), item 6 (failure handling), item 7 (rollback and upgrade), and item 8 (data residency,
retention, and migration safety) — are only gated insofar as the **Requirements Brief and the
architecture constraints turn them into acceptance criteria a verifier can check**. If the brief
does not, those items are specified here but not enforced. So the brief must convert the
operability, failure-mode, data, interface, and SLO answers into acceptance criteria, or they ride
on agent compliance alone. GA is the human engineer's accountable sign-off that this bar is
genuinely met; the agents take work only to it, never past it.
