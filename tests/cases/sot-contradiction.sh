# lint-platform.sh CHECK 22 — the Jira-as-source-of-truth-for-decisions contradiction.
#
# A 2026-07-20 audit found the agency workbench asserting the OPPOSITE of the vault-governance
# law (law_version 1.1.0) in nine places, headed by the foundation contract's invariant #1. That
# was fixed by edit; check 22 stops it drifting back. The check earns its place only if it both
# CATCHES the original wording and ACCEPTS the corrected wording — a check that only goes green
# on already-clean text proves nothing.

mk_skill() { # $1=dir $2=name $3=body
  mkdir -p "$TMP/sot/skills/$2"
  printf -- '---\nname: %s\nversion: 1.0.0\ndescription: x\n---\n%s\n' "$2" "$3" > "$TMP/sot/skills/$2/SKILL.md"
}

setup_tree() {
  rm -rf "$TMP/sot"; mkdir -p "$TMP/sot/skills" "$TMP/sot/lib" "$TMP/sot/dist"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/sot/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/sot/"
}

# The runner EXPORTS LINT_PLATFORM_LIB=1 to guard out the main run when it sources the script
# as a library. Clear it for the child, or the child guards out its own main and prints nothing.
run22() { ( cd "$TMP/sot" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/22\. Jira-as-source/,/^$/p' ); }

printf '%s-- C22 catches the original invariant #1 wording --%s\n' "$B" "$X"
setup_tree
mk_skill x jarvis-agency-contradiction \
'## The four invariants

1. **Jira is the source of truth.** All durable state lives on the issue. Agent context is
   ephemeral and gets discarded. Never carry status, decisions, or artifacts only in context.'
out=$(run22)
case "$out" in *FAIL*) assert_eq "unqualified invariant #1 is caught" "yes" "yes";;
  *) assert_eq "unqualified invariant #1 is caught" "no" "yes";; esac

printf '%s-- C22 accepts the corrected execution-scoped wording --%s\n' "$B" "$X"
setup_tree
mk_skill x jarvis-agency-corrected \
'## The four invariants

1. **Jira is the source of truth for EXECUTION; the vault is the source of truth for INTENT.**
   Execution state (status, worklog, PR links, verdicts) lives on the issue; intent lives in a
   vault note the issue backlinks.'
out=$(run22)
case "$out" in *FAIL*) assert_eq "execution-scoped wording passes" "no" "yes";;
  *) assert_eq "execution-scoped wording passes" "yes" "yes";; esac

printf '%s-- C22 catches the paraphrase, not just the exact sentence --%s\n' "$B" "$X"
setup_tree
mk_skill x jarvis-agency-paraphrase \
'Capture is a convenience layer over Jira, not a new source of truth — the issue it creates
**is** the record, and every downstream gate still applies.

Artifacts attach to the issue so the issue stays the single source of truth.'
out=$(run22)
case "$out" in *FAIL*) assert_eq "issue-stays-the-single-source-of-truth paraphrase is caught" "yes" "yes";;
  *) assert_eq "issue-stays-the-single-source-of-truth paraphrase is caught" "no" "yes";; esac

# Scope widened 2026-07-21: the vault law is UNIVERSAL (jarvis-vault-governance deploys into any
# repo), so the claim is wrong in any skill, not only an agency one. The audit found 8 of 12
# surviving instances outside the old jarvis-agency-* glob. This case previously asserted the
# opposite boundary; it encodes the current intent.
printf '%s-- C22 polices every skill, not only jarvis-agency-* --%s\n' "$B" "$X"
setup_tree
mk_skill x jarvis-unrelated 'Jira is the source of truth for this unrelated tool.'
out=$(run22)
case "$out" in *FAIL*) assert_eq "a non-agency skill is in scope too" "yes" "yes";;
  *) assert_eq "a non-agency skill is in scope too" "no" "yes";; esac

printf '%s-- C22 spares the changelog (history is not drift) --%s\n' "$B" "$X"
setup_tree
mkdir -p "$TMP/sot/skills/jarvis-agency-history"
printf -- '---\nname: jarvis-agency-history\nversion: 2.0.0\ndescription: x\nchangelog: |\n  1.0.0 — Established that Jira is the source of truth for all durable state.\n---\nThe vault owns intent; Jira is the source of truth for execution state.\n' \
  > "$TMP/sot/skills/jarvis-agency-history/SKILL.md"
out=$(run22)
case "$out" in *FAIL*) assert_eq "changelog history does not trip the check" "no" "yes";;
  *) assert_eq "changelog history does not trip the check" "yes" "yes";; esac

printf '%s-- C22 reports one violation once, not twice --%s\n' "$B" "$X"
setup_tree
mk_skill x jarvis-agency-spanning \
'1. **Jira is the
   source of truth.** All durable state lives on the issue.'
n=$(run22 | grep -c 'FAIL' || true)
assert_eq "a claim spanning two lines reports a single FAIL" "$n" "1"

# ---------------------------------------------------------------------------
# CHECK 22, WIDENED (2026-07-21 audit): 8 of the 12 surviving instances were outside the first
# version's reach — it never descended into reference/_internal/, never looked at docs/, CLAUDE.md,
# README.md or config/, and required the literal string "source of truth" so every paraphrase
# ("holds the truth", "state lives in Jira", "durable state in Jira", "intent in Jira") walked past
# it. These cases pin the widening AND the two exemptions that keep it honest.
# ---------------------------------------------------------------------------

printf '%s-- C22 descends into reference/_internal (where the operative registry lives) --%s\n' "$B" "$X"
setup_tree
mkdir -p "$TMP/sot/skills/jarvis-agency-cfg/reference/_internal"
printf -- '---\nname: jarvis-agency-cfg\nversion: 1.0.0\ndescription: x\n---\nbody\n' > "$TMP/sot/skills/jarvis-agency-cfg/SKILL.md"
printf 'The instance registry. Jira is the single source of truth for this workbench.\n' \
  > "$TMP/sot/skills/jarvis-agency-cfg/reference/_internal/config-internal.md"
out=$(run22)
case "$out" in *_internal*FAIL*|*FAIL*_internal*) assert_eq "a claim inside reference/_internal is caught" "yes" "yes";;
  *) assert_eq "a claim inside reference/_internal is caught" "no" "yes";; esac

printf '%s-- C22 catches the paraphrases the literal-string version missed --%s\n' "$B" "$X"
for para in 'The issue holds the truth for this epic.' \
            'All durable state lives in Jira and nowhere else.' \
            'The loop keeps all durable state in Jira.' \
            'You put intent in Jira and the loop picks it up.'; do
  setup_tree
  mk_skill x jarvis-agency-para "$para"
  out=$(run22)
  case "$out" in *FAIL*) assert_eq "paraphrase caught: ${para:0:40}" "yes" "yes";;
    *) assert_eq "paraphrase caught: ${para:0:40}" "no" "yes";; esac
done

printf '%s-- C22 scans docs/, CLAUDE.md and README.md, not only skills/ --%s\n' "$B" "$X"
setup_tree
mkdir -p "$TMP/sot/docs"
printf '# A doc\n\nJira remains the single source of truth for the whole product.\n' > "$TMP/sot/docs/a-doc.md"
printf '# Root\n\nThe issue holds the truth.\n' > "$TMP/sot/README.md"
out=$(run22)
case "$out" in *docs/a-doc.md*) assert_eq "a claim in docs/ is caught" "yes" "yes";;
  *) assert_eq "a claim in docs/ is caught" "no" "yes";; esac
case "$out" in *README.md*) assert_eq "a claim in README.md is caught" "yes" "yes";;
  *) assert_eq "a claim in README.md is caught" "no" "yes";; esac

printf '%s-- C22 spares a QUOTED claim (a citation is not an assertion) --%s\n' "$B" "$X"
setup_tree
mkdir -p "$TMP/sot/docs"
printf '# Fix plan\n\nRow 2a quotes invariant 1 in its pre-split form ("Jira is the source of truth") and replaces it.\n' \
  > "$TMP/sot/docs/plan.md"
out=$(run22)
case "$out" in *FAIL*) assert_eq "a quoted pre-split citation does not trip the check" "no" "yes";;
  *) assert_eq "a quoted pre-split citation does not trip the check" "yes" "yes";; esac

printf '%s-- C22 honours the historical-record banner --%s\n' "$B" "$X"
setup_tree
mkdir -p "$TMP/sot/docs"
printf '# Old review\n\n> Retained as a historical record; see the current law.\n\nJira is the single source of truth.\n' \
  > "$TMP/sot/docs/old-review.md"
out=$(run22)
case "$out" in *FAIL*) assert_eq "a bannered point-in-time doc is exempt" "no" "yes";;
  *) assert_eq "a bannered point-in-time doc is exempt" "yes" "yes";; esac
# ...and the banner is not a blanket escape hatch: without it, the same file fails.
setup_tree
mkdir -p "$TMP/sot/docs"
printf '# Old review\n\nJira is the single source of truth.\n' > "$TMP/sot/docs/old-review.md"
out=$(run22)
case "$out" in *FAIL*) assert_eq "the same doc WITHOUT the banner still fails" "yes" "yes";;
  *) assert_eq "the same doc WITHOUT the banner still fails" "no" "yes";; esac

printf '%s-- C22 does not misread a correct VAULT-is-source-of-truth sentence --%s\n' "$B" "$X"
setup_tree
mk_skill x jarvis-agency-correct \
'Obey the governance mirror for all vault<->Jira behavior: vault is source of truth for intent.'
out=$(run22)
case "$out" in *FAIL*) assert_eq "vault-attributed source-of-truth is not a Jira claim" "no" "yes";;
  *) assert_eq "vault-attributed source-of-truth is not a Jira claim" "yes" "yes";; esac
