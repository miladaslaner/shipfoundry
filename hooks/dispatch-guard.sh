#!/usr/bin/env bash
# dispatch-guard.sh — PreToolUse hook on subagent dispatch (Agent / Task).
#
# THE PROBLEM IT EXISTS FOR. An agency dispatch that acts on recorded intent — a Jira issue, a vault
# note — is supposed to READ that record first. Nothing observed whether it did. A skipped read
# produces no verdict, no bounce, no round: it is invisible to every verifier and therefore
# invisible to retro, so the same failure recurs across sessions while each one reports having
# learned from it. An agent cannot be asked to remember; the read has to leave evidence.
#
# WHAT IT CHECKS. If a dispatch brief names a Jira issue key, it must also carry a READ-RECEIPT line:
#
#   READ-RECEIPT: {vault-note-path}@{review-state} · {ISSUE}#{comment-id} · "{verbatim quote}" ...
#
# The verbatim quote is the load-bearing part: it cannot be reliably produced from memory, and a
# fabricated one is falsifiable by re-fetching the source. This hook checks PRESENCE and SHAPE only —
# it cannot call Jira. Truthfulness is a verifier-layer check. Two layers, neither complete alone.
#
# WHAT IT CANNOT DO. It sees dispatch briefs, not the orchestrator's own in-context reasoning (the
# main loop is not a dispatch). It detects an absent receipt, not a shallow read. It is a floor.
#
# MODES (env JARVIS_DISPATCH_GUARD): warn (default — surfaces, never blocks) | enforce (denies the
# dispatch) | off. Ship warn first, read what it catches, then enforce.
set -uo pipefail

MODE="${JARVIS_DISPATCH_GUARD:-warn}"
[ "$MODE" = "off" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0          # no jq → cannot parse; never block on tooling
input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0

prompt="$(printf '%s' "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null)" || exit 0
[ -n "$prompt" ] || exit 0

# Does this brief act on recorded intent? A Jira issue key is the signature.
# Deliberately narrow: 2-10 uppercase alnum, hyphen, digits. Placeholder keys used in docs and
# templates (STORY-x, EPIC-x) do not match — they carry no digits.
# Written with POSIX classes on purpose: the bracket-range spelling of this pattern SELF-MATCHES as
# an issue key, and lint check 31 rightly failed the first draft of this file for it.
key_re='\b[[:upper:]][[:upper:][:digit:]]{1,9}-[[:digit:]]+\b'
keys="$(grep -oE "$key_re" <<<"$prompt" | sort -u | head -5 | paste -sd' ' -)"
[ -n "$keys" ] || exit 0

# Receipt present? No pipe into grep -q: `| grep -q` under pipefail is a documented race in this
# repo that makes gates flake (lessons.md 2026-07-13). Herestring, no pipeline.
if grep -qE '^[[:space:]]*READ-RECEIPT:' <<<"$prompt"; then exit 0; fi

reason="Dispatch brief names $keys but carries no READ-RECEIPT line, so nothing evidences that the \
issue or its owning vault note was actually read this dispatch. Resolve the record now and prepend: \
READ-RECEIPT: {vault-note-path}@{review-state} · {ISSUE}#{comment-id} · \"{verbatim quote, <=15 \
words}\" · run-id={id}. Quote verbatim from the source you just read — not from memory."

if [ "$MODE" = "enforce" ]; then
  jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
else
  jq -nc --arg r "$reason" --arg s "Dispatch guard (warn): no READ-RECEIPT in a brief citing an issue key." \
    '{systemMessage:$s,hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$r}}'
fi
exit 0
