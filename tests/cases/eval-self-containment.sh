# lint-platform.sh CHECK 25 — eval scenario self-containment.
#
# evaluation-strategy.md: "If the scenario reviews an artifact, it MUST ship a `fixture` — a
# self-contained query is the bar, not a `[PASTE …]` stub." Nothing enforced it, and a scenario
# shipped telling the model to review content that was never supplied; the runner scored the
# improvisation. The rule is CONDITIONAL, so these cases pin BOTH halves: a placeholder WITH a
# resolving fixture is the documented pattern and must pass; without one it must fail.

esc_setup() {
  rm -rf "$TMP/esc"; mkdir -p "$TMP/esc/skills/jarvis-x/evaluations/fixtures" "$TMP/esc/lib" "$TMP/esc/dist"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/esc/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/esc/"
  printf -- '---\nname: jarvis-x\nversion: 1.0.0\ndescription: x\n---\nbody\n' > "$TMP/esc/skills/jarvis-x/SKILL.md"
  printf 'fixture content\n' > "$TMP/esc/skills/jarvis-x/evaluations/fixtures/f1.md"
}
esc_evals() { cat > "$TMP/esc/skills/jarvis-x/evaluations/baseline-evals.json"; }
run25() { ( cd "$TMP/esc" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/25\. Eval scenario self-containment/,/^$/p' ); }

printf '%s-- C25 catches a [PASTE …] stub with no fixture --%s\n' "$B" "$X"
esc_setup
esc_evals <<'JSON'
{"scenarios":[
 {"id":"jarvis-x-001","query":"Review the PRD. [PASTE PRD] Is it sound?","expected_behavior":["x"]}
]}
JSON
out=$(run25)
case "$out" in *FAIL*jarvis-x-001*) assert_eq "a [PASTE] stub with no fixture is caught" "yes" "yes";;
  *) assert_eq "a [PASTE] stub with no fixture is caught" "no" "yes";; esac

printf '%s-- C25 accepts the documented pattern: placeholder + resolving fixture --%s\n' "$B" "$X"
esc_setup
esc_evals <<'JSON'
{"scenarios":[
 {"id":"jarvis-x-001","query":"Review the PRD. [PASTE PRD] Is it sound?","fixture":"fixtures/f1.md","expected_behavior":["x"]}
]}
JSON
out=$(run25)
case "$out" in *FAIL*) assert_eq "placeholder plus a resolving fixture passes" "no" "yes";;
  *) assert_eq "placeholder plus a resolving fixture passes" "yes" "yes";; esac

printf '%s-- C25 catches a fixture pointer that resolves to nothing --%s\n' "$B" "$X"
esc_setup
esc_evals <<'JSON'
{"scenarios":[
 {"id":"jarvis-x-002","query":"Review the PRD. [PASTE PRD]","fixture":"fixtures/does-not-exist.md","expected_behavior":["x"]}
]}
JSON
out=$(run25)
case "$out" in *FAIL*does-not-exist*) assert_eq "a dangling fixture pointer is caught" "yes" "yes";;
  *) assert_eq "a dangling fixture pointer is caught" "no" "yes";; esac

printf '%s-- C25 catches the other placeholder families --%s\n' "$B" "$X"
for ph in '<INSERT THE DIFF>' '{{story}}' '[INSERT AC]' '[...]'; do
  esc_setup
  printf '{"scenarios":[{"id":"jarvis-x-003","query":"Judge this: %s","expected_behavior":["x"]}]}\n' "$ph" \
    > "$TMP/esc/skills/jarvis-x/evaluations/baseline-evals.json"
  out=$(run25)
  case "$out" in *FAIL*) assert_eq "placeholder family caught: $ph" "yes" "yes";;
    *) assert_eq "placeholder family caught: $ph" "no" "yes";; esac
done

printf '%s-- C25 does not false-positive on prose that merely mentions a bracketed value --%s\n' "$B" "$X"
esc_setup
esc_evals <<'JSON'
{"scenarios":[
 {"id":"jarvis-x-004","query":"The mirror's repo-config records quarantine_list: [EPIC-90]. Run the pass. The helper has a // TODO: implement stub.","expected_behavior":["x"]}
]}
JSON
out=$(run25)
case "$out" in *FAIL*) assert_eq "a YAML list literal and a prose TODO are not stubs" "no" "yes";;
  *) assert_eq "a YAML list literal and a prose TODO are not stubs" "yes" "yes";; esac

printf '%s-- C25 fails loudly on malformed JSON --%s\n' "$B" "$X"
esc_setup
printf '{"scenarios": [ oops\n' > "$TMP/esc/skills/jarvis-x/evaluations/baseline-evals.json"
out=$(run25)
case "$out" in *FAIL*) assert_eq "unparseable evals JSON is a FAIL, not a vacuous pass" "yes" "yes";;
  *) assert_eq "unparseable evals JSON is a FAIL, not a vacuous pass" "no" "yes";; esac
