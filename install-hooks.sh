#!/usr/bin/env bash
# install-hooks.sh — wire hooks/pre-commit into .git/hooks.
# Safe to run anytime: if this workspace isn't a git repo yet, it prints guidance and exits 0.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Worktree-safe: a worktree's .git is a FILE, so test via git itself, and install into the
# COMMON hooks dir (shared by all worktrees) with ABSOLUTE targets (VIBE-017).
if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository yet."
  echo "When this becomes git-tracked, run ./install-hooks.sh again to activate the pre-commit gate."
  echo "Meanwhile, run ./lint-platform.sh manually before declaring an edit complete (CLAUDE.md close-out)."
  exit 0
fi

COMMON_DIR="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git -C "$ROOT" rev-parse --git-common-dir)"
case "$COMMON_DIR" in /*) ;; *) COMMON_DIR="$ROOT/$COMMON_DIR" ;; esac   # old git returns a relative path
HOOKS_DIR="$COMMON_DIR/hooks"
# Worktree-safe target: the common hooks dir is SHARED across all worktrees of a repo, but a
# linked worktree is often ephemeral (cleaned up after the task). If the symlink TARGET points
# into the invoking worktree ($ROOT), the main checkout's hooks dangle once that worktree is
# removed, and git silently skips a broken hook. Resolve the target against the MAIN checkout
# that owns the common dir instead — $COMMON_DIR always resolves to "<main-root>/.git" (verified:
# git never nests it under .git/worktrees/<name>, even when invoked from a linked worktree), so
# its parent is the main root.
MAIN_ROOT="$(dirname "$COMMON_DIR")"
[ -f "$MAIN_ROOT/hooks/pre-commit" ] || MAIN_ROOT="$ROOT"   # fallback: unexpected repo shape (e.g. bare repo)
mkdir -p "$HOOKS_DIR"
ln -sf "$MAIN_ROOT/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
ln -sf "$MAIN_ROOT/hooks/pre-push" "$HOOKS_DIR/pre-push"
chmod +x "$MAIN_ROOT/hooks/pre-commit" "$MAIN_ROOT/hooks/pre-push" 2>/dev/null || chmod +x "$ROOT/hooks/pre-commit" "$ROOT/hooks/pre-push"
echo "Installed: $HOOKS_DIR/pre-commit -> $MAIN_ROOT/hooks/pre-commit (runs ./lint-platform.sh on every commit)."
echo "Installed: $HOOKS_DIR/pre-push   -> $MAIN_ROOT/hooks/pre-push   (refuses a direct push to main)."
echo "Override a single commit with: git commit --no-verify"
echo "Override a single push   with: git push   --no-verify"
