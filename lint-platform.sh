#!/usr/bin/env bash
#
# lint-platform.sh — executable enforcement of shipfoundry's close-out invariants.
#
# This script IS the close-out checklist. Invariants enforced by memory rot; invariants
# enforced by a command that exits non-zero do not. CLAUDE.md's "Before declaring a skill
# edit complete" section points here.
#
# Usage:
#   ./lint-platform.sh                 # lint the whole platform
#   ./lint-platform.sh <skill-name>    # lint a single skill (per-skill checks only)
#   ./lint-platform.sh --strict        # treat warnings as failures (CI mode)
#   ./lint-platform.sh --versions      # print the authoritative skill->version table and exit
#   ./lint-platform.sh --verify-mirror <path>
#                                      # verify one deployed vault-governance mirror
#                                      # ({vault}/_governance/SOURCE-OF-TRUTH.md, in ANY repo)
#                                      # against the platform law, slots masked (CHECK 21)
#
# Exit codes: 0 = all checks pass (warnings allowed unless --strict); 1 = one or more FAILs.
#
# Source-of-truth note: the per-check rationale lives in docs/platform/governance-model.md.
# When you add or change an invariant, change it HERE first, then update that doc to explain WHY.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$ROOT/skills"
DIST_DIR="$ROOT/dist"

# ---- args -------------------------------------------------------------------
STRICT=0
ONLY_SKILL=""
VERSIONS=0
MIRROR_PATH=""
EXPECT_MIRROR_ARG=0
for arg in "$@"; do
  if [ "$EXPECT_MIRROR_ARG" -eq 1 ]; then MIRROR_PATH="$arg"; EXPECT_MIRROR_ARG=0; continue; fi
  case "$arg" in
    --strict) STRICT=1 ;;
    --versions) VERSIONS=1 ;;
    --verify-mirror) EXPECT_MIRROR_ARG=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) ONLY_SKILL="$arg" ;;
  esac
done
[ "$EXPECT_MIRROR_ARG" -eq 1 ] && { echo "--verify-mirror needs a path to a deployed SOURCE-OF-TRUTH.md" >&2; exit 2; }

# ---- counters / output ------------------------------------------------------
FAILS=0
WARNS=0
if [ -t 1 ]; then
  R=$'\e[31m'; Y=$'\e[33m'; G=$'\e[32m'; B=$'\e[1m'; X=$'\e[0m'
else
  R=""; Y=""; G=""; B=""; X=""
fi

section() { printf '\n%s== %s ==%s\n' "$B" "$1" "$X"; }
pass()    { printf '  %sOK%s   %s\n'   "$G" "$X" "$1"; }
warn()    { printf '  %sWARN%s %s\n'   "$Y" "$X" "$1"; WARNS=$((WARNS+1)); }
fail()    { printf '  %sFAIL%s %s\n'   "$R" "$X" "$1"; FAILS=$((FAILS+1)); }

# ---- helpers ----------------------------------------------------------------
# PyYAML availability — detected once; also consumed by CHECK 10.
HAVE_PYYAML=0
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  HAVE_PYYAML=1
fi

# Extract the description value. With PyYAML, parse it authoritatively — this matches exactly
# what the claude.ai uploader sees (quotes stripped, block scalars >|/|- resolved), so the
# char-count (CHECK 4) and tag-scan (CHECK 5) are correct. Without PyYAML, fall back to the awk
# extraction (correct for the common single-line case; leaves block-scalar indicators in place).
desc_of() {
  if [ "$HAVE_PYYAML" -eq 1 ]; then
    awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$1" | python3 -c '
import sys, yaml
try:
    d = yaml.safe_load(sys.stdin) or {}
    sys.stdout.write(str(d.get("description", "")))
except Exception:
    pass'
  else
    # Fallback: awk-extract, then drop a leading block-scalar indicator line (>|, |-, …),
    # join, trim leading space, and strip a fully-surrounding quote pair — so the char-count
    # and tag-scan see the value, not YAML syntax.
    awk '/^description:/{flag=1; sub(/^description: */,""); print; next} flag && /^[a-z_]+:/{flag=0} flag' "$1" \
      | sed -E '1s/^[|>][+-]?[0-9]*[[:space:]]*$//' \
      | tr -d '\n' \
      | sed -E 's/^[[:space:]]+//; s/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/'
  fi
}
version_of() {
  grep -m1 '^version:' "$1" | sed 's/^version: *//' | tr -d ' \r'
}
# Body line count = lines after the second frontmatter '---'.
body_lines_of() {
  local f="$1" fmend total
  fmend=$(frontmatter_end_line "$f")
  fmend=${fmend:-0}   # no closing frontmatter fence → guard the empty-operand arithmetic crash
  total=$(wc -l < "$f" | tr -d ' ')
  echo $(( total - fmend ))
}

# SKILL.md frontmatter/body extraction (frontmatter_end_line, skill_body_of) — single source,
# shared with eval-runner.sh. Used by body_lines_of above (CHECK 6).
# shellcheck source=lib/skill-md.sh
. "$ROOT/lib/skill-md.sh"

# Internal-only content convention (INTERNAL_RE, is_internal_path) — single source, shared
# with build-dist.sh. Used by the dist-leak (CHECK 2) and .distignore-coverage (CHECK 8) checks.
# shellcheck source=lib/internal-convention.sh
. "$ROOT/lib/internal-convention.sh"

skill_list() {
  if [ -n "$ONLY_SKILL" ]; then
    echo "$ONLY_SKILL"
  else
    for d in "$SKILLS_DIR"/*/; do basename "$d"; done
  fi
}

# =============================================================================
# CHECK 1 — Source <-> dist parity  (FAIL)
# Every skill has exactly one dist zip whose filename version matches SKILL.md.
# No orphan zips. Counts match.
# =============================================================================
check_parity() {
  section "1. Source <-> dist parity"
  local src_count=0 problems=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local sm="$SKILLS_DIR/$s/SKILL.md"
    [ -f "$sm" ] || { fail "$s: no SKILL.md"; continue; }
    src_count=$((src_count+1))
    local v; v=$(version_of "$sm")
    local expected="$DIST_DIR/${s}-v${v}-public.zip"
    if [ ! -f "$expected" ]; then
      local found; found=$(ls "$DIST_DIR/${s}-v"*-public.zip 2>/dev/null | head -1)
      if [ -n "$found" ]; then
        fail "$s: source is v$v but dist has $(basename "$found") — rebuild dist zip"
      else
        fail "$s: source is v$v but NO dist zip exists"
      fi
      problems=$((problems+1))
    fi
  done
  if [ -z "$ONLY_SKILL" ]; then
    for z in "$DIST_DIR"/*.zip; do
      [ -e "$z" ] || continue
      local base; base=$(basename "$z")
      local skill="${base%-v*}"
      if [ ! -d "$SKILLS_DIR/$skill" ]; then
        fail "orphan dist zip with no source skill: $base"; problems=$((problems+1))
      fi
    done
    local zip_count; zip_count=$(ls "$DIST_DIR"/*.zip 2>/dev/null | wc -l | tr -d ' ')
    if [ "$src_count" -ne "$zip_count" ]; then
      warn "skill count ($src_count) != dist zip count ($zip_count)"
    fi
  fi
  [ "$problems" -eq 0 ] && pass "all sources have a matching-version dist zip; no orphans"
}

# =============================================================================
# CHECK 2 — Dist leak  (FAIL)
# No dist zip contains internal-only paths (see INTERNAL_RE).
# =============================================================================
check_dist_leak() {
  section "2. Dist internal-only leak"
  local leaks=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local z; z=$(ls "$DIST_DIR/${s}-v"*-public.zip 2>/dev/null | head -1)
    [ -n "$z" ] || continue
    if unzip -Z1 "$z" 2>/dev/null | grep -Eq "$INTERNAL_RE"; then
      fail "$(basename "$z") contains internal-only content"
      leaks=$((leaks+1))
    fi
  done
  [ "$leaks" -eq 0 ] && pass "no internal-only paths in any dist zip"
}

# =============================================================================
# CHECK 3 — Dist bracket filenames  (FAIL)
# The claude.ai uploader rejects '[' or ']' in zip paths.
# =============================================================================
check_dist_brackets() {
  section "3. Dist bracket-laden filenames"
  local hits=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local z; z=$(ls "$DIST_DIR/${s}-v"*-public.zip 2>/dev/null | head -1)
    [ -n "$z" ] || continue
    if unzip -Z1 "$z" 2>/dev/null | grep '[][]' >/dev/null; then
      fail "$(basename "$z") has '[' or ']' in a filename"
      hits=$((hits+1))
    fi
  done
  [ "$hits" -eq 0 ] && pass "no bracket characters in any dist zip filename"
}

# =============================================================================
# CHECK 4 + 5 — Description length & angle-bracket tags  (FAIL)
# claude.ai uploader: <=1024 chars; no <...> XML-parseable tags.
# =============================================================================
check_description() {
  section "4+5. Description length (<=1024) & no angle-bracket tags"
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local sm="$SKILLS_DIR/$s/SKILL.md"; [ -f "$sm" ] || continue
    local d; d=$(desc_of "$sm")
    local n=${#d}
    if [ "$n" -gt 1024 ]; then
      fail "$s: description is $n chars (limit 1024)"; probs=$((probs+1))
    fi
    local tags; tags=$(printf '%s' "$d" | grep -oE '<[^>]+>' | wc -l | tr -d ' ')
    if [ "$tags" -ne 0 ]; then
      fail "$s: description has $tags angle-bracket tag(s) — use {braces}"; probs=$((probs+1))
    fi
  done
  [ "$probs" -eq 0 ] && pass "all descriptions <=1024 chars with no angle-bracket tags"
}

# =============================================================================
# CHECK 6 — Body line cap  (FAIL >500, WARN >450)
# =============================================================================
check_body_lines() {
  section "6. SKILL.md body line cap (hard 500 / soft 450)"
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local sm="$SKILLS_DIR/$s/SKILL.md"; [ -f "$sm" ] || continue
    local n; n=$(body_lines_of "$sm")
    if [ "$n" -gt 500 ]; then
      fail "$s: body is $n lines (>500 hard cap) — extract to reference/"; probs=$((probs+1))
    elif [ "$n" -gt 450 ]; then
      warn "$s: body is $n lines (>450 soft target) — plan a reference/ extraction"
    fi
  done
  [ "$probs" -eq 0 ] && pass "no skill body exceeds the 500-line hard cap"
}

# =============================================================================
# CHECK 7 — Dist manifest in sync  (FAIL)
# dist/MANIFEST.json (skill->version->sha256, written by build-dist.sh) must match the
# actual zips. A stale manifest means someone rebuilt a zip without build-dist.sh.
# Platform-wide only — skipped on single-skill runs.
# =============================================================================
check_manifest() {
  section "7. Dist manifest in sync (dist/MANIFEST.json)"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (manifest is platform-wide)"; return; fi
  local mf="$DIST_DIR/MANIFEST.json"
  if [ ! -f "$mf" ]; then fail "no dist/MANIFEST.json — run ./build-dist.sh"; return; fi
  command -v jq >/dev/null || { warn "jq unavailable — cannot verify manifest"; return; }
  jq -e . "$mf" >/dev/null 2>&1 || { fail "dist/MANIFEST.json is not valid JSON"; return; }
  local probs=0 z base cur rec mz
  for z in "$DIST_DIR"/*-public.zip; do
    [ -e "$z" ] || continue
    base=$(basename "$z")
    cur=$( { command -v sha256sum >/dev/null 2>&1 && sha256sum "$z" || shasum -a 256 "$z"; } | awk '{print $1}')
    rec=$(jq -r --arg z "$base" '.skills[]|select(.zip==$z)|.sha256' "$mf")
    if [ -z "$rec" ]; then fail "manifest has no entry for $base — run ./build-dist.sh"; probs=$((probs+1))
    elif [ "$rec" != "$cur" ]; then fail "manifest sha256 stale for $base — run ./build-dist.sh"; probs=$((probs+1)); fi
  done
  while IFS= read -r mz; do
    [ -f "$DIST_DIR/$mz" ] || { fail "manifest lists $mz but no such zip"; probs=$((probs+1)); }
  done < <(jq -r '.skills[].zip' "$mf")
  [ "$probs" -eq 0 ] && pass "manifest matches all dist zips (sha256)"
}

# =============================================================================
# CHECK 8 — Internal content has a .distignore covering it  (FAIL)
# If a skill holds internal-only content (see INTERNAL_RE), it must declare a .distignore.
# The real leak-prevention is CHECK 2; this guards the documented-intent half.
# =============================================================================
check_distignore() {
  section "8. .distignore covers internal content"
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local dir="$SKILLS_DIR/$s"; [ -d "$dir" ] || continue
    local has_internal=0
    # Match every file path against INTERNAL_RE (the single source) — not a second -name/-path
    # expression of the same rule.
    if find "$dir" -type f 2>/dev/null | grep -Eq "$INTERNAL_RE"; then
      has_internal=1
    fi
    if [ "$has_internal" -eq 1 ] && [ ! -f "$dir/.distignore" ]; then
      fail "$s: holds internal-only content but has no .distignore"; probs=$((probs+1))
    fi
  done
  [ "$probs" -eq 0 ] && pass "every skill with internal content declares a .distignore"
}

# =============================================================================
# CHECK 9 — Trigger-phrase collisions  (WARN)
# Discoverability guard: if two skills quote the SAME trigger phrase in their description's
# "Triggers on ..." clause, a dispatcher may mis-route. Scoped to the trigger clause so
# check-patterns don't false-positive. Platform-wide only.
# =============================================================================
check_trigger_collisions() {
  section "9. Trigger-phrase collisions (discoverability)"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (collisions are cross-skill)"; return; fi
  local rows; rows=$(
    for d in "$SKILLS_DIR"/*/; do
      local s; s=$(basename "$d"); [ -f "$d/SKILL.md" ] || continue
      local desc clause; desc=$(desc_of "$d/SKILL.md")
      clause=$(printf '%s' "$desc" | grep -oiE 'Triggers on[^.]*(\.[^.]*)*' | sed -E 's/[Dd]oes [Nn][Oo][Tt].*//')
      printf '%s' "$clause" | grep -oE "\"[^\"]+\"|'[^']+'" | while IFS= read -r q; do
        local norm; norm=$(printf '%s' "$q" | tr -d "\"'" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; s/[.,;:!?]+$//')
        [ "$(printf '%s' "$norm" | wc -w | tr -d ' ')" -ge 2 ] && printf '%s\t%s\n' "$norm" "$s"
      done
    done
  )
  local collisions; collisions=$(printf '%s\n' "$rows" | awk -F'\t' '$1!=""{if(!seen[$1","$2]++){c[$1]++; w[$1]=w[$1]" "$2}} END{for(p in c) if(c[p]>=2) print "\""p"\" shared by"w[p]}')
  if [ -n "$collisions" ]; then
    while IFS= read -r c; do [ -n "$c" ] && warn "trigger collision: $c"; done <<< "$collisions"
  else
    pass "no exact trigger-phrase collisions across skills"
  fi
}

# =============================================================================
# CHECK 10 — Frontmatter YAML validity  (FAIL)
# The claude.ai org Skills uploader parses SKILL.md frontmatter with a STRICT YAML parser
# and rejects malformed YAML — e.g. an unquoted scalar containing ": " (colon-space), which
# YAML reads as a nested mapping. The awk helpers do NOT catch this; this mirrors the uploader.
# =============================================================================
check_frontmatter_yaml() {
  section "10. Frontmatter YAML validity (mirrors the org uploader)"
  if [ "$HAVE_PYYAML" -ne 1 ]; then
    warn "python3 + PyYAML unavailable — frontmatter YAML parse skipped (CI installs python3-yaml; locally: pip/apt install pyyaml)"
    return
  fi
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local sm="$SKILLS_DIR/$s/SKILL.md"; [ -f "$sm" ] || continue
    local err
    err=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$sm" | python3 -c '
import sys, yaml
try:
    yaml.safe_load(sys.stdin)
except Exception as e:
    print(str(e).replace(chr(10), " ")[:140])' 2>&1)
    if [ -n "$err" ]; then
      fail "$s: frontmatter is not valid YAML — $err"; probs=$((probs+1))
    fi
  done
  [ "$probs" -eq 0 ] && pass "all SKILL.md frontmatter parses as strict YAML"
}

# =============================================================================
# CHECK 11 — Local symlink install coverage  (WARN, local-only)
# The personal Claude Code install discovers skills via ~/.claude/skills/ symlinks into
# this repo. A new skill that never gets its symlink is invisible to the local `/` menu.
# LOCAL-ONLY: self-skips when ~/.claude/skills is absent (CI / fresh checkout) or does not
# manage this repo on this machine. WARN, not FAIL — a missing symlink is a convenience gap.
# =============================================================================
check_symlinks() {
  section "11. Local symlink install coverage (local-only)"
  local link_dir="$HOME/.claude/skills"
  if [ ! -d "$link_dir" ]; then
    pass "skipped — no ~/.claude/skills install on this machine (CI / fresh checkout)"
    return
  fi
  local present=0 s
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(for d in "$SKILLS_DIR"/*/; do basename "$d"; done); do
    [ -L "$link_dir/$s" ] && { present=1; break; }
  done
  if [ "$present" -eq 0 ]; then
    pass "skipped — ~/.claude/skills does not manage this repo's skills on this machine"
    return
  fi
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local link="$link_dir/$s"
    if [ ! -L "$link" ]; then
      warn "$s: no ~/.claude/skills symlink — invisible to the local '/' menu (fix: ln -s \"$SKILLS_DIR/$s\" \"$link\")"; probs=$((probs+1))
    elif [ ! -e "$link" ]; then
      warn "$s: ~/.claude/skills symlink is broken (resolves to nothing)"; probs=$((probs+1))
    fi
  done
  [ "$probs" -eq 0 ] && pass "every source skill has a resolving ~/.claude/skills symlink"
}

# =============================================================================
# CHECK 12 — CLAUDE.md skill inventory parity  (FAIL)
# The maintenance step "update CLAUDE.md skill counts + structure tree" was enforced by memory
# (every playbook says it; no command checked it). This makes it executable — the platform's own
# meta-principle applied to itself (see lessons.md 2026-06-26).
#   Forward : every skill under skills/ must be named in CLAUDE.md (catches add-without-update).
#   Reverse : every `skills/<name>` path mentioned in CLAUDE.md must resolve (catches a stale
#             reference to a deleted/renamed skill). Platform-wide only.
# Known limit: a bare tree entry (`oldname/` with no `skills/` prefix) is not reverse-checked;
# the forward check plus the structure-tree discipline cover the common drift.
# =============================================================================
check_claudemd_inventory() {
  section "12. CLAUDE.md skill inventory parity"
  local cm="$ROOT/CLAUDE.md"
  if [ ! -f "$cm" ]; then warn "no CLAUDE.md at repo root — inventory check skipped"; return; fi
  local probs=0 s ref
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    [ -d "$SKILLS_DIR/$s" ] || continue
    grep -Fq "$s" "$cm" || { fail "$s: not named in CLAUDE.md — update the structure tree / inventory"; probs=$((probs+1)); }
  done
  if [ -z "$ONLY_SKILL" ]; then
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      [ -d "$SKILLS_DIR/$ref" ] || { fail "CLAUDE.md references skills/$ref but no such skill exists (stale)"; probs=$((probs+1)); }
    done < <(grep -oE 'skills/[A-Za-z0-9._-]+' "$cm" | sed -E 's#^skills/##' | sort -u)
  fi
  # Count-claims parity (platform-wide): a line in CLAUDE.md or README.md that mentions the agency
  # and claims "<N> skills" must match the actual number of jarvis-agency-* skill dirs. Names were
  # guarded (above); counts were not — README shipped "30 skills" after the 31st skill landed.
  # Scoped to lines containing "agency" so unrelated prose ("the edit touches ≥3 skills") cannot
  # false-positive.
  if [ -z "$ONLY_SKILL" ]; then
    local actual f claim
    actual=$(find "$SKILLS_DIR" -maxdepth 1 -type d -name 'jarvis-agency-*' 2>/dev/null | wc -l | tr -d ' ')
    for f in "$cm" "$ROOT/README.md"; do
      [ -f "$f" ] || continue
      while IFS= read -r claim; do
        [ -n "$claim" ] || continue
        if [ "$claim" != "$actual" ]; then
          fail "$(basename "$f") claims $claim agency skills but skills/ holds $actual — update the count"; probs=$((probs+1))
        fi
      done < <(grep -iE 'agency' "$f" | grep -oE '[0-9]+ skills' | grep -oE '[0-9]+')
    done
  fi
  [ "$probs" -eq 0 ] && pass "CLAUDE.md names every skill; no stale skill references; count claims match"
}

# =============================================================================
# CHECK 13 — Agency registry parity  (FAIL, needs the registry config)
# The orchestrator and intake route work by reading registries in a workbench's internal config
# (skills/*/reference/_internal/*.md) — the producer-capability registry, the verifier notes —
# NOT by scanning the skills folder. So a producer skill that exists but is unregistered will
# never be routed to (loadable but invisible to the agency's own logic), and a registry entry
# naming a deleted/renamed skill is a dangling route. Those are the one by-hand layer that used
# to be caught only by the independent review; this makes it a gate.
#   Forward : every producer skill (name contains '-build-') must be named in an internal config.
#   Reverse : every producer NAME referenced in an internal config must resolve to a real skill.
# Reverse is scoped to producer (`*-build-*`) tokens on purpose: the config also references
# non-skill `jarvis-agency-*` identifiers (paired repo names such as a project's sandbox repo), which a
# blanket skill-name reverse-check would false-positive on. Verifier-name staleness stays
# review-caught; the producer routing class — the highest-value one — is now gated both ways.
# Runs wherever the committed slice (config/agency-registry.md, VIBE-016) or the gitignored
# internal config exists — CI included, not maintainer-only anymore. The slice is a sanitized
# mirror of the producer registry (see config/agency-registry.md's own header for what it omits);
# it lets the forward/reverse/label/tier checks below run their real verdict on a fresh clone,
# not only on the maintainer's machine. Self-skips only when NEITHER source exists (a fork with no
# agency workbench at all). Platform-wide only.
# =============================================================================
check_agency_registry() {
  section "13. Agency registry parity (internal config / committed slice)"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (registry parity is cross-skill)"; return; fi
  local cfgs; cfgs=$(find "$SKILLS_DIR" -type f -path '*/reference/_internal/*.md' 2>/dev/null)
  [ -f "$ROOT/config/agency-registry.md" ] && cfgs="$cfgs"$'\n'"$ROOT/config/agency-registry.md"
  cfgs=$(printf '%s\n' "$cfgs" | grep -v '^$')
  if [ -z "$cfgs" ]; then
    pass "skipped — no registry config on this checkout (fresh / fork)"
    return
  fi
  local blob; blob=$(cat $cfgs 2>/dev/null)   # unquoted: newline-separated paths, no spaces
  local probs=0 s ref
  local IFS=$'\n'
  # Forward: every producer skill (*-build-*) must be named somewhere in an internal config. This is
  # a NAMED-ANYWHERE test, not a parse of the specific registry TABLE (parsing markdown by header is
  # brittle) — a producer mentioned only in prose would satisfy it. That is an accepted limit: it
  # catches the common drift (a new producer registered nowhere at all) without a fragile parser.
  for s in $(for d in "$SKILLS_DIR"/*-build-*/; do [ -d "$d" ] && basename "$d"; done); do
    printf '%s' "$blob" | grep -Fq "$s" \
      || { fail "$s: producer skill not named in any workbench internal config — intake/orchestrator will not route to it"; probs=$((probs+1)); }
  done
  # Reverse: every producer name referenced in the config must resolve to a real skill. The token
  # captures ONE stack segment after '-build-' (final class is [a-z0-9], NO dash), so an identifier
  # that embeds a producer name plus a suffix — e.g. a paired repo 'jarvis-agency-build-go-sandbox' —
  # yields 'jarvis-agency-build-go' (which resolves) instead of the whole compound (which would not,
  # and would red-gate a legitimate commit). Producer names are single-segment-after-build by
  # convention (build-<stack>), so this is exact for real producers and cannot false-positive on a
  # suffixed non-skill identifier.
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ -d "$SKILLS_DIR/$ref" ] \
      || { fail "internal config references producer '$ref' but no such skill exists (stale registry entry — deleted/renamed?)"; probs=$((probs+1)); }
  done < <(printf '%s' "$blob" | grep -oE 'jarvis-[a-z0-9-]*-build-[a-z0-9]+' | sed -E 's/-+$//' | sort -u)
  # Label-list parity: the config's "label values" row is the authoritative legal-label list the
  # loop validates against; a producer registered in the registry table whose label is missing from
  # that row is routable on paper but illegal at validation (the docs-tier wave shipped exactly this
  # drift: registry row added, label-values row missed). For each registry row that names a producer
  # skill, every backticked label token in its first cell must appear in a "label values" row.
  local lblrow regline lbl
  lblrow=$(printf '%s' "$blob" | grep -F 'label values' | head -1)
  if [ -n "$lblrow" ]; then
    while IFS= read -r regline; do
      for lbl in $(printf '%s' "$regline" | awk -F'|' '{print $2}' | grep -oE '`[a-z0-9-]+`'); do
        printf '%s' "$lblrow" | grep -Fq "$lbl" \
          || { fail "registry label $lbl (a registered producer's route) is missing from the config's 'label values' row — stories with it fail label validation"; probs=$((probs+1)); }
      done
    done < <(printf '%s' "$blob" | grep -E '^\|[^|]*\|[^|]*jarvis-[a-z0-9-]*-build-[a-z0-9]+')
  fi
  # TIER-row vocabulary completeness: the config's "Work tier" marker row is the surface a TIER:
  # marker is validated against; the contract body defines four tiers, and the docs tier shipped
  # with this row still listing three (the drift this catches). Explicit tier list, same style as
  # check 14's explicit gate list. Self-skips when the config has no Work-tier row.
  local tierrow t
  tierrow=$(printf '%s' "$blob" | grep -E '^\| Work tier ' | head -1)
  if [ -n "$tierrow" ]; then
    for t in docs small feature product; do
      printf '%s' "$tierrow" | grep -F "\`$t\`" >/dev/null \
        || { fail "internal config 'Work tier' row is missing tier \`$t\` — a TIER: $t marker would fail validation against it"; probs=$((probs+1)); }
    done
  fi
  [ "$probs" -eq 0 ] && pass "every producer is registered; every referenced skill resolves; registry labels appear in the label-values row; the tier row is complete"
}

# =============================================================================
# CHECK 14 — Model-tier parity  (FAIL)
# The orchestrator dispatches every subagent on a model tier sized to the work
# (jarvis-agency-orchestrate/reference/model-tiers.md). A skill missing from the tier table would be
# dispatched on the session model by default (silently the strongest, most expensive); a tier row
# naming a deleted/renamed skill is dead policy. Gated both ways:
#   Forward : every jarvis-agency-* skill appears as a row in the tier table.
#   Reverse : every skill named in the tier table resolves to a real skill.
# Runs on shipped files (the table ships in the orchestrator), so it holds in CI / a fork too. Skipped
# on a single-skill run (roster parity is cross-skill) and self-skips if the table is absent.
# =============================================================================
check_model_tiers() {
  section "14. Model-tier parity (orchestrator dispatch)"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (tier parity is cross-skill)"; return; fi
  local tierfile="$SKILLS_DIR/jarvis-agency-orchestrate/reference/model-tiers.md"
  if [ ! -f "$tierfile" ]; then
    pass "skipped — no model-tiers.md on this checkout (non-agency fork)"
    return
  fi
  local probs=0 s d declared
  local IFS=$'\n'
  # declared = first cell of every table row that names a jarvis-agency-* skill
  declared=$(grep -oE '^\| jarvis-agency-[a-z0-9-]+ ' "$tierfile" | sed -E 's/^\| //; s/ $//' | sort -u)
  # Reverse: every declared skill resolves.
  for d in $declared; do
    [ -f "$SKILLS_DIR/$d/SKILL.md" ] \
      || { fail "model-tiers.md names '$d' but no such skill exists (stale tier row — deleted/renamed?)"; probs=$((probs+1)); }
  done
  # Forward: every agency skill is tiered.
  for s in $(for dd in "$SKILLS_DIR"/jarvis-agency-*/; do [ -d "$dd" ] && basename "$dd"; done); do
    printf '%s\n' "$declared" | grep -Fxq "$s" \
      || { fail "$s: not assigned a model tier in model-tiers.md — it would dispatch on the session model by default"; probs=$((probs+1)); }
  done
  # Tier-floor safety invariants — the tiering must never silently weaken a gate.
  # (a) tier-vocabulary typo guard; (b) the security red-team is always the strongest tier;
  # (c) no gate/verifier role runs on the cheap tier. Enforced for whatever rows exist, so a partial
  # repo / minimal fixture checks only the gates it declares. The gate list is explicit: adding a new
  # verifier without a floor here is a reviewed governance act — the everyday risk (retiering an
  # existing gate DOWN) is what this catches.
  local gates="jarvis-agency-critique-acceptance jarvis-agency-verify-artifact jarvis-agency-review-code jarvis-agency-run-tests jarvis-agency-redteam-security jarvis-agency-qa jarvis-agency-perf"
  local row sk ti
  while IFS= read -r row; do
    sk=$(printf '%s' "$row" | awk -F'|' '{gsub(/^[ ]+|[ ]+$/,"",$2); print $2}')
    ti=$(printf '%s' "$row" | awk -F'|' '{gsub(/^[ ]+|[ ]+$/,"",$3); print $3}')
    case "$ti" in opus|sonnet|haiku|session|n/a) ;; *) fail "$sk: unknown model tier '$ti' in model-tiers.md (expected opus/sonnet/haiku/session/n/a)"; probs=$((probs+1));; esac
    if [ "$sk" = "jarvis-agency-redteam-security" ] && [ "$ti" != "opus" ]; then
      fail "$sk: the security red-team must run on the strongest tier (opus), found '$ti' — the tiering must not weaken the security gate"; probs=$((probs+1))
    fi
    case " $gates " in *" $sk "*) if [ "$ti" = "haiku" ]; then fail "$sk is a gate/verifier and must not run on the cheap tier (haiku) — a gate must not be silently weakened"; probs=$((probs+1)); fi ;; esac
  done < <(grep -E '^\| jarvis-agency-' "$tierfile")
  [ "$probs" -eq 0 ] && pass "every agency skill is tiered; every tier row resolves; the gate floor holds"
}

# =============================================================================
# CHECK 15 — Operator-guide inventory parity  (FAIL)
# The operator guide (docs/jarvis-agency-operator-guide.md) is the founder-facing mirror of the
# agency roster and the source for its Confluence copy. Check 12 guards CLAUDE.md; the guide had no
# guard, and the docs-tier wave shipped with the guide claiming updates that never landed (a failed
# edit script). Forward-only: every jarvis-agency-* skill must be named somewhere in the guide.
# Self-skips if the guide is absent (a fork without the agency docs). Platform-wide only.
# =============================================================================
check_operator_guide() {
  section "15. Operator-guide inventory parity"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (inventory parity is cross-skill)"; return; fi
  local guide="$ROOT/docs/jarvis-agency-operator-guide.md"
  if [ ! -f "$guide" ]; then
    pass "skipped — no operator guide on this checkout (non-agency fork)"
    return
  fi
  local probs=0 s
  local IFS=$'\n'
  for s in $(for d in "$SKILLS_DIR"/jarvis-agency-*/; do [ -d "$d" ] && basename "$d"; done); do
    grep -Fq "$s" "$guide" \
      || { fail "$s: not named in docs/jarvis-agency-operator-guide.md — the founder-facing roster is stale"; probs=$((probs+1)); }
  done
  [ "$probs" -eq 0 ] && pass "every agency skill is named in the operator guide"
}

# =============================================================================
# CHECK 16 — Eval scenario-id uniqueness  (FAIL)
# Each skill's evaluations/baseline-evals.json must have unique scenario `id`s. eval-runner iterates
# by array index, so a duplicate id runs but silently breaks per-scenario traceability (which
# scenario is "…-012"?) — a real review-caught defect the structural checks didn't catch. Needs
# python3 (JSON parse); WARNs if unavailable. Per-skill on a single-skill run, else all skills.
# =============================================================================
check_eval_ids() {
  section "16. Eval scenario-id uniqueness"
  if ! command -v python3 >/dev/null 2>&1; then warn "python3 unavailable — eval-id check skipped"; return; fi
  local probs=0 s
  local IFS=$'\n'
  for s in $(skill_list); do
    local ev="$SKILLS_DIR/$s/evaluations/baseline-evals.json"; [ -f "$ev" ] || continue
    local dup; dup=$(python3 - "$ev" <<'PY'
import json,sys,collections
try: d=json.load(open(sys.argv[1]))
except Exception as e: print("PARSE_ERROR:%s"%e); sys.exit(0)
ids=[sc.get("id","") for sc in d.get("scenarios",[])]
print(",".join(sorted({i for i,c in collections.Counter(ids).items() if c>1 and i})))
PY
)
    case "$dup" in
      PARSE_ERROR:*) fail "$s: baseline-evals.json — ${dup#PARSE_ERROR:}"; probs=$((probs+1)) ;;
      "") ;;
      *) fail "$s: duplicate eval scenario id(s): $dup — breaks per-scenario traceability"; probs=$((probs+1)) ;;
    esac
    # An id must also BELONG to its skill. A tree-wide rename (the 2026-07-29 eval-domain rewrite
    # renamed `audit`->`duty-status` and silently rewrote all nine of jarvis-agency-audit's ids)
    # leaves ids that are still unique, so the uniqueness half passes while every id points at a
    # skill that does not exist. The run output then names a phantom skill.
    local stray; stray=$(python3 - "$ev" "$s" <<'PY'
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
pre=sys.argv[2]+"-"
print(",".join(sc.get("id","") for sc in d.get("scenarios",[]) if not sc.get("id","").startswith(pre))[:200])
PY
)
    if [ -n "$stray" ]; then
      fail "$s: eval scenario id(s) not prefixed '$s-': $stray — id does not name its own skill"
      probs=$((probs+1))
    fi
  done
  [ "$probs" -eq 0 ] && pass "every skill's eval scenario ids are unique and prefixed with their skill"
}

# =============================================================================
# CHECK 17 — Verifier-branch parity (code stacks)  (FAIL, needs the registry config)
# "Adding a producer is a wave" requires a per-stack branch in ALL THREE code verifiers
# (review-code, run-tests, redteam-security) — a load-bearing step the registry documents but that
# nothing enforced, so a producer could land routable-but-unverified-against-its-own-stack-rules
# (its PR reviewed/tested/attacked as if it were the house baseline). This gates it: every
# non-baseline code type label must appear (as a `label` token) in each of the three verifier
# SKILL.md bodies. Named-anywhere, like check 13 — a brittle branch-header parse is avoided; a label
# that appears NOWHERE in a verifier is the drift this catches.
#   Baseline stacks (backend/api/frontend/data) are covered by the verifiers' DEFAULT checks (a
#   Kotlin/JVM service, a REST API, a React screen, a SQL migration are the house baseline) and are
#   exempt; docs has its own single-gate tier; artifact labels (research/design/architecture) take
#   the artifact path, not the code trio.
# The label set is DERIVED from the config's "label values" row, so a NEW producer's label is
# required in the verifiers automatically. Runs wherever the committed slice
# (config/agency-registry.md, VIBE-016) or the gitignored internal config exists — CI included, not
# maintainer-only anymore. Self-skips only when NEITHER source exists (a fork with no agency
# workbench at all), like check 13. Platform-wide only.
# =============================================================================
check_verifier_branches() {
  section "17. Verifier-branch parity (code stacks)"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (verifier parity is cross-skill)"; return; fi
  local cfgs; cfgs=$(find "$SKILLS_DIR" -type f -path '*/reference/_internal/*.md' 2>/dev/null)
  [ -f "$ROOT/config/agency-registry.md" ] && cfgs="$cfgs"$'\n'"$ROOT/config/agency-registry.md"
  cfgs=$(printf '%s\n' "$cfgs" | grep -v '^$')
  if [ -z "$cfgs" ]; then pass "skipped — no registry config on this checkout (fresh / fork)"; return; fi
  local verifiers="jarvis-agency-review-code jarvis-agency-run-tests jarvis-agency-redteam-security"
  local v present=0
  for v in $verifiers; do [ -f "$SKILLS_DIR/$v/SKILL.md" ] && present=$((present+1)); done
  if [ "$present" -eq 0 ]; then pass "skipped — none of the three code verifiers on this checkout"; return; fi
  local lblrow; lblrow=$(cat $cfgs 2>/dev/null | grep -F 'label values' | head -1)
  if [ -z "$lblrow" ]; then pass "skipped — config has no 'label values' row to derive code labels from"; return; fi
  # Exempt: baseline code stacks + docs (single-gate tier) + artifact labels (not the code trio).
  local exempt=" backend api frontend data docs research design architecture "
  local probs=0 lbl bare
  # NB: default IFS (not newline-only) — the label tokens are space-free, and the inner
  # `for v in $verifiers` needs space-splitting; forcing IFS=$'\n' made the inner loop treat the
  # whole verifier list as one path, silently checking nothing (a vacuous pass caught in review).
  for lbl in $(printf '%s' "$lblrow" | grep -oE '`[a-z0-9-]+`' | sort -u); do
    bare=${lbl//\`/}
    case "$exempt" in *" $bare "*) continue ;; esac
    for v in $verifiers; do
      [ -f "$SKILLS_DIR/$v/SKILL.md" ] || continue
      # Grep the BODY only (strip the frontmatter, incl. the changelog): a changelog mention of a
      # stack must not keep a DELETED body branch green — the exact body-vs-changelog drift a review
      # caught (the eBPF clause had landed in a changelog entry, not the operative body).
      # NOT `grep -q`: under `set -o pipefail`, -q's early exit closes the pipe mid-write and a
      # SUCCESSFUL match becomes a spurious pipeline failure (sed EPIPE) — a race that flaked CI
      # red on an unchanged file (2026-07-13). Full-read + >/dev/null is race-free.
      sed '1,/^---$/d' "$SKILLS_DIR/$v/SKILL.md" | grep -F "$lbl" >/dev/null \
        || { fail "code label $lbl has no branch in the body of $v — a producer for it is routable but unverified against its own stack rules (add its verifier branch, or exempt it as baseline)"; probs=$((probs+1)); }
    done
    # The `detection` label carries a mandatory FOURTH per-story RC gate (jarvis-agency-verify-detection);
    # require the label in its body too, so its dedicated efficacy gate cannot silently stop covering it.
    if [ "$bare" = "detection" ] && [ -f "$SKILLS_DIR/jarvis-agency-verify-detection/SKILL.md" ]; then
      sed '1,/^---$/d' "$SKILLS_DIR/jarvis-agency-verify-detection/SKILL.md" | grep -F "$lbl" >/dev/null \
        || { fail "code label $lbl is missing from jarvis-agency-verify-detection's body — its dedicated fourth RC gate would not cover it"; probs=$((probs+1)); }
    fi
  done
  [ "$probs" -eq 0 ] && pass "every non-baseline code label has a branch in all three code verifiers"
}

# =============================================================================
# CHECK 18 — Version frontmatter is semver  (FAIL)
# build-dist names the zip and the manifest entry from `version:`; an empty/malformed value
# silently produced `<skill>-v-public.zip` with a garbage manifest version, and check 1's
# expected-path computation matched it (VIBE-003). Validate at the source.
# =============================================================================
check_version_format() {
  section "18. Version frontmatter is semver"
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local sm="$SKILLS_DIR/$s/SKILL.md"; [ -f "$sm" ] || continue
    local v; v=$(version_of "$sm")
    printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
      || { fail "$s: version '$v' is not MAJOR.MINOR.PATCH"; probs=$((probs+1)); }
  done
  [ "$probs" -eq 0 ] && pass "every skill version is MAJOR.MINOR.PATCH"
}

# =============================================================================
# CHECK 19 — Scaffold TODO placeholders  (WARN; FAILs in CI via --strict)
# new-skill.sh scaffolds a TODO description that passes every structural check, so an
# unfilled stub could be built and uploaded (VIBE-020). WARN keeps local scaffolding
# friction-free; --strict (CI) blocks the merge.
# =============================================================================
check_todo_placeholders() {
  section "19. Scaffold TODO placeholders"
  local probs=0
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(skill_list); do
    local sm="$SKILLS_DIR/$s/SKILL.md"; [ -f "$sm" ] || continue
    case "$(desc_of "$sm")" in
      TODO*) warn "$s: description still starts with the scaffold's TODO — fill it in before shipping"; probs=$((probs+1)) ;;
    esac
  done
  [ "$probs" -eq 0 ] && pass "no skill description starts with TODO"
}

# =============================================================================
# CHECK 20 — Producer skeleton parity  (FAIL)
# The 14 code producers share one structural skeleton; build-backend (the original template)
# drifted from its own descendants and lost the other-stack exclusion rule (VIBE-010).
# Skill bodies ARE the dispatched subagent's behavior spec — a producer missing a skeleton
# section is running on a different contract. build-docs is exempt (documented single-gate
# divergence, contract 0.4.22). Platform-wide only.
# =============================================================================
check_producer_skeleton() {
  section "20. Producer skeleton parity"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (skeleton parity is cross-producer)"; return; fi
  local required_headings='## What it never does
## What it receives
## The build process
## Stack conventions
## Restricted write
## Files in this skill'
  local probs=0 s h
  local IFS=$'\n'   # newline-split: a skill name is never split on internal spaces
  for s in $(for d in "$SKILLS_DIR"/*-build-*/; do [ -d "$d" ] && basename "$d"; done); do
    case "$s" in *-build-docs) continue ;; esac   # docs tier: documented divergence
    local sm="$SKILLS_DIR/$s/SKILL.md"; [ -f "$sm" ] || continue
    for h in $required_headings; do
      grep -Fxq "$h" "$sm" \
        || { fail "$s: missing producer-skeleton section '$h' — the producer runs on a divergent contract"; probs=$((probs+1)); }
    done
  done
  [ "$probs" -eq 0 ] && pass "every code producer carries the shared skeleton (docs-tier exempt)"
}

# =============================================================================
# Shared scan surface + exemptions for the prose-contradiction checks (22, 23)
# -----------------------------------------------------------------------------
# Two exemptions apply to BOTH, and both are deliberate:
#   * SKILL.md frontmatter (the changelog) is never scanned — a changelog is the immutable record
#     of what the rule USED to say, and rewriting history to satisfy a lint is the drift this
#     platform refuses.
#   * A file carrying the recognised historical banner in its first 30 lines is skipped whole. The
#     banner marks a point-in-time record (a dated review, a superseded model) whose old wording is
#     evidence, not instruction. Two accepted forms: the prose convention already used in docs/
#     ("Retained as a historical record") and an explicit HTML marker for files with no prose banner.
# =============================================================================
HISTORICAL_BANNER_RE='Retained as a historical record|lint-exempt: historical-record'
has_historical_banner() { head -30 "$1" 2>/dev/null | grep -Ei "$HISTORICAL_BANNER_RE" >/dev/null; }

# The text an agent would ACT on: SKILL.md body only; whole file otherwise.
operative_text() { case "$1" in */SKILL.md) skill_body_of "$1" ;; *) cat "$1" ;; esac; }
# Line-number offset so a body-relative hit reports the REAL file line.
operative_offset() {
  case "$1" in
    */SKILL.md) local n; n=$(frontmatter_end_line "$1"); echo "${n:-0}" ;;
    *) echo 0 ;;
  esac
}

# The operative tree — every surface an agent reads and acts on. Descends into reference/**
# (including _internal/, where the operative registries live — the old glob stopped at reference/*).
operative_files() {
  local s
  for s in $(skill_list); do
    [ -d "$SKILLS_DIR/$s" ] || continue
    [ -f "$SKILLS_DIR/$s/SKILL.md" ] && printf '%s\n' "$SKILLS_DIR/$s/SKILL.md"
    find "$SKILLS_DIR/$s/reference" -type f -name '*.md' 2>/dev/null
  done
  [ -n "$ONLY_SKILL" ] && return 0
  [ -f "$ROOT/CLAUDE.md" ] && printf '%s\n' "$ROOT/CLAUDE.md"
  [ -f "$ROOT/README.md" ] && printf '%s\n' "$ROOT/README.md"
  find "$ROOT/config" -maxdepth 1 -type f -name '*.md' 2>/dev/null | grep -v 'stated-defaults\.md$'
  find "$ROOT" -type d -name .git -prune -o -path '*/_governance/*.md' -print 2>/dev/null
}

# =============================================================================
# CHECK 22 — Jira-as-source-of-truth-for-decisions contradiction  (FAIL)
# The vault-governance law (law_version 1.1.0) makes the VAULT the source of truth for INTENT
# and Jira the ledger for EXECUTION. A 2026-07-20 audit found the agency workbench asserting the
# opposite in nine places, headed by the foundation contract's invariant #1 — a repo-wide premise
# every agency skill inherits. That was fixed by edit; this check stops it drifting back.
#
# The test is NARROW in the dimension that matters. "Jira is the source of truth" is only wrong
# when it is UNQUALIFIED or scoped to decisions/intent; the same phrase scoped to EXECUTION state
# is the corrected wording and must pass. So a hit is reported only when a source-of-truth claim
# about Jira is NOT qualified by an execution-scoping word on the same or the following line.
#
# It is WIDE in the dimensions the first version got wrong (2026-07-21 audit: 8 of the 12 surviving
# instances were out of its reach):
#   * surface — the old glob was `skills/jarvis-agency-*/{SKILL.md,reference/*.md}`, which does not
#     descend into reference/_internal/ (where the operative registry lives) and never saw docs/,
#     CLAUDE.md, README.md or config/. It now scans the whole operative tree plus all of docs/.
#   * wording — requiring the literal "source of truth" missed every paraphrase: "the issue HOLDS
#     THE TRUTH", "state LIVES IN Jira", "all DURABLE STATE in Jira", "you put INTENT IN Jira".
#     Those forms are in the pattern set now.
# Two further exemptions beyond the shared ones (changelog, historical banner):
#   * A claim inside quotation marks is a QUOTATION, not an assertion — a plan or review doc citing
#     the pre-split wording is reporting it, which is exactly what those documents are for.
#   * A line that correctly attributes source-of-truth to the VAULT is not a Jira claim, even
#     though "jira" appears earlier in the sentence (CLAUDE.md's governance block reads that way).
# =============================================================================
SOT_CLAIM_RE='jira[^.]{0,40}(is|as|remains|stays|holds)[^.]{0,30}(the )?(single |sole )?(source of truth|truth)|issue (is|as|stays|remains|holds)[^.]{0,30}(the )?(single |sole )?(source of truth|truth)|(all )?(durable )?state lives (in|on) (jira|the issue)|all durable state[^.]{0,25}(in|on) (jira|the issue)|intent (in|lives in|belongs in|goes in) jira'
SOT_QUALIFIER_RE='execution|status|worklog|ledger|not the source of truth|never the source of truth|not a new source of truth|vault (is|as|remains|stays|holds)[^.]{0,25}(the )?(single |sole )?(source of truth|truth)'

check_sot_contradiction() {
  section "22. Jira-as-source-of-truth-for-decisions contradiction"
  local probs=0 f
  local IFS=$'\n'
  for f in $( { operative_files; [ -z "$ONLY_SKILL" ] && find "$ROOT/docs" -type f -name '*.md' 2>/dev/null; } | sort -u); do
    [ -f "$f" ] || continue
    has_historical_banner "$f" && continue
    local off; off=$(operative_offset "$f")
    local hit
    # Strip quoted spans (a citation is not an assertion), then window each line with the next so a
    # qualifier on the FOLLOWING line still counts, then drop a hit on the line immediately after
    # another: one claim spanning two lines matches two windows and is ONE violation.
    hit=$(operative_text "$f" \
      | sed -e 's/"[^"]*"//g' -e 's/“[^”]*”/ /g' \
      | awk '
        { prev=cur; cur=$0; if (NR>1) print NR-1 "\t" prev " " cur }
        END { if (NR) print NR "\t" cur }
      ' | grep -iE "$SOT_CLAIM_RE" \
        | grep -viE "$SOT_QUALIFIER_RE" \
        | awk -F'\t' 'NR==1 || $1 > last+1 { print } { last=$1 }' || true)
    if [ -n "$hit" ]; then
      local rel="${f#"$ROOT"/}"
      local line n
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        n=${line%%$'\t'*}
        fail "$rel:$((n + off)): unqualified Jira-as-source-of-truth claim — scope it to EXECUTION state (the vault owns intent; law_version 1.1.0), or mark a point-in-time file 'Retained as a historical record'"
        probs=$((probs+1))
      done <<< "$hit"
    fi
  done
  [ "$probs" -eq 0 ] && pass "no operative file claims Jira is the source of truth for decisions/intent"
}

# =============================================================================
# CHECK 23 — Stated-defaults drift  (FAIL)
# A cross-cutting default gets changed WHERE IT IS STATED and not WHERE IT IS CONSUMED, and no gate
# can see the difference — the single largest family in the 2026-07-21 audit (the `ga-granularity`
# default, PRFAQ ownership, and the actionable `review:` state set were each corrected in one place
# while an older contradicting sentence stayed live elsewhere and kept being obeyed).
#
# config/stated-defaults.md is the committed registry: per default, the canonical value plus the
# literal strings that would contradict it. This check greps the operative tree for each literal.
# The registry file is the single place a maintainer registers a new default — its own header says
# so, and this check is what makes that statement load-bearing instead of aspirational.
#
# Literals are matched with grep -F -i (verbatim, case-insensitive) — never as regexes, so a
# maintainer registering a literal cannot accidentally write a pattern that matches half the repo.
# Same exemptions as CHECK 22's shared pair (changelog block, historical banner).
# =============================================================================
STATED_DEFAULTS_REL="config/stated-defaults.md"

# Emit "id<TAB>canonical<TAB>literal" per registered contradicting literal.
stated_defaults_rows() {
  awk '
    /^### /   { id=$0; sub(/^### /,"",id); sub(/ .*/,"",id)
                val=$0; sub(/^.*canonical: /,"",val); next }
    /^```contradicts/ { inb=1; next }
    inb && /^```/     { inb=0; next }
    inb && NF         { print id "\t" val "\t" $0 }
  ' "$1"
}

check_stated_defaults() {
  section "23. Stated-defaults drift (config/stated-defaults.md)"
  local reg="$ROOT/$STATED_DEFAULTS_REL"
  if [ ! -f "$reg" ]; then
    warn "no $STATED_DEFAULTS_REL — no cross-cutting default is registered, so nothing is guarded"
    return
  fi
  local rows; rows=$(stated_defaults_rows "$reg")
  if [ -z "$rows" ]; then
    # Loud, not silent: a registry that parses to nothing is a shape change, not an empty ruleset.
    fail "$STATED_DEFAULTS_REL parses to ZERO registered literals — the registry's shape changed and this check is guarding nothing"
    return
  fi
  local files; files=$(operative_files | sort -u)
  local probs=0 row id val lit f
  local IFS=$'\n'
  for f in $files; do
    [ -f "$f" ] || continue
    has_historical_banner "$f" && continue
    local off text rel
    off=$(operative_offset "$f"); rel="${f#"$ROOT"/}"
    text=$(operative_text "$f")
    for row in $rows; do
      id=${row%%$'\t'*}
      val=${row#*$'\t'}; val=${val%%$'\t'*}
      lit=${row##*$'\t'}
      local hits n
      hits=$(printf '%s\n' "$text" | grep -n -F -i -- "$lit" || true)
      [ -n "$hits" ] || continue
      local h
      while IFS= read -r h; do
        [ -n "$h" ] || continue
        n=${h%%:*}
        fail "$rel:$((n + off)): contradicts registered default '$id' (canonical: $val) — found the literal \"$lit\""
        probs=$((probs+1))
      done <<< "$hits"
    done
  done
  [ "$probs" -eq 0 ] && pass "no registered stated-default is contradicted in the operative tree ($(printf '%s\n' "$rows" | wc -l | tr -d ' ') literals across $(printf '%s\n' "$rows" | cut -f1 | sort -u | wc -l | tr -d ' ') defaults)"
}

# =============================================================================
# CHECK 24 — Internal-config lane-name uniqueness  (FAIL)
# The agency's lane table (the `| Artifact | Location | Id / heading |` table in a workbench's
# internal config) is the authoritative list of Jira comment lanes and what each one MEANS. A wave
# once APPENDED a second `PM Acceptance` row with the opposite rule instead of replacing the first,
# leaving two live rows contradicting each other — whichever an agent read first won. Duplicate lane
# names are always a defect: a lane name is a key.
# Self-skips cleanly when no internal config is present (a fork, or a clone without the gitignored
# file), exactly like CHECK 13. WARNs — rather than passing silently — if a config exists but holds
# no lane table at all, because that is a shape change, not an empty ruleset.
# =============================================================================
check_lane_uniqueness() {
  section "24. Internal-config lane-name uniqueness"
  local cfgs; cfgs=$(find "$SKILLS_DIR" -type f -path '*/reference/_internal/*.md' 2>/dev/null)
  if [ -z "$cfgs" ]; then
    pass "skipped — no internal config on this checkout (fork / gitignored)"
    return
  fi
  local probs=0 tables=0 f
  local IFS=$'\n'
  for f in $cfgs; do
    local names dups
    names=$(awk '
      /^\| *Artifact *\| *Location *\|/ { intab=1; next }
      intab && /^\|[-: |]+\|/           { next }
      intab && /^\|/ { name=$0; sub(/^\| */,"",name); sub(/ *\|.*/,"",name)
                       gsub(/^[ \t]+|[ \t]+$/,"",name); if (name != "") print name; next }
      intab { intab=0 }
    ' "$f")
    [ -n "$names" ] || continue
    tables=$((tables+1))
    dups=$(printf '%s\n' "$names" | sort | uniq -d)
    if [ -n "$dups" ]; then
      local d
      while IFS= read -r d; do
        [ -n "$d" ] || continue
        fail "${f#"$ROOT"/}: lane '$d' is declared more than once — a lane name is a key; two rows with the same name means whichever an agent reads first wins"
        probs=$((probs+1))
      done <<< "$dups"
    fi
  done
  if [ "$tables" -eq 0 ]; then
    warn "internal config present but no '| Artifact | Location |' lane table found — the table shape changed and this check is guarding nothing"
    return
  fi
  [ "$probs" -eq 0 ] && pass "every lane name in the internal config lane table(s) is unique ($tables table(s))"
}

# =============================================================================
# CHECK 25 — Eval scenario self-containment  (FAIL)
# docs/platform/evaluation-strategy.md: "If the scenario reviews an artifact, it MUST ship a
# `fixture` — a self-contained query is the bar, not a `[PASTE …]` stub." Nothing enforced it, and a
# scenario shipped whose query told the model to review content that was never supplied; the runner
# happily executed it and scored the model's improvisation.
# The rule as written is CONDITIONAL, so the check is too: a placeholder token in the query is fine
# when the scenario ships a fixture (the documented pattern — 62 scenarios do exactly that); it is a
# FAIL when there is no fixture, and equally a FAIL when the `fixture` path does not resolve on disk
# (a pointer to nothing is a stub wearing a fixture's name).
# Needs python3 (JSON parse); WARNs if unavailable, like CHECK 16.
# =============================================================================
check_eval_self_containment() {
  section "25. Eval scenario self-containment (fixtures, not stubs)"
  if ! command -v python3 >/dev/null 2>&1; then warn "python3 unavailable — eval self-containment check skipped"; return; fi
  local probs=0 s
  local IFS=$'\n'
  for s in $(skill_list); do
    local ev="$SKILLS_DIR/$s/evaluations/baseline-evals.json"; [ -f "$ev" ] || continue
    local out; out=$(python3 - "$ev" <<'PY'
import json, os, re, sys
p = sys.argv[1]; base = os.path.dirname(p)
try:
    d = json.load(open(p))
except Exception as e:
    print("PARSE_ERROR\t%s" % str(e).replace("\n", " ")[:140]); sys.exit(0)
PLACEHOLDER = re.compile(r'\[PASTE|\[INSERT|\[ATTACH|\[TODO|<INSERT|<PASTE|\{\{|\[\.\.\.\]|\[…\]', re.I)
for sc in d.get("scenarios", []):
    sid = sc.get("id", "<no id>")
    q = sc.get("query", "") or ""
    fx = (sc.get("fixture") or "").strip()
    m = PLACEHOLDER.search(q)
    if fx and not os.path.exists(os.path.join(base, fx)):
        print("MISSING_FIXTURE\t%s\t%s" % (sid, fx))
    elif m and not fx:
        print("STUB\t%s\t%s" % (sid, m.group(0)))
PY
)
    [ -n "$out" ] || continue
    local line kind
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      kind=${line%%$'\t'*}
      case "$kind" in
        PARSE_ERROR) fail "$s: baseline-evals.json — ${line#*$'\t'}"; probs=$((probs+1)) ;;
        MISSING_FIXTURE)
          fail "$s: scenario $(printf '%s' "$line" | cut -f2) declares fixture '$(printf '%s' "$line" | cut -f3)' but no such file — a pointer to nothing is a stub"
          probs=$((probs+1)) ;;
        STUB)
          fail "$s: scenario $(printf '%s' "$line" | cut -f2) has an unresolved placeholder '$(printf '%s' "$line" | cut -f3)' in its query and ships no fixture — the runner would score the model's improvisation"
          probs=$((probs+1)) ;;
      esac
    done <<< "$out"
  done
  [ "$probs" -eq 0 ] && pass "every eval scenario is self-contained (placeholder queries ship a resolving fixture)"
}

# =============================================================================
# CHECK 26 — Gate-name -> reference parity  (FAIL)
# The orchestrator's SKILL.md lists the gates it enforces as a bulleted body list and points readers
# at reference/enforcement-gates.md for "the mechanism and honesty of each gate". Three gates were
# added to the body list and never to the reference, so the operative list and the file that
# explains it diverged silently — the body says the gate exists, the reference cannot tell an agent
# how to run it.
# HONEST LIMIT, stated plainly: this compares CONTENT WORDS, not exact names. The reference
# deliberately re-words a gate's title ("`STATUS-ACTOR:` on every status move" vs "Every status move
# records `STATUS-ACTOR:`"), so an exact-string test would red-gate correct files. A gate whose
# distinctive words are largely absent from the reference is the drift this catches; a gate that IS
# described but whose description is stale or wrong is NOT catchable here and stays review-caught.
# Needs python3; WARNs if unavailable. Self-skips when either file is absent.
# =============================================================================
GATE_BODY_REL="skills/jarvis-agency-orchestrate/SKILL.md"
GATE_REF_REL="skills/jarvis-agency-orchestrate/reference/enforcement-gates.md"
GATE_SECTION="## The gates the orchestrator enforces"

check_gate_reference_parity() {
  section "26. Gate-name -> reference parity (orchestrator)"
  if [ -n "$ONLY_SKILL" ] && [ "$ONLY_SKILL" != "jarvis-agency-orchestrate" ]; then
    pass "skipped on single-skill run of another skill"; return
  fi
  local body="$ROOT/$GATE_BODY_REL" ref="$ROOT/$GATE_REF_REL"
  if [ ! -f "$body" ] || [ ! -f "$ref" ]; then
    pass "skipped — no orchestrator gate list on this checkout (non-agency fork)"; return
  fi
  if ! command -v python3 >/dev/null 2>&1; then warn "python3 unavailable — gate-reference parity skipped"; return; fi
  local out; out=$(python3 - "$body" "$ref" "$GATE_SECTION" <<'PY'
import re, sys
body = open(sys.argv[1], encoding="utf-8").read()
ref  = open(sys.argv[2], encoding="utf-8").read()
head = sys.argv[3]
if head not in body:
    print("NO_SECTION"); sys.exit(0)
sec = body.split(head, 1)[1].split("\n## ", 1)[0]
STOP = {"the","a","an","on","in","of","is","it","and","or","to","by","for","not","at","be","its","no","every","all"}
def toks(s):
    return [t for t in re.sub(r"[^a-z0-9]+", " ", s.lower()).split() if len(t) > 2 and t not in STOP]
rt = set(toks(ref))
names = [m.group(1) for m in re.finditer(r"^- \*\*(.+?)\*\*", sec, re.M)]
if not names:
    print("NO_GATES"); sys.exit(0)
print("COUNT\t%d" % len(names))
for n in names:
    t = toks(n)
    if not t:
        continue
    miss = [x for x in t if x not in rt]
    if (1 - len(miss) / len(t)) < 0.5:
        print("UNDOCUMENTED\t%s\t%s" % (n, ",".join(miss)))
PY
)
  local probs=0 line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      NO_SECTION) fail "$GATE_BODY_REL: section '$GATE_SECTION' not found — the gate list moved or was renamed and this check is guarding nothing"; probs=$((probs+1)) ;;
      NO_GATES)   fail "$GATE_BODY_REL: the gate section parses to ZERO '- **name**' bullets — the list shape changed and this check is guarding nothing"; probs=$((probs+1)) ;;
      UNDOCUMENTED*)
        fail "gate '$(printf '%s' "$line" | cut -f2)' is listed in $GATE_BODY_REL but is absent from $GATE_REF_REL (missing words: $(printf '%s' "$line" | cut -f3)) — the body claims the gate, the reference cannot tell an agent how to run it"
        probs=$((probs+1)) ;;
    esac
  done <<< "$out"
  local n; n=$(printf '%s\n' "$out" | awk -F'\t' '$1=="COUNT"{print $2}')
  [ "$probs" -eq 0 ] && pass "all ${n:-0} gates listed in the orchestrator body are described in enforcement-gates.md"
}

# =============================================================================
# CHECK 27 — Governance-slot self-consistency  (FAIL)
# docs/_governance/repo-config.md carries the per-repo slots in frontmatter; its own prose (and
# run-counter.md's) describes what those slots MEAN for this repo. A find/replace set
# a real `jira_project_key` in the frontmatter and left both files' prose asserting the repo was
# UNSET — "Jira writes are blocked", "Inert in this repo … both reconciliation triggers are
# skipped". An agent reading the prose skips the law's every-10-runs drift sweep on a repo that
# HAS a Jira project; an agent reading the frontmatter does not. Both directions are gated:
#   key SET   + prose says inert/blocked/UNSET      -> FAIL (the observed defect)
#   key UNSET + prose says the triggers are live    -> FAIL (the converse)
# Self-skips when there is no _governance/ directory (a fork without the vault). The law mirror
# itself (SOURCE-OF-TRUTH.md) is NOT scanned: it legitimately describes both branches, and its
# fidelity is CHECK 21's job.
# =============================================================================
check_governance_slots() {
  section "27. Governance-slot self-consistency"
  local cfg; cfg=$(find "$ROOT" -type d -name .git -prune -o -path '*/_governance/repo-config.md' -print 2>/dev/null | head -1)
  if [ -z "$cfg" ]; then
    pass "skipped — no _governance/repo-config.md in this repo (fork without the vault)"; return
  fi
  local gov_dir; gov_dir=$(dirname "$cfg")
  local key; key=$(awk '/^---$/{c++; next} c==1 && /^jira_project_key:/{sub(/^jira_project_key: */,""); gsub(/[ \r]/,""); print; exit}' "$cfg")
  local inert_re='jira writes are blocked|inert in this repo|reconciliation triggers? (are|is) skipped|both reconciliation triggers are skipped|there is no execution ledger'
  local live_re='both reconciliation triggers (are|run) live|the two reconciliation triggers run|jira writes are (enabled|live)'
  local probs=0 f want_re msg
  if [ -z "$key" ] || [ "$key" = "UNSET" ]; then
    want_re="$live_re"; msg="jira_project_key is UNSET but the prose claims the Jira half is live"
  else
    want_re="$inert_re"; msg="jira_project_key is '$key' (SET) but the prose claims this repo is UNSET/inert — an agent obeying it skips the law's reconciliation triggers on a repo that HAS a Jira project"
  fi
  local IFS=$'\n'
  for f in $(find "$gov_dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | grep -v 'SOURCE-OF-TRUTH\.md$' | sort); do
    local hits h
    hits=$(grep -niE "$want_re" "$f" || true)
    [ -n "$hits" ] || continue
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      fail "${f#"$ROOT"/}:${h%%:*}: $msg"
      probs=$((probs+1))
    done <<< "$hits"
  done
  [ "$probs" -eq 0 ] && pass "governance slot (jira_project_key: ${key:-UNSET}) agrees with the prose in $(basename "$gov_dir")/"
}

# =============================================================================
# CHECK 28 — Absolute-refusal clause without a permitting case  (WARN)
# On 2026-07-21 ONE absolute clause produced SEVEN denial-of-service defects across seven skills.
# "An unresolvable pointer is a stop" was read as "refuse whenever you do not have a pointer", so
# skills refused to work when the artifact's content was present INLINE, when NO brief was
# referenced at all, and when an environment existed but no marker did — the front door
# (jarvis-agency-intake) refused to interrogate a founder's raw intent. All seven passed
# `--strict` (27 checks) and 209 tests: nothing structural can see a rule that is merely too
# broad. CLAUDE.md best practice #8 states the rule this check proxies for: a constraint states
# its PERMITTED cases, not only its forbidden one.
#
# The test: an absolute-refusal phrasing in a skill BODY with no permitting clause within a few
# lines either side. The permitting vocabulary is the wording the seven fixes actually used
# ("three cases", "nothing to dereference", "use it and proceed", "is not the same as", plus the
# ordinary permitting connectives unless/otherwise/except when/only when).
#
# HONEST LIMIT — this is a heuristic over prose and cannot know intent. It is WARN, not FAIL:
#   * it cannot tell an over-broad absolute from a correct unconditional one. Genuine
#     unconditional prohibitions exist and are right (the GA ceiling, pending-intent-inert, the
#     never-provision security rules) — those are quiet here only because they are not phrased in
#     the refusal vocabulary below, not because the check understood them.
#   * a prohibition whose SCOPE is carried inside the prohibition itself ("do not proceed past a
#     still-red item" — green items proceed) reads as unpermitted to a window heuristic. Rather
#     than widen the permit vocabulary until the check stops catching the 2026-07-21 wording,
#     those are listed explicitly in ABSOLUTE_EXCEPTIONS below, each with its reason.
# Frontmatter is never scanned: a changelog legitimately records what an absolute USED to say.
# =============================================================================
ABSOLUTE_REFUSAL_RE='is a stop|is a hard stop|do not proceed|does not proceed|never proceed|refuse to |must not act|stop and queue|record the block and stop|surface it and stop'
ABSOLUTE_PERMIT_RE='but only when|only when|only after|only the founder|only the human|only the operator|and proceed|then proceed|proceed as|proceed normally|proceed when|proceed with|does not stop|is not a stop|not a stop either|still runs|still applies|nothing to dereference|is not the same as|unless|otherwise|except when|three cases|take the case you are actually in|content is present|present inline|supplied inline'
ABSOLUTE_WINDOW=4
# skill<TAB>lowercased substring of the offending line<TAB>reason. Narrow by construction: both
# the skill AND the phrase must match, so the exemption cannot silently cover a later edit.
ABSOLUTE_EXCEPTIONS=$(cat <<'EXC'
jarvis-agency-onboard	do not proceed past a still-red item	the prohibition carries its own scope (a *still-red* item; a green one proceeds) — scope-inside-the-prohibition is invisible to a window heuristic
EXC
)

absolute_is_excepted() { # <skill> <line-text>
  local skill="$1" line; line=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  local e es ep
  local IFS=$'\n'
  for e in $ABSOLUTE_EXCEPTIONS; do
    [ -n "$e" ] || continue
    es=${e%%$'\t'*}; ep=${e#*$'\t'}; ep=${ep%%$'\t'*}
    [ "$es" = "$skill" ] || continue
    case "$line" in *"$ep"*) return 0 ;; esac
  done
  return 1
}

check_absolute_refusals() {
  section "28. Absolute-refusal clause without a permitting case"
  local probs=0 s f
  for s in $(skill_list); do
    f="$SKILLS_DIR/$s/SKILL.md"
    [ -f "$f" ] || continue
    local off; off=$(operative_offset "$f")
    local hits
    hits=$(skill_body_of "$f" | awk -v ABS="$ABSOLUTE_REFUSAL_RE" -v PERM="$ABSOLUTE_PERMIT_RE" -v W="$ABSOLUTE_WINDOW" '
      { L[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          if (tolower(L[i]) !~ ABS) continue
          ok = 0
          for (j = i - W; j <= i + W; j++) {
            if (j < 1 || j > NR) continue
            t = tolower(L[j]); gsub(ABS, " ", t)     # the prohibition itself never permits
            if (t ~ PERM) { ok = 1; break }
          }
          if (!ok) print i "\t" L[i]
        }
      }' || true)
    [ -n "$hits" ] || continue
    local h n text
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      n=${h%%$'\t'*}; text=${h#*$'\t'}
      absolute_is_excepted "$s" "$text" && continue
      warn "skills/$s/SKILL.md:$((n + off)): absolute refusal with no permitting case nearby — \"$(printf '%s' "$text" | sed -E 's/^[[:space:]]+//' | cut -c1-90)\" — state the cases where the skill STILL acts (CLAUDE.md best practice #8)"
      probs=$((probs+1))
    done <<< "$hits"
  done
  [ "$probs" -eq 0 ] && pass "every absolute-refusal clause in a skill body names a permitting case nearby"
}

# =============================================================================
# CHECK 29 — Eval receipt for behaviour-level version bumps  (NOTE; never gates)
# CLAUDE.md says to run ./eval-runner.sh when behaviour changed, and nothing enforced it — a
# memory-enforced invariant, the exact shape this platform condemns everywhere else. It matters:
# in the 2026-07-21 sweep the BEHAVIOURAL gate found 7 of 7 real defects and the structural gates
# found 0 of 7.
#
# The behavioural gate cannot run in CI (live model calls, real money), so the enforceable proxy
# is a RECEIPT: config/eval-receipts.md records, per skill, the version that was last actually
# evaluated. eval-runner.sh writes the row itself on a full single-skill run. A MINOR or MAJOR
# bump past the recorded version means behaviour changed since anything replayed it.
# A PATCH-only difference is fine by construction (patch = clarification, per CLAUDE.md semver).
#
# HONEST LIMIT — a receipt proves a run was RECORDED at that version. It does not prove the run
# was good, that its scenarios were the right ones, or that the skill is correct; the `Failed`
# column is recorded precisely so a green receipt cannot be mistaken for a green skill.
# Self-skips when config/eval-receipts.md is absent (a fork), like CHECK 13.
# =============================================================================
EVAL_RECEIPTS_REL="config/eval-receipts.md"

# Emit "skill<TAB>version" per receipt row (header and separator rows dropped by shape).
eval_receipt_rows() {
  awk -F'|' '
    /^[[:space:]]*\|/ {
      s = $2; v = $3
      gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (s == "" || s ~ /^-+$/ || tolower(s) == "skill") next
      if (v !~ /^[0-9]+\.[0-9]+\.[0-9]+$/) next
      print s "\t" v
    }' "$1"
}

# 0 when <receipt> is behind <current> at MAJOR.MINOR. Numeric per component (0.10.0 > 0.9.0).
mm_behind() {
  local rM rm cM cm
  IFS=. read -r rM rm _ <<< "$1"
  IFS=. read -r cM cm _ <<< "$2"
  rM=$((10#${rM:-0})); rm=$((10#${rm:-0})); cM=$((10#${cM:-0})); cm=$((10#${cm:-0}))
  [ "$rM" -lt "$cM" ] && return 0
  [ "$rM" -eq "$cM" ] && [ "$rm" -lt "$cm" ] && return 0
  return 1
}

check_eval_receipts() {
  section "29. Eval receipt for behaviour-level version bumps"
  local file="$ROOT/$EVAL_RECEIPTS_REL"
  if [ ! -f "$file" ]; then
    pass "skipped — no $EVAL_RECEIPTS_REL in this repo (a fork with no recorded eval runs)"; return
  fi
  local rows; rows=$(eval_receipt_rows "$file")
  if [ -z "$rows" ]; then
    # Loud, not silent: a receipts file that parses to nothing is a shape change, not "no runs".
    fail "$EVAL_RECEIPTS_REL parses to ZERO receipt rows — the table's shape changed and this check is guarding nothing"
    return
  fi
  local probs=0 s cur rv never="" stale=""
  for s in $(skill_list); do
    [ -f "$SKILLS_DIR/$s/SKILL.md" ] || continue
    # A skill with no eval file cannot have a receipt; nothing to say about it here.
    [ -f "$SKILLS_DIR/$s/evaluations/baseline-evals.json" ] || continue
    cur=$(version_of "$SKILLS_DIR/$s/SKILL.md")
    case "$cur" in [0-9]*.[0-9]*.[0-9]*) ;; *) continue ;; esac   # CHECK 18 owns malformed versions
    rv=$(printf '%s\n' "$rows" | awk -F'\t' -v s="$s" '$1==s{print $2; exit}')
    if [ -z "$rv" ]; then
      # NEVER-EVALUATED is a BACKLOG, not a regression this change introduced. Warning per skill
      # would turn --strict red on every future PR for a pre-existing condition, which trains
      # people to ignore the check — so it is counted and reported once, loudly enough to see.
      never="$never $s"
      continue
    elif mm_behind "$rv" "$cur"; then
      # NOTE, not WARN, and deliberately. The remedy costs REAL MONEY and is rate-limited
      # (this check first fired on a change that could not be cleared for three days), so
      # gating merges on it would either stall work or push people to silence the check by
      # editing the receipt — which would make the whole trail worthless. Its value is the
      # visible, auditable record of what has NOT been replayed, not a block.
      stale="${stale}${s} (receipt $rv, now $cur)\n"
    fi
  done
  local nn ns; nn=$(printf '%s' "$never" | wc -w | tr -d ' ')
  ns=$(printf '%b' "$stale" | grep -c . || true)
  if [ "${ns:-0}" -gt 0 ]; then
    printf '  %sNOTE%s %s skill(s) changed behaviour since their last recorded eval run — ./run-pending-evals.sh:%s\n' "$Y" "$X" "$ns" ""
    printf '%b' "$stale" | sed 's/^/       /'
  fi
  [ "$probs" -eq 0 ] && pass "every RECORDED eval run is current at MAJOR.MINOR ($(printf '%s\n' "$rows" | wc -l | tr -d ' ') receipts)"
  # Visible without gating: the unevaluated backlog is real, but it is not this change's fault.
  if [ "$nn" -gt 0 ]; then
    printf '  %sNOTE%s %s skill(s) have NO recorded eval run at all (backlog, not gated here):%s\n' "$Y" "$X" "$nn" ""
    printf '       %s\n' "$(printf '%s' "$never" | tr -s ' ' | sed 's/^ //')"
  fi
}

# =============================================================================
# =============================================================================
# CHECK 30 — Stall-probe coverage  (NOTE only; never gates)
# The 2026-07-21 wave produced SEVEN denial-of-service defects — a safety rule written absolutely
# becoming a refusal — and all seven passed lint --strict. CHECK 28 catches the authoring shape
# statically; the STALL PROBE (evaluation-strategy.md) is the behavioural half: one scenario asking
# "a precondition is absent — do you still do your job?". new-skill.sh now scaffolds a `-900-` probe
# for every new skill; this reports which existing skills still lack one.
#
# NOTE, never WARN, and deliberately so: 38 skills predate the convention. Gating on a pre-existing
# backlog would turn --strict red on every future PR and train people to ignore the output — the
# same reasoning CHECK 29 applies to never-evaluated skills.
# HONEST LIMIT — this counts a scenario whose id contains `-900-`. It cannot tell whether the probe
# is well-written, whether its assertions are right, or whether it was ever RUN (CHECK 29 owns the
# run record). Presence is not proof.
# =============================================================================
check_stall_probes() {
  section "30. Stall-probe coverage (over-refusal / over-rejection)"
  local missing="" have=0 s ev
  local IFS=$'\n'
  for s in $(skill_list); do
    ev="$SKILLS_DIR/$s/evaluations/baseline-evals.json"
    [ -f "$ev" ] || continue
    if grep -F -- '-900-' "$ev" >/dev/null 2>&1; then
      have=$((have+1))
    else
      missing="$missing $s"
    fi
  done
  local nm; nm=$(printf '%s' "$missing" | wc -w | tr -d ' ')
  if [ "$nm" -eq 0 ]; then
    pass "every skill with evals ships a stall probe ($have)"
    return
  fi
  pass "$have skill(s) ship a stall probe"
  printf '  %sNOTE%s %s skill(s) have no stall probe (backlog, not gated — new-skill.sh scaffolds one):%s\n' "$Y" "$X" "$nm" ""
  printf '       %s\n' "$(printf '%s' "$missing" | tr -s ' ' | sed 's/^ //')"
}

# =============================================================================
# CHECK 31 — Project-identity allowlist  (FAIL)
# The decoupling sweep found real project identifiers in FIVE distinct token shapes, each escaping
# the probe written for the previous one: `KEY-nn` issue keys, bare uppercase project designators,
# numeric Jira ids, `S-nn` story handles, and an id embedded inside a run-id. Every sweep that used
# a BLOCKLIST missed the next shape. This check is therefore POSITIVE: every project-shaped token
# must be an allowlist member; anything else FAILS. A blocklist cannot fail on the sixth shape
# nobody has found yet — an allowlist can.
#
# Polarity note — the OPPOSITE of scan-secrets.sh's ORG_PATTERNS, deliberately. That detector
# FIRES ON A MATCH (a real-org key shape must not ship). This check FIRES ON A NON-MATCH (a token
# outside the fictional allowlist must not ship). The membership test below is independent of the
# detector's match logic; sharing it would make this check flag the very allowlist members it
# exists to permit.
#
# HONEST LIMIT — shape (b) is narrow ON PURPOSE. The spec's original "any [A-Z]{2,5} near a Jira
# word" measured 676 hits on this tree, dominated by the repo's own vocabulary (AC 138, GA 121,
# RC 60, PR 36): unusable, and the same false-positive class that made the [A-Z]{2,}-[0-9]+
# detector widening unshippable. (b) now fires only in an explicit project-designator position.
# =============================================================================
check_project_identity() {
  section "31. Project-identity allowlist (fresh-clone invariant)"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (tree-wide invariant)"; return; fi
  local probs=0 f ln tok rel
  local KEY_OK='PROJ|PROJ-EP|STORY|EPIC|BUG|FIX|REQ|VIBE|SIM|NR|SHA|ISO'
  local WORD_OK='UNSET|SET|PROJ|ACME|FLEET|PAY|LogBench|AC|ML|MCP|STAYS|NOT'
  local ID_OK='10[56][0-9]{2}'          # fictional fixture id band
  local BT_OK='UNSET|RC|TODO|DONE|TEXT|PR|PASS|FAIL|WARN|NOTE|SKIP|OK|IFS|GA|FIXME|AC|CI|MCP|API|QA|UX|ML|SET|NOT'
  # Shape (g) — quoted mixed-case display names. Generic workflow nouns plus documented fictional
  # examples. A real product/project display name is not here, and that is the point.
  local DISPLAY_OK='To Do|In Review|Before Review|The Review|Test Verdict|Producer Notes|Acme Telemetry|Acme Ingest'
  local sl=""
  local IFS=$'\n'
  for f in $(git -C "$ROOT" ls-files); do
    case "$f" in dist/*|*/_internal/*|.secretignore) continue ;; esac
    [ -f "$ROOT/$f" ] || continue
    # This file used to be exempt WHOLESALE because its own regex literals ([A-Z0-9]{1,9}-[0-9])
    # self-match. That exemption was far wider than the reason for it: on 2026-07-29 a plain-English
    # comment in this very file naming three real project keys survived every sweep, because the one
    # check built to hunt project identity could not see itself. The exemption is now per-LINE and
    # only for lines carrying regex character-class syntax — prose in this file is scanned like
    # anywhere else.
    local selfpat=""; [ "$f" = "lint-platform.sh" ] && selfpat='\[[A-Za-z]-[A-Za-z]|\[0-9\]|\[A-Z'
    # (a) KEY-nn issue keys
    for hit in $(grep -noE '[A-Z][A-Z0-9]{1,9}-[0-9]+' "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; tok="${hit#*:}"
      if [ -n "$selfpat" ]; then sl=$(sed -n "${ln}p" "$ROOT/$f"); [[ "$sl" =~ $selfpat ]] && continue; fi
      [[ "$tok" =~ ^(${KEY_OK})-[0-9]+$ ]] && continue
      fail "$f:$ln: non-allowlisted issue key '$tok'"; probs=$((probs+1))
    done
    # (b) bare key in an explicit project-designator position
    for hit in $(grep -noE "([Pp]roject|[Kk]ey|jira_project_key:)[[:space:]]+['\`\"]?[A-Z][A-Z0-9]{1,4}\b|\b[A-Z][A-Z0-9]{1,4}\b[[:space:]]+(board|project)\b" "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; tok=$(printf '%s' "${hit#*:}" | grep -oE '[A-Z][A-Z0-9]{1,4}')
      if [ -n "$selfpat" ]; then sl=$(sed -n "${ln}p" "$ROOT/$f"); [[ "$sl" =~ $selfpat ]] && continue; fi
      [[ "$tok" =~ ^(${WORD_OK})$ ]] && continue
      fail "$f:$ln: non-allowlisted project key '$tok'"; probs=$((probs+1))
    done
    # (f) backtick-quoted bare uppercase token. The SIXTH shape, found 2026-07-29: a comment in
    # this file listed three real project designators in backticks and escaped every scan above —
    # (a) needs trailing digits, (b) needs a literal project/key word before the token. A bare
    # designator in running prose has neither. The tree carries only ~11 distinct tokens of this
    # shape, all generic, so an allowlist is cheap and a real project key lands outside it.
    # (Naming the escaped keys here would reintroduce them — the shape is the point, not the keys.)
    for hit in $(grep -noE '`[A-Z][A-Z0-9]{1,4}`' "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; tok=$(printf '%s' "${hit#*:}" | tr -d '`')
      if [ -n "$selfpat" ]; then sl=$(sed -n "${ln}p" "$ROOT/$f"); [[ "$sl" =~ $selfpat ]] && continue; fi
      [[ "$tok" =~ ^(${BT_OK})$ ]] && continue
      fail "$f:$ln: non-allowlisted bare designator \`$tok\`"; probs=$((probs+1))
    done
    # (c) numeric Jira ids
    for hit in $(grep -noiE '(project|type|status|transition|board|issue) id [0-9]{5}' "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; tok=$(printf '%s' "${hit#*:}" | grep -oE '[0-9]{5}')
      [[ "$tok" =~ ^(${ID_OK})$ ]] && continue
      fail "$f:$ln: non-allowlisted Jira id '$tok'"; probs=$((probs+1))
    done
    # (d) story handles
    for hit in $(grep -noE '\bS[0-9]{1,2}\b' "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; tok="${hit#*:}"
      [ "$tok" = "S3" ] && continue
      fail "$f:$ln: non-allowlisted story handle '$tok'"; probs=$((probs+1))
    done
    # (g) quoted mixed-case DISPLAY NAME. The SEVENTH shape, found by a pre-publication audit on
    # 2026-07-29. Every shape above requires an ALL-UPPERCASE token, so a two-word product or
    # project display name written in ordinary prose case was invisible to all of them. One
    # survived a full scrub that had renamed the compact codename everywhere, and shipped in the
    # tree, in the built zips, and in two commits already pushed. A Jira project has BOTH a key
    # and a display name; only the key was ever modelled here.
    # (Naming the escaped value here would reintroduce it — and this check now catches that too,
    # which is how this very comment got rewritten. The shape is the point, not the name.)
    # The tree carries ~7 distinct bigrams of this shape, all generic workflow nouns, so — as with
    # (f) — an allowlist is cheap and a real product name lands outside it.
    for hit in $(grep -noE "['\"][A-Z][a-z]+ [A-Z][a-z]+['\"]" "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; tok=$(printf '%s' "${hit#*:}" | tr -d "'\"")
      if [ -n "$selfpat" ]; then sl=$(sed -n "${ln}p" "$ROOT/$f"); [[ "$sl" =~ $selfpat ]] && continue; fi
      [[ "$tok" =~ ^(${DISPLAY_OK})$ ]] && continue
      fail "$f:$ln: non-allowlisted display name '$tok'"; probs=$((probs+1))
    done
  done
  [ "$probs" -eq 0 ] && pass "every project-shaped token is an allowlist member (PROJ-nn, LogBench, acme, fleet-agent, display names, fixture ids)"
}

# =============================================================================
# CHECK 36 — Source <-> dist CONTENT parity  (FAIL)
# Check 1 compares the VERSION in the zip filename; check 7 compares the manifest sha to the zip.
# Neither compares the zip's CONTENTS to the source it was built from. So an edit that does not
# bump the version leaves a stale zip and every gate stays green — and the dangerous direction is
# a zip still carrying text the source no longer has. On 2026-07-29 a scrub removed a product
# identifier from two skills' evaluations; lint passed clean while the built zips kept shipping it,
# and only a manual `unzip | grep` caught it. The zips are a SEPARATE distribution path (uploaded
# to the claude.ai Skills panel), so a repo-only scrub does not reach them.
# Compares every file in each zip byte-for-byte against its source. Needs unzip; WARNs without it.
# =============================================================================
check_dist_content() {
  section "36. Source <-> dist content parity"
  if ! command -v unzip >/dev/null 2>&1; then warn "unzip unavailable — dist content check skipped"; return; fi
  local probs=0 s checked=0
  local IFS=$'\n'
  for s in $(skill_list); do
    local z; z=$(ls "$DIST_DIR/${s}-v"*-public.zip 2>/dev/null | head -1)
    [ -n "$z" ] || continue
    local entry
    for entry in $(unzip -Z1 "$z" 2>/dev/null); do
      case "$entry" in */) continue ;; esac
      local rel="${entry#"$s"/}"
      local src="$SKILLS_DIR/$s/$rel"
      if [ ! -f "$src" ]; then
        fail "$s: dist zip carries '$rel' with no source file — stale zip, rebuild with ./build-dist.sh $s"
        probs=$((probs+1)); continue
      fi
      local zh sh2
      zh=$(unzip -p "$z" "$entry" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
      sh2=$(shasum -a 256 < "$src" | cut -d' ' -f1)
      if [ "$zh" != "$sh2" ]; then
        fail "$s: dist zip content differs from source for '$rel' — rebuild with ./build-dist.sh $s"
        probs=$((probs+1))
      fi
      checked=$((checked+1))
    done
  done
  [ "$probs" -eq 0 ] && pass "every dist zip's contents match its source ($checked file(s))"
}

# =============================================================================
# CHECK 37 — A documented hook is actually wired  (FAIL)
# CLAUDE.md has claimed since the initial public release that a Stop hook auto-runs the gate, while
# .claude/settings.json sat at `{}` — the hook body was stripped by the public-release scrub and
# nothing compared the claim against the file. So the repo documented a control it did not have,
# and the only way to notice was reading both files side by side. That is the memory-enforced shape
# this platform condemns, applied to the platform's own safety net. Two directions, because both
# have failed: a doc that PROMISES a Stop hook must find one wired, and a WIRED hook must point at
# a file that exists and is executable (a rename or a chmod silently disarms it while lint stays
# green). Deliberately narrow: it resolves `hooks/*.sh` references, not arbitrary shell.
check_documented_hooks() {
  section "37. Documented hooks are wired and executable"
  local settings="$ROOT/.claude/settings.json" probs=0
  if ! command -v jq >/dev/null 2>&1; then
    pass "skipped — jq not installed (cannot parse settings.json)"; return
  fi
  if [ -f "$settings" ] && ! jq -e . "$settings" >/dev/null 2>&1; then
    fail ".claude/settings.json is not valid JSON — every setting in it is silently ignored"
    return
  fi
  local wired="" cmds=""
  if [ -f "$settings" ]; then
    wired=$(jq -r '.hooks // {} | keys[]?' "$settings" 2>/dev/null)
    cmds=$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | select(.type=="command") | .command' "$settings" 2>/dev/null)
  fi
  local ref f hit ln
  local IFS=$'\n'
  # (a) a wired hook must resolve to an executable script
  for ref in $(printf '%s\n' "$cmds" | grep -oE 'hooks/[A-Za-z0-9_.-]+\.sh' | sort -u); do
    [ -n "$ref" ] || continue
    if [ ! -x "$ROOT/$ref" ]; then
      fail ".claude/settings.json wires a hook to $ref, which is missing or not executable"
      probs=$((probs+1))
    fi
  done
  # (b) a doc promising a Stop hook must find one wired
  for f in $(git -C "$ROOT" ls-files '*.md'); do
    [ -f "$ROOT/$f" ] || continue
    for hit in $(grep -noiE 'stop hook (also )?(runs|auto-runs)|stop hook →' "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"
      case "$wired" in
        *Stop*) ;;
        *) fail "$f:$ln: promises a Stop hook runs automatically, but .claude/settings.json wires no Stop hook"
           probs=$((probs+1)) ;;
      esac
    done
  done
  [ "$probs" -eq 0 ] && pass "documented hooks are wired; every wired hook script exists and is executable"
}

# =============================================================================
# CHECK 38 — Contract marker -> orchestrator parity  (FAIL)
# A control marker is only worth writing if the pass that must ACT on it recognizes the name. The
# contract defines the marker; the orchestrator is the consumer that reads and writes it. Adding one
# to the contract alone leaves a signal nothing acts on; adding it to the orchestrator alone leaves a
# signal no other skill can rely on. Same shape as the 2026-07-21 lesson — a rule changed where it is
# STATED and not where it is CONSUMED — applied to the one vocabulary both files share, and it is the
# drift the READ-RECEIPT change would have caused had it landed in one file.
# DIRECTIONAL ON PURPOSE: contract -> orchestrator. The reverse asymmetry is legitimate and expected
# (the orchestrator carries operational markers such as PRODUCED-BY and VERIFICATION-ROUND-COUNT that
# the contract never defines), so requiring identical sets would fail on correct state.
check_marker_parity() {
  section "38. Contract marker -> orchestrator parity"
  local c="$ROOT/skills/jarvis-agency-jira-contract" o="$ROOT/skills/jarvis-agency-orchestrate"
  if [ ! -f "$c/SKILL.md" ] || [ ! -f "$o/SKILL.md" ]; then
    pass "skipped — the agency contract/orchestrator pair is not installed in this tree"; return
  fi
  # POSIX classes, not a bracket range: the range spelling self-matches as a project key (check 31).
  # TWO forms, because the first draft of this check passed VACUOUSLY on the very marker it was
  # written for: backticked in prose (`NAME:`) AND bare at the start of a line, which is how a marker
  # is actually written in the fenced example that defines it. Matching only the prose form meant a
  # marker could be fully specified in a code block and stay invisible to the parity check.
  local re='(`|^)[[:upper:]][[:upper:]-]{3,}:'
  local cset oset missing
  # `MARKER` itself is the generic prose word for the convention ("grep-able `MARKER:` prefixes"),
  # not the name of any marker — excluded, or every file discussing the convention self-reports.
  cset=$(cat "$c/SKILL.md" "$c"/reference/*.md 2>/dev/null | grep -oE "$re" | tr -d '`:' | grep -vx 'MARKER' | sort -u)
  oset=$(cat "$o/SKILL.md" "$o"/reference/*.md 2>/dev/null | grep -oE "$re" | tr -d '`:' | grep -vx 'MARKER' | sort -u)
  missing=$(comm -23 <(printf '%s\n' "$cset") <(printf '%s\n' "$oset"))
  if [ -n "$missing" ]; then
    local m
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      fail "contract defines marker '$m:' but jarvis-agency-orchestrate never names it — a signal nothing acts on"
    done <<< "$missing"
    return
  fi
  pass "every marker the contract defines is named by the orchestrator ($(printf '%s\n' "$cset" | grep -c . ) marker(s); orchestrator-only markers are legitimately asymmetric)"
}

# =============================================================================
# CHECK 32 — Stated check-count parity  (FAIL)
# Count drift has recurred THREE times, and at the moment this check was written FOUR different
# live values were in the tree at once: README/CLAUDE said 30, governance-model said 30,
# and two further docs each said something different — while the real count was 31. Every previous
# fix updated the docs by hand, which is what produced the next drift.
#
# COUNTING RULE — the authoritative count is the SET OF CHECK NUMBERS, not the header count and
# not the function count. Both of those under-report by one: `# CHECK 4 + 5` is ONE header
# declaring TWO checks, implemented by ONE function. A naive `grep -c '^# CHECK'` returns 31 when
# the answer is 32. This check parses both forms, requires the set to be contiguous 1..N (a gap or
# duplicate makes any count meaningless, so that is its own FAIL), and takes N as the count.
#
# SELF-COUNTING — this check's own `# CHECK 32` header is part of the set it counts. That is
# correct and intended: the count includes itself, exactly as check 31 scans files including its
# own allowlist members.
#
# lint-platform.sh is exempt (it is not a *.md and so is never scanned): it QUOTES a past count as
# evidence of the drift, and rewriting it would destroy the evidence.
# =============================================================================
check_check_count() {
  section "32. Stated check-count parity"
  local nums n_expected probs=0
  nums=$(grep -oE '^# CHECK [0-9]+( \+ [0-9]+)?' "$ROOT/lint-platform.sh" | grep -oE '[0-9]+' | sort -nu)
  n_expected=$(printf '%s\n' "$nums" | tail -1)
  local count; count=$(printf '%s\n' "$nums" | wc -l | tr -d ' ')
  if [ "$count" -ne "$n_expected" ]; then
    fail "CHECK numbers are not contiguous 1..$n_expected ($count distinct) — a count cannot be derived"
    return
  fi
  local f ln stated rel
  local IFS=$'\n'
  for f in $(git -C "$ROOT" ls-files '*.md'); do
    :   # no per-doc exemption needed; the only historical citation now lives in this file
    [ -f "$ROOT/$f" ] || continue
    for hit in $(grep -noE '\(([0-9]+) checks\)|[Tt]he [0-9]+ checks|\(lint \([0-9]+ checks\)|\b[0-9]+ executable checks\b' "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"; stated=$(printf '%s' "${hit#*:}" | grep -oE '[0-9]+')
      [ "$stated" = "$n_expected" ] && continue
      fail "$f:$ln: states $stated checks, actual is $n_expected"; probs=$((probs+1))
    done
  done
  [ "$probs" -eq 0 ] && pass "every stated check count matches the actual $n_expected (numbers contiguous 1..$n_expected)"
}

# =============================================================================
# CHECK 33 — Instance state is never tracked  (FAIL)
# The Model-A split rests on one wall: platform content is public, per-instance state
# (`**/_internal/` — live Jira bindings, account ids, transition ids) never enters the platform
# repo at all. Today that wall is `.gitignore:14`, and .gitignore is a CONVENTION: `git add -f`
# overrides it silently, and the file is then tracked, published, and in history forever.
#
# CHECK 31 cannot catch this. It scans the CONTENT of tracked files for project-shaped tokens; a
# force-added binding file would be flagged only if its tokens happened to match, and an instance
# config full of opaque ids and URLs may match nothing at all. This check asserts REPO STATE
# instead of file content: is any `_internal/` path tracked, yes or no. Different question,
# different failure mode, different fix — hence its own check rather than an extension of 31.
#
# Scope note — the internal convention has TWO halves and only one is asserted here:
#   `**/_internal/` dirs      -> gitignored, MUST NOT be tracked  (this check)
#   `*-internal.md` files     -> tracked on purpose, excluded from dist by .distignore (CHECK 2/8)
# skills/jarvis-example/reference/notes-internal.md is tracked BY DESIGN and must not be flagged.
# =============================================================================
check_internal_untracked() {
  section "33. Instance state is never tracked (_internal/)"
  local tracked
  tracked=$(git -C "$ROOT" ls-files -- '*_internal/*' '_internal/*' 2>/dev/null)
  if [ -z "$tracked" ]; then
    pass "no _internal/ path is tracked (the Model-A wall is mechanical, not conventional)"
    return
  fi
  local f
  local IFS=$'\n'
  for f in $tracked; do
    fail "$f: instance state is TRACKED — must be gitignored (.gitignore '**/_internal/'); untrack with: git rm --cached '$f'"
  done
}

# =============================================================================
# CHECK 34 — Confidential-doc type in the public tree  (FAIL)
# Assessments, gap analyses, roadmaps and run-evidence memos belong in the private docs repo.
# That boundary was enforced by hand repeatedly during the public/private split, and hand
# enforcement is what produced every escape this repo has had. This makes it mechanical: a doc
# whose FILENAME carries a confidential shape, or whose BODY carries a run-evidence marker, fails.
# The allowlist is explicit rather than clever; playbooks and the governance/operating models do
# not match the shapes and need no exemption — verified on a clean tree, which returns zero.
# =============================================================================
check_confidential_docs() {
  section "34. Confidential-doc type in the public tree"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (tree-wide invariant)"; return; fi
  local probs=0 f base base_lc
  local EV_RE='^## Run Report|^## Artifact Verdict|^## Improvement Proposals'
  local IFS=$'\n'
  for f in $(git -C "$ROOT" ls-files '*.md'); do
    case "$f" in docs/jarvis-agency-operator-guide.md) continue ;; esac
    [ -f "$ROOT/$f" ] || continue
    base="${f##*/}"; base_lc=$(printf '%s' "$base" | tr 'A-Z' 'a-z')
    if [[ "$base_lc" =~ (assessment|_review|review_|gap|roadmap|expansion|_plan) ]]; then
      fail "$f: confidential-doc filename shape — assessments/roadmaps belong in the private docs repo"
      probs=$((probs+1)); continue
    fi
    if grep -qE "$EV_RE" "$ROOT/$f" 2>/dev/null; then
      fail "$f: carries a run-evidence marker (Run Report / Artifact Verdict / Improvement Proposals)"
      probs=$((probs+1))
    fi
  done
  [ "$probs" -eq 0 ] && pass "no confidential-doc type in the public tree"
}

# =============================================================================
# CHECK 35 — Private-document titles and strategy language  (FAIL)
# The split leaked seven times, and every escape was a shape no probe knew. The last two were
# PROSE: private planning docs named in changelogs, and the unreleased market thesis stated
# outright. CHECK 31 cannot catch either — it hunts project-shaped TOKENS, and a document title is
# ordinary capitalised English. This is the first pattern class aimed at sentences.
#
# HONEST LIMIT — the title pattern is narrow ON PURPOSE. The unguarded form matched 174 times on a
# clean tree, every hit being `In Review`, the Jira workflow status. Status words are excluded and
# the doc-type noun list is short. It will not catch a private title avoiding those nouns; it
# catches the family that actually leaked.
# =============================================================================
check_private_doc_prose() {
  section "35. Private-document titles and strategy language"
  if [ -n "$ONLY_SKILL" ]; then pass "skipped on single-skill run (tree-wide invariant)"; return; fi
  local probs=0 f ln hit
  local TITLE_RE='(^|[^A-Za-z])[A-Z][A-Za-z-]{2,}( [A-Z][A-Za-z-]+)? (Plan|Review|Assessment|Analysis|Roadmap|Strategy|Memo)([^A-Za-z]|$)'
  local STRAT_RE='forecast [^ ]+ (demand|growth|need)|market (thesis|demand)|ahead of (the )?market'
  # SHAPE 8: a bare #NN issue/PR reference resolves to nothing in a fresh public repo. Two-or-more
  # digits ONLY — single digits are legitimate prose ("best practice #8", "invariant #1", markdown
  # anchors like (#1-validation-queries)). Measured: every real PR ref found was >=2 digits, every
  # legitimate one was a single digit. That is the discriminator; without it this is unusable.
  local BAREREF_RE='(^|[^A-Za-z0-9&#])#[0-9]{2,}([^0-9]|$)'
  local IFS=$'\n'
  for f in $(git -C "$ROOT" ls-files); do
    case "$f" in dist/*|*/_internal/*|lint-platform.sh) continue ;; esac
    [ -f "$ROOT/$f" ] || continue
    for hit in $(grep -nE "$TITLE_RE" "$ROOT/$f" 2>/dev/null); do
      case "$hit" in *"In Review"*|*"The Review"*|*"Before Review"*) continue ;; esac
      ln="${hit%%:*}"
      fail "$f:$ln: private-document title shape — assessments/plans/reviews live in the private docs repo"
      probs=$((probs+1))
    done
    for hit in $(grep -nE "$STRAT_RE" "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"
      fail "$f:$ln: forward-looking market/strategy statement — belongs in the private roadmap"
      probs=$((probs+1))
    done
    for hit in $(grep -nE "$BAREREF_RE" "$ROOT/$f" 2>/dev/null); do
      ln="${hit%%:*}"
      fail "$f:$ln: bare #NN issue/PR reference — resolves to nothing in a fresh public repo"
      probs=$((probs+1))
    done
  done
  [ "$probs" -eq 0 ] && pass "no private-document title or strategy statement in the public tree"
}

# CHECK 21 — verify-mirror: the vault-governance law is platform-owned  (FAIL)
# The Vault-as-Source-of-Truth law (skills/jarvis-vault-governance) is authored ONCE here and
# deployed into every work repo as a read-only mirror at {vault}/_governance/SOURCE-OF-TRUTH.md.
# "Repos never edit the law" was a promise no command checked — exactly the class of invariant
# this platform makes executable. A repo quietly softening a rule in its own mirror (dropping
# pending-intent-inert, say) is invisible to every other check.
#
# A raw diff is the WRONG test: a faithful mirror legitimately differs from the template in the
# per-repo slots. So both sides are MASKED before comparison —
#   frontmatter : repo_vault_root / jira_project_key / quarantine_list / updated  -> <SLOT>
#   generated_note : any ISO date inside it                                        -> <DATE>
#   body        : the vault-root value ({{VAULT_ROOT}} template-side, the repo's real path
#                 mirror-side) and the other slot values                           -> <SLOT:NAME>
# Everything that survives masking is LAW and must match byte-for-byte.
#
# law_version handling: a mirror AHEAD of the platform can only come from a hand-edit -> FAIL.
# A mirror BEHIND is stale -> WARN (the next run regenerates it); the text comparison is skipped
# there on purpose, since diffing an old mirror against a newer law reports law CHANGES, not
# repo EDITS, and the platform does not keep historical template versions to compare against.
#
# Two modes, one function:
#   ./lint-platform.sh --verify-mirror <path>   verify a deployed mirror (any repo, any path)
#   (in the normal suite)                       self-check this platform's own template —
#                                               law_version agreeing across the template
#                                               frontmatter, its generated_note, and SKILL.md's
#                                               body; every {{SLOT}} a known slot (a typo'd slot
#                                               is never substituted and yields invalid YAML in
#                                               every mirror generated from it) — plus any mirror
#                                               that happens to live in THIS repo.
# Self-skips when the governance skill is absent (a fork without it).
# =============================================================================
GOV_SKILL="jarvis-vault-governance"
GOV_TEMPLATE_REL="skills/$GOV_SKILL/reference/contract-template.md"
# The per-repo slots — the ONLY legitimate mirror-vs-template difference. Keep in sync with the
# template's frontmatter and the SKILL.md slot table; a slot added there must be added here or a
# faithful mirror will fail.
GOV_SLOT_KEYS="repo_vault_root jira_project_key quarantine_list updated"

law_version_of() { grep -m1 '^law_version:' "$1" 2>/dev/null | sed 's/^law_version: *//' | tr -d ' \r'; }

# Print a slot-masked, comparable rendering of a contract file (template or mirror).
# $1 = file. Reads the file's own slot VALUES and masks them wherever they appear, so a mirror
# with vault_root ./docs and a template with {{VAULT_ROOT}} render identically.
gov_mask() {
  local f="$1" key val
  # Values as they appear in THIS file (the template's are the {{SLOT}} literals).
  local sed_args=()
  for key in $GOV_SLOT_KEYS; do
    val=$(grep -m1 "^$key:" "$f" 2>/dev/null | sed "s/^$key: *//" | sed 's/[[:space:]]*$//')
    # Mask the frontmatter line itself unconditionally.
    sed_args+=(-e "s|^$key:.*|$key: <SLOT>|")
    # Mask body occurrences of the value (a bare/short value is skipped — masking "." or "[]"
    # everywhere would corrupt the law text it is supposed to be comparing).
    if [ ${#val} -ge 3 ] && [ "$val" != "UNSET" ]; then
      local esc; esc=$(printf '%s' "$val" | sed 's/[][\\.^$*/|&]/\\&/g')
      sed_args+=(-e "s|$esc|<SLOT:$key>|g")
    fi
  done
  # Any ISO date inside generated_note is a generation timestamp, not law.
  sed_args+=(-e "/^generated_note:/ s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/<DATE>/g")
  sed "${sed_args[@]}" "$f"
}

# Verify one deployed mirror against the platform template. Echoes its own PASS/WARN/FAIL.
verify_one_mirror() {
  local mirror="$1" tmpl="$ROOT/$GOV_TEMPLATE_REL"
  if [ ! -f "$mirror" ]; then fail "verify-mirror: no such mirror: $mirror"; return; fi
  if [ ! -f "$tmpl" ]; then fail "verify-mirror: platform template missing ($GOV_TEMPLATE_REL)"; return; fi
  local mv pv; mv=$(law_version_of "$mirror"); pv=$(law_version_of "$tmpl")
  if [ -z "$mv" ]; then fail "$mirror: no law_version — not a generated mirror of this law"; return; fi
  if [ "$mv" != "$pv" ]; then
    # Numeric ordering, field by field: 1.10.0 is AHEAD of 1.9.0, not behind it.
    local newest; newest=$(printf '%s\n%s\n' "$mv" "$pv" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
    if [ "$newest" = "$mv" ]; then
      fail "$mirror: law_version $mv is AHEAD of the platform's $pv — a mirror cannot outrank the law it is generated from; this is a hand-edit"
    else
      warn "$mirror: law_version $mv is behind the platform's $pv — stale; the next run regenerates it (law text not compared across versions)"
    fi
    return
  fi
  local d; d=$(diff <(gov_mask "$tmpl") <(gov_mask "$mirror"))
  if [ -n "$d" ]; then
    fail "$mirror: LAW TEXT DIVERGES from the platform template at law_version $mv — a repo may change its slots, never the law. Diverging lines (slots masked):"
    printf '%s\n' "$d" | sed 's/^/         /'
  else
    pass "$mirror: faithful mirror of law_version $mv (differs only in masked slots)"
  fi
}

check_verify_mirror() {
  section "21. Vault-governance mirror fidelity (verify-mirror)"
  local tmpl="$ROOT/$GOV_TEMPLATE_REL"
  if [ ! -f "$tmpl" ]; then pass "skipped — no vault-governance skill on this checkout (fork without it)"; return; fi
  if [ -n "$ONLY_SKILL" ] && [ "$ONLY_SKILL" != "$GOV_SKILL" ]; then
    pass "skipped on single-skill run of another skill"; return
  fi
  local probs=0
  # --- self-check A: law_version agrees everywhere it is stated -------------------
  local pv note_v skill_v
  pv=$(law_version_of "$tmpl")
  note_v=$(grep -m1 '^generated_note:' "$tmpl" | grep -oE 'law_version [0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [ -z "$pv" ] || ! printf '%s' "$pv" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    fail "$GOV_SKILL: template law_version '$pv' is missing or not MAJOR.MINOR.PATCH"; probs=$((probs+1))
  fi
  if [ "$note_v" != "$pv" ]; then
    fail "$GOV_SKILL: generated_note states law_version '$note_v' but the frontmatter says '$pv' — every mirror would be stamped with the wrong version"; probs=$((probs+1))
  fi
  # SKILL.md: BODY only (frontmatter carries the changelog, where older law_versions are history,
  # not claims) — same body-vs-changelog discipline as check 17.
  local sm="$SKILLS_DIR/$GOV_SKILL/SKILL.md"
  if [ -f "$sm" ]; then
    for skill_v in $(sed '1,/^---$/d' "$sm" | grep -oE 'law_version [0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
      [ "$skill_v" = "$pv" ] || { fail "$GOV_SKILL: SKILL.md body cites law_version $skill_v but the template is at $pv"; probs=$((probs+1)); }
    done
  fi
  # --- self-check B: every {{SLOT}} in the template is a known slot ---------------
  local known=" VAULT_ROOT JIRA_PROJECT_KEY QUARANTINE_LIST TODAY " tok
  for tok in $(grep -oE '\{\{[A-Z_]+\}\}' "$tmpl" | tr -d '{}' | sort -u); do
    case "$known" in
      *" $tok "*) ;;
      *) fail "$GOV_SKILL: template uses unknown slot {{$tok}} — it would never be substituted, leaving invalid YAML in every generated mirror"; probs=$((probs+1)) ;;
    esac
  done
  [ "$probs" -eq 0 ] && pass "law_version agrees across template frontmatter, generated_note, and SKILL.md; all slots known"
  # --- any mirror deployed in THIS repo ------------------------------------------
  local m found=0
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    found=1; verify_one_mirror "$m"
  done < <(find "$ROOT" -type d -name .git -prune -o -type f -path '*/_governance/SOURCE-OF-TRUTH.md' -print 2>/dev/null)
  [ "$found" -eq 0 ] && pass "no deployed mirror in this repo — verify one with: ./lint-platform.sh --verify-mirror <path>"
}

# ---- main (skipped when sourced as a lib for testing: LINT_PLATFORM_LIB=1) ---
if [ "${LINT_PLATFORM_LIB:-0}" != "1" ]; then

# ---- --versions: print the authoritative skill->version table and exit -------
if [ "$VERSIONS" -eq 1 ]; then
  printf '%-34s %s\n' "SKILL" "VERSION"
  for d in "$SKILLS_DIR"/*/; do
    s=$(basename "$d")
    [ -f "$d/SKILL.md" ] && printf '%-34s %s\n' "$s" "$(version_of "$d/SKILL.md")"
  done
  exit 0
fi

# ---- --verify-mirror <path>: verify one deployed mirror and exit -------------
# Deliberately standalone: a work repo's mirror is verified from the platform checkout without
# running (or being gated by) the platform's own structural checks.
if [ -n "$MIRROR_PATH" ]; then
  printf '%sshipfoundry — verify-mirror%s\n' "$B" "$X"
  section "21. Vault-governance mirror fidelity (verify-mirror)"
  verify_one_mirror "$MIRROR_PATH"
  section "Summary"
  printf '  %s%d FAIL%s   %s%d WARN%s\n' "$([ "$FAILS" -gt 0 ] && echo "$R" || echo "$G")" "$FAILS" "$X" \
                                         "$([ "$WARNS" -gt 0 ] && echo "$Y" || echo "$G")" "$WARNS" "$X"
  [ "$FAILS" -gt 0 ] && { printf '%sRESULT: FAIL%s — the mirror is not a faithful copy of the law.\n' "$R" "$X"; exit 1; }
  [ "$STRICT" -eq 1 ] && [ "$WARNS" -gt 0 ] && { printf '%sRESULT: FAIL (--strict)%s\n' "$R" "$X"; exit 1; }
  printf '%sRESULT: PASS%s\n' "$G" "$X"
  exit 0
fi

# ---- run --------------------------------------------------------------------
printf '%sshipfoundry — platform lint%s\n' "$B" "$X"
[ -n "$ONLY_SKILL" ] && printf 'scope: single skill (%s)\n' "$ONLY_SKILL" || printf 'scope: full platform\n'
[ "$HAVE_PYYAML" -ne 1 ] && printf '%sDEGRADED:%s python3+PyYAML missing — description parsing uses the awk fallback and check 10 is skipped. CI has PyYAML; a local PASS here may still fail CI/upload.\n' "$Y" "$X"

check_parity
check_dist_leak
check_dist_brackets
check_description
check_body_lines
check_manifest
check_distignore
check_trigger_collisions
check_frontmatter_yaml
check_symlinks
check_claudemd_inventory
check_agency_registry
check_model_tiers
check_operator_guide
check_eval_ids
check_verifier_branches
check_version_format
check_todo_placeholders
check_producer_skeleton
check_verify_mirror
check_sot_contradiction
check_stated_defaults
check_lane_uniqueness
check_eval_self_containment
check_gate_reference_parity
check_governance_slots
check_absolute_refusals
check_eval_receipts
check_stall_probes
check_project_identity
check_check_count
check_internal_untracked
check_confidential_docs
check_private_doc_prose
check_dist_content
check_documented_hooks
check_marker_parity

section "Summary"
printf '  %s%d FAIL%s   %s%d WARN%s\n' "$([ "$FAILS" -gt 0 ] && echo "$R" || echo "$G")" "$FAILS" "$X" \
                                       "$([ "$WARNS" -gt 0 ] && echo "$Y" || echo "$G")" "$WARNS" "$X"

if [ "$FAILS" -gt 0 ]; then
  printf '%sRESULT: FAIL%s — fix the above before declaring the edit complete.\n' "$R" "$X"
  exit 1
fi
if [ "$STRICT" -eq 1 ] && [ "$WARNS" -gt 0 ]; then
  printf '%sRESULT: FAIL (--strict)%s — warnings treated as failures.\n' "$R" "$X"
  exit 1
fi
printf '%sRESULT: PASS%s\n' "$G" "$X"
exit 0

fi  # end main guard (LINT_PLATFORM_LIB)
