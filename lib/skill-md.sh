#!/usr/bin/env bash
# skill-md.sh — the SINGLE source of SKILL.md frontmatter/body extraction.
# lint-platform.sh (body_lines_of) and eval-runner.sh (skill_body) had hand-copied twins of
# this logic and they diverged once already (the missing-fence guard landed in only one — VIBE-022).
#
# frontmatter_end_line FILE → line number of the SECOND '---' fence, or empty if absent.
# skill_body_of FILE        → everything after the closing fence; whole file when the fence
#                             is missing (guarded: empty fmend must not crash arithmetic).

frontmatter_end_line() { awk '/^---$/{c++; if(c==2){print NR; exit}}' "$1"; }

skill_body_of() {
  local fmend; fmend=$(frontmatter_end_line "$1")
  fmend=${fmend:-0}
  tail -n +"$((fmend+1))" "$1"
}
