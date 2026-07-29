# lint-platform.sh CHECK 30 — stall-probe coverage.
#
# The 2026-07-21 wave produced SEVEN denial-of-service defects (a safety rule written absolutely
# becoming a refusal) and all seven passed lint --strict. CHECK 28 catches the authoring shape
# statically; the STALL PROBE is the behavioural half. new-skill.sh scaffolds a `-900-` probe for
# every new skill; CHECK 30 reports which existing skills still lack one.
#
# The load-bearing property these cases pin is that it NEVER GATES. 38 skills predate the
# convention, and warning on a pre-existing backlog would turn --strict red on every future PR and
# train people to ignore the output — the same reasoning CHECK 29 applies to never-evaluated skills.

sp_setup() {
  rm -rf "$TMP/sp"; mkdir -p "$TMP/sp/skills" "$TMP/sp/lib" "$TMP/sp/dist" "$TMP/sp/config"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/sp/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/sp/"
}

sp_skill() { # $1=name $2=probe|noprobe
  mkdir -p "$TMP/sp/skills/$1/evaluations"
  printf -- '---\nname: %s\nversion: 1.0.0\ndescription: x\n---\nbody\n' "$1" > "$TMP/sp/skills/$1/SKILL.md"
  if [ "$2" = probe ]; then
    printf '{"scenarios":[{"id":"%s-001-happy"},{"id":"%s-900-stall-probe"}]}\n' "$1" "$1" \
      > "$TMP/sp/skills/$1/evaluations/baseline-evals.json"
  else
    printf '{"scenarios":[{"id":"%s-001-happy"}]}\n' "$1" \
      > "$TMP/sp/skills/$1/evaluations/baseline-evals.json"
  fi
}

sp_skill_noevals() { # a skill with no eval file at all
  mkdir -p "$TMP/sp/skills/$1"
  printf -- '---\nname: %s\nversion: 1.0.0\ndescription: x\n---\nbody\n' "$1" > "$TMP/sp/skills/$1/SKILL.md"
}

run30() { ( cd "$TMP/sp" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/30\. Stall-probe/,/^$/p' ); }

printf '%s-- C30 reports a skill that ships no stall probe --%s\n' "$B" "$X"
sp_setup; sp_skill jarvis-has probe; sp_skill jarvis-lacks noprobe
out=$(run30)
case "$out" in *NOTE*jarvis-lacks*) assert_eq "a skill with no probe is reported" "yes" "yes";;
  *) assert_eq "a skill with no probe is reported" "no" "yes";; esac

printf '%s-- C30 NEVER gates: the backlog is a NOTE, never WARN or FAIL --%s\n' "$B" "$X"
case "$out" in *WARN*|*FAIL*) assert_eq "the probe backlog does not gate" "no" "yes";;
  *) assert_eq "the probe backlog does not gate" "yes" "yes";; esac

printf '%s-- C30 is quiet when every skill ships a probe --%s\n' "$B" "$X"
sp_setup; sp_skill jarvis-a probe; sp_skill jarvis-b probe
out=$(run30)
case "$out" in *NOTE*) assert_eq "no NOTE when coverage is complete" "no" "yes";;
  *) assert_eq "no NOTE when coverage is complete" "yes" "yes";; esac

printf '%s-- C30 ignores a skill with no eval file at all --%s\n' "$B" "$X"
sp_setup; sp_skill jarvis-a probe; sp_skill_noevals jarvis-noevals
out=$(run30)
case "$out" in *jarvis-noevals*) assert_eq "a skill with no eval file is not reported" "no" "yes";;
  *) assert_eq "a skill with no eval file is not reported" "yes" "yes";; esac
