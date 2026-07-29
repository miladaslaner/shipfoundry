# lint-platform.sh helpers + checks. Functions (body_lines_of, desc_of, check_claudemd_inventory,
# is_internal_path) come from the libraries sourced by run-tests.sh. Uses $TMP, $ROOT, assert_*.

printf '%s-- C1 body_lines_of (missing-fence guard) --%s\n' "$B" "$X"
cat > "$TMP/normal.md" <<'EOF'
---
name: x
version: 1.0.0
---
line1
line2
line3
EOF
assert_eq "normal: 3 body lines" "$(body_lines_of "$TMP/normal.md")" "3"
cat > "$TMP/nofence.md" <<'EOF'
---
name: x
version: 1.0.0
body a
body b
EOF
assert_eq "missing fence: explicit guard, returns a number" "$(body_lines_of "$TMP/nofence.md")" "5"

printf '%s-- C2 desc_of (block scalar + quotes) --%s\n' "$B" "$X"
cat > "$TMP/plain.md" <<'EOF'
---
name: x
description: Use when authoring a thing. Does not trigger otherwise.
version: 1.0.0
---
body
EOF
assert_eq "plain description intact" "$(desc_of "$TMP/plain.md")" "Use when authoring a thing. Does not trigger otherwise."
cat > "$TMP/block.md" <<'EOF'
---
name: x
description: >-
  Use when you need a folded description.
version: 1.0.0
---
body
EOF
got="$(desc_of "$TMP/block.md")"
assert_eq "block scalar resolved" "$got" "Use when you need a folded description."
assert_ne "block scalar: no leading '>' indicator" "${got:0:1}" ">"
cat > "$TMP/quoted.md" <<'EOF'
---
name: x
description: "Use when X happens."
version: 1.0.0
---
body
EOF
got="$(desc_of "$TMP/quoted.md")"
assert_eq "surrounding quotes stripped" "$got" "Use when X happens."
assert_ne "quoted: no leading double-quote in count" "${got:0:1}" '"'

printf '%s-- C13 check 9 sees single-quoted trigger phrases --%s\n' "$B" "$X"
clause="Triggers on phrases like 'show me the example skill', 'scaffold a skill'."
newx="$(printf '%s' "$clause" | grep -oE "\"[^\"]+\"|'[^']+'" | head -1 | tr -d "\"'")"
oldx="$(printf '%s' "$clause" | grep -oE '"[^"]+"' || true)"
assert_eq "new regex extracts the single-quoted phrase" "$newx" "show me the example skill"
assert_eq "old regex extracted nothing (the bug)" "$oldx" ""

printf '%s-- C12 CLAUDE.md inventory parity --%s\n' "$B" "$X"
mkdir -p "$TMP/repo/skills/jarvis-ghost"; : > "$TMP/repo/skills/jarvis-ghost/SKILL.md"
printf '# CLAUDE.md\nNo skills named here.\n' > "$TMP/repo/CLAUDE.md"
f1=$( ROOT="$TMP/repo"; SKILLS_DIR="$TMP/repo/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory >/dev/null 2>&1; echo "$FAILS" )
assert_ne "skill missing from CLAUDE.md → FAIL" "$f1" "0"
printf '# CLAUDE.md\nWe ship skills/jarvis-ghost as the example.\n' > "$TMP/repo/CLAUDE.md"
f2=$( ROOT="$TMP/repo"; SKILLS_DIR="$TMP/repo/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory >/dev/null 2>&1; echo "$FAILS" )
assert_eq "skill named + path resolves → no FAIL" "$f2" "0"
printf '# CLAUDE.md\nskills/jarvis-ghost and skills/jarvis-deleted both.\n' > "$TMP/repo/CLAUDE.md"
f3=$( ROOT="$TMP/repo"; SKILLS_DIR="$TMP/repo/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory >/dev/null 2>&1; echo "$FAILS" )
assert_ne "stale skills/<name> reference → FAIL" "$f3" "0"

printf '%s-- C5 skill_list loops are whitespace-safe (IFS) --%s\n' "$B" "$X"
# A skill name containing a space must iterate as ONE item, not split into two.
listfn() { printf '%s\n' 'jarvis-one' 'jarvis two'; }
old_count=$(c=0; for s in $(listfn); do c=$((c+1)); done; echo "$c")
new_count=$(c=0; IFS=$'\n'; for s in $(listfn); do c=$((c+1)); done; echo "$c")
assert_eq "default IFS splits a spaced name (the bug)" "$old_count" "3"
assert_eq "newline IFS keeps it whole (the fix)" "$new_count" "2"

printf '%s-- Cinternal internal-content convention (single source) --%s\n' "$B" "$X"
isint() { is_internal_path "$1"; echo $?; }
assert_eq "*-internal.md is internal"       "$(isint 'reference/notes-internal.md')" "0"
assert_eq "_internal/ path is internal"     "$(isint 'reference/_internal/x.md')"    "0"
assert_eq "_internal-examples seg internal" "$(isint 'a/_internal-examples/y')"       "0"
assert_eq "ordinary file is not internal"   "$(isint 'reference/example.md')"         "1"
assert_eq "'internal' substring not enough" "$(isint 'reference/internalish.md')"     "1"
if grep -q 'internal-convention.sh' "$ROOT/lint-platform.sh"; then assert_eq "lint sources the lib" "yes" "yes"
else assert_eq "lint sources the lib" "no" "yes"; fi
if grep -q 'internal-convention.sh' "$ROOT/build-dist.sh"; then assert_eq "build-dist sources the lib" "yes" "yes"
else assert_eq "build-dist sources the lib" "no" "yes"; fi
if grep -Fq "INTERNAL_RE='(-internal" "$ROOT/lint-platform.sh"; then assert_eq "lint no longer hardcodes INTERNAL_RE" "present" "absent"
else assert_eq "lint no longer hardcodes INTERNAL_RE" "absent" "absent"; fi

printf '%s-- C14 check 13 agency registry parity (behavioral) --%s\n' "$B" "$X"
if grep -q 'check_agency_registry()' "$ROOT/lint-platform.sh"; then assert_eq "check 13 function defined" "yes" "yes"
else assert_eq "check 13 function defined" "no" "yes"; fi
if grep -qE '^check_agency_registry$' "$ROOT/lint-platform.sh"; then assert_eq "check 13 invoked in run sequence" "yes" "yes"
else assert_eq "check 13 invoked in run sequence" "no" "yes"; fi
# ROOT is pinned to an empty dir (no config/agency-registry.md) for every check_agency_registry /
# check_verifier_branches invocation below, so these isolated fixtures aren't silently joined by
# the real committed slice at the actual repo ROOT (VIBE-016 — the slice is now committed there).
mkdir -p "$TMP/noslice"
# Functional fixture: a real producer dir + an internal config that mentions it AND embeds it in a
# suffixed non-skill identifier (a paired-repo/sandbox name). The check must pass clean — the
# suffixed compound must NOT false-positive (the §1 regression the review caught).
mkdir -p "$TMP/reg13/jarvis-agency-build-go" "$TMP/reg13/jarvis-agency-contract/reference/_internal"
: > "$TMP/reg13/jarvis-agency-build-go/SKILL.md"
printf 'routes go to jarvis-agency-build-go; paired repo jarvis-agency-build-go-sandbox\n' \
  > "$TMP/reg13/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/reg13"; ONLY_SKILL=""; FAILS=0; check_agency_registry >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "registered producer + suffixed identifier => no false-positive FAIL" "$out" "FAILS=0"
# And a genuinely stale producer reference DOES fail.
printf 'stale ref jarvis-agency-build-deleted\n' >> "$TMP/reg13/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/reg13"; ONLY_SKILL=""; FAILS=0; check_agency_registry 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "stale producer reference => FAIL" "$out" "FAILS=0"
# self-skips when NEITHER the gitignored internal config NOR the committed slice exists (CI / fork
# with no agency workbench at all) — ROOT here has no config/agency-registry.md either.
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/reg13/jarvis-agency-build-go"; ONLY_SKILL=""; FAILS=0; check_agency_registry 2>&1; printf '|FAILS=%s' "$FAILS" )
case "$out" in *"skipped — no registry config"*"|FAILS=0") assert_eq "check 13 self-skips without registry config" "skips" "skips";;
  *) assert_eq "check 13 self-skips without registry config" "$out" "skips";; esac

printf '%s-- C15 check 14 model-tier parity (behavioral) --%s\n' "$B" "$X"
if grep -q 'check_model_tiers()' "$ROOT/lint-platform.sh"; then assert_eq "check 14 function defined" "yes" "yes"
else assert_eq "check 14 function defined" "no" "yes"; fi
if grep -qE '^check_model_tiers$' "$ROOT/lint-platform.sh"; then assert_eq "check 14 invoked in run sequence" "yes" "yes"
else assert_eq "check 14 invoked in run sequence" "no" "yes"; fi
# Clean fixture: three agency skill dirs, all three tiered in the table => pass.
mkdir -p "$TMP/mt15/jarvis-agency-orchestrate/reference" "$TMP/mt15/jarvis-agency-intake" "$TMP/mt15/jarvis-agency-capture"
: > "$TMP/mt15/jarvis-agency-orchestrate/SKILL.md"; : > "$TMP/mt15/jarvis-agency-intake/SKILL.md"; : > "$TMP/mt15/jarvis-agency-capture/SKILL.md"
tf="$TMP/mt15/jarvis-agency-orchestrate/reference/model-tiers.md"
printf '| jarvis-agency-orchestrate | session | x |\n| jarvis-agency-intake | opus | x |\n| jarvis-agency-capture | haiku | x |\n' > "$tf"
out=$( SKILLS_DIR="$TMP/mt15"; ONLY_SKILL=""; FAILS=0; check_model_tiers >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "every skill tiered => no FAIL" "$out" "FAILS=0"
# Reverse: a tier row naming a non-existent skill => FAIL.
printf '| jarvis-agency-ghost | opus | x |\n' >> "$tf"
out=$( SKILLS_DIR="$TMP/mt15"; ONLY_SKILL=""; FAILS=0; check_model_tiers 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "stale tier row => FAIL" "$out" "FAILS=0"
# Forward: an agency skill dir absent from the table => FAIL (fresh temp to isolate).
mkdir -p "$TMP/mt15b/jarvis-agency-orchestrate/reference" "$TMP/mt15b/jarvis-agency-untabled"
: > "$TMP/mt15b/jarvis-agency-orchestrate/SKILL.md"; : > "$TMP/mt15b/jarvis-agency-untabled/SKILL.md"
printf '| jarvis-agency-orchestrate | session | x |\n' > "$TMP/mt15b/jarvis-agency-orchestrate/reference/model-tiers.md"
out=$( SKILLS_DIR="$TMP/mt15b"; ONLY_SKILL=""; FAILS=0; check_model_tiers 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "untiered agency skill => FAIL" "$out" "FAILS=0"
# Self-skips when the tier table is absent (non-agency fork).
out=$( SKILLS_DIR="$TMP/mt15/jarvis-agency-intake"; ONLY_SKILL=""; FAILS=0; check_model_tiers 2>&1; printf '|FAILS=%s' "$FAILS" )
case "$out" in *"no model-tiers.md"*"|FAILS=0") assert_eq "check 14 self-skips without tier table" "skips" "skips";;
  *) assert_eq "check 14 self-skips without tier table" "$out" "skips";; esac
# Skips on a single-skill run (cross-skill parity).
out=$( SKILLS_DIR="$TMP/mt15"; ONLY_SKILL="jarvis-agency-intake"; FAILS=0; check_model_tiers 2>&1; printf '|FAILS=%s' "$FAILS" )
case "$out" in *"skipped on single-skill run"*"|FAILS=0") assert_eq "check 14 skips on single-skill run" "skips" "skips";;
  *) assert_eq "check 14 skips on single-skill run" "$out" "skips";; esac
# Tier-floor invariants: red-team must be opus; a gate must not be haiku; tier vocabulary is fixed.
mkdir -p "$TMP/mt15c/jarvis-agency-orchestrate/reference" "$TMP/mt15c/jarvis-agency-redteam-security" "$TMP/mt15c/jarvis-agency-review-code"
: > "$TMP/mt15c/jarvis-agency-orchestrate/SKILL.md"; : > "$TMP/mt15c/jarvis-agency-redteam-security/SKILL.md"; : > "$TMP/mt15c/jarvis-agency-review-code/SKILL.md"
tc="$TMP/mt15c/jarvis-agency-orchestrate/reference/model-tiers.md"
printf '| jarvis-agency-orchestrate | session | x |\n| jarvis-agency-redteam-security | opus | x |\n| jarvis-agency-review-code | sonnet | x |\n' > "$tc"
out=$( SKILLS_DIR="$TMP/mt15c"; ONLY_SKILL=""; FAILS=0; check_model_tiers >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "floor: red-team opus + gate sonnet => no FAIL" "$out" "FAILS=0"
printf '| jarvis-agency-orchestrate | session | x |\n| jarvis-agency-redteam-security | sonnet | x |\n| jarvis-agency-review-code | sonnet | x |\n' > "$tc"
out=$( SKILLS_DIR="$TMP/mt15c"; ONLY_SKILL=""; FAILS=0; check_model_tiers 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "floor: red-team below opus => FAIL" "$out" "FAILS=0"
printf '| jarvis-agency-orchestrate | session | x |\n| jarvis-agency-redteam-security | opus | x |\n| jarvis-agency-review-code | haiku | x |\n' > "$tc"
out=$( SKILLS_DIR="$TMP/mt15c"; ONLY_SKILL=""; FAILS=0; check_model_tiers 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "floor: gate on haiku => FAIL" "$out" "FAILS=0"
printf '| jarvis-agency-orchestrate | session | x |\n| jarvis-agency-redteam-security | opus | x |\n| jarvis-agency-review-code | banana | x |\n' > "$tc"
out=$( SKILLS_DIR="$TMP/mt15c"; ONLY_SKILL=""; FAILS=0; check_model_tiers 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "floor: unknown tier value => FAIL" "$out" "FAILS=0"

printf '%s-- C16 check 13 label-list parity + check 15 guide inventory --%s\n' "$B" "$X"
# check 13 label sub-check: registry label missing from the label-values row => FAIL
mkdir -p "$TMP/lbl16/jarvis-agency-build-go" "$TMP/lbl16/jarvis-agency-contract/reference/_internal"
: > "$TMP/lbl16/jarvis-agency-build-go/SKILL.md"
printf '| Type label | label values | `backend`, `go` |\n| `go` | jarvis-agency-build-go | Go |\n' \
  > "$TMP/lbl16/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/lbl16"; ONLY_SKILL=""; FAILS=0; check_agency_registry >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "registry label present in label-values row => no FAIL" "$out" "FAILS=0"
printf '| Type label | label values | `backend` |\n| `go` | jarvis-agency-build-go | Go |\n' \
  > "$TMP/lbl16/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/lbl16"; ONLY_SKILL=""; FAILS=0; check_agency_registry 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "registry label absent from label-values row => FAIL" "$out" "FAILS=0"
if grep -q 'check_operator_guide()' "$ROOT/lint-platform.sh"; then assert_eq "check 15 function defined" "yes" "yes"
else assert_eq "check 15 function defined" "no" "yes"; fi
if grep -qE '^check_operator_guide$' "$ROOT/lint-platform.sh"; then assert_eq "check 15 invoked in run sequence" "yes" "yes"
else assert_eq "check 15 invoked in run sequence" "no" "yes"; fi
# check 15: every agency skill named in the guide; a missing one FAILs; absent guide self-skips.
mkdir -p "$TMP/og16/skills/jarvis-agency-alpha" "$TMP/og16/skills/jarvis-agency-beta" "$TMP/og16/docs"
: > "$TMP/og16/skills/jarvis-agency-alpha/SKILL.md"; : > "$TMP/og16/skills/jarvis-agency-beta/SKILL.md"
printf 'roster: jarvis-agency-alpha and jarvis-agency-beta\n' > "$TMP/og16/docs/jarvis-agency-operator-guide.md"
out=$( ROOT="$TMP/og16"; SKILLS_DIR="$TMP/og16/skills"; ONLY_SKILL=""; FAILS=0; check_operator_guide >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "all skills named in guide => no FAIL" "$out" "FAILS=0"
printf 'roster: jarvis-agency-alpha only\n' > "$TMP/og16/docs/jarvis-agency-operator-guide.md"
out=$( ROOT="$TMP/og16"; SKILLS_DIR="$TMP/og16/skills"; ONLY_SKILL=""; FAILS=0; check_operator_guide 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "skill missing from guide => FAIL" "$out" "FAILS=0"
rm -f "$TMP/og16/docs/jarvis-agency-operator-guide.md"
out=$( ROOT="$TMP/og16"; SKILLS_DIR="$TMP/og16/skills"; ONLY_SKILL=""; FAILS=0; check_operator_guide 2>&1; printf '|FAILS=%s' "$FAILS" )
case "$out" in *"no operator guide"*"|FAILS=0") assert_eq "check 15 self-skips without the guide" "skips" "skips";;
  *) assert_eq "check 15 self-skips without the guide" "$out" "skips";; esac

printf '%s-- C17 check 16 eval-id uniqueness --%s\n' "$B" "$X"
if grep -q 'check_eval_ids()' "$ROOT/lint-platform.sh"; then assert_eq "check 16 function defined" "yes" "yes"
else assert_eq "check 16 function defined" "no" "yes"; fi
if grep -qE '^check_eval_ids$' "$ROOT/lint-platform.sh"; then assert_eq "check 16 invoked in run sequence" "yes" "yes"
else assert_eq "check 16 invoked in run sequence" "no" "yes"; fi
mkdir -p "$TMP/ev16/jarvis-x/evaluations"
: > "$TMP/ev16/jarvis-x/SKILL.md"
printf '{"scenarios":[{"id":"jarvis-x-1"},{"id":"jarvis-x-2"}]}' > "$TMP/ev16/jarvis-x/evaluations/baseline-evals.json"
out=$( SKILLS_DIR="$TMP/ev16"; ONLY_SKILL=""; FAILS=0; check_eval_ids >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "unique, correctly-prefixed eval ids => no FAIL" "$out" "FAILS=0"
printf '{"scenarios":[{"id":"jarvis-x-1"},{"id":"jarvis-x-1"}]}' > "$TMP/ev16/jarvis-x/evaluations/baseline-evals.json"
out=$( SKILLS_DIR="$TMP/ev16"; ONLY_SKILL=""; FAILS=0; check_eval_ids 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "duplicate eval id => FAIL" "$out" "FAILS=0"
# A tree-wide rename can leave ids that are still UNIQUE but name a skill that does not exist
# (2026-07-29: an eval-domain rewrite renamed all nine of jarvis-agency-audit's ids to
# jarvis-agency-duty-status-*; uniqueness passed and the run output named a phantom skill).
printf '{"scenarios":[{"id":"jarvis-x-1"},{"id":"jarvis-other-2"}]}' > "$TMP/ev16/jarvis-x/evaluations/baseline-evals.json"
out=$( SKILLS_DIR="$TMP/ev16"; ONLY_SKILL=""; FAILS=0; check_eval_ids 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "unique but wrong-skill eval id => FAIL" "$out" "FAILS=0"

printf '%s-- C36 check 36 dist content parity --%s\n' "$B" "$X"
# Check 1 compares the zip FILENAME version; check 7 the manifest sha. Neither reads the zip's
# contents, so an edit without a version bump left a stale zip and every gate stayed green
# (2026-07-29: a scrubbed identifier kept shipping in the built zips after the source was clean).
if grep -q 'check_dist_content()' "$ROOT/lint-platform.sh"; then assert_eq "check 36 function defined" "yes" "yes"
else assert_eq "check 36 function defined" "no" "yes"; fi
if grep -qE '^check_dist_content$' "$ROOT/lint-platform.sh"; then assert_eq "check 36 invoked in run sequence" "yes" "yes"
else assert_eq "check 36 invoked in run sequence" "no" "yes"; fi
if command -v unzip >/dev/null 2>&1 && command -v zip >/dev/null 2>&1; then
  mkdir -p "$TMP/dc36/skills/jarvis-z" "$TMP/dc36/dist"
  printf -- '---\nname: jarvis-z\nversion: 1.0.0\n---\nbody\n' > "$TMP/dc36/skills/jarvis-z/SKILL.md"
  ( cd "$TMP/dc36/skills" && zip -q -r "$TMP/dc36/dist/jarvis-z-v1.0.0-public.zip" jarvis-z )
  out=$( ROOT="$TMP/dc36"; SKILLS_DIR="$TMP/dc36/skills"; DIST_DIR="$TMP/dc36/dist"; ONLY_SKILL=""; FAILS=0; check_dist_content >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
  assert_eq "zip matching source => no FAIL" "$out" "FAILS=0"
  printf -- '---\nname: jarvis-z\nversion: 1.0.0\n---\nbody CHANGED\n' > "$TMP/dc36/skills/jarvis-z/SKILL.md"
  out=$( ROOT="$TMP/dc36"; SKILLS_DIR="$TMP/dc36/skills"; DIST_DIR="$TMP/dc36/dist"; ONLY_SKILL=""; FAILS=0; check_dist_content 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
  assert_ne "source edited, zip stale => FAIL" "$out" "FAILS=0"
fi

printf '%s-- C18 check 12 count-claims parity --%s\n' "$B" "$X"
# Two agency dirs; an agency-line claiming the right count passes, a stale one FAILs,
# and non-agency "N skills" prose is ignored.
mkdir -p "$TMP/cnt18/skills/jarvis-agency-a" "$TMP/cnt18/skills/jarvis-agency-b"
: > "$TMP/cnt18/skills/jarvis-agency-a/SKILL.md"; : > "$TMP/cnt18/skills/jarvis-agency-b/SKILL.md"
printf '# CLAUDE.md\nthe agency workbench (2 skills): skills/jarvis-agency-a skills/jarvis-agency-b\nplan first when the edit touches 3 skills or more\n' > "$TMP/cnt18/CLAUDE.md"
out=$( ROOT="$TMP/cnt18"; SKILLS_DIR="$TMP/cnt18/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory >/dev/null 2>&1; echo "FAILS=$FAILS" )
assert_eq "correct agency count claim => no FAIL (non-agency '3 skills' ignored)" "$out" "FAILS=0"
printf '# CLAUDE.md\nthe agency workbench (3 skills): skills/jarvis-agency-a skills/jarvis-agency-b\n' > "$TMP/cnt18/CLAUDE.md"
out=$( ROOT="$TMP/cnt18"; SKILLS_DIR="$TMP/cnt18/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory 2>&1 1>/dev/null; echo "FAILS=$FAILS" )
assert_ne "stale CLAUDE.md agency count => FAIL" "$out" "FAILS=0"
printf '# CLAUDE.md\nthe agency workbench (2 skills): skills/jarvis-agency-a skills/jarvis-agency-b\n' > "$TMP/cnt18/CLAUDE.md"
printf 'the flagship agency (5 skills) does things\n' > "$TMP/cnt18/README.md"
out=$( ROOT="$TMP/cnt18"; SKILLS_DIR="$TMP/cnt18/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory 2>&1 1>/dev/null; echo "FAILS=$FAILS" )
assert_ne "stale README agency count => FAIL" "$out" "FAILS=0"
printf 'the flagship agency (2 skills) does things\n' > "$TMP/cnt18/README.md"
out=$( ROOT="$TMP/cnt18"; SKILLS_DIR="$TMP/cnt18/skills"; ONLY_SKILL=""; FAILS=0; check_claudemd_inventory >/dev/null 2>&1; echo "FAILS=$FAILS" )
assert_eq "corrected README agency count => no FAIL" "$out" "FAILS=0"

printf '%s-- C19 check 13 tier-row completeness --%s\n' "$B" "$X"
mkdir -p "$TMP/tier19/jarvis-agency-build-go" "$TMP/tier19/jarvis-agency-contract/reference/_internal"
: > "$TMP/tier19/jarvis-agency-build-go/SKILL.md"
printf 'routes to jarvis-agency-build-go\n| Work tier | marker comment | `docs` / `small` / `feature` / `product` |\n' \
  > "$TMP/tier19/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/tier19"; ONLY_SKILL=""; FAILS=0; check_agency_registry >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "complete four-tier row => no FAIL" "$out" "FAILS=0"
printf 'routes to jarvis-agency-build-go\n| Work tier | marker comment | `small` / `feature` / `product` |\n' \
  > "$TMP/tier19/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/tier19"; ONLY_SKILL=""; FAILS=0; check_agency_registry 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "tier row missing docs => FAIL" "$out" "FAILS=0"
printf 'routes to jarvis-agency-build-go\n' > "$TMP/tier19/jarvis-agency-contract/reference/_internal/cfg.md"
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/tier19"; ONLY_SKILL=""; FAILS=0; check_agency_registry >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "absent tier row self-skips => no FAIL" "$out" "FAILS=0"

printf '%s-- C20 check 18 version-format --%s\n' "$B" "$X"
if grep -q 'check_version_format()' "$ROOT/lint-platform.sh"; then assert_eq "check 18 function defined" "yes" "yes"
else assert_eq "check 18 function defined" "no" "yes"; fi
if grep -qE '^check_version_format$' "$ROOT/lint-platform.sh"; then assert_eq "check 18 invoked in run sequence" "yes" "yes"
else assert_eq "check 18 invoked in run sequence" "no" "yes"; fi
mkdir -p "$TMP/vf/jarvis-badv"
printf -- '---\nname: jarvis-badv\nversion: 1.2\n---\nbody\n' > "$TMP/vf/jarvis-badv/SKILL.md"
out=$( SKILLS_DIR="$TMP/vf"; ONLY_SKILL=""; FAILS=0; check_version_format 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "non-semver version => FAIL" "$out" "FAILS=0"
printf -- '---\nname: jarvis-badv\nversion: 1.2.0\n---\nbody\n' > "$TMP/vf/jarvis-badv/SKILL.md"
out=$( SKILLS_DIR="$TMP/vf"; ONLY_SKILL=""; FAILS=0; check_version_format >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "semver version => no FAIL" "$out" "FAILS=0"

printf '%s-- C21 shared fence-guarded body extraction (lib/skill-md.sh) --%s\n' "$B" "$X"
cat > "$TMP/fence.md" <<'EOF'
---
name: x
version: 1.0.0
body-without-closing-fence
EOF
got="$(skill_body_of "$TMP/fence.md")"
case "$got" in *"name: x"*) assert_eq "missing fence: whole file returned (guarded, documented)" "yes" "yes" ;; *) assert_eq "missing fence: whole file returned (guarded, documented)" "no" "yes" ;; esac
cat > "$TMP/fence2.md" <<'EOF'
---
name: x
version: 1.0.0
---
THE_BODY
EOF
assert_eq "normal file: body only" "$(skill_body_of "$TMP/fence2.md")" "THE_BODY"
if grep -q 'skill-md.sh' "$ROOT/lint-platform.sh"; then assert_eq "lint sources lib/skill-md.sh" "yes" "yes"
else assert_eq "lint sources lib/skill-md.sh" "no" "yes"; fi
if grep -q 'skill-md.sh' "$ROOT/eval-runner.sh"; then assert_eq "eval-runner sources lib/skill-md.sh" "yes" "yes"
else assert_eq "eval-runner sources lib/skill-md.sh" "no" "yes"; fi

printf '%s-- C22 zip listing parsed with unzip -Z1 (space-safe) --%s\n' "$B" "$X"
mkdir -p "$TMP/zt/reference/_internal"
printf 'x\n' > "$TMP/zt/reference/_internal/design notes.md"
( cd "$TMP" && zip -qrD "$TMP/zt.zip" zt )   # -D: no directory entries — isolates the leaf-filename-space bug from dir-entry noise
if unzip -Z1 "$TMP/zt.zip" | grep -Eq "$INTERNAL_RE"; then assert_eq "-Z1 catches spaced internal path" "yes" "yes"
else assert_eq "-Z1 catches spaced internal path" "no" "yes"; fi
if unzip -l "$TMP/zt.zip" | awk '{print $NF}' | grep -Eq "$INTERNAL_RE"; then old=caught; else old=missed; fi
assert_eq "old \$NF parse misses it (the bug)" "$old" "missed"
if grep -q 'unzip -Z1' "$ROOT/lint-platform.sh"; then assert_eq "lint uses unzip -Z1" "yes" "yes"
else assert_eq "lint uses unzip -Z1" "no" "yes"; fi

printf '%s-- C23 check 19 TODO placeholder description --%s\n' "$B" "$X"
if grep -q 'check_todo_placeholders()' "$ROOT/lint-platform.sh"; then assert_eq "check 19 function defined" "yes" "yes"
else assert_eq "check 19 function defined" "no" "yes"; fi
if grep -qE '^check_todo_placeholders$' "$ROOT/lint-platform.sh"; then assert_eq "check 19 invoked in run sequence" "yes" "yes"
else assert_eq "check 19 invoked in run sequence" "no" "yes"; fi
mkdir -p "$TMP/todo/jarvis-stub"
printf -- '---\nname: jarvis-stub\ndescription: TODO replace — scaffolded.\nversion: 0.1.0\n---\nbody\n' > "$TMP/todo/jarvis-stub/SKILL.md"
out=$( SKILLS_DIR="$TMP/todo"; ONLY_SKILL=""; WARNS=0; check_todo_placeholders >/dev/null 2>&1; printf 'WARNS=%s' "$WARNS" )
assert_ne "TODO description => WARN" "$out" "WARNS=0"
printf -- '---\nname: jarvis-stub\ndescription: Use when testing. Does not trigger otherwise.\nversion: 0.1.0\n---\nbody\n' > "$TMP/todo/jarvis-stub/SKILL.md"
out=$( SKILLS_DIR="$TMP/todo"; ONLY_SKILL=""; WARNS=0; check_todo_placeholders >/dev/null 2>&1; printf 'WARNS=%s' "$WARNS" )
assert_eq "real description => no WARN" "$out" "WARNS=0"

printf '%s-- C24 check 20 producer skeleton parity --%s\n' "$B" "$X"
if grep -q 'check_producer_skeleton()' "$ROOT/lint-platform.sh"; then assert_eq "check 20 function defined" "yes" "yes"
else assert_eq "check 20 function defined" "no" "yes"; fi
if grep -qE '^check_producer_skeleton$' "$ROOT/lint-platform.sh"; then assert_eq "check 20 invoked in run sequence" "yes" "yes"
else assert_eq "check 20 invoked in run sequence" "no" "yes"; fi
mkdir -p "$TMP/ps/jarvis-agency-build-zz"
{ printf -- '---\nname: z\nversion: 1.0.0\n---\n# t\n'
  printf '## What it never does\n## What it receives\n## The build process\n## Stack conventions\n## Restricted write\n## Files in this skill\n'
} > "$TMP/ps/jarvis-agency-build-zz/SKILL.md"
out=$( SKILLS_DIR="$TMP/ps"; ONLY_SKILL=""; FAILS=0; check_producer_skeleton >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "conforming producer => no FAIL" "$out" "FAILS=0"
printf -- '---\nname: z\nversion: 1.0.0\n---\n# t\n## What it receives\n' > "$TMP/ps/jarvis-agency-build-zz/SKILL.md"
out=$( SKILLS_DIR="$TMP/ps"; ONLY_SKILL=""; FAILS=0; check_producer_skeleton 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "missing skeleton sections => FAIL" "$out" "FAILS=0"
mkdir -p "$TMP/ps/jarvis-agency-build-docs"
printf -- '---\nname: d\nversion: 1.0.0\n---\n# docs producer, intentionally different\n' > "$TMP/ps/jarvis-agency-build-docs/SKILL.md"
out=$( SKILLS_DIR="$TMP/ps"; ONLY_SKILL="jarvis-agency-build-docs"; FAILS=0; check_producer_skeleton 2>&1; printf '|FAILS=%s' "$FAILS" )
case "$out" in *"skipped on single-skill run"*"|FAILS=0") assert_eq "check 20 skips on single-skill run" "skips" "skips";;
  *) assert_eq "check 20 skips on single-skill run" "$out" "skips";; esac
out=$( SKILLS_DIR="$TMP/ps"; ONLY_SKILL=""; FAILS=0; check_producer_skeleton 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "docs-tier exempt but the broken zz producer still FAILs" "$out" "FAILS=0"

printf '%s-- C25 committed slice makes check 13 run without internal config --%s\n' "$B" "$X"
mkdir -p "$TMP/slice/config" "$TMP/slice/skills/jarvis-agency-build-go"
: > "$TMP/slice/skills/jarvis-agency-build-go/SKILL.md"
printf 'registry: jarvis-agency-build-go\n' > "$TMP/slice/config/agency-registry.md"
out=$( ROOT="$TMP/slice"; SKILLS_DIR="$TMP/slice/skills"; ONLY_SKILL=""; FAILS=0; check_agency_registry >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "slice present, producer registered => runs and passes" "$out" "FAILS=0"
printf 'registry: nothing here\n' > "$TMP/slice/config/agency-registry.md"
out=$( ROOT="$TMP/slice"; SKILLS_DIR="$TMP/slice/skills"; ONLY_SKILL=""; FAILS=0; check_agency_registry 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "slice present, producer unregistered => FAIL (would have self-skipped before)" "$out" "FAILS=0"

printf '%s-- C26 committed slice makes check 17 run without internal config --%s\n' "$B" "$X"
# Same shape as C25 but for check_verifier_branches: the slice's 'label values' row derives the
# label set; a verifier SKILL.md body missing the label => FAIL where it used to self-skip.
mkdir -p "$TMP/slice17/config" "$TMP/slice17/skills/jarvis-agency-review-code" \
  "$TMP/slice17/skills/jarvis-agency-run-tests" "$TMP/slice17/skills/jarvis-agency-redteam-security"
printf 'registry: jarvis-agency-build-go\n| Type label | label values | `backend`, `go` |\n' \
  > "$TMP/slice17/config/agency-registry.md"
for v in review-code run-tests redteam-security; do
  printf -- '---\nname: jarvis-agency-%s\nversion: 1.0.0\n---\ncovers the `go` stack branch\n' "$v" \
    > "$TMP/slice17/skills/jarvis-agency-$v/SKILL.md"
done
out=$( ROOT="$TMP/slice17"; SKILLS_DIR="$TMP/slice17/skills"; ONLY_SKILL=""; FAILS=0; check_verifier_branches >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
assert_eq "slice present, all three verifiers branch the label => runs and passes" "$out" "FAILS=0"
printf -- '---\nname: jarvis-agency-run-tests\nversion: 1.0.0\n---\nno stack branch here\n' \
  > "$TMP/slice17/skills/jarvis-agency-run-tests/SKILL.md"
out=$( ROOT="$TMP/slice17"; SKILLS_DIR="$TMP/slice17/skills"; ONLY_SKILL=""; FAILS=0; check_verifier_branches 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
assert_ne "slice present, one verifier missing the label branch => FAIL (would have self-skipped before)" "$out" "FAILS=0"
# self-skip still holds when NEITHER the slice nor the internal config exists.
out=$( ROOT="$TMP/noslice"; SKILLS_DIR="$TMP/slice17/skills"; ONLY_SKILL=""; FAILS=0; check_verifier_branches 2>&1; printf '|FAILS=%s' "$FAILS" )
case "$out" in *"skipped — no registry config"*"|FAILS=0") assert_eq "check 17 self-skips without registry config" "skips" "skips";;
  *) assert_eq "check 17 self-skips without registry config" "$out" "skips";; esac

printf '%s-- C31 check 31 shape (g): quoted mixed-case display names --%s\n' "$B" "$X"
# The SEVENTH identifier shape, found by a pre-publication audit on 2026-07-29. Shapes (a),(b),(f)
# all require an ALL-UPPERCASE token, so a two-word display name in ordinary prose case escaped
# every one of them and shipped in the tree, the built zips, and two pushed commits.
# check 31 reads the file list via `git ls-files`, so these fixtures need a real git repo.
if command -v git >/dev/null 2>&1; then
  mkdir -p "$TMP/pi31"
  ( cd "$TMP/pi31" && git init -q . && git config user.email t@example.com && git config user.name t )
  printf 'the workflow moves it to "In Review" then "To Do".\n' > "$TMP/pi31/ok.md"
  ( cd "$TMP/pi31" && git add -A >/dev/null 2>&1 )
  out=$( ROOT="$TMP/pi31"; ONLY_SKILL=""; FAILS=0; check_project_identity >/dev/null 2>&1; printf 'FAILS=%s' "$FAILS" )
  assert_eq "allowlisted workflow bigrams => no FAIL" "$out" "FAILS=0"

  # Compose the fixture names from parts: written literally, this file would itself carry a
  # non-allowlisted display name and check 31 would (correctly) fail the real tree on its own tests.
  _w1=Contoso; _w2=Telemetry; _w3=Northwind; _w4=Analytics
  printf "set up the agency for project '%s %s' now.\n" "$_w1" "$_w2" > "$TMP/pi31/leak.md"
  ( cd "$TMP/pi31" && git add -A >/dev/null 2>&1 )
  out=$( ROOT="$TMP/pi31"; ONLY_SKILL=""; FAILS=0; check_project_identity 2>&1; printf '|FAILS=%s' "$FAILS" )
  assert_ne "non-allowlisted display name => FAIL" "${out##*|}" "FAILS=0"
  case "$out" in *"display name"*) assert_eq "the FAIL names the display-name shape" "yes" "yes";;
    *) assert_eq "the FAIL names the display-name shape" "$out" "yes";; esac

  # The uppercase-only shapes must NOT be what catches it — prove (g) is doing the work by using a
  # name that no other shape can match (no digits, no all-caps token, no backticks).
  rm -f "$TMP/pi31/leak.md"
  printf 'we shipped "%s %s" last quarter.\n' "$_w3" "$_w4" > "$TMP/pi31/prose.md"
  ( cd "$TMP/pi31" && git add -A >/dev/null 2>&1 )
  out=$( ROOT="$TMP/pi31"; ONLY_SKILL=""; FAILS=0; check_project_identity 2>&1 1>/dev/null; printf 'FAILS=%s' "$FAILS" )
  assert_ne "display name in running prose (no project keyword) => FAIL" "$out" "FAILS=0"
fi
