# Stated defaults registry

**This file is the single place a cross-cutting default is registered.** If you change a default
that more than one skill reads — a mode, an owner, an enumerated state set — add or update its
entry here in the same edit. `lint-platform.sh` CHECK 23 reads this file and fails the build when
any registered *contradicting literal* is still present in the operative tree.

Why it exists: the recurring failure is a rule changed **where it is stated** and not **where it is
consumed**, with no gate able to see the difference. A default's canonical value is cheap to state;
the expensive part is knowing which older sentences now contradict it. This file makes that
knowledge machine-readable instead of review-dependent.

## How to add a default

1. Add a `### <id> — canonical: <value>` heading.
2. Write one paragraph of *why* the canonical value is what it is (a future maintainer reading a
   FAIL needs to know whether to fix the prose or retire the entry).
3. List the literal strings that would contradict it inside a ```` ```contradicts ```` fenced block,
   one per line. Each line is matched **verbatim, case-insensitively** (`grep -F -i`), never as a
   regex. Prefer a literal long enough to be unambiguous — a two-word literal will false-positive.
4. Run `./lint-platform.sh` and confirm CHECK 23 is green (it will FAIL immediately if the literal
   you just registered is still live somewhere — which is the point).

## What CHECK 23 scans

The **operative** tree — the surfaces an agent actually reads and acts on:
`skills/**/SKILL.md` bodies, `skills/**/reference/**/*.md` (including `_internal/`), `CLAUDE.md`,
`README.md`, `config/*.md` (this file excepted) and `docs/_governance/**`.

Two exemptions, both deliberate:

- **SKILL.md frontmatter (the `changelog:` block) is skipped.** A changelog is the historical
  record of what the rule *used to* say; rewriting history to satisfy a lint is the exact drift this
  platform refuses.
- **A file whose first 30 lines carry the historical banner is skipped** — the literal
  `Retained as a historical record` or `<!-- lint-exempt: historical-record -->`. Same marker CHECK
  22 honours.

Narrative planning and review documents under `docs/` (outside `_governance/`) are **out of scope**
on purpose: a fix plan legitimately quotes the value it is replacing in a before/after table, and a
point-in-time review legitimately records the value as of its date. A default is only *wrong* where
an agent would act on it.

---

### ga-granularity — canonical: `epic`

One PRFAQ = one epic = one GA. GA is signed at the **epic** level by default; story-level GA
survives only as the named severity carve-out (security / auth / tenant-boundary / data-migration /
payment surfaces) or where a project's config row explicitly sets it with a dated rationale (the
sandbox row does, deliberately). A new project's default is `epic`.

```contradicts
default `story`
default story
story mode (default
`story` mode (the default
ga-granularity defaults to story
```

### prfaq-owner — canonical: `jarvis-agency-pm`

The PM authors the PRFAQ (future press release + customer FAQ) into a vault requirement note during
discovery. Intake **reads** it and derives scope backwards from it; it never authors a launch
narrative of its own. An intake-written PRFAQ would make the requirements author and the launch
promise the same identity, which is the separation the front of the pipeline exists to keep.

```contradicts
intake writes the Working-Backwards launch
intake writes the press release
intake authors the PRFAQ
intake writes the PRFAQ
intake drafts the press release
```

### review-states — canonical: `pending | founder-delegated | founder-confirmed`

A vault note's `review:` field has three states, and **two** of them are actionable:
`founder-confirmed` and `founder-delegated` (the latter only under a recorded standing grant, and
never on intent the acting role authored itself). `pending` is inert. Any sentence that enumerates
the actionable set as `founder-confirmed` alone silently disables the delegation grant — an agent
executing that sentence literally refuses all delegated work.

```contradicts
ACT only on founder-confirmed
act only on founder-confirmed intent
stays inert until founder-confirmed
inert until founder-confirmed
only founder-confirmed intent is actionable
```
