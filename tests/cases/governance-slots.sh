# lint-platform.sh CHECK 27 — governance-slot self-consistency.
#
# A find/replace set `jira_project_key: PROJ` in repo-config.md's frontmatter and left both that
# file's prose and run-counter.md asserting the repo was UNSET ("Jira writes are blocked",
# "Inert in this repo … both reconciliation triggers are skipped"). An agent reading the prose skips
# the law's every-10-runs drift sweep on a repo that HAS a Jira project. Both directions are gated.

gs_setup() {
  rm -rf "$TMP/gs"; mkdir -p "$TMP/gs/skills" "$TMP/gs/lib" "$TMP/gs/dist" "$TMP/gs/docs/_governance"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/gs/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/gs/"
}
gs_cfg() { # $1 = jira_project_key value ; stdin = prose body
  { printf -- '---\ntype: governance\nvault_root: ./docs\njira_project_key: %s\nquarantine_list: []\n---\n\n' "$1"
    cat; } > "$TMP/gs/docs/_governance/repo-config.md"
}
run27() { ( cd "$TMP/gs" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/27\. Governance-slot/,/^$/p' ); }

printf '%s-- C27 catches the botched find/replace: key SET, prose says blocked --%s\n' "$B" "$X"
gs_setup
gs_cfg PROJ <<'P'
# Slots

`jira_project_key: PROJ` is a legal state: governance still applies, Jira writes are blocked
until the founder supplies the key.
P
out=$(run27)
case "$out" in *FAIL*repo-config.md*) assert_eq "key SET + 'Jira writes are blocked' prose is caught" "yes" "yes";;
  *) assert_eq "key SET + 'Jira writes are blocked' prose is caught" "no" "yes";; esac

printf '%s-- C27 catches the same lie in run-counter.md --%s\n' "$B" "$X"
gs_setup
gs_cfg PROJ <<'P'
# Slots

Governance applies; the Jira half is active for this repo.
P
cat > "$TMP/gs/docs/_governance/run-counter.md" <<'P'
# Run counter

**Inert in this repo.** `jira_project_key` is `UNSET`, so both reconciliation triggers are skipped.
P
out=$(run27)
case "$out" in *FAIL*run-counter.md*) assert_eq "an inert-claim in run-counter.md is caught" "yes" "yes";;
  *) assert_eq "an inert-claim in run-counter.md is caught" "no" "yes";; esac

printf '%s-- C27 passes when the prose matches the SET slot --%s\n' "$B" "$X"
gs_setup
gs_cfg PROJ <<'P'
# Slots

`jira_project_key: PROJ` — the Jira half of the law is active: writes carry a vault backlink and
both reconciliation triggers run on schedule.
P
cat > "$TMP/gs/docs/_governance/run-counter.md" <<'P'
# Run counter

Feeds the law's periodic drift sweep: every 10th run, a light three-way diff.
P
out=$(run27)
case "$out" in *FAIL*) assert_eq "prose consistent with a SET slot passes" "no" "yes";;
  *) assert_eq "prose consistent with a SET slot passes" "yes" "yes";; esac

printf '%s-- C27 gates the CONVERSE: slot UNSET but prose claims the triggers are live --%s\n' "$B" "$X"
gs_setup
gs_cfg UNSET <<'P'
# Slots

No Jira project yet, but the two reconciliation triggers run every pass.
P
out=$(run27)
case "$out" in *FAIL*) assert_eq "slot UNSET + live-triggers prose is caught" "yes" "yes";;
  *) assert_eq "slot UNSET + live-triggers prose is caught" "no" "yes";; esac

printf '%s-- C27 passes on a legitimately UNSET repo --%s\n' "$B" "$X"
gs_setup
gs_cfg UNSET <<'P'
# Slots

`jira_project_key` is `UNSET`: governance still applies, Jira writes are blocked and both
reconciliation triggers are skipped until the founder supplies the key.
P
out=$(run27)
case "$out" in *FAIL*) assert_eq "an honestly UNSET repo passes" "no" "yes";;
  *) assert_eq "an honestly UNSET repo passes" "yes" "yes";; esac

printf '%s-- C27 self-skips when there is no vault --%s\n' "$B" "$X"
gs_setup
rm -rf "$TMP/gs/docs"
out=$(run27)
case "$out" in *OK*skipped*) assert_eq "no _governance/ self-skips with a pass message" "yes" "yes";;
  *) assert_eq "no _governance/ self-skips with a pass message" "no" "yes";; esac
