# lint-platform.sh CHECK 29 + eval-runner.sh's receipt writer.
#
# CLAUDE.md says to run ./eval-runner.sh when behaviour changed and nothing enforced it — a
# memory-enforced invariant. The behavioural gate found 7 of 7 real defects in the 2026-07-21
# sweep; the structural gates found 0 of 7. The gate cannot run in CI (live model calls, money),
# so config/eval-receipts.md is the enforceable proxy: a MINOR/MAJOR bump past the recorded
# version means behaviour changed since anything replayed it.

er_setup() {
  rm -rf "$TMP/er"; mkdir -p "$TMP/er/skills" "$TMP/er/lib" "$TMP/er/dist" "$TMP/er/config"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/er/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/er/"
}

er_skill() { # $1=name $2=version
  mkdir -p "$TMP/er/skills/$1/evaluations"
  printf -- '---\nname: %s\nversion: %s\ndescription: x\n---\nbody\n' "$1" "$2" > "$TMP/er/skills/$1/SKILL.md"
  printf '{"scenarios":[]}\n' > "$TMP/er/skills/$1/evaluations/baseline-evals.json"
}

er_receipts() { # rows on stdin
  { printf '| Skill | Version evaluated | Date | Scenarios | Failed |\n|---|---|---|---|---|\n'; cat; } \
    > "$TMP/er/config/eval-receipts.md"
}

run29() { ( cd "$TMP/er" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/29\. Eval receipt/,/^$/p' ); }

# CHECK 29 REPORTS, IT NEVER GATES. The remedy costs real money and is rate-limited — it first
# fired on a change that could not be cleared for three days. Gating merges on it would either
# stall work or push people to silence it by editing the receipt, which would make the whole trail
# worthless. It must emit a NOTE and must NOT warn.
printf '%s-- C29 reports a MINOR bump past the receipt as a NOTE, not a gating WARN --%s\n' "$B" "$X"
er_setup; er_skill jarvis-x 0.10.0
er_receipts <<'R'
| jarvis-x | 0.9.0 | 2026-07-21 | 12 | 1 |
R
out=$(run29)
case "$out" in *NOTE*jarvis-x*) assert_eq "a minor bump past the receipt is reported" "yes" "yes";;
  *) assert_eq "a minor bump past the receipt is reported" "no" "yes";; esac
case "$out" in *WARN*) assert_eq "reporting a stale receipt does not gate" "no" "yes";;
  *) assert_eq "reporting a stale receipt does not gate" "yes" "yes";; esac

printf '%s-- C29 is quiet on a PATCH-only bump --%s\n' "$B" "$X"
er_setup; er_skill jarvis-x 0.9.2
er_receipts <<'R'
| jarvis-x | 0.9.1 | 2026-07-21 | 12 | 1 |
R
out=$(run29)
case "$out" in *WARN*) assert_eq "a patch bump does not warn" "no" "yes";;
  *) assert_eq "a patch bump does not warn" "yes" "yes";; esac

printf '%s-- C29 compares versions NUMERICALLY (0.10.0 > 0.9.0) --%s\n' "$B" "$X"
# string comparison would call 0.10.0 "behind" 0.9.0 and warn on an up-to-date receipt
er_setup; er_skill jarvis-x 0.10.0
er_receipts <<'R'
| jarvis-x | 0.10.0 | 2026-07-21 | 12 | 1 |
R
out=$(run29)
case "$out" in *WARN*) assert_eq "0.10.0 receipt is not 'behind' 0.10.0" "no" "yes";;
  *) assert_eq "0.10.0 receipt is not 'behind' 0.10.0" "yes" "yes";; esac
# and the converse: 0.9.0 current with a 0.10.0 receipt is ahead, not behind -> quiet
er_setup; er_skill jarvis-x 0.9.0
er_receipts <<'R'
| jarvis-x | 0.10.0 | 2026-07-21 | 12 | 1 |
R
out=$(run29)
case "$out" in *WARN*) assert_eq "a receipt AHEAD of the skill is not reported as behind" "no" "yes";;
  *) assert_eq "a receipt AHEAD of the skill is not reported as behind" "yes" "yes";; esac

# A skill that was NEVER evaluated is a BACKLOG item, not a regression this change introduced.
# Warning per skill would turn --strict red on every future PR for a pre-existing condition, which
# trains people to ignore the check. It is reported once as a NOTE and must NOT warn.
printf '%s-- C29 reports never-evaluated skills as a NOTE, not a gating WARN --%s\n' "$B" "$X"
er_setup; er_skill jarvis-x 1.0.0; er_skill jarvis-y 1.0.0
er_receipts <<'R'
| jarvis-x | 1.0.0 | 2026-07-21 | 12 | 1 |
R
out=$(run29)
case "$out" in *NOTE*jarvis-y*) assert_eq "a never-evaluated skill is reported as a NOTE" "yes" "yes";;
  *) assert_eq "a never-evaluated skill is reported as a NOTE" "no" "yes";; esac
case "$out" in *WARN*jarvis-y*) assert_eq "a never-evaluated skill does NOT gate" "no" "yes";;
  *) assert_eq "a never-evaluated skill does NOT gate" "yes" "yes";; esac

printf '%s-- C29 self-skips when there is no receipts file (a fork) --%s\n' "$B" "$X"
er_setup; er_skill jarvis-x 1.0.0
out=$(run29)
case "$out" in *OK*skipped*) assert_eq "no receipts file self-skips cleanly" "yes" "yes";;
  *) assert_eq "no receipts file self-skips cleanly" "no" "yes";; esac

printf '%s-- C29 fails LOUDLY when the receipts table parses to nothing --%s\n' "$B" "$X"
er_setup; er_skill jarvis-x 1.0.0
printf '# Eval receipts\n\nthe table shape changed and no row parses any more.\n' > "$TMP/er/config/eval-receipts.md"
out=$(run29)
case "$out" in *FAIL*ZERO*) assert_eq "an unparseable receipts table is a FAIL, not a vacuous pass" "yes" "yes";;
  *) assert_eq "an unparseable receipts table is a FAIL, not a vacuous pass" "no" "yes";; esac

# ---- the writer side (eval-runner.sh) ---------------------------------------
# The runner is sourced by run-tests.sh with EVAL_RUNNER_LIB=1, so record_eval_receipt is in
# scope. It reads the run-shape globals; set them per case.
printf '%s-- receipt writer: no row for a ZERO-scenario run --%s\n' "$B" "$X"
mkdir -p "$TMP/erw"
EVAL_RECEIPTS_FILE="$TMP/erw/receipts.md"; rm -f "$EVAL_RECEIPTS_FILE"
ONLY_SKILL="jarvis-example"; ONLY_SCENARIO=""; DRY_RUN=0
# graded=0 is the rate-limited / rejected-every-call case: 100% "failure" at $0.00 cost.
record_eval_receipt "jarvis-example" 0 26 26
assert_eq "a zero-scenario run writes no receipt file at all" "$([ -f "$EVAL_RECEIPTS_FILE" ] && echo yes || echo no)" "no"

printf '%s-- receipt writer: writes, then UPSERTS, a full run --%s\n' "$B" "$X"
record_eval_receipt "jarvis-example" 26 26 4
got=$(grep -c '^| jarvis-example |' "$EVAL_RECEIPTS_FILE" 2>/dev/null || echo 0)
assert_eq "a full graded run writes exactly one row" "$got" "1"
record_eval_receipt "jarvis-example" 26 26 0
got=$(grep -c '^| jarvis-example |' "$EVAL_RECEIPTS_FILE" 2>/dev/null || echo 0)
assert_eq "a second run upserts rather than appending" "$got" "1"
case "$(grep '^| jarvis-example |' "$EVAL_RECEIPTS_FILE")" in *'| 26 | 0 |') assert_eq "the row carries the latest counts" "yes" "yes";;
  *) assert_eq "the row carries the latest counts" "no" "yes";; esac

printf '%s-- receipt writer: refuses a partial run (--scenario / --dry-run) --%s\n' "$B" "$X"
rm -f "$EVAL_RECEIPTS_FILE"
ONLY_SCENARIO="scn-001"; record_eval_receipt "jarvis-example" 1 1 0; ONLY_SCENARIO=""
assert_eq "a --scenario run writes no receipt" "$([ -f "$EVAL_RECEIPTS_FILE" ] && echo yes || echo no)" "no"
DRY_RUN=1; record_eval_receipt "jarvis-example" 26 26 0; DRY_RUN=0
assert_eq "a --dry-run writes no receipt" "$([ -f "$EVAL_RECEIPTS_FILE" ] && echo yes || echo no)" "no"
ONLY_SKILL=""; record_eval_receipt "jarvis-example" 26 26 0
assert_eq "an all-skills run writes no receipt" "$([ -f "$EVAL_RECEIPTS_FILE" ] && echo yes || echo no)" "no"
EVAL_RECEIPTS_FILE="$ROOT/config/eval-receipts.md"
