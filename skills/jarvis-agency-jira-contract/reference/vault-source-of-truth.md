# Vault and Jira — intent versus execution

Companion to `SKILL.md` (**Vault and Jira: intent versus execution**). The universal law lives in
the repo's governance mirror, `{vault_root}/_governance/SOURCE-OF-TRUTH.md`, deployed by the
`jarvis-vault-governance` platform skill. **The mirror wins over this file and over the contract
body wherever they differ** — this is the agency-facing operating guide to it, not a second law.

## Contents

- [Which store owns what](#which-store-owns-what)
- [The note shape](#the-note-shape)
- [Note granularity and parent links](#note-granularity-and-parent-links)
- [Resolving a pointer comment](#resolving-a-pointer-comment) — the canonical rule other skills cite
- [Pending intent is inert](#pending-intent-is-inert)
- [Who may confirm — and the three review states](#who-may-confirm--and-the-three-review-states)
- [Repos with no Jira project](#repos-with-no-jira-project)

## Which store owns what

| Lives in the vault (born there) | Lives in Jira (born there) |
|---|---|
| Requirements, scope, non-goals | Status and the workflow transitions |
| Design decisions and contracts | Worklog, assignment, priority |
| Architecture decisions | PR and commit links |
| GA decisions | Verifier verdicts, cost notes, merge records |
| Findings | Execution progress of every kind |

Nothing is authored in both. The issue always carries a **backlink** to the note that authorizes
the work; no silent Jira writes.

`{vault_root}` comes from `{vault_root}/_governance/repo-config.md`. **Never hardcode `docs/`** —
it is the default, not the rule, and the agency runs in work repos whose vault root differs.

## The note shape

An authorizing note — one that permits work to happen — carries this frontmatter:

```yaml
authored_by: founder | agency
decision_type: requirement | scope | ga
review: pending | founder-delegated | founder-confirmed
overrides_agency_reco: true | false | n/a
```

Findings and execution/status notes are free-write and need no stamp.

`overrides_agency_reco` records the **trust asymmetry** honestly: an approval is credible when it
overrides the agency's own prior recommendation, and suspect when it rubber-stamps what the agency
already wanted. Record it truthfully; it is the signal a later audit reads.

## Note granularity and parent links

**One note per decision.** Do not combine a requirement and its scope into a single note: each
decision is confirmed at its own moment, and a single note cannot be half-confirmed.

The chain, and the link each note must carry:

```
requirement note  (PM shaped intent — the problem, users, slice)
      ▲
      │ parent link
scope note        (intake Requirements Brief — the locked, buildable scope)
      ▲
      │ parent link
ga note           (the GA decision — what shipped, against which scope)
```

- A **scope** note MUST link the requirement note it scopes. A scope note with no requirement
  parent-link is **incomplete** — do not action it; treat it like a missing note and queue it.
- A **ga** note MUST link the scope it signs off.
- A requirement note has no parent (it is the root of the chain).

The links are what make the chain auditable: from a shipped GA decision you can walk back to the
problem statement that justified it, and from a requirement forward to what it became.

## Resolving a pointer comment

The canonical rule, and the single one that keeps every downstream stage correct without editing it.
Other skills cite **this** section by name rather than restating it.

When an issue names an intent artifact, **what is on the issue is a pointer, not the content**:

| On the issue | What it actually is | What to do |
|---|---|---|
| `## Requirements Brief` comment | Backlink + short summary | Follow it; read the **scope note** |
| `## Shaped Intent` comment | Backlink + short summary | Follow it; read the **requirement note** |
| `INTAKE-APPROVAL:` marker | Backlink to the authorizing note | Follow it; verify `review` is `founder-confirmed` (or `founder-delegated` under a recorded grant) — `pending` is a hard stop |

So a stage told to "read the Requirements Brief" — the architect, `author-prd`, `design`, the AC
critic, `hydrate`, `verify-artifact`, `perf`, the PM at acceptance — resolves that instruction to
the vault note through this rule, with no change to its own instructions.

- **Any stage that needs the brief or the PRFAQ MUST resolve the pointer and read the note.** Acting
  on the summary alone is a defect, not a shortcut, however plausible the summary looks.
- **Where the summary and the note disagree, the NOTE wins.** Never merge them, never average them,
  never prefer the one that looks more recent — a stale summary is the expected failure mode, and
  reconciling it against the note is the note's job, not the reader's.
- Resolve `{vault_root}` from `{vault_root}/_governance/repo-config.md`. **Never assume `docs/`.**
- **A scope note's PRFAQ lives in its PARENT requirement note.** A stage that needs the PRFAQ (the
  PM at acceptance, `author-prd`, the walkthrough script) resolves one level **up** the parent chain;
  the scope note itself does not carry it.
- **This rule fires on a POINTER, not on the word "brief".** If the artifact's **content is present
  inline** — an older issue written before vault-first, a `small`-tier epic whose brief was never
  split out, a fixture — there is nothing to dereference: **use it and proceed**. A stage that
  refuses to work because it expected a pointer and found the actual content has converted a safety
  rule into a denial of service.
- Only an **unresolvable pointer** is a stop: a comment that *names* a note (or plainly stands in for
  one) whose backlink is missing, broken, or resolves to nothing.
- **No brief referenced at all is NOT an unresolvable pointer.** A `docs`-tier story has none by
  design; a story can arrive before one is attached; some work is driven by a prototype or an AC
  set instead. There is nothing to dereference, so proceed on the inputs you DO have and name the
  absent one in your output. Producing nothing because an input you expected was not referenced is
  the same stall in a different disguise. There, **stop and queue it** — the
  stub is never a fallback for a note that was supposed to exist. When in doubt about which case you
  are in, say which you concluded and why, then proceed on the content you actually have.

## Pending intent is inert

**Never build, scope, or take irreversible action on an authorizing note still at `review:
pending`.** Pending intent may be drafted; it may not be acted upon. The actionable states are
`founder-confirmed` and `founder-delegated`.

Blocked by a pending note:

1. Queue it into `{vault_root}/_governance/founder-decision-queue.md`.
2. Surface it in the run summary.
3. **Proceed to other unblocked work** — never stall the whole run silently.

Items in the mirror's `quarantine_list` are not actioned or scoped at all. At a decision point,
carve a quarantined or reality-drifted item out of the decision's scope, note the carve-out, and
proceed on the known-clean remainder — halting a whole decision on unrelated drift trains
override-reflex, which launders bad decisions as reviewed.

## Who may confirm — and the three review states

| State | Actionable? | Who may set it | Means |
|---|---|---|---|
| `pending` | **No — inert** | any agency role, on its own notes | drafted, not yet authorized |
| `founder-delegated` | Yes | an agency role, **only** under a recorded standing grant, and **never** on a note it authored itself | the founder pre-authorized this *class* of work; **not** a claim they read this item |
| `founder-confirmed` | Yes | **the founder alone** | the founder read this item and approved it |

**Only the founder sets `founder-confirmed`.** That is literal, and it is why the third state
exists (law_version 1.2.0): a standing grant is a real founder decision, but about a *class*, so it
gets its own mark and stays distinguishable in the record forever. An audit can therefore separate
what shipped on delegation from what a human actually read — a distinction a single shared state
would erase.

**The one combination that never runs:** the same role authoring intent *and* clearing it. Inline
authorship is allowed and delegated-proceed is allowed, but a brief the orchestrator wrote itself
(`ARTIFACT-AUTHORED-BY: intake-inline-orchestrator …`) always takes a real founder confirmation.
Each shortcut is defensible alone; together they are the rubber-stamp the trust-asymmetry stamp
exists to expose. See the contract's `reference/work-tiers.md` (Inline-lite roles and
delegated-proceed).

## Repos with no Jira project

A repo may set `jira_project_key: UNSET`. It is still fully governed — intent, provenance stamps,
and pending-intent-inert all apply — but it performs **no Jira writes** and skips both
reconciliation triggers, because there is no execution ledger to reconcile against. Code
contradicting a claim stays a hard stop wherever code exists. Setting the key later activates the
Jira half automatically, with no re-bootstrap.
