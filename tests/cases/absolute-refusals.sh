# lint-platform.sh CHECK 28 — an absolute-refusal clause with no permitting case.
#
# On 2026-07-21 ONE absolute clause ("an unresolvable pointer is a stop") produced SEVEN
# denial-of-service defects across seven skills: it was read as "refuse whenever you do not have a
# pointer", so skills refused when the content was present inline, when nothing was referenced at
# all, and — at the front door — when a founder brought raw intent. All seven passed `--strict`
# and the whole test suite. The check earns its place only if it CATCHES that exact wording and
# stays QUIET on the corrected wording; a check tuned until the tree is silent proves nothing.

ar_setup() {
  rm -rf "$TMP/ar"; mkdir -p "$TMP/ar/skills" "$TMP/ar/lib" "$TMP/ar/dist"
  cp "$ROOT/lib/internal-convention.sh" "$ROOT/lib/skill-md.sh" "$TMP/ar/lib/" 2>/dev/null
  cp "$ROOT/lint-platform.sh" "$TMP/ar/"
}

ar_skill() { # $1=name $2=body
  mkdir -p "$TMP/ar/skills/$1"
  printf -- '---\nname: %s\nversion: 1.0.0\ndescription: x\n---\n%s\n' "$1" "$2" > "$TMP/ar/skills/$1/SKILL.md"
}

run28() { ( cd "$TMP/ar" && LINT_PLATFORM_LIB=0 ./lint-platform.sh 2>&1 | sed -n '/28\. Absolute-refusal/,/^$/p' ); }

printf '%s-- C28 catches the real 2026-07-21 wording --%s\n' "$B" "$X"
ar_setup
ar_skill jarvis-agency-pointer \
'## Reading the brief

Dereference the pointer the brief gives you and read the artifact it names.
An unresolvable pointer is a stop, not a licence to spec against the stub.
Record the block and stop.'
out=$(run28)
case "$out" in *WARN*unresolvable*) assert_eq "the 2026-07-21 absolute is caught" "yes" "yes";;
  *) assert_eq "the 2026-07-21 absolute is caught" "no" "yes";; esac

printf '%s-- C28 stays quiet once the permitting case is stated --%s\n' "$B" "$X"
ar_setup
ar_skill jarvis-agency-pointer \
'## Reading the brief

Take the case you are actually in. Three cases, and only one of them stops:
- The brief names an artifact and the pointer resolves — read it and proceed.
- The content is present inline — use it and proceed; inline content is not a pointer.
- Nothing is referenced at all — nothing to dereference, so proceed with the intent you were given.
An unresolvable pointer is a stop, not a licence to spec against the stub.'
out=$(run28)
case "$out" in *WARN*) assert_eq "the permitting case silences the warning" "no" "yes";;
  *) assert_eq "the permitting case silences the warning" "yes" "yes";; esac

printf '%s-- C28 ignores a changelog-only occurrence (frontmatter is history) --%s\n' "$B" "$X"
ar_setup
mkdir -p "$TMP/ar/skills/jarvis-agency-hist"
printf -- '---\nname: jarvis-agency-hist\nversion: 2.0.0\ndescription: x\nchangelog: |\n  1.0.0 — An unresolvable pointer is a stop. Record the block and stop.\n---\nTake the case you are actually in; an inline artifact is used as given.\n' \
  > "$TMP/ar/skills/jarvis-agency-hist/SKILL.md"
out=$(run28)
case "$out" in *WARN*) assert_eq "a changelog absolute does not trip the check" "no" "yes";;
  *) assert_eq "a changelog absolute does not trip the check" "yes" "yes";; esac

printf '%s-- C28 reports the REAL file line, not the body-relative one --%s\n' "$B" "$X"
ar_setup
ar_skill jarvis-agency-line 'filler
filler
Refuse to act until the marker exists.'
out=$(run28)
# frontmatter is 5 lines here (---, name, version, description, ---); the hit is body line 3 -> 8
case "$out" in *SKILL.md:8:*) assert_eq "the warning names the real file line" "yes" "yes";;
  *) assert_eq "the warning names the real file line" "no" "yes";; esac

printf '%s-- C28 honours only its narrow, documented exception --%s\n' "$B" "$X"
ar_setup
# the exception is keyed on skill AND phrase: the same phrase in another skill still warns
ar_skill jarvis-agency-onboard 'After each fix, re-validate. Do not proceed past a still-red item.'
out=$(run28)
case "$out" in *WARN*) assert_eq "the documented exception is honoured for its own skill" "no" "yes";;
  *) assert_eq "the documented exception is honoured for its own skill" "yes" "yes";; esac
ar_setup
ar_skill jarvis-agency-other 'After each fix, re-validate. Do not proceed past a still-red item.'
out=$(run28)
case "$out" in *WARN*) assert_eq "the exception does not leak to another skill" "yes" "yes";;
  *) assert_eq "the exception does not leak to another skill" "no" "yes";; esac
