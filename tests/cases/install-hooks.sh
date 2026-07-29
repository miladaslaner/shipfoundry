# install-hooks.sh — must detect repos via git (worktrees have a .git FILE, not dir) and
# install with absolute symlink targets so worktree hook resolution works (VIBE-017).

printf '%s-- Chooks worktree-safe hook install --%s\n' "$B" "$X"
if grep -q 'rev-parse --git-common-dir' "$ROOT/install-hooks.sh"; then assert_eq "uses git-common-dir for hooks path" "yes" "yes"
else assert_eq "uses git-common-dir for hooks path" "no" "yes"; fi
if grep -qE '\[ ! -d "\$ROOT/\.git" \]' "$ROOT/install-hooks.sh"; then assert_eq "dir-test repo detection removed" "present" "absent"
else assert_eq "dir-test repo detection removed" "absent" "absent"; fi
# behavioral: a scratch repo + worktree both get resolving hooks
if command -v git >/dev/null 2>&1; then
  wt="$TMP/hookrepo"; mkdir -p "$wt"
  ( cd "$wt" && git init -q && mkdir -p hooks && printf '#!/bin/sh\nexit 0\n' > hooks/pre-commit && printf '#!/bin/sh\nexit 0\n' > hooks/pre-push
    cp "$ROOT/install-hooks.sh" . && ./install-hooks.sh >/dev/null 2>&1 )
  if [ -e "$wt/.git/hooks/pre-commit" ]; then assert_eq "hook installed and resolves in a normal repo" "yes" "yes"
  else assert_eq "hook installed and resolves in a normal repo" "no" "yes"; fi

  # behavioral: a git WORKTREE off a SEPARATE scratch repo (no prior install run in the main
  # checkout, so the common hooks dir starts empty) also gets a resolving hook, landed in the
  # COMMON hooks dir (shared across all worktrees), not a worktree-local one. Isolated from the
  # "normal repo" block above so a leftover symlink there can't make this pass vacuously.
  wtmain="$TMP/hookrepo-wtmain"; mkdir -p "$wtmain"
  ( cd "$wtmain" && git init -q && mkdir -p hooks && printf '#!/bin/sh\nexit 0\n' > hooks/pre-commit && printf '#!/bin/sh\nexit 0\n' > hooks/pre-push
    git -c user.email=t@example.com -c user.name=t commit --allow-empty -q -m init )
  wt2="$TMP/hookrepo-wt"
  if ( cd "$wtmain" && git worktree add -q "$wt2" -b hookrepo-wt-branch >/dev/null 2>&1 ); then
    common_dir="$(cd "$wt2" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
    if [ -e "$wt2/.git" ] && [ ! -d "$wt2/.git" ]; then assert_eq "worktree .git is a file, not a dir (sanity check)" "yes" "yes"
    else assert_eq "worktree .git is a file, not a dir (sanity check)" "no" "yes"; fi
    if [ -n "$common_dir" ] && [ -e "$common_dir/hooks/pre-commit" ]; then assert_eq "common dir has no pre-existing hook (sanity check)" "unexpectedly present" "absent"
    else assert_eq "common dir has no pre-existing hook (sanity check)" "absent" "absent"; fi
    ( cd "$wt2" && cp "$ROOT/install-hooks.sh" . && mkdir -p hooks && printf '#!/bin/sh\nexit 0\n' > hooks/pre-commit && printf '#!/bin/sh\nexit 0\n' > hooks/pre-push && ./install-hooks.sh >/dev/null 2>&1 )
    if [ -n "$common_dir" ] && [ -e "$common_dir/hooks/pre-commit" ]; then assert_eq "hook installed into the common dir from a worktree" "yes" "yes"
    else assert_eq "hook installed into the common dir from a worktree" "no" "yes"; fi
    # regression: the symlink TARGET must resolve into the MAIN repo ($wtmain), not the
    # (possibly ephemeral) invoking worktree ($wt2) — else the main repo's hooks dangle once
    # the worktree is cleaned up and git silently skips them. Compare against the REALPATH of
    # wtmain/wt2 (not the literal $TMP-based string) — macOS mktemp -d returns a path under a
    # symlink (/var/folders/... -> /private/var/folders/...) that git's absolute-path output
    # has already resolved, so a literal-string prefix match would false-positive-FAIL.
    wtmain_real="$(cd "$wtmain" && pwd -P)"
    wt2_real="$(cd "$wt2" && pwd -P)"
    if [ -n "$common_dir" ] && [ -L "$common_dir/hooks/pre-commit" ]; then
      target="$(readlink "$common_dir/hooks/pre-commit")"
      case "$target" in
        "$wtmain_real"/*) assert_eq "hook symlink target points into the main repo, not the worktree" "yes" "yes" ;;
        *) assert_eq "hook symlink target points into the main repo, not the worktree" "$target" "$wtmain_real/*" ;;
      esac
      case "$target" in
        "$wt2_real"/*) assert_eq "hook symlink target does not point into the ephemeral worktree" "$target" "not under $wt2_real" ;;
        *) assert_eq "hook symlink target does not point into the ephemeral worktree" "yes" "yes" ;;
      esac
    else
      assert_eq "hook symlink target points into the main repo, not the worktree" "no symlink found" "yes"
      assert_eq "hook symlink target does not point into the ephemeral worktree" "no symlink found" "yes"
    fi
  else
    assert_eq "worktree .git is a file, not a dir (sanity check)" "skipped (git worktree add unsupported)" "skipped (git worktree add unsupported)"
    assert_eq "common dir has no pre-existing hook (sanity check)" "skipped (git worktree add unsupported)" "skipped (git worktree add unsupported)"
    assert_eq "hook installed into the common dir from a worktree" "skipped (git worktree add unsupported)" "skipped (git worktree add unsupported)"
    assert_eq "hook symlink target points into the main repo, not the worktree" "skipped (git worktree add unsupported)" "skipped (git worktree add unsupported)"
    assert_eq "hook symlink target does not point into the ephemeral worktree" "skipped (git worktree add unsupported)" "skipped (git worktree add unsupported)"
  fi
fi
