#!/usr/bin/env bash
#
# run-tests.sh — dependency-free test runner (no bats / framework). Discovers and runs every
# tests/cases/*.sh in order. Each case file uses the shared assert_eq / assert_ne and the $TMP
# scratch dir, with the platform libraries already sourced (their main runs are guarded out via
# the *_LIB flags): lint-platform.sh, eval-runner.sh, lib/internal-convention.sh, lib/skill-md.sh.
#
# Add a new feature's tests as a NEW file under tests/cases/ — there is no shared summary anchor
# for two PRs to collide on (this split exists to kill that merge-conflict class).
#
# Usage: ./tests/run-tests.sh   (exit 0 = all pass, 1 = a failure, 2 = setup error)

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; B=$'\e[1m'; X=$'\e[0m'; else G=""; R=""; B=""; X=""; fi

assert_eq() { # <name> <got> <want>
  if [ "$2" = "$3" ]; then printf '  %sPASS%s %s\n' "$G" "$X" "$1"; PASS=$((PASS+1))
  else printf '  %sFAIL%s %s\n        got:  [%s]\n        want: [%s]\n' "$R" "$X" "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}
assert_ne() { # <name> <got> <unwanted>
  if [ "$2" != "$3" ]; then printf '  %sPASS%s %s\n' "$G" "$X" "$1"; PASS=$((PASS+1))
  else printf '  %sFAIL%s %s (value was the unwanted [%s])\n' "$R" "$X" "$1" "$3"; FAIL=$((FAIL+1)); fi
}

# Load the platform libraries the cases exercise (main runs guarded out by the *_LIB flags).
set --
export LINT_PLATFORM_LIB=1 EVAL_RUNNER_LIB=1
# shellcheck disable=SC1091
. "$ROOT/lint-platform.sh"
# shellcheck disable=SC1091
. "$ROOT/eval-runner.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/internal-convention.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/skill-md.sh"

ran=0
for case_file in "$ROOT"/tests/cases/*.sh; do
  [ -f "$case_file" ] || continue
  ran=$((ran+1))
  printf '\n%s== %s ==%s\n' "$B" "$(basename "$case_file" .sh)" "$X"
  # shellcheck disable=SC1090
  . "$case_file"
done
[ "$ran" -gt 0 ] || { echo "no test cases found under tests/cases/" >&2; exit 2; }

printf '\n%s== summary ==%s\n  %s%d pass%s   %s%d fail%s\n' "$B" "$X" "$G" "$PASS" "$X" "$([ "$FAIL" -gt 0 ] && echo "$R" || echo "$G")" "$FAIL" "$X"
[ "$FAIL" -eq 0 ] || exit 1
