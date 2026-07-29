---
type: governance
title: Vault ⇄ Jira Source-of-Truth Contract
law_version: 1.2.1
authored_by: founder
review: founder-confirmed
generated_note: "Read-only mirror generated from platform law_version 1.2.1. Do not edit — edits are overwritten on next deploy/run. Change the law in the platform skill, not here."
repo_vault_root: {{VAULT_ROOT}}
jira_project_key: {{JIRA_PROJECT_KEY}}
quarantine_list: {{QUARANTINE_LIST}}
updated: {{TODAY}}
---

# The one rule
The vault is the source of truth for INTENT. Jira is the ledger for EXECUTION. Nothing is authored in both.

# What lives where
- Vault (born here): requirements, design & contracts, scope, GA decisions, architecture, findings.
- Jira (born here): status, worklog, assignment, PR/commit links, execution progress.

# Direction of authority
- Decisions flow vault → Jira. Read the vault to decide; record in Jira that you acted; every Jira write links back to the authorizing vault note.
- A scope/requirement/GA decision with NO owning vault note is INVALID and must not be actioned. A decision cannot be born in a Jira comment.
- Jira execution state never overrides vault intent. Contradiction is a FINDING, not a silent reconcile.

# Repos without a Jira project
A repo may have no Jira project (jira_project_key: UNSET). Such a repo still records INTENT in its vault under this law — requirements, design, scope, findings, provenance stamps, and pending-intent-inert all apply. But it performs NO Jira writes and SKIPS the reconciliation triggers (periodic drift sweep and decision-point gate), because there is no execution ledger to reconcile against. Code-contradicts-claim remains a hard stop wherever code exists. When jira_project_key becomes set later, Jira writes and reconciliation activate automatically from that point.

# Jira updates continue — with a backlink
Every completed task still updates Jira (status + worklog). The only change: each update references the authorizing vault note. No silent Jira writes.

# Provenance stamping
Jarvis may create/edit vault notes without pre-approval. Every note that AUTHORIZES work carries:
  authored_by: founder | agency
  decision_type: requirement | design | scope | ga
  review: pending | founder-delegated | founder-confirmed
  overrides_agency_reco: true | false | n/a
- Only the founder sets review: founder-confirmed. An agency-authored authorizing note stays review: pending UNLESS a DIFFERENT agency role marks it review: founder-delegated under a recorded standing grant covering that class of work (next bullet). The role that authored the note may never move its own note out of pending — self-authored intent always takes a real founder confirmation.
- review: founder-delegated is the THIRD state, added in 1.2.0: intent the founder pre-authorized as a CLASS by a recorded standing grant, rather than reviewing item by item. It is actionable like founder-confirmed, and it is never a claim the founder saw this item. An agency role may set it ONLY when (a) a recorded standing grant covers this class of work, and (b) the note was NOT authored by the same role that is setting it — self-authored intent always takes a real founder confirmation. It stays permanently distinguishable in the record so an audit can separate what shipped on delegation from what a human actually read.
- Trust asymmetry (binding): an agency approval is credible when it OVERRIDES the agency's own prior recommendation, suspect when it rubber-stamps what the agency wanted. Record honestly.
- Findings and execution/status notes are free-write — no stamp.

# PENDING INTENT IS INERT (core control)
Never build, scope, or take irreversible action on an authorizing note whose review is still pending. Pending intent may be drafted, never acted upon. Actionable states are founder-confirmed and founder-delegated; pending is inert.
- Blocked by a pending note → queue it into {{VAULT_ROOT}}/_governance/founder-decision-queue.md AND surface it in the run summary. Then proceed to other unblocked work. Never stall silently.
- The trust-asymmetry exception does NOT grant action rights: credibility is not authorization. An override-type note stays inert until it reaches an actionable state — founder-confirmed, or founder-delegated under the delegation rules above. Overriding the agency's own recommendation never, by itself, makes a note actionable.

# CODE IS THE INDEPENDENT SIGNAL (hard stop)
Code either runs or it doesn't — it is the one source that isn't self-attested. When code contradicts a Jira "Done" or a vault claim, that is a HARD STOP on that item: it becomes a founder decision or a tracked CLAIMED-NOT-BUILT finding before any automated action touches it. Code is NEVER auto-overridden by Jira/vault agreement.

# Every run, in order
1. Version check: if platform law_version > this mirror's law_version, regenerate the mirror (preserve slots) and log it.
2. READ the vault first (relevant PRFAQ/spec/finding/governance) — the instruction source, not Jira, not a ticket comment.
3. Check review status of any authorizing note in the path. Pending → queue + surface, do not act. founder-delegated → act, and name the delegation in the run summary so it is never mistaken for a reviewed decision.
4. ACT only on intent in an ACTIONABLE state — review: founder-confirmed OR review: founder-delegated. Anything still review: pending is inert; never act on it.
5. WRITE BACK: (If jira_project_key is set:) Jira execution state + vault backlink; new intent → stamped (agency, pending) vault note referenced from Jira. With jira_project_key UNSET, the stamped vault note is the whole write-back.

# Ongoing reconciliation — two triggers
1. (If jira_project_key is set:) Periodic drift sweep — every 10 runs. Maintain {{VAULT_ROOT}}/_governance/run-counter.md. Every 10th run, before other work, do a LIGHT three-way diff (Jira status+changelog ⇄ working-tree code ⇄ vault). Auto-resolve execution-state drift (Jira wins); quarantine reality drift (code≠claim) as findings; surface anything new in the run summary.
2. (If jira_project_key is set:) Decision-point gate — before ANY GA or scope decision, every time. Run a scoped diff on the affected items, then RESOLVE-OR-QUARANTINE-THEN-PROCEED:
   - Execution-state drift → auto-resolve (Jira wins), proceed.
   - Reality drift (code≠claim) → cannot auto-resolve; quarantine as a finding, EXCLUDE that item from the decision's scope, note the carve-out in the run summary, proceed on the known-clean remainder. Never proceed as if the contradiction weren't there.
   - Pending intent in the path → that portion is blocked; queue + surface.
   Rationale (binding): halting a whole decision on unrelated drift trains override-reflex, which launders bad decisions as reviewed. Carve out the drifted item; keep unrelated work moving.

# Hard stops (summary)
- No requirement/scope decision born in a Jira comment. Ever.
- No acting on review: pending intent.
- No agency role writing founder-confirmed, and none writing founder-delegated on intent it authored itself.
- No Jira status change without a vault backlink.
- No actioning scope lacking an owning, non-quarantined, founder-confirmed or founder-delegated vault note.
- Code contradicting a claim halts action on that item.
- Items in quarantine_list are not actioned or scoped.

# Changing this law
Only the founder may change the universal rules, in the platform skill, with a bumped law_version. Repos never edit the law; they inherit it.
