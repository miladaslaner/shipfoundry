---
name: jarvis-vault-governance
description: Use when an agent is about to read, decide from, or write back to a repo's vault (docs/notes) and its Jira project, and the question is which source is authoritative — symptoms are a requirement or scope decision appearing only in a Jira comment, a story marked Done whose code does not exist, an agency-written note being acted on before the founder confirmed it, or a repo that has no governance files yet. It carries the universal Vault-as-Source-of-Truth law as a versioned template plus the bootstrap that deploys it into any work repo as a read-only mirror with three local slots (vault root, Jira project key, quarantine list). Triggers on phrases like "is this repo governed", "bootstrap the vault governance", "which is source of truth here", "regenerate the source-of-truth mirror", "can I act on this note yet". Does not trigger for the Jira workflow states and linking rules themselves (jarvis-agency-jira-contract), routing work (the orchestrator), building, verifying, or signing GA.
version: 1.2.2
owner: Founder (law) / Platform maintainer (mechanics)
updated: 2026-07-21
source: Founder-authored universal agency law, law_version 1.2.1 (2026-07-21).
changelog: |
  1.2.2 - Eval-only. Scenarios 002 and 009 asked a short judgement question ("Can we build it now?", "Verdict?") while their assertions demanded mechanism the query never requested - the queue-and-proceed step, and the slot-masking/diverging-line detail. Both rules ARE stated in the body (verified before touching anything); the queries now elicit them, per evaluation-strategy rule 4. No law text changed and law_version is deliberately NOT bumped: the deployed mirrors stay faithful at 1.2.1.
  1.2.1 — Law bumped to law_version 1.2.1: CLARIFICATION ONLY — the rule did not move. 1.2.0's intent (founder-delegated is an actionable state alongside founder-confirmed) is unchanged; three sentences of the same law failed to state it and still enumerated two states, so an agent executing the law literally would have refused all delegated work and silently disabled the grant 1.2.0 exists to enable. Fixed: (1) the every-run procedure's step 4 ("ACT only on founder-confirmed intent") now names both actionable states, consistent with its own step 3; (2) the provenance bullet's "Agency-authored authorizing notes stay review: pending" now carries the delegation exception (a DIFFERENT agency role may mark it founder-delegated under a recorded standing grant) while keeping the self-authorship prohibition explicit; (3) the trust-asymmetry rider ("stays inert until founder-confirmed") now reads "until it reaches an actionable state", since 1.2.0 created no override-type carve-out and inventing one here would be a rule change, not a clarification. No new permission, no removed permission, no changed hard stop. Mirrors regenerate on their next run's version check.
  1.2.0 — Law bumped to law_version 1.2.0: adds the THIRD review state `founder-delegated` (founder ruling, 2026-07-20). It marks intent the founder pre-authorized as a CLASS via a recorded standing grant rather than reviewing item by item: actionable like founder-confirmed, but never a claim the founder saw that item, and permanently distinguishable in the record so an audit can separate delegated work from reviewed work. An agency role may set it only when a recorded grant covers the class AND the note was not authored by the same role setting it — self-authored intent always takes a real founder confirmation. `Only the founder sets founder-confirmed` is unchanged and now literally true. Pending-intent-inert restated over the three states (pending is inert; the other two are actionable). Hard stops gain 'no agency role writing founder-confirmed, and none writing founder-delegated on intent it authored itself'. Motivation: the agency workbench's delegated-proceed grant could not be re-enabled under 1.1.0 without an agency role writing the founder's field.
  1.1.0 — Law bumped to law_version 1.1.0 (this entry previously mis-stated it as 1.2.0; corrected in 1.2.1): adds the "Repos without a Jira project" clause (jira_project_key UNSET records intent, performs no Jira writes, skips both reconciliation triggers; code-contradicts-claim still a hard stop) and guards the Jira write-back step and both reconciliation triggers with "(If jira_project_key is set:)" rather than deleting them. Mechanical enforcement added: lint-platform.sh check 21 (verify-mirror) compares a deployed mirror against this template with the per-repo slots masked, so an edit to the law text in a mirror fails while a slot-only difference passes.
  1.0.0 — Initial law. Canonical contract template (law_version 1.0.0) + repo-config template + auto-bootstrap deployment contract. Universal rules are platform-owned and non-repo-editable; only vault root, Jira project key, and quarantine list are per-repo slots.
---

# jarvis-vault-governance

The universal law governing how any agent treats a repo's **vault** (intent) versus its
**Jira project** (execution). The law is authored **once, here**, and deployed into every
work repo as a **read-only mirror**. Repos inherit; they never edit.

## The one rule

The vault is the source of truth for INTENT. Jira is the ledger for EXECUTION.
Nothing is authored in both.

The full, binding text is [`reference/contract-template.md`](reference/contract-template.md) —
that file *is* the law. This body is the deployment contract around it. When they appear to
disagree, the template wins.

## Platform / repo boundary

| | Owned by | Editable where | Deployed as |
|---|---|---|---|
| The universal rules | Platform (this skill) | Here only, founder-only, with a bumped `law_version` | `{vault}/_governance/SOURCE-OF-TRUTH.md` — read-only mirror |
| The three slots | The work repo | `{vault}/_governance/repo-config.md` | n/a |

A repo may change **what the law is generated against** (its vault root, its Jira key, its
quarantine list). It may never change **what the law says**. An edit to a mirror is not a
governance change — it is drift, and the next run overwrites it.

That boundary is **mechanically enforced**, not promised: `./lint-platform.sh --verify-mirror
{path-to-mirror}` (check 21, *verify-mirror*) compares a deployed mirror against this skill's
template with the per-repo slots masked on both sides. A slot-only difference passes; an edited
law sentence fails and prints the diverging lines; a mirror whose `law_version` is *ahead* of
the platform fails (only a hand-edit can produce it); a mirror *behind* warns as stale, since
the next run regenerates it. The same check self-verifies this skill's own internal consistency
(`law_version` agreeing across the template frontmatter, the `generated_note`, and this file)
on every platform lint run.

## The slots — and only these

| Slot | Filled with | Default |
|---|---|---|
| `{{VAULT_ROOT}}` | Path to the repo's vault | `./docs` |
| `{{JIRA_PROJECT_KEY}}` | The repo's Jira project key | `UNSET` (surface a request; never guess) |
| `{{QUARANTINE_LIST}}` | Items excluded from action/scope | `[]` |
| `{{TODAY}}` | Generation date | today |
| `{{LAW_VERSION}}` | The platform law version this deploy was generated from | the current `law_version` — never a literal typed by hand |

Substitute every slot before writing the mirror: a `{{...}}` left in place is invalid YAML
(a brace pair parses as a flow mapping) and marks an incomplete deploy.

`UNSET` is a **state, not a repo**. A repo with no Jira project is
still fully governed: it records intent in its vault, stamps provenance, and honours
pending-intent-inert — it simply performs no Jira writes and skips both reconciliation
triggers, because there is no execution ledger to reconcile against. Code contradicting a
claim stays a hard stop wherever code exists. Setting the key later activates the Jira half
from that point, with no re-bootstrap.

## Deploying it into a repo

The bootstrap sequence an agent runs before work in any repo is the standing instruction in
this platform's `CLAUDE.md` (`## Vault governance (universal law — auto-bootstrap)`). In
outline:

1. Detect the vault root (default `./docs`; a repo may override in its repo-config).
2. No `{vault}/_governance/repo-config.md` → first run: create it from
   [`reference/repo-config-template.md`](reference/repo-config-template.md) with the three slots.
3. Generate `{vault}/_governance/SOURCE-OF-TRUTH.md` from the contract template, slots filled
   from repo-config, marked read-only mirror.
4. Mirror `law_version` < platform `law_version` → regenerate, preserving the repo's slots, and
   log the bump.
5. Ensure `founder-decision-queue.md` and `run-counter.md` exist.
6. Obey the mirror for all vault↔Jira behaviour.

Bootstrap is idempotent: on a governed, current repo it reads three files and does nothing else.

## The three controls that do the work

- **Pending intent is inert.** Never build, scope, or take irreversible action on an
  authorizing note still at `review: pending` (since 1.2.0 the actionable states are
  `founder-confirmed` and `founder-delegated`). Blocked → queue it *and* surface
  it, then move on to unblocked work. Never stall silently.
- **Code is the independent signal.** Code is the one source that is not self-attested. Code
  contradicting a Jira "Done" or a vault claim is a hard stop on that item — founder decision
  or a tracked CLAIMED-NOT-BUILT finding first. Jira and the vault agreeing does not override it.
- **Resolve-or-quarantine-then-proceed.** At a decision point, auto-resolve execution-state
  drift (Jira wins), carve the reality-drifted item out of the decision's scope and note the
  carve-out, and proceed on the known-clean remainder. Halting a whole decision on unrelated
  drift trains override-reflex, which launders bad decisions as reviewed.

## Changing the law

Founder-only, in `reference/contract-template.md`, with the `law_version` bumped in both the
template frontmatter and its `generated_note`. Every governed repo picks the change up on its
next run via the version check in step 4 — that is the whole distribution mechanism. Never
patch a repo's mirror to ship a rule change.

## Files in this skill

- `SKILL.md` (this file) — the deployment contract and the boundary
- `reference/contract-template.md` — **the law**, law_version 1.2.1, slots only
- `reference/repo-config-template.md` — the per-repo slot file
- `evaluations/baseline-evals.json` — baseline scenarios
