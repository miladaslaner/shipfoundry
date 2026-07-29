# lean-runner.sh — the cost handoff between eval-runner and run-evals-lean must be a stable
# machine-readable key, and the stash/restore must be whitespace-safe (VIBE-004/005/013).

printf '%s-- Clean machine-readable cost handoff --%s\n' "$B" "$X"
if grep -q 'EVAL_COST_USD=' "$ROOT/eval-runner.sh"; then assert_eq "eval-runner emits EVAL_COST_USD key" "yes" "yes"
else assert_eq "eval-runner emits EVAL_COST_USD key" "no" "yes"; fi
if grep -q 'EVAL_COST_USD=' "$ROOT/run-evals-lean.sh"; then assert_eq "lean consumes EVAL_COST_USD key" "yes" "yes"
else assert_eq "lean consumes EVAL_COST_USD key" "no" "yes"; fi
if grep -q 'approx model cost this run' "$ROOT/run-evals-lean.sh"; then assert_eq "lean no longer scrapes the prose line" "present" "absent"
else assert_eq "lean no longer scrapes the prose line" "absent" "absent"; fi

printf '%s-- Clean whitespace-safe stash bookkeeping --%s\n' "$B" "$X"
if grep -q 'moved=()' "$ROOT/run-evals-lean.sh"; then assert_eq "stash list is a bash array" "yes" "yes"
else assert_eq "stash list is a bash array" "no" "yes"; fi
if grep -Eq 'for p in \$moved' "$ROOT/run-evals-lean.sh"; then assert_eq "unquoted word-split loop removed" "present" "absent"
else assert_eq "unquoted word-split loop removed" "absent" "absent"; fi
if grep -qE '\[ "\$\{#moved\[@\]\}" -gt 0 \] && rm -f' "$ROOT/run-evals-lean.sh"; then assert_eq "restore removes the note only after a real stash" "yes" "yes"
else assert_eq "restore removes the note only after a real stash" "no" "yes"; fi

printf '%s-- Clean probe tolerates model formatting --%s\n' "$B" "$X"
norm() { printf '%s' "$1" | tr -d '[:punct:][:space:]' | tr '[:upper:]' '[:lower:]'; }
assert_eq "probe normalizer: 'Ok.' == ok" "$(norm 'Ok.')" "ok"
assert_eq "probe normalizer: ' OK! ' == ok" "$(norm ' OK! ')" "ok"
if grep -q "tr -d '\[:punct:\]\[:space:\]'" "$ROOT/run-evals-lean.sh"; then assert_eq "probe normalization in source" "yes" "yes"
else assert_eq "probe normalization in source" "no" "yes"; fi
