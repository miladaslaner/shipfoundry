# lint-platform.sh CHECK 26 — gate-name -> reference parity.
#
# Three gates were added to the orchestrator's body list and never to reference/enforcement-gates.md,
# so the operative list and the file that explains it diverged silently. The check compares CONTENT
# WORDS, not exact names (the reference deliberately re-words a gate's title), so these cases pin
# both directions: a wholly undocumented gate FAILs, a re-worded but documented one PASSes.

grp_setup() {
  rm -rf "$TMP/grp"
  mkdir -p "$TMP/grp/skills/jarvis-agency-orchestrate/reference" "$TMP/grp/lib" "$TMP/grp/dist"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/grp/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/grp/"
}
grp_body() { # stdin = the gate bullet list
  { printf -- '---\nname: jarvis-agency-orchestrate\nversion: 1.0.0\ndescription: x\n---\n## The gates the orchestrator enforces\n\n'
    cat
    printf '\n## Writing back to Jira\n\nlater section\n'
  } > "$TMP/grp/skills/jarvis-agency-orchestrate/SKILL.md"
}
grp_ref() { cat > "$TMP/grp/skills/jarvis-agency-orchestrate/reference/enforcement-gates.md"; }
run26() { ( cd "$TMP/grp" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/26\. Gate-name/,/^$/p' ); }

printf '%s-- C26 catches a gate listed in the body but absent from the reference --%s\n' "$B" "$X"
grp_setup
grp_body <<'BODY'
- **Claim, serialized** — re-read before dispatch.
- **Quantum flux dampener** — a gate nobody documented.
BODY
grp_ref <<'REF'
# The gates the orchestrator enforces (detail)

- **Claim, serialized.** Entering In Progress sets the owner; re-read and confirm before dispatch.
REF
out=$(run26)
case "$out" in *FAIL*"Quantum flux dampener"*) assert_eq "an undocumented gate is caught" "yes" "yes";;
  *) assert_eq "an undocumented gate is caught" "no" "yes";; esac

printf '%s-- C26 accepts a documented gate the reference re-words --%s\n' "$B" "$X"
grp_setup
grp_body <<'BODY'
- **Every status move records `STATUS-ACTOR:`** — the marker names the role.
BODY
grp_ref <<'REF'
# detail

- **`STATUS-ACTOR:` on every status move.** The orchestrator remains the only writer; the marker
  records which organisational role the move was made for.
REF
out=$(run26)
case "$out" in *FAIL*) assert_eq "a re-worded but documented gate passes" "no" "yes";;
  *) assert_eq "a re-worded but documented gate passes" "yes" "yes";; esac

printf '%s-- C26 fails loudly when the body section is renamed away --%s\n' "$B" "$X"
grp_setup
printf -- '---\nname: jarvis-agency-orchestrate\nversion: 1.0.0\ndescription: x\n---\n## Gates (renamed)\n\n- **Claim, serialized** — x.\n' \
  > "$TMP/grp/skills/jarvis-agency-orchestrate/SKILL.md"
grp_ref <<'REF'
# detail
- **Claim, serialized.** x
REF
out=$(run26)
case "$out" in *FAIL*) assert_eq "a renamed gate section is a FAIL, not a vacuous pass" "yes" "yes";;
  *) assert_eq "a renamed gate section is a FAIL, not a vacuous pass" "no" "yes";; esac

printf '%s-- C26 fails loudly when the bullet shape changes to zero gates --%s\n' "$B" "$X"
grp_setup
grp_body <<'BODY'
Gates are now described in a table instead of bullets.
BODY
grp_ref <<'REF'
# detail
REF
out=$(run26)
case "$out" in *FAIL*ZERO*) assert_eq "a zero-bullet gate list is a FAIL, not a vacuous pass" "yes" "yes";;
  *) assert_eq "a zero-bullet gate list is a FAIL, not a vacuous pass" "no" "yes";; esac

printf '%s-- C26 self-skips on a checkout with no orchestrator --%s\n' "$B" "$X"
grp_setup
rm -rf "$TMP/grp/skills/jarvis-agency-orchestrate"
mkdir -p "$TMP/grp/skills"
out=$(run26)
case "$out" in *OK*skipped*) assert_eq "a non-agency fork self-skips with a pass message" "yes" "yes";;
  *) assert_eq "a non-agency fork self-skips with a pass message" "no" "yes";; esac
