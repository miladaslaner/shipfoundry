#!/usr/bin/env bash
#
# new-skill.sh — scaffold a new skill correct-by-construction (operating-model.md type A).
# Generates frontmatter, a minimal body, an evaluations/baseline-evals.json stub, and a
# .distignore — so the new skill passes lint-platform.sh structural checks by default and the
# author fills in content rather than re-deriving conventions.
#
# Usage:
#   ./new-skill.sh <skill-name> [class]
#     class = standalone (default) | pattern | foundation | orchestrator
#
# Naming: <skill-name> should be jarvis-<workbench>-<verb-noun> (see skill-taxonomy.md).
# After scaffolding: fill in the description + body + evals, then run ./build-dist.sh <name>,
# ./lint-platform.sh <name>, and update CLAUDE.md counts + the structure tree.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="${1:-}"
CLASS="${2:-standalone}"
DATE="$(date +%F)"

[ -z "$NAME" ] && { echo "usage: ./new-skill.sh <skill-name> [standalone|pattern|foundation|orchestrator]" >&2; exit 2; }
case "$NAME" in jarvis-*) ;; *) echo "name should start with 'jarvis-' (see skill-taxonomy.md)" >&2; exit 2 ;; esac
case "$CLASS" in standalone|pattern|foundation|orchestrator) ;; *) echo "unknown class: $CLASS" >&2; exit 2 ;; esac
DIR="$ROOT/skills/$NAME"
[ -e "$DIR" ] && { echo "refusing: $DIR already exists" >&2; exit 2; }

mkdir -p "$DIR/reference" "$DIR/evaluations"

# --- SKILL.md ---
cat > "$DIR/SKILL.md" <<EOF
---
name: $NAME
description: TODO replace — third person, open with "Use when …", describe triggers + symptoms (not the workflow), include a "Does not trigger" clause. Max 1024 chars; use {braces} not angle-bracket placeholders. Scaffolded $DATE; class=$CLASS.
version: 0.1.0
owner: TODO
updated: $DATE
source: Scaffolded by new-skill.sh ($DATE). Replace description, body, and evals before first use.
changelog: |
  0.1.0 — Scaffolded by new-skill.sh (class=$CLASS). Placeholder description/body/evals; not yet usable.
---

# $NAME

TODO — skill body. Keep under 500 lines (Anthropic cap; soft target 380–450). Extract heavy
sections to \`reference/<name>.md\` with a table of contents.

## What this skill does

TODO.

## When to use it

TODO.

## Files in this skill

- \`SKILL.md\` (this file)
- \`evaluations/baseline-evals.json\` — 3 baseline scenarios + a 900 stall probe
EOF

# --- evaluations/baseline-evals.json (3 grounded stubs) ---
cat > "$DIR/evaluations/baseline-evals.json" <<EOF
{
  "schema_version": "1.0",
  "skill": "$NAME",
  "purpose": "TODO — what these scenarios assert. Cover happy-path + a gate/bounce + a signature failure-mode.",
  "scenarios": [
    {"id": "${NAME}-001-happy-path", "query": "TODO representative happy-path query", "expected_behavior": ["TODO observable assertion 1", "TODO assertion 2"]},
    {"id": "${NAME}-002-gate", "query": "TODO query that should hit a gate / bounce", "expected_behavior": ["TODO: skill bounces / refuses with a clear reason"]},
    {"id": "${NAME}-003-signature-failure-mode", "query": "TODO query exercising this skill's signature failure-mode", "expected_behavior": ["TODO: skill catches the signature issue"]},
    {"id": "${NAME}-900-stall-probe", "query": "TODO — the skill's PRIMARY task, with ONE precondition its own rules name (a brief, a marker, an upstream artifact) ABSENT and everything else present and sufficient. Add: 'This is an offline exercise with no filesystem — do not attempt writes; write out what you would produce.' Then demand the artifact: 'PRODUCE the actual <output>.'", "expected_behavior": ["Still produces its primary artifact from the inputs it DOES have, rather than only reporting the missing one", "Names the absent input as a gap so the omission is visible in the record", "Does NOT defer, bounce, park, or route back INSTEAD of producing — a skill that genuinely must stop says so AND says what it still produced", "Keeps its normal discipline rather than treating the missing input as licence to skip it"]}
  ]
}
EOF

# --- .distignore (convention; covers any future internal content) ---
cat > "$DIR/.distignore" <<EOF
# Paths excluded from the distribution bundle (the shareable -public.zip).
# build-dist.sh reads this as the single source of exclusions.
# Internal-only content lives in *-internal.md files or _internal/ paths.

reference/_internal/
.distignore
dist/
EOF

echo "scaffolded skills/$NAME/ (class=$CLASS)"

# --- local discovery: symlink into the personal install (~/.claude/skills) ----
# The personal Claude Code install discovers skills via symlinks in ~/.claude/skills/
# that point back into this repo. A new skill needs its own symlink or it is invisible
# to the local `/` menu. Guarded by the dir existing, so it is a no-op in CI / on a
# machine without the symlink install. lint-platform.sh check 11 warns if this is missed.
LINK_DIR="$HOME/.claude/skills"
if [ -d "$LINK_DIR" ]; then
  if [ -L "$LINK_DIR/$NAME" ] || [ -e "$LINK_DIR/$NAME" ]; then
    echo "local symlink already present: $LINK_DIR/$NAME"
  elif ln -s "$DIR" "$LINK_DIR/$NAME" 2>/dev/null; then
    echo "linked into personal install: $LINK_DIR/$NAME -> $DIR"
  else
    echo "WARNING: could not create $LINK_DIR/$NAME — link it by hand: ln -s \"$DIR\" \"$LINK_DIR/$NAME\""
  fi
else
  echo "note: no ~/.claude/skills install on this machine — skipped local symlink"
fi

echo
echo "Next steps:"
echo "  1. Fill in SKILL.md description (Use-when + Does-not-trigger), body, and the 3 evals."
echo "  2. ./build-dist.sh $NAME      # build the dist zip + refresh the manifest"
echo "  3. ./lint-platform.sh $NAME   # must exit 0"
echo "  4. Update CLAUDE.md skill counts + structure tree."
echo
echo "See docs/platform/new-skill-playbook.md for the full process."
