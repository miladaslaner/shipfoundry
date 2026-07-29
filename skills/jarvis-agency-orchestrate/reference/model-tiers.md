# Model tiers — per-role dispatch policy

Every subagent the orchestrator spawns inherits the session model unless the dispatch names a
different one. The session model is the strongest (and most expensive), so an un-tiered loop runs a
test re-run and a PRD author on the same model. That is the cost driver: one story fans out 11–14
subagents, all on the top tier. This file sizes each role to its work so the ceremony matches the
risk instead of applying maximum weight to everything.

## The rule

- **Judgment and adversarial work runs on the strongest model.** Where a wrong call is expensive and
  reasoning is the point — locking requirements, cross-cutting architecture, security red-team,
  reality audit — pay for the best model.
- **Mechanical work runs cheap.** Arithmetic, classification, extraction, and transcription cannot
  pass a gate on their own, so run them on the cheapest model.
- **No gate runs below the mid tier**, and the **security red-team never drops below the strongest.**
  The saving comes from moving the *bulk* off the top tier, not from cheapening the gates.
- **Name the model on every dispatch.** An omitted model defaults to the session model and silently
  defeats the tiering.

## The tiers

| Tier | Model | For |
|---|---|---|
| **strongest** | opus | judgment, adversarial, expensive-if-wrong |
| **mid** | sonnet | structured work and bounded gates |
| **cheap** | haiku | mechanical: arithmetic, classify, extract |

The strongest/mid/cheap names are the contract; the concrete model is `opus` / `sonnet` / `haiku`
today and moves with the model roster without re-tiering every role.

## Per-role tiers

| Skill | Tier | Why |
|---|---|---|
| jarvis-agency-jira-contract | n/a | inlined foundation, never dispatched as a subagent |
| jarvis-agency-orchestrate | session | the dispatcher; runs as the loop's own (session) model |
| jarvis-agency-onboard | sonnet | project validation + browser-driven setup |
| jarvis-agency-capture | haiku | classify a chat ask, create the issue |
| jarvis-agency-pm | opus | product discovery and acceptance judgment |
| jarvis-agency-intake | opus | interrogation, locking requirements, decomposition |
| jarvis-agency-hydrate | sonnet | codebase-digest synthesis (dropping its parallel readers to haiku is a deferred refinement — see below) |
| jarvis-agency-research | sonnet | evidence gathering and synthesis |
| jarvis-agency-architect | opus | cross-cutting constraints, deployment model |
| jarvis-agency-author-prd | sonnet | structured PRD authoring and decomposition |
| jarvis-agency-design | sonnet | UX and screen states |
| jarvis-agency-triage-bug | sonnet | reproduce and root-cause a defect |
| jarvis-agency-build-backend | sonnet | producer (Kotlin/Micronaut) |
| jarvis-agency-build-frontend | sonnet | producer (React/Next.js) |
| jarvis-agency-build-web | sonnet | producer (framework-less web) |
| jarvis-agency-build-data | sonnet | producer (migrations/schema) |
| jarvis-agency-build-go | sonnet | producer (Go) |
| jarvis-agency-build-docs | sonnet | producer (documentation-only, the docs tier) |
| jarvis-agency-build-native | opus | producer (C/C++/Rust); security-critical systems code |
| jarvis-agency-build-ios | sonnet | producer (Swift) |
| jarvis-agency-build-ml | sonnet | producer (Python pipelines) |
| jarvis-agency-build-stream | opus | producer (streaming/data-pipeline); distributed-systems correctness (exactly-once, backpressure, recovery) is poorly deterministically-testable, so the mid correctness gates are weakest here — opus while UNVALIDATED, revisit to sonnet once the fault-injection harness proves it |
| jarvis-agency-build-analytics | sonnet | producer (analytics/search store); structured mappings/ILM/queries — the expensive data-model design (partition/shard/retention) is architect-owned, so if that upstream ownership lapses, bump to opus |
| jarvis-agency-build-detection | sonnet | producer (detection-as-code); authors rules against a spec — the adversarial efficacy judgment is externalized to jarvis-agency-verify-detection (opus) |
| jarvis-agency-build-agent | opus | producer (agentic/LLM-application); orchestration quality is unguarded at the strongest tier (only the security lens is opus) and an opus-class problem wants an opus builder |
| jarvis-agency-build-integration | sonnet | producer (connectors + SOAR); structured and contract-testable, the opus security branch is the net |
| jarvis-agency-build-infra | sonnet | producer (IaC/platform); highly tool-checkable (plan/tfsec/OPA), the opus redteam-security infra branch is the net |
| jarvis-agency-critique-acceptance | opus | the refinement gate; a lenient critic poisons everything downstream |
| jarvis-agency-verify-artifact | sonnet | upstream artifact quality gate |
| jarvis-agency-review-code | sonnet | code-review gate |
| jarvis-agency-run-tests | sonnet | test re-run + coverage-vs-AC gate |
| jarvis-agency-redteam-security | opus | adversarial security; never below strongest |
| jarvis-agency-verify-detection | opus | detection-efficacy gate (the fourth RC gate for a detection story); adversarial — replays the corpus + evasion variants, expensive-if-lenient (a blind SIEM ships), same class as redteam-security/audit |
| jarvis-agency-qa | sonnet | functional QA gate |
| jarvis-agency-perf | sonnet | performance gate |
| jarvis-agency-audit | opus | adversarial whole-product reality hunt |
| jarvis-agency-retro | opus | cross-run pattern judgment; drafts founder-gated skill-improvement proposals |
| jarvis-agency-watch-cost | haiku | arithmetic against the budget |

Every agency skill must appear in this table (lint check 14 gates the parity, both directions). The
same check enforces the **tier floor**: no gate/verifier row may run on the cheap tier, and
`redteam-security` must be the strongest tier — so a future edit cannot silently weaken a gate.

## Deferred refinements (not in v1)

- **Risk-sensitive verifiers.** The code trio and producers could scale with the story's risk tier —
  a docs story runs its verifiers on cheap, a native/security story bumps them to strongest. v1 is
  fixed-per-role for simplicity; this is the fast-follow, coupled with the docs/low-risk ceremony tier.
- **Per-skill `model:` frontmatter.** A self-documenting default on each skill for direct (non-loop)
  invocation. The dispatch-time model above is the authority; frontmatter is a nicety, added only
  after the mechanism is verified to re-tier a dispatched subagent.
- **The solo docs gate's tier.** review-code runs mid as one-of-three; on a docs story it is the
  ONLY gate, where a miss is unmitigated. If real docs runs show misses, bump the docs-mode dispatch
  to strongest (a one-row change) — the risk-sensitive fast-follow covers this case.
- **Parallel readers to cheap.** `hydrate`'s fan-out repo-readers are pure extraction and can run on
  cheap even though the synthesis stays mid.
