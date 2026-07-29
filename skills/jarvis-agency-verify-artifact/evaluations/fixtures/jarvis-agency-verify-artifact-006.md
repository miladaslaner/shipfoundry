# STORY-98 — Requirements Brief: customer analytics dashboard

Status: Backlog
Artifact kind: Requirements Brief (intake, product tier)
TIER: product
Artifact-authored-by run: run-i7

Resolves against: the PRFAQ in the PM's requirement note REQ-52 (reproduced below as context).

## GA-readiness answers

- Users/buyers: customers.
- Launch: a dashboard that shows analytics.
- Non-goals: none noted.
- Deployment model: cloud.
- Data: standard.
- Threat model: standard security.
- Compliance: TBD.
- Failure modes: handled by the platform.
- Operability: monitored.
- SLOs: fast.
- Open unknowns: none.

## First-principles register

- A web dashboard — **fundamental**: important for users.
- A mobile app — **fundamental**: industry standard.
- A dedicated data warehouse — **fundamental**: best practice for analytics.
- A real-time streaming pipeline — **fundamental**: modern products need it.

## Decomposition

- Epic: web dashboard → REQ-52 press release "see last week's numbers without asking us for a
  report". Coverage: covered.
- Epic: mobile app. Coverage: needs-producer.
- Epic: data warehouse. Coverage: needs-producer.
- Epic: machine-learning recommendation engine. Coverage: needs-producer.

---

## Context supplied with the brief — requirement note REQ-52 (PM-authored PRFAQ, not part of this artifact)

**Press release.** From today, an account owner opens the console and sees last week's usage —
requests, errors, and top consumers — without asking us for a report. The weekly report request,
which took our support team two days to fulfil, is gone; the numbers refresh every hour and can be
exported as CSV.

**Customer FAQ.**
- What does it not do? It does not do custom queries or ad-hoc segmentation at launch, and it shows
  usage only, not billing.
- How does it fail? If the aggregation job is behind, the dashboard shows the timestamp of the last
  complete hour rather than a stale number presented as current.
- Why this over the status quo? Today a report request takes two days of support time; this is
  self-served and hourly.
- What does it cost me? Included in the existing plan.
