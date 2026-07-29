#!/usr/bin/env bash
# stop-lint.sh — Claude Code Stop hook. Auto-runs the platform gates at the end of a session in
# this repo so no session ends with broken invariants OR a committed secret/PII — without anyone
# remembering to run them. Runs the structural gate (lint-platform.sh) AND the content gate
# (scan-secrets.sh). Wired into .claude/settings.json (hooks.Stop); companion to the pre-commit hook.
#
# Behaviour: both gates clean → exit 0 silently (stop proceeds). Either fails → exit 2 and surface
# it on stderr so Claude addresses it before finishing. Loop-guarded: if this hook already blocked
# once this stop (stop_hook_active), it lets the stop proceed — it can never trap a session. To
# bypass entirely, remove the Stop entry from .claude/settings.json.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

input="$(cat 2>/dev/null || true)"
# loop guard: never block twice for the same stop
if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
  [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
fi

# Run both platform gates: structure (lint) and content (secrets/PII).
gate_bad=0; gate_out=""
if [ -x "$ROOT/lint-platform.sh" ]; then
  out="$("$ROOT/lint-platform.sh" 2>&1)" || { gate_bad=1; gate_out="$gate_out"$'\n'"$out"; }
fi
if [ -x "$ROOT/scan-secrets.sh" ]; then
  sout="$("$ROOT/scan-secrets.sh" 2>&1)" || { gate_bad=1; gate_out="$gate_out"$'\n'"$sout"; }
fi
[ "$gate_bad" -eq 0 ] && exit 0             # both clean → silent, stop proceeds

{
  echo "A platform gate is failing — resolve before finishing this session."
  echo "(Run ./lint-platform.sh and ./scan-secrets.sh; to bypass, remove the Stop hook from .claude/settings.json.)"
  printf '%s\n' "$gate_out" | grep -E 'FAIL|SECRET|PII|ORG' || true
} >&2
exit 2
