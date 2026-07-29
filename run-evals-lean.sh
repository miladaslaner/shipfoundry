#!/bin/bash
#
# run-evals-lean.sh — run eval-runner.sh in a LEAN environment on a maintainer machine
# (a known eval-harness limitation; hardened from the 2026-07-05 stash workaround).
#
# Problem this solves: on a machine with a rich personal Claude setup, every headless
# `claude -p` call loads the user's global CLAUDE.md, rules/, and skills/ (~90k tokens,
# ~$0.55-equivalent measured 2026-07-05) — above eval-runner's default $0.50/call budget,
# so every scenario fails with "no parseable judge output" before any real work.
#
# NOTE (2026-07-13): eval-runner.sh now self-slims when the CLI supports it
# (--setting-sources "" --disable-slash-commands --strict-mcp-config in call_model), which
# removes the overhead without touching the filesystem. This wrapper remains useful for its
# per-run spend ceiling, the pre-spend probe, and as the fallback on an older CLI without
# --setting-sources (where the stash below is still the only clean room).
#
# Mechanism: temporarily stash ~/.claude/{CLAUDE.md,rules,skills} (leaving a plain-text
# RESTORE-NOTE), PROVE the stash worked with a probe call (health + cost ceiling + token-size
# check) before any real spend, run eval-runner with a per-call budget, enforce a per-run
# spend ceiling, and RESTORE ON ANY EXIT (trap: normal, error, Ctrl-C, kill).
#
# Config (env vars; defaults are the measured lean values):
#   EVAL_LEAN_CALL_CEILING   trivial-PROBE ceiling in $-equivalent (default 0.30) — gates only
#                            the "reply ok" probe that proves the stash worked. NOT the eval
#                            budget: a real EXECUTE call carries the skill body + companion +
#                            fixture + a long generated artifact and legitimately costs more.
#   EVAL_LEAN_EXEC_BUDGET    per-call budget passed to eval-runner (--max-budget-usd; default
#                            0.75 — the harness docs' long-structured-output guidance). Setting
#                            this at or below the probe ceiling STARVES real scenarios into
#                            "no parseable judge output" (2026-07-06 incident: 73/85 scenarios
#                            failed that way under a 0.30 budget).
#   EVAL_LEAN_RUN_CEILING    per-run ceiling in $-equivalent (default 20.00; abort between
#                            skills when exceeded — checked post-invocation, so the ceiling
#                            can be overshot by at most one skill's cost)
#   EVAL_LEAN_TOKEN_CEILING  probe cache-creation token ceiling proving the stash worked
#                            (default 60000; a failed stash reads ~90k+)
#
# Usage (args pass through to eval-runner.sh; --allow-nested is added automatically):
#   ./run-evals-lean.sh                          # full suite, per-skill, run-ceiling enforced
#   ./run-evals-lean.sh <skill>                  # one skill
#   ./run-evals-lean.sh <skill> --scenario <id>  # one scenario
#
# Exit: 0 all pass · 1 eval failures · 2 setup/probe/ceiling abort (nothing further spent).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CD="$HOME/.claude"
S="evalstash"
CALL_CEIL="${EVAL_LEAN_CALL_CEILING:-0.30}"
EXEC_BUDGET="${EVAL_LEAN_EXEC_BUDGET:-0.75}"
RUN_CEIL="${EVAL_LEAN_RUN_CEILING:-20.00}"
TOK_CEIL="${EVAL_LEAN_TOKEN_CEILING:-60000}"
command -v jq >/dev/null || { echo "run-evals-lean needs jq" >&2; exit 2; }

moved=()
restore() {
  local p
  for p in ${moved[@]+"${moved[@]}"}; do   # bash-3.2-safe empty-array expansion under set -u
    [ -e "$p.$S" ] && mv -f "$p.$S" "$p" && echo "[restore] $p"
  done
  # Only the invocation that stashed may remove the note — an aborting second run must not
  # delete the active run's recovery signal.
  [ "${#moved[@]}" -gt 0 ] && rm -f "$CD/RESTORE-NOTE.txt"
  rm -f "${PROBE_ERR_FILE:-}"
  return 0
}
trap restore EXIT INT TERM

# Refuse to stash over another active lean run — a second run's restore would clobber the first.
[ -e "$CD/RESTORE-NOTE.txt" ] && { echo "[ABORT] RESTORE-NOTE.txt present — another lean run appears active (or a prior run died; restore *.$S by hand first)." >&2; exit 2; }

for p in "$CD/CLAUDE.md" "$CD/rules" "$CD/skills"; do
  [ -e "$p" ] && mv "$p" "$p.$S" && moved+=("$p") && echo "[stash] $p"
done
# Only write the recovery note when something was actually stashed (e.g. a bare ~/.claude with
# no CLAUDE.md/rules/skills) — otherwise the note is written, restore() never removes it (moved
# is empty), and it permanently blocks every future run with the "another lean run appears
# active" refusal above.
if [ "${#moved[@]}" -gt 0 ]; then
  cat > "$CD/RESTORE-NOTE.txt" <<NOTE
Temporary: run-evals-lean.sh stashed CLAUDE.md, rules/, skills/ (suffix .$S).
They restore automatically when the run exits. If this note remains and items
look missing, rename each *.$S back to its original name.
NOTE
fi

# ---- probe: health + cost ceiling + token-size proof the stash actually worked ----------
PROBE_ERR_FILE=$(mktemp)
probe=$(echo "reply with the word ok" | claude -p --model sonnet --output-format json 2>"$PROBE_ERR_FILE")
p_res=$(printf '%s' "$probe" | jq -r '.result // empty')
p_cost=$(printf '%s' "$probe" | jq -r '.total_cost_usd // 0')
p_tok=$(printf '%s' "$probe" | jq -r '(.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)')
echo "[probe] result=$p_res cost=$p_cost overhead_tokens=$p_tok (ceilings: call \$$CALL_CEIL, tokens $TOK_CEIL)"
ok=$(awk -v c="$p_cost" -v cc="$CALL_CEIL" -v t="$p_tok" -v tc="$TOK_CEIL" 'BEGIN{print (c>0 && c<cc && t<tc)?1:0}')
p_res_norm=$(printf '%s' "$p_res" | tr -d '[:punct:][:space:]' | tr '[:upper:]' '[:lower:]')
if [ "$ok" != "1" ] || [ "$p_res_norm" != "ok" ]; then
  echo "[ABORT] probe failed a gate (unhealthy, cost >= \$$CALL_CEIL, or overhead >= $TOK_CEIL tokens" \
       "— the stash may not have taken effect). No eval spend incurred. CLI stderr: $PROBE_ERR_FILE" >&2
  exit 2
fi

# ---- run, with the per-run ceiling ------------------------------------------------------
run_total=0
run_one() {  # invoke eval-runner once with the EXEC budget (never the probe ceiling)
  "$ROOT/eval-runner.sh" --allow-nested --max-budget-usd "$EXEC_BUDGET" "$@"
  rc=$?
  return $rc
}
sum_from_log() { grep -E '^EVAL_COST_USD=[0-9.]+$' "$1" | tail -1 | cut -d= -f2; }

overall_rc=0
LOG=$(mktemp)
if [ $# -gt 0 ]; then
  run_one "$@" 2>&1 | tee "$LOG"; overall_rc=${PIPESTATUS[0]}
  c=$(sum_from_log "$LOG")
  if [ -z "$c" ]; then
    if [ "$overall_rc" -eq 2 ]; then
      echo "[ABORT] eval-runner reported a setup error (exit 2) — fix the invocation." >&2
    else
      echo "[ABORT] eval-runner output had no EVAL_COST_USD line — the run ceiling cannot be enforced. Stopping." >&2
    fi
    rm -f "$LOG"; exit 2
  fi
  run_total=$c
else
  for d in "$ROOT/skills"/*/; do
    sk=$(basename "$d")
    [ -f "$d/evaluations/baseline-evals.json" ] || continue
    run_one "$sk" 2>&1 | tee "$LOG"; rc=${PIPESTATUS[0]}
    [ "$rc" -ne 0 ] && overall_rc=1
    c=$(sum_from_log "$LOG")
    if [ -z "$c" ]; then
      if [ "$rc" -eq 2 ]; then
        echo "[ABORT] eval-runner reported a setup error (exit 2) for $sk — fix the invocation." >&2
      else
        echo "[ABORT] eval-runner output had no EVAL_COST_USD line — the run ceiling cannot be enforced. Stopping." >&2
      fi
      rm -f "$LOG"; exit 2
    fi
    run_total=$(awk -v a="$run_total" -v b="$c" 'BEGIN{printf "%.4f", a+b}')
    over=$(awk -v t="$run_total" -v m="$RUN_CEIL" 'BEGIN{print (t>=m)?1:0}')
    if [ "$over" = "1" ]; then
      echo "[ABORT] per-run ceiling reached (\$$run_total >= \$$RUN_CEIL) — stopping before the next skill." >&2
      rm -f "$LOG"; exit 2
    fi
  done
fi
rm -f "$LOG"
echo "[lean-run] total reported spend: \$${run_total} (ceiling \$$RUN_CEIL)"
exit "$overall_rc"
