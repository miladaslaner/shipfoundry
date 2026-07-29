#!/usr/bin/env bash
#
# scan-secrets.sh — the CONTENT gate. lint-platform.sh enforces structure; this refuses to let
# secrets or PII into the repo. Wired into the same three layers as the lint: the git pre-commit
# hook (staged), the Claude Code Stop hook, and CI (whole tree).
#
# Usage:
#   ./scan-secrets.sh                 # scan all tracked files
#   ./scan-secrets.sh --staged        # scan only staged files (pre-commit)
#   ./scan-secrets.sh <file> [file…]  # scan explicit files (used by the tests)
#
# Exit: 0 = clean, 1 = finding(s), 2 = setup error.
#
# Allowlist: .secretignore (extended-regex, one per line; # comments). A finding whose match line
# matches any allowlist pattern is suppressed (suppression is line-level — a real secret sharing a
# line with an allowlisted value would be missed, but accidental commits land on their own lines).
# Seeded with known-safe placeholders; add your org's safe values (a vendor sandbox key, a public
# support email, a documentation IP) there.
#
# Patterns are intentionally high-confidence to keep false positives near zero. Extend
# SECRET_PATTERNS / PII_PATTERNS for org-specific needs (e.g. a customer name, an internal host).

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 2
if [ -t 1 ]; then R=$'\e[31m'; G=$'\e[32m'; B=$'\e[1m'; X=$'\e[0m'; else R=""; G=""; B=""; X=""; fi
command -v git >/dev/null || { echo "scan-secrets needs git" >&2; exit 2; }

SELF="scan-secrets.sh"; ALLOW=".secretignore"
STAGED=0; EXPLICIT=()
for a in "$@"; do
  case "$a" in
    --staged) STAGED=1 ;;
    -*) echo "unknown flag: $a" >&2; exit 2 ;;
    *) EXPLICIT+=("$a") ;;
  esac
done

# label::extended-regex
SECRET_PATTERNS=(
  "AWS access key id::AKIA[0-9A-Z]{16}"
  "GitHub token::gh[pousr]_[A-Za-z0-9]{30,}"
  "GitHub fine-grained PAT::github_pat_[A-Za-z0-9_]{40,}"
  "Anthropic API key::sk-ant-[A-Za-z0-9_-]{20,}"
  # This platform is Jira/Confluence-centric, so an Atlassian credential is the token most likely
  # to be pasted into a config example here. Both live shapes: the classic API token and the
  # scoped one (ATCTT). Added 2026-07-29 — a pre-publication audit found the detector absent.
  "Atlassian API token::AT(AT|CT)T[A-Za-z0-9_=.-]{20,}"
  "OpenAI API key::sk-[A-Za-z0-9]{32,}"
  "Slack token::xox[baprs]-[A-Za-z0-9-]{10,}"
  "Google API key::AIza[0-9A-Za-z_-]{35}"
  "Private key block::-----BEGIN [A-Z ]*PRIVATE KEY-----"
  "Hardcoded credential::(password|passwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret)[[:space:]]*[:=][[:space:]]*[\"'][^\"']{6,}[\"']"
)
PII_PATTERNS=(
  "Email address::[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
  "IPv4 address::([0-9]{1,3}\.){3}[0-9]{1,3}"
)
# Org-private identifiers — instance footprints that must not ship. Deliberately NOT a generic
# [A-Z]+-[0-9]+ (SHA-256, ISO-8601, and the fictional STORY-/EPIC-/PROJ- fixture handles would all
# false-positive): list YOUR org's real project keys here.
#
# READ THIS BEFORE TRUSTING A GREEN RUN. The values below are a FICTIONAL EXAMPLE. A fork that
# ships them unedited has a detector that matches nothing — it cannot fail, so its green result
# means "not configured", not "clean". A 2026-07-29 pre-publication audit confirmed this exactly:
# the real org keys had to be removed BY HAND because this list had never been pointed at them.
# Replace ACME|OPS with your real keys, or accept that org-key detection is off.
#
# Note the polarity: this FIRES ON A MATCH (a real key must not ship). lint-platform.sh CHECK 31
# is the opposite — it fires on a NON-match against a fictional allowlist. Neither subsumes the
# other, and CHECK 31 only sees ALL-UPPERCASE token shapes, so a mixed-case product or project
# DISPLAY NAME ("Acme Telemetry") is invisible to both. Add such names here as their own pattern.
ORG_PATTERNS=(
  "Org Jira issue key::\b(ACME|OPS)-[0-9]+\b"
  # Example of the display-name shape neither gate catches by structure — replace or delete:
  # "Org product display name::(Acme Telemetry|Acme Ingest)"
)

# ---- file list --------------------------------------------------------------
files=()
if [ "${#EXPLICIT[@]}" -gt 0 ]; then
  files=( "${EXPLICIT[@]}" )
else
  while IFS= read -r -d '' f; do
    case "$f" in "$SELF"|"$ALLOW") continue ;; esac
    files+=("$f")
  done < <(if [ "$STAGED" -eq 1 ]; then git diff --cached -z --name-only --diff-filter=ACM; else git ls-files -z; fi)
fi
if [ "${#files[@]}" -eq 0 ]; then
  printf '%sscan-secrets: nothing to scan%s\n' "$G" "$X"; exit 0
fi

# ---- allowlist filter -------------------------------------------------------
allow_filter() {
  if [ -s "$ALLOW" ]; then
    local pats; pats=$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$ALLOW" 2>/dev/null)
    if [ -n "$pats" ]; then grep -vEf <(printf '%s\n' "$pats"); else cat; fi
  else
    cat
  fi
}

# ---- scan -------------------------------------------------------------------
findings=0
scan_group() {
  local kind="$1"; shift
  local entry label re hits
  for entry in "$@"; do
    label="${entry%%::*}"; re="${entry#*::}"
    hits=$(grep -IHnE -e "$re" "${files[@]}" 2>/dev/null | allow_filter)   # -e: a pattern starting with '-' (private-key block) must not parse as a flag
    if [ -n "$hits" ]; then
      printf '%s%s %s%s\n' "$R" "$kind" "$label" "$X"
      printf '%s\n' "$hits" | sed 's/^/    /'
      findings=$((findings+1))
    fi
  done
}

printf '%sscan-secrets%s — %s file(s)%s\n' "$B" "$X" "${#files[@]}" "$([ "$STAGED" -eq 1 ] && echo ' (staged)')"
scan_group "SECRET" "${SECRET_PATTERNS[@]}"
scan_group "PII" "${PII_PATTERNS[@]}"
scan_group "ORG" "${ORG_PATTERNS[@]}"

if [ "$findings" -gt 0 ]; then
  printf '%sRESULT: %d finding group(s)%s — remove the secret/PII, or add a known-safe pattern to %s.\n' "$R" "$findings" "$X" "$ALLOW"
  exit 1
fi
printf '%sRESULT: clean%s\n' "$G" "$X"
exit 0
