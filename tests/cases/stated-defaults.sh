# lint-platform.sh CHECK 23 — stated-defaults drift.
#
# The 2026-07-21 audit's largest family: a cross-cutting default is changed WHERE IT IS STATED and
# not WHERE IT IS CONSUMED, and no gate can see the difference. config/stated-defaults.md registers
# the canonical value plus the literals that contradict it; the check greps the operative tree.
# A check that only goes green on clean text proves nothing, so every case below seeds a violation.

sd_setup() { # build a minimal platform tree with a stated-defaults registry
  rm -rf "$TMP/sd"; mkdir -p "$TMP/sd/skills" "$TMP/sd/lib" "$TMP/sd/dist" "$TMP/sd/config"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/sd/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/sd/"
  cat > "$TMP/sd/config/stated-defaults.md" <<'REG'
# Stated defaults registry

### ga-granularity — canonical: `epic`

One PRFAQ = one epic = one GA.

```contradicts
default `story`
story mode (default
```
REG
}

sd_skill() { # $1=name $2=body
  mkdir -p "$TMP/sd/skills/$1"
  printf -- '---\nname: %s\nversion: 1.0.0\ndescription: x\n---\n%s\n' "$1" "$2" > "$TMP/sd/skills/$1/SKILL.md"
}

run23() { ( cd "$TMP/sd" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/23\. Stated-defaults/,/^$/p' ); }

printf '%s-- C23 catches a registered literal in a SKILL.md body --%s\n' "$B" "$X"
sd_setup
sd_skill jarvis-agency-ga 'GA granularity is per project; the default `story` mode applies unless set.'
out=$(run23)
case "$out" in *FAIL*ga-granularity*) assert_eq "contradicting literal in a skill body is caught" "yes" "yes";;
  *) assert_eq "contradicting literal in a skill body is caught" "no" "yes";; esac

printf '%s-- C23 catches it in a reference file, incl. reference/_internal --%s\n' "$B" "$X"
sd_setup
sd_skill jarvis-agency-ga 'clean body'
mkdir -p "$TMP/sd/skills/jarvis-agency-ga/reference/_internal"
printf 'Per-project rows. Story mode (default) unless the row says otherwise.\n' \
  > "$TMP/sd/skills/jarvis-agency-ga/reference/_internal/cfg-internal.md"
out=$(run23)
case "$out" in *FAIL*) assert_eq "contradicting literal in reference/_internal is caught" "yes" "yes";;
  *) assert_eq "contradicting literal in reference/_internal is caught" "no" "yes";; esac

printf '%s-- C23 passes on the corrected wording --%s\n' "$B" "$X"
sd_setup
sd_skill jarvis-agency-ga 'GA granularity defaults to `epic`: one PRFAQ = one epic = one GA.'
out=$(run23)
case "$out" in *FAIL*) assert_eq "corrected wording passes" "no" "yes";;
  *) assert_eq "corrected wording passes" "yes" "yes";; esac

printf '%s-- C23 spares the changelog (history is not drift) --%s\n' "$B" "$X"
sd_setup
mkdir -p "$TMP/sd/skills/jarvis-agency-hist"
printf -- '---\nname: jarvis-agency-hist\nversion: 2.0.0\ndescription: x\nchangelog: |\n  1.0.0 — Introduced the default `story` mode.\n---\nDefaults to `epic`.\n' \
  > "$TMP/sd/skills/jarvis-agency-hist/SKILL.md"
out=$(run23)
case "$out" in *FAIL*) assert_eq "a changelog entry does not trip the check" "no" "yes";;
  *) assert_eq "a changelog entry does not trip the check" "yes" "yes";; esac

printf '%s-- C23 honours the historical-record banner --%s\n' "$B" "$X"
sd_setup
sd_skill jarvis-agency-ga 'clean body'
mkdir -p "$TMP/sd/skills/jarvis-agency-ga/reference"
printf '# Old note\n\n> Retained as a historical record.\n\nThe default `story` mode applied then.\n' \
  > "$TMP/sd/skills/jarvis-agency-ga/reference/old.md"
out=$(run23)
case "$out" in *FAIL*) assert_eq "a bannered reference file is exempt" "no" "yes";;
  *) assert_eq "a bannered reference file is exempt" "yes" "yes";; esac

printf '%s-- C23 does not police its own registry (the literals live there by design) --%s\n' "$B" "$X"
sd_setup
sd_skill jarvis-agency-ga 'clean body'
out=$(run23)
case "$out" in *FAIL*) assert_eq "config/stated-defaults.md is not scanned against itself" "no" "yes";;
  *) assert_eq "config/stated-defaults.md is not scanned against itself" "yes" "yes";; esac

printf '%s-- C23 fails LOUDLY when the registry parses to nothing --%s\n' "$B" "$X"
sd_setup
printf '# Stated defaults registry\n\nnothing registered here any more.\n' > "$TMP/sd/config/stated-defaults.md"
sd_skill jarvis-agency-ga 'the default `story` mode applies'
out=$(run23)
case "$out" in *FAIL*ZERO*) assert_eq "an unparseable registry is a FAIL, not a vacuous pass" "yes" "yes";;
  *) assert_eq "an unparseable registry is a FAIL, not a vacuous pass" "no" "yes";; esac

printf '%s-- C23 warns when there is no registry at all --%s\n' "$B" "$X"
sd_setup
rm -f "$TMP/sd/config/stated-defaults.md"
sd_skill jarvis-agency-ga 'the default `story` mode applies'
out=$(run23)
case "$out" in *WARN*) assert_eq "a missing registry warns rather than passing silently" "yes" "yes";;
  *) assert_eq "a missing registry warns rather than passing silently" "no" "yes";; esac
