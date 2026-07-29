# lint-platform.sh CHECK 24 — internal-config lane-name uniqueness.
#
# The real defect (2026-07-21 audit): a wave APPENDED a second `PM Acceptance` lane row carrying the
# opposite rule instead of replacing the first, leaving two live rows in contradiction — whichever an
# agent read first won. A lane name is a key; duplicates are always a defect.

lu_setup() {
  rm -rf "$TMP/lu"; mkdir -p "$TMP/lu/skills/jarvis-agency-contract/reference/_internal" "$TMP/lu/lib" "$TMP/lu/dist"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/lu/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/lu/"
  printf -- '---\nname: jarvis-agency-contract\nversion: 1.0.0\ndescription: x\n---\nbody\n' \
    > "$TMP/lu/skills/jarvis-agency-contract/SKILL.md"
}
lu_cfg() { cat > "$TMP/lu/skills/jarvis-agency-contract/reference/_internal/jira-config-internal.md"; }
run24() { ( cd "$TMP/lu" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/24\. Internal-config lane/,/^$/p' ); }

printf '%s-- C24 catches the duplicate PM Acceptance lane --%s\n' "$B" "$X"
lu_setup
lu_cfg <<'CFG'
## Fields and sections

| Artifact | Location | Id / heading |
|---|---|---|
| PR link | comment | the producer posts the PR URL |
| PM Acceptance | heading comment | the agent writes the verdict |
| Review Verdict | heading comment | VERDICT: PASS/FAIL |
| PM Acceptance | heading comment | the HUMAN's verdict, recorded verbatim |
CFG
out=$(run24)
case "$out" in *FAIL*"PM Acceptance"*) assert_eq "a duplicate lane name is caught" "yes" "yes";;
  *) assert_eq "a duplicate lane name is caught" "no" "yes";; esac

printf '%s-- C24 passes once the stale row is deleted --%s\n' "$B" "$X"
lu_setup
lu_cfg <<'CFG'
| Artifact | Location | Id / heading |
|---|---|---|
| PR link | comment | the producer posts the PR URL |
| PM Acceptance | heading comment | the HUMAN's verdict, recorded verbatim |
| Review Verdict | heading comment | VERDICT: PASS/FAIL |
CFG
out=$(run24)
case "$out" in *FAIL*) assert_eq "a de-duplicated lane table passes" "no" "yes";;
  *) assert_eq "a de-duplicated lane table passes" "yes" "yes";; esac

printf '%s-- C24 self-skips cleanly when the internal config is absent (fork/gitignored) --%s\n' "$B" "$X"
lu_setup
rm -rf "$TMP/lu/skills/jarvis-agency-contract/reference"
out=$(run24)
case "$out" in *"OK"*skipped*) assert_eq "absent internal config self-skips with a pass message" "yes" "yes";;
  *) assert_eq "absent internal config self-skips with a pass message" "no" "yes";; esac

printf '%s-- C24 warns (not silently passes) when the table shape changes --%s\n' "$B" "$X"
lu_setup
lu_cfg <<'CFG'
## Fields and sections

| Lane | Where | Meaning |
|---|---|---|
| PM Acceptance | comment | renamed columns — the check can no longer find the table |
| PM Acceptance | comment | duplicate that would now go unseen |
CFG
out=$(run24)
case "$out" in *WARN*) assert_eq "a renamed lane table warns instead of passing green" "yes" "yes";;
  *) assert_eq "a renamed lane table warns instead of passing green" "no" "yes";; esac
