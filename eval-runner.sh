#!/usr/bin/env bash
#
# eval-runner.sh — replay each skill's baseline-evals.json scenarios against the model
# and score them, turning the static eval files into a real regression gate.
# Companion to lint-platform.sh: the lint enforces STRUCTURE; this
# enforces BEHAVIOUR.
#
# Mechanism: the `claude` CLI in headless mode (`-p`). No API key needed — it uses the
# existing Claude Code auth. Calls run in a CLEAN ROOM (--setting-sources "" plus
# --disable-slash-commands --strict-mcp-config, when the CLI supports it): the machine's
# global CLAUDE.md/rules/skills/MCP config is NOT loaded, so the execution sees exactly the
# inlined skill + companions, and no per-call budget is burned on config overhead (gap G2).
# Each scenario is run in TWO calls:
#   1. EXECUTE — the skill's SKILL.md body is inlined as the active skill, then the
#      scenario `query` is sent; the model's response is captured.
#   2. JUDGE   — the response + the scenario's `expected_behavior` list are sent to a
#      judge model, which scores each assertion pass/fail. Output parsed as JSON.
#
# Scenario modes: default ("apply") force-loads the body and tests applying the skill. A scenario
# with "mode": "selection" feeds only the name + description and asks the model to classify the
# query IN SCOPE / OUT OF SCOPE — testing trigger selection (the body is NOT inlined).
#
# IMPORTANT: by default this refuses to run inside a Claude Code session — not because it would
# crash (headless `claude -p` does run nested), but because a full run nests dozens of model calls
# under your interactive session. Run it in a normal terminal or CI; --allow-nested forces a
# bounded run; --dry-run inspects prompts safely from anywhere.
#
# TRUST BOUNDARY: this inlines the skill body, fixtures, and companion skill bodies into model
# prompts. Run it ONLY against skill files you trust (your own repo). Do NOT run it against an
# unreviewed external contribution before a human has read the SKILL.md + fixtures — a malicious
# body or fixture can attempt prompt-injection on the judge. The path guards below block file
# traversal via the fixture/companion fields; they do NOT neutralise injection via file *contents*.
#
# Usage:
#   ./eval-runner.sh                          # run every skill that has baseline-evals.json
#   ./eval-runner.sh <skill>                  # run one skill
#   ./eval-runner.sh <skill> --scenario <id>  # run one scenario
#   ./eval-runner.sh --dry-run                # assemble + print prompts; NO model calls
#   ./eval-runner.sh --exec-model opus --judge-model sonnet
#   ./eval-runner.sh --max-budget-usd 0.30    # per-call ceiling (default 0.50)
#   ./eval-runner.sh --threshold 1.0          # fraction of assertions to PASS (default 1.0)
#   ./eval-runner.sh --samples 3              # run each scenario N times, majority verdict (variance-prone gates)
#   ./eval-runner.sh --allow-nested           # permit a bounded run inside a Claude Code session
#   ./eval-runner.sh --with-references        # also inline reference/*.md into the execute prompt
#
# Exit codes: 0 = all run scenarios PASS at the threshold; 1 = one or more FAIL; 2 = setup error.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$ROOT/skills"
# shellcheck source=lib/skill-md.sh
. "$ROOT/lib/skill-md.sh"

# ---- defaults / args --------------------------------------------------------
EXEC_MODEL="sonnet"
JUDGE_MODEL="sonnet"
MAX_BUDGET="0.50"
THRESHOLD="1.0"
DRY_RUN=0
WITH_REFS=0
ALLOW_NESTED=0
SAMPLES=1
ONLY_SKILL=""
ONLY_SCENARIO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --allow-nested) ALLOW_NESTED=1 ;;
    --samples) SAMPLES="${2:?--samples requires a value}"; shift ;;
    --with-references) WITH_REFS=1 ;;
    --exec-model) EXEC_MODEL="${2:?--exec-model requires a value}"; shift ;;
    --judge-model) JUDGE_MODEL="${2:?--judge-model requires a value}"; shift ;;
    --max-budget-usd) MAX_BUDGET="${2:?--max-budget-usd requires a value}"; shift ;;
    --threshold) THRESHOLD="${2:?--threshold requires a value}"; shift ;;
    --scenario) ONLY_SCENARIO="${2:?--scenario requires a value}"; shift ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) ONLY_SKILL="$1" ;;
  esac
  shift
done

if [ -t 1 ]; then R=$'\e[31m'; Y=$'\e[33m'; G=$'\e[32m'; B=$'\e[1m'; X=$'\e[0m'; else R=""; Y=""; G=""; B=""; X=""; fi

command -v jq >/dev/null || { echo "eval-runner needs jq" >&2; exit 2; }

# ---- nested-session guard ---------------------------------------------------
# Headless `claude -p` subprocesses DO run from inside a Claude Code session (verified
# 2026-06-10). The guard is a cost/clarity safeguard, not a crash-prevention: a full run
# nests dozens of model calls under your interactive session. Pass --allow-nested to
# override (bounded runs), or run in a plain terminal / CI for the full suite.
# Skipped when sourced as a lib for testing (EVAL_RUNNER_LIB=1) — the guard + run have side
# effects (exit / model calls); sourcing wants only the pure helpers below.
if [ "${EVAL_RUNNER_LIB:-0}" != "1" ]; then
  if [ "${CLAUDECODE:-}" = "1" ] && [ "$DRY_RUN" -eq 0 ] && [ "$ALLOW_NESTED" -eq 0 ]; then
    echo "${R}REFUSING:${X} running inside a Claude Code session nests model calls under your session." >&2
    echo "Pass --allow-nested for a bounded run here, run in a plain terminal / CI, or use --dry-run." >&2
    exit 2
  fi
  # --dry-run makes no model calls ("inspects prompts safely from anywhere" — header), so it
  # must not require the CLI: CI has no `claude` yet runs the dry-run-based tests.
  if [ "$DRY_RUN" -eq 0 ]; then
    command -v claude >/dev/null || { echo "eval-runner needs the 'claude' CLI" >&2; exit 2; }
  fi
fi

# ---- helpers ----------------------------------------------------------------
# Reject a path that escapes its intended base — absolute, or containing a ".." segment.
# Portable (no realpath dependency, which differs BSD/macOS vs GNU). Applied to the fixture and
# companion fields read from baseline-evals.json, which are attacker-controlled in the untrusted-
# contributor threat model. Blocks path traversal; does NOT neutralise content-level injection.
path_is_safe() {
  case "$1" in
    /*|../*|*/../*|*/..|..) return 1 ;;
    *) return 0 ;;
  esac
}

# SKILL.md body (everything after the second frontmatter '---'). Delegates to lib/skill-md.sh —
# the single source shared with lint-platform.sh (body_lines_of).
skill_body() { skill_body_of "$1"; }

# Frontmatter description only — how a skill is actually selected (body not yet loaded).
# Mirrors lint-platform.sh desc_of's awk fallback: drop a block-scalar indicator + surrounding quotes.
skill_description() {
  awk '/^description:/{flag=1; sub(/^description: */,""); print; next} flag && /^[a-z_]+:/{flag=0} flag' "$1" \
    | sed -E '1s/^[|>][+-]?[0-9]*[[:space:]]*$//' | tr -d '\n' | sed -E 's/^[[:space:]]+//; s/^"(.*)"$/\1/'
}

# One headless model call. stdin = prompt; echoes the model's text result; appends cost.
COST_TOTAL=0
JUDGE_BUDGET="1.50"   # judges read a large EXECUTE output as input; give the short JSON reply room

# Clean-room flags (2026-07-13). A bare `claude -p` loads the machine's global config — the
# user's CLAUDE.md, rules, skills, and MCP schemas (~90k tokens measured on a rich setup,
# a known eval-harness limitation) — which both CONTAMINATES the execution (this runner inlines the skill and
# its companions explicitly; nothing else should be in context) and can starve --max-budget-usd
# on pure overhead before the skill answers ($10.93 burned across 16 all-FAIL scenarios,
# 2026-07-13). These flags give a clean room with the user's existing auth intact
# (--bare would require ANTHROPIC_API_KEY, so it is not used). Probed once: an older CLI
# without --setting-sources runs bare as before — run-evals-lean.sh's stash covers that case.
CLEANROOM=()
# NOT `grep -q`: under `set -o pipefail`, -q's early exit can EPIPE the writer and turn a
# successful match into a pipeline failure — here that would SILENTLY degrade to a bare (no
# clean-room) run and reintroduce the budget blowout. Full-read + >/dev/null is race-free.
if command -v claude >/dev/null 2>&1 && claude --help 2>/dev/null | grep -F -- '--setting-sources' >/dev/null; then
  CLEANROOM=(--setting-sources "" --disable-slash-commands --strict-mcp-config)
fi

call_model() {
  local model="$1" budget="${2:-$MAX_BUDGET}" out result cost
  out=$(claude -p ${CLEANROOM[@]+"${CLEANROOM[@]}"} --model "$model" --output-format json --max-budget-usd "$budget" 2>>"${ERR_FILE:-/dev/null}")
  result=$(printf '%s' "$out" | jq -r '.result // empty' 2>/dev/null)
  cost=$(printf '%s' "$out" | jq -r '(.total_cost_usd // .cost_usd // .usage.total_cost_usd // 0) | tostring' 2>/dev/null)
  # call_model is invoked inside $(...) (a subshell) at every call site, so assigning COST_TOTAL
  # here is discarded when the subshell exits — that is why the run summary always read $0.
  # Append each call's cost to a file the parent sums at the end. ${COST_FILE:-/dev/null} keeps
  # this inert when the script is sourced as a lib (EVAL_RUNNER_LIB=1).
  printf '%s\n' "${cost:-0}" >> "${COST_FILE:-/dev/null}"
  # Empty result with real cost = the CLI ran and was cut off (budget kill, API error). Record
  # WHY from the CLI's own JSON so the FAIL line names the cause instead of guessing at auth —
  # the 2026-07-13 incident was a budget kill misread as an auth problem.
  if [ -z "$result" ]; then
    printf '%s\n' "$(printf '%s' "$out" | jq -r '"terminal_reason=\(.terminal_reason // "?") subtype=\(.subtype // "?") is_error=\(.is_error // "?") cost=\(.total_cost_usd // 0)"' 2>/dev/null)" >> "${DIAG_FILE:-/dev/null}"
  fi
  printf '%s' "$result"
}

FAILS=0
RUN=0
MATCHED=0
GRADED=0   # scenarios that produced a real verdict — the receipt's precondition (see below)

# ---- eval receipt -----------------------------------------------------------
# config/eval-receipts.md records WHICH VERSION of a skill the behavioural gate actually replayed.
# lint-platform.sh CHECK 29 reads it: a MINOR/MAJOR bump past the recorded version means behaviour
# changed since anything replayed it. The runner writes the row so the record cannot drift from the
# runs — a receipt a human types is the memory-enforced invariant this platform refuses.
#
# It is written ONLY for a full single-skill run: one named skill, no --scenario filter, not
# --dry-run, and at least one scenario actually GRADED. That last condition is not pedantry — this
# session had runs report "100% failure at $0.00 cost" because every model call was rejected; a
# receipt written from that would assert an eval that never happened.
# Written via temp file + mv, so an interrupted run cannot leave a half-written table.
EVAL_RECEIPTS_FILE="${EVAL_RECEIPTS_FILE:-$ROOT/config/eval-receipts.md}"

eval_receipts_header() {
  cat <<'HDR'
# Eval receipts — which skill versions the behavioural gate actually replayed

Written by `eval-runner.sh` on a full single-skill run; read by `lint-platform.sh` check 29.
Do not hand-edit a row except to record a deliberate skip, and then say why in the row.

| Skill | Version evaluated | Date | Scenarios | Failed |
|---|---|---|---|---|
HDR
}

# record_eval_receipt <skill> <graded> <scenarios> <failed>
# No-ops (returns 0) whenever the run was not a full graded single-skill run.
record_eval_receipt() {
  local skill="$1" graded="${2:-0}" scen="${3:-0}" failed="${4:-0}"
  [ -n "$ONLY_SKILL" ]   || return 0
  [ -z "$ONLY_SCENARIO" ] || return 0
  [ "$DRY_RUN" -eq 0 ]   || return 0
  [ "$graded" -gt 0 ]    || return 0

  local sm="$SKILLS_DIR/$skill/SKILL.md" version=""
  [ -f "$sm" ] && version=$(grep -m1 '^version:' "$sm" | sed 's/^version: *//' | tr -d ' \r')
  [ -n "$version" ] || return 0

  local file="$EVAL_RECEIPTS_FILE" tmp
  mkdir -p "$(dirname "$file")" 2>/dev/null
  [ -f "$file" ] || eval_receipts_header > "$file"
  tmp="$file.tmp.$$"
  local row="| $skill | $version | $(date +%Y-%m-%d) | $scen | $failed |"
  awk -v skill="$skill" -v row="$row" '
    !done && /^[[:space:]]*\|/ {
      cell = $0; sub(/^[[:space:]]*\|[[:space:]]*/, "", cell); sub(/[[:space:]]*\|.*$/, "", cell)
      if (cell == skill) { print row; done = 1; next }
    }
    { print }
    END { if (!done) print row }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

run_skill() {
  local skill="$1"
  local sm="$SKILLS_DIR/$skill/SKILL.md"
  local ev="$SKILLS_DIR/$skill/evaluations/baseline-evals.json"
  [ -f "$ev" ] || return 0
  [ -f "$sm" ] || { echo "${R}FAIL${X} $skill: no SKILL.md"; FAILS=$((FAILS+1)); return; }

  printf '\n%s== %s ==%s\n' "$B" "$skill" "$X"

  # assemble the skill context once
  local ctx; ctx=$(skill_body "$sm")
  local want_refs="$WITH_REFS"
  [ "$(jq -r '.inline_references // false' "$ev" 2>/dev/null)" = "true" ] && want_refs=1
  if [ "$want_refs" -eq 1 ] && [ -d "$SKILLS_DIR/$skill/reference" ]; then
    local rf
    for rf in "$SKILLS_DIR/$skill/reference"/*.md; do
      [ -f "$rf" ] || continue
      ctx="$ctx"$'\n\n----- reference: '"$(basename "$rf")"$' -----\n'"$(cat "$rf")"
    done
  fi
  # orchestrator-class skills can cite content that lives in companion skill bodies
  # (IDs, rules defined by a foundation skill). A top-level "companions" array in
  # baseline-evals.json inlines those bodies so a headless EXECUTE can resolve them.
  local companions; companions=$(jq -r '.companions[]?' "$ev" 2>/dev/null)
  if [ -n "$companions" ]; then
    local cs csf
    while IFS= read -r cs; do
      [ -z "$cs" ] && continue
      if ! path_is_safe "$cs"; then printf '  %sWARN%s companion ignored — unsafe path: %s\n' "$Y" "$X" "$cs" >&2; continue; fi
      csf="$SKILLS_DIR/$cs/SKILL.md"
      [ -f "$csf" ] && ctx="$ctx"$'\n\n----- companion skill (rules and IDs in effect): '"$cs"$' -----\n'"$(skill_body "$csf")"
    done <<< "$companions"
  fi

  local n_scen; n_scen=$(jq '.scenarios | length' "$ev")
  local i
  for ((i=0; i<n_scen; i++)); do
    local sid query mode; sid=$(jq -r ".scenarios[$i].id" "$ev"); query=$(jq -r ".scenarios[$i].query" "$ev"); mode=$(jq -r ".scenarios[$i].mode // \"apply\"" "$ev")
    if [ -n "$ONLY_SCENARIO" ]; then
      [ "$sid" != "$ONLY_SCENARIO" ] && continue
      MATCHED=$((MATCHED+1))
    fi
    # Unknown mode must fail loudly: a typo like "slection" would otherwise silently run as
    # "apply" (body force-loaded) — a different, weaker test that still reports PASS (VIBE-007).
    case "$mode" in
      apply|selection) ;;
      *) printf '  %sFAIL%s %s — unknown mode "%s" (expected "apply" or "selection")\n' "$R" "$X" "$sid" "$mode"; FAILS=$((FAILS+1)); continue ;;
    esac
    # manual-verify scenarios (interactive multi-turn, or live side-effecting) are not
    # single-call evaluable — skip without running or counting as fail.
    if [ "$(jq -r ".scenarios[$i].manual_verify // false" "$ev")" = "true" ]; then
      printf '  %sSKIP%s %s — manual-verify (%s)\n' "$Y" "$X" "$sid" "$(jq -r ".scenarios[$i].manual_verify_reason // \"not single-call evaluable\"" "$ev")"
      continue
    fi
    local n_assert; n_assert=$(jq ".scenarios[$i].expected_behavior | length" "$ev")
    RUN=$((RUN+1))

    # fixture: an inlined synthetic artifact that makes the scenario self-contained.
    # When present, strip any "[PASTE …]" marker from the query and append the artifact.
    local fix artifact cleanq; fix=$(jq -r ".scenarios[$i].fixture // empty" "$ev")
    artifact=""; cleanq="$query"
    if [ -n "$fix" ]; then
      if ! path_is_safe "$fix"; then printf '  %sFAIL%s %s — unsafe fixture path (no absolute paths or ".."): %s\n' "$R" "$X" "$sid" "$fix"; FAILS=$((FAILS+1)); continue; fi
      local fpath="$SKILLS_DIR/$skill/evaluations/$fix"
      if [ ! -f "$fpath" ]; then printf '  %sFAIL%s %s — fixture not found: %s\n' "$R" "$X" "$sid" "$fix"; FAILS=$((FAILS+1)); continue; fi
      artifact=$(cat "$fpath")
      cleanq=$(printf '%s' "$query" | sed -E 's/\[[Pp][Aa][Ss][Tt][Ee][^]]*\]//g')
    fi

    local exec_prompt judge_assert_list
    if [ "$mode" = "selection" ]; then
      # Selection mode: test whether the skill would be CHOSEN from its description alone — the
      # trigger-selection signal the force-load 'apply' mode cannot exercise. Body NOT inlined.
      local sdesc; sdesc=$(skill_description "$sm")
      exec_prompt="You are deciding whether a skill should ACTIVATE for a user request, based ONLY on
the skill's name and description — this is exactly how a skill is selected before its body loads.
Judge from the description alone; do not assume capabilities it does not state.

Skill name: $skill
Skill description: $sdesc

User request: $cleanq

Reply with \"IN SCOPE\" or \"OUT OF SCOPE\" on the first line, then one sentence of justification."
    else
      exec_prompt="You are operating with the skill below active. This is an OFFLINE EVALUATION in a chat session. Apply the skill's own decision logic to the input exactly:
- If the skill's stated gates and prerequisites are met, produce its full output artifact.
- If a gate the skill explicitly defines is unmet (e.g. an unmet threshold, a pre-approval status, a missing recorded clearance), bounce or refuse as the skill directs — a short, direct bounce, not a full artifact.
Do not invent gates the skill does not define, and do not skip gates it does define.

Operational note (evaluation only): do NOT run any pre-flight step, do NOT create or look up an external ticket, do NOT set up an audit trail, and do NOT ask for credentials, tools, or external files. Any companion / foundation skills this skill requires are already loaded and in effect — apply their rules from memory; do not try to read them.

<skill>
$ctx
</skill>

Task: $cleanq"
      if [ -n "$artifact" ]; then
        exec_prompt="$exec_prompt

--- ARTIFACT UNDER REVIEW ---
$artifact
--- END ARTIFACT ---"
      fi
    fi
    judge_assert_list=$(jq -r ".scenarios[$i].expected_behavior | to_entries[] | \"\(.key+1). \(.value)\"" "$ev")

    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  %s[dry-run]%s %s — %s assertions; mode=%s exec=%s judge=%s\n' "$Y" "$X" "$sid" "$n_assert" "$mode" "$EXEC_MODEL" "$JUDGE_MODEL"
      if [ "$mode" = "selection" ]; then
        printf '    execute prompt: %s chars (description-only — body NOT inlined)\n' "${#exec_prompt}"
      else
        if [ -n "$fix" ]; then printf '    fixture: %s (%s chars spliced)\n' "$fix" "${#artifact}"; else printf '    fixture: %s(none — query is self-contained or a stub)%s\n' "$Y" "$X"; fi
        printf '    execute prompt: %s chars (skill body + query%s)\n' "${#exec_prompt}" "$([ -n "$artifact" ] && echo ' + artifact')"
      fi
      printf '    expected_behavior:\n'; printf '%s\n' "$judge_assert_list" | sed 's/^/      /'
      continue
    fi

    # EXECUTE + JUDGE, repeated SAMPLES times. A scenario near a produce/bounce gate
    # boundary can flip run-to-run; majority-of-N absorbs that single-sample variance.
    local sample_pass=0 sample_ok_total=0 rep_judged="" rep_frac=0 rep_passed=0
    local exec_empty=0
    local s resp judge_prompt judge_raw judged jattempt
    for ((s=1; s<=SAMPLES; s++)); do
      resp=$(printf '%s' "$exec_prompt" | call_model "$EXEC_MODEL")
      [ -z "$resp" ] && { exec_empty=$((exec_empty+1)); continue; }
      judge_prompt="You are grading a skill's output against a list of expected behaviours. Be strict but fair: mark an item \"pass\" only if the output clearly satisfies it.

Expected behaviours:
$judge_assert_list

--- OUTPUT TO GRADE ---
$resp
--- END OUTPUT ---

Respond with ONLY a JSON array, one object per expected behaviour, no prose:
[{\"n\":1,\"pass\":true,\"reason\":\"<=12 words\"}, ...]"
      judged=""; jattempt=0
      while [ "$jattempt" -lt 2 ]; do
        judge_raw=$(printf '%s' "$judge_prompt" | call_model "$JUDGE_MODEL" "$JUDGE_BUDGET")
        judged=$(printf '%s' "$judge_raw" | sed -n '/\[/,/\]/p' | jq -c '.' 2>/dev/null)
        [ -n "$judged" ] && break
        jattempt=$((jattempt+1))
      done
      [ -z "$judged" ] && continue
      sample_ok_total=$((sample_ok_total+1))
      local p frac okk
      p=$(printf '%s' "$judged" | jq '[.[]|select(.pass==true)]|length')
      frac=$(awk -v p="$p" -v t="$n_assert" 'BEGIN{printf "%.2f", (t>0)?p/t:0}')
      okk=$(awk -v f="$frac" -v th="$THRESHOLD" 'BEGIN{print (f+0>=th+0)?1:0}')
      [ "$okk" -eq 1 ] && sample_pass=$((sample_pass+1))
      # keep a representative judged set for display — prefer a failing sample's misses
      if [ -z "$rep_judged" ] || [ "$okk" -eq 0 ]; then rep_judged="$judged"; rep_frac="$frac"; rep_passed="$p"; fi
    done

    if [ "$sample_ok_total" -eq 0 ]; then
      if [ "$exec_empty" -eq "$SAMPLES" ]; then
        local diag=""
        [ -n "${DIAG_FILE:-}" ] && [ -s "${DIAG_FILE:-}" ] && diag=$(tail -1 "$DIAG_FILE")
        printf '  %sFAIL%s %s — EXECUTE produced no output in all %s sample(s): %s (CLI stderr: %s)\n' \
          "$R" "$X" "$sid" "$SAMPLES" "${diag:-check auth / --exec-model / budget}" "${ERR_FILE:-unavailable}"
      else
        printf '  %sFAIL%s %s — no parseable judge output (after retry; CLI stderr: %s)\n' "$R" "$X" "$sid" "${ERR_FILE:-unavailable}"
      fi
      FAILS=$((FAILS+1)); continue
    fi
    # strict-majority verdict across the samples that produced a parseable judgment.
    # `p*2 > t` (not >=) so an even split (e.g. 1/2) does NOT pass — a tie is not a majority.
    # Single-sample default is unaffected: 1 pass → 2 > 1 → PASS; 0 pass → 0 > 1 → FAIL.
    GRADED=$((GRADED+1))   # a real verdict exists for this scenario (see record_eval_receipt)
    local ok; ok=$(awk -v p="$sample_pass" -v t="$sample_ok_total" 'BEGIN{print (p*2>t && p>0)?1:0}')
    local verdict; if [ "$ok" -eq 1 ]; then verdict="${G}PASS${X}"; else verdict="${R}FAIL${X}"; FAILS=$((FAILS+1)); fi
    if [ "$SAMPLES" -gt 1 ]; then
      printf '  %s %s — %s/%s samples passed; rep %s/%s assertions\n' "$verdict" "$sid" "$sample_pass" "$sample_ok_total" "$rep_passed" "$n_assert"
    else
      printf '  %s %s — %s/%s assertions (%.0f%%)\n' "$verdict" "$sid" "$rep_passed" "$n_assert" "$(awk -v f="$rep_frac" 'BEGIN{print f*100}')"
    fi
    printf '%s' "$rep_judged" | jq -r '.[]|select(.pass!=true)|"      ✗ #\(.n): \(.reason)"'
  done
}

# ---- run (skipped when sourced as a lib: EVAL_RUNNER_LIB=1) ------------------
if [ "${EVAL_RUNNER_LIB:-0}" != "1" ]; then
COST_FILE=$(mktemp); ERR_FILE=$(mktemp); DIAG_FILE=$(mktemp); trap 'rm -f "$COST_FILE" "$ERR_FILE" "$DIAG_FILE"' EXIT   # per-call costs, stderr, and empty-result diagnostics land here
printf '%seval-runner%s  exec=%s judge=%s budget/call=$%s threshold=%s%s\n' "$B" "$X" "$EXEC_MODEL" "$JUDGE_MODEL" "$MAX_BUDGET" "$THRESHOLD" "$([ "$DRY_RUN" -eq 1 ] && echo '  [DRY-RUN]')"

if [ -n "$ONLY_SKILL" ]; then
  [ -d "$SKILLS_DIR/$ONLY_SKILL" ] || { echo "eval-runner: no such skill: $ONLY_SKILL" >&2; exit 2; }
  [ -f "$SKILLS_DIR/$ONLY_SKILL/evaluations/baseline-evals.json" ] \
    || { echo "eval-runner: $ONLY_SKILL has no evaluations/baseline-evals.json" >&2; exit 2; }
fi

if [ -n "$ONLY_SKILL" ]; then
  run_skill "$ONLY_SKILL"
else
  for d in "$SKILLS_DIR"/*/; do run_skill "$(basename "$d")"; done
fi

if [ -n "$ONLY_SCENARIO" ] && [ "$MATCHED" -eq 0 ]; then
  echo "eval-runner: no scenario matched id '$ONLY_SCENARIO'" >&2; exit 2
fi

if [ -n "$ONLY_SKILL" ] && [ -z "$ONLY_SCENARIO" ] && [ "$DRY_RUN" -eq 0 ] && [ "$GRADED" -gt 0 ]; then
  record_eval_receipt "$ONLY_SKILL" "$GRADED" "$RUN" "$FAILS"
  printf '\n  receipt recorded in %s (%s scenarios, %s failed)\n' "${EVAL_RECEIPTS_FILE#"$ROOT"/}" "$RUN" "$FAILS"
fi

printf '\n%s== summary ==%s\n' "$B" "$X"
printf '  scenarios run: %s   %sfailed: %s%s\n' "$RUN" "$([ "$FAILS" -gt 0 ] && echo "$R" || echo "$G")" "$FAILS" "$X"
# An empty model result records its cause in DIAG_FILE, but the EXIT trap deletes the file — so
# the cause was captured and never shown, and an empty result read as an unexplained "API error".
# That is the exact misdiagnosis the 2026-07-13 incident cost a day to, reintroduced by the
# diagnostic having no reader. Print it. (Found 2026-07-29 when a $0.50 budget kill on
# redteam-security-009 surfaced only as "API error only" and cost a re-run to identify.)
if [ "$DRY_RUN" -eq 0 ] && [ -s "$DIAG_FILE" ]; then
  printf '  %sempty model result(s) — cause from the CLI:%s\n' "$Y" "$X"
  sed 's/^/      /' "$DIAG_FILE"
  if grep -q 'terminal_reason=max_budget' "$DIAG_FILE" 2>/dev/null; then
    printf '      %s^ budget kill, not a skill failure — re-run with --max-budget-usd above $%s%s\n' "$Y" "$MAX_BUDGET" "$X"
  fi
fi
[ "$DRY_RUN" -eq 0 ] && { COST_TOTAL=$(awk '{s+=$1} END{printf "%.4f", s+0}' "$COST_FILE" 2>/dev/null); printf '  approx model cost this run: $%s\n' "$COST_TOTAL"; }
[ "$DRY_RUN" -eq 0 ] && printf 'EVAL_COST_USD=%s\n' "$COST_TOTAL"
if [ "$DRY_RUN" -eq 1 ]; then printf '  %s(dry-run — no model calls made)%s\n' "$Y" "$X"; exit 0; fi
[ "$FAILS" -gt 0 ] && { printf '%sRESULT: FAIL%s\n' "$R" "$X"; exit 1; }
printf '%sRESULT: PASS%s\n' "$G" "$X"; exit 0

fi  # end run guard (EVAL_RUNNER_LIB)
