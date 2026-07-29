# eval-runner.sh helpers + behaviour. Functions (path_is_safe, skill_description) come from the
# library sourced by run-tests.sh. Uses $TMP, $ROOT, assert_*.

printf '%s-- C3 flag with no value fails cleanly (set -u) --%s\n' "$B" "$X"
out="$(cd "$ROOT" && ./eval-runner.sh --samples 2>&1)"; rc=$?
assert_ne "non-zero exit when --samples has no value" "$rc" "0"
case "$out" in *"requires a value"*) assert_eq "clear error message" "yes" "yes" ;; *) assert_eq "clear error message" "$out" "...requires a value..." ;; esac

printf '%s-- C4 strict-majority vote (a tie is not a majority) --%s\n' "$B" "$X"
vote() { awk -v p="$1" -v t="$2" 'BEGIN{print (p*2>t && p>0)?1:0}'; }
assert_eq "tie 1/2 → FAIL (was the bug: >= passed it)" "$(vote 1 2)" "0"
assert_eq "majority 2/3 → PASS" "$(vote 2 3)" "1"
assert_eq "single sample pass 1/1 → PASS" "$(vote 1 1)" "1"
assert_eq "single sample fail 0/1 → FAIL" "$(vote 0 1)" "0"
assert_eq "minority 1/3 → FAIL" "$(vote 1 3)" "0"

printf '%s-- C16 path-traversal guard --%s\n' "$B" "$X"
safe() { path_is_safe "$1"; echo $?; }
assert_eq "plain fixture path is safe"   "$(safe 'fixtures/foo.md')"   "0"
assert_eq "bare skill name is safe"      "$(safe 'jarvis-foo')"        "0"
assert_eq "absolute path rejected"       "$(safe '/etc/passwd')"       "1"
assert_eq "leading ../ rejected"         "$(safe '../secret.md')"      "1"
assert_eq "embedded /../ rejected"       "$(safe 'fixtures/../../x')"  "1"
assert_eq "trailing /.. rejected"        "$(safe 'a/..')"              "1"
assert_eq "bare .. rejected"             "$(safe '..')"                "1"

printf '%s-- Ccost cost accounting (subshell fix) --%s\n' "$B" "$X"
if grep -q 'COST_FILE' "$ROOT/eval-runner.sh"; then assert_eq "COST_FILE accumulator in source" "yes" "yes"
else assert_eq "COST_FILE accumulator in source" "no" "yes"; fi
if grep -Fq 'COST_TOTAL=$(awk -v a="$COST_TOTAL"' "$ROOT/eval-runner.sh"; then assert_eq "old in-subshell accumulation removed" "present" "absent"
else assert_eq "old in-subshell accumulation removed" "absent" "absent"; fi
cf="$TMP/costs"; printf '0.10\n0.23\n0\n' > "$cf"
assert_eq "cost file sums correctly" "$(awk '{s+=$1} END{printf "%.4f", s+0}' "$cf")" "0.3300"

printf '%s-- Cselection description-only selection mode --%s\n' "$B" "$X"
cat > "$TMP/sel.md" <<'EOF'
---
name: x
description: Use when you need a thing. Does not trigger otherwise.
version: 1.0.0
---
BODY_LINE_SHOULD_NOT_APPEAR
EOF
desc="$(skill_description "$TMP/sel.md")"
assert_eq "skill_description extracts the description" "$desc" "Use when you need a thing. Does not trigger otherwise."
case "$desc" in *BODY_LINE*) leak=yes ;; *) leak=no ;; esac
assert_eq "selection feed excludes the body" "$leak" "no"
if grep -Fq '"$mode" = "selection"' "$ROOT/eval-runner.sh"; then assert_eq "selection-mode branch in source" "yes" "yes"
else assert_eq "selection-mode branch in source" "no" "yes"; fi

printf '%s-- Cvacuous explicit target must not pass vacuously --%s\n' "$B" "$X"
out="$(cd "$ROOT" && EVAL_RUNNER_LIB=0 ./eval-runner.sh jarvis-no-such-skill --dry-run 2>&1)"; rc=$?
assert_ne "typo'd skill name exits non-zero" "$rc" "0"
case "$out" in *"no such skill"*) assert_eq "typo'd skill: clear error" "yes" "yes" ;; *) assert_eq "typo'd skill: clear error" "$out" "...no such skill..." ;; esac
out="$(cd "$ROOT" && EVAL_RUNNER_LIB=0 ./eval-runner.sh jarvis-example --scenario no-such-id --dry-run 2>&1)"; rc=$?
assert_ne "typo'd scenario id exits non-zero" "$rc" "0"
case "$out" in *"no scenario matched"*) assert_eq "typo'd scenario: clear error" "yes" "yes" ;; *) assert_eq "typo'd scenario: clear error" "$out" "...no scenario matched..." ;; esac

printf '%s-- Cmode unknown scenario mode must FAIL, not silently run as apply --%s\n' "$B" "$X"
mkdir -p "$TMP/modes/jarvis-m/evaluations"
printf -- '---\nname: jarvis-m\nversion: 1.0.0\n---\nbody\n' > "$TMP/modes/jarvis-m/SKILL.md"
printf '{"scenarios":[{"id":"m-1","mode":"slection","query":"q","expected_behavior":["a"]}]}' \
  > "$TMP/modes/jarvis-m/evaluations/baseline-evals.json"
f=$( SKILLS_DIR="$TMP/modes"; DRY_RUN=1; FAILS=0; run_skill jarvis-m >/dev/null 2>&1; echo "$FAILS" )
assert_ne "unknown mode => FAIL counted" "$f" "0"

printf '%s-- Cdiag execute-vs-judge failure diagnosis + dead code gone --%s\n' "$B" "$X"
if grep -q 'EXECUTE produced no output' "$ROOT/eval-runner.sh"; then assert_eq "distinct EXECUTE-failure message" "yes" "yes"
else assert_eq "distinct EXECUTE-failure message" "no" "yes"; fi
if grep -q 'ERR_FILE' "$ROOT/eval-runner.sh"; then assert_eq "CLI stderr captured, not discarded" "yes" "yes"
else assert_eq "CLI stderr captured, not discarded" "no" "yes"; fi
if grep -q 'local asserts; asserts=' "$ROOT/eval-runner.sh"; then assert_eq "dead asserts var removed" "present" "absent"
else assert_eq "dead asserts var removed" "absent" "absent"; fi

printf '%s-- Ccleanroom clean-room execution + budget-kill diagnostics (2026-07-13, gap G2) --%s\n' "$B" "$X"
# call_model must run claude -p with the clean-room flags (no global CLAUDE.md/rules/skills/MCP
# in the eval context), gated on CLI support so an older CLI still runs bare.
if grep -q -- '--setting-sources' "$ROOT/eval-runner.sh"; then assert_eq "clean-room --setting-sources in call path" "yes" "yes"
else assert_eq "clean-room --setting-sources in call path" "no" "yes"; fi
if grep -q -- '--disable-slash-commands' "$ROOT/eval-runner.sh" && grep -q -- '--strict-mcp-config' "$ROOT/eval-runner.sh"; then
  assert_eq "clean-room skill+MCP flags in call path" "yes" "yes"
else assert_eq "clean-room skill+MCP flags in call path" "no" "yes"; fi
if grep -q 'CLEANROOM=()' "$ROOT/eval-runner.sh"; then assert_eq "clean-room degrades gracefully on old CLI" "yes" "yes"
else assert_eq "clean-room degrades gracefully on old CLI" "no" "yes"; fi
# An empty EXECUTE result must surface the CLI's own terminal_reason (a budget kill said
# "check auth" on 2026-07-13 and misdirected the diagnosis while $10.93 burned).
if grep -q 'terminal_reason' "$ROOT/eval-runner.sh"; then assert_eq "empty-result FAIL surfaces terminal_reason" "yes" "yes"
else assert_eq "empty-result FAIL surfaces terminal_reason" "no" "yes"; fi
if grep -q 'DIAG_FILE' "$ROOT/eval-runner.sh"; then assert_eq "diagnostics land in a parent-readable file" "yes" "yes"
else assert_eq "diagnostics land in a parent-readable file" "no" "yes"; fi
