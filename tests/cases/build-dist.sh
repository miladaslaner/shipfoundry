# build-dist.sh — the builder must not claim success on failure, and must reject a
# missing/malformed version (VIBE-002/003). Exercises the real script against a temp tree.

printf '%s-- Cbuild build-dist refuses a version-less skill --%s\n' "$B" "$X"
mkdir -p "$TMP/bd/skills/jarvis-noversion" "$TMP/bd/dist" "$TMP/bd/lib"
cp "$ROOT/lib/internal-convention.sh" "$TMP/bd/lib/"
cp "$ROOT/build-dist.sh" "$TMP/bd/"
printf -- '---\nname: jarvis-noversion\ndescription: x\n---\nbody\n' > "$TMP/bd/skills/jarvis-noversion/SKILL.md"
( cd "$TMP/bd" && ./build-dist.sh jarvis-noversion >/dev/null 2>&1 ); rc=$?
assert_ne "version-less skill => non-zero exit" "$rc" "0"
assert_eq "no garbage -v-public.zip written" "$(ls "$TMP/bd/dist" 2>/dev/null | grep -c 'jarvis-noversion')" "0"

printf '%s-- Cbuild build-dist builds a valid skill --%s\n' "$B" "$X"
mkdir -p "$TMP/bd/skills/jarvis-good"
printf -- '---\nname: jarvis-good\nversion: 1.2.3\n---\nbody\n' > "$TMP/bd/skills/jarvis-good/SKILL.md"
( cd "$TMP/bd" && ./build-dist.sh jarvis-good >/dev/null 2>&1 ); rc=$?
assert_eq "valid skill builds, exit 0" "$rc" "0"
assert_eq "zip named with the version" "$(ls "$TMP/bd/dist" | grep -c 'jarvis-good-v1.2.3-public.zip')" "1"

printf '%s-- Cbuild build-dist refuses a typo'"'"'d explicit target --%s\n' "$B" "$X"
out=$( cd "$TMP/bd" && ./build-dist.sh jarvis-agency-onbaord 2>&1 ); rc=$?
assert_ne "typo'd explicit skill name => non-zero exit" "$rc" "0"
case "$out" in *"no such skill: jarvis-agency-onbaord"*) assert_eq "error names the typo'd skill" "yes" "yes";;
  *) assert_eq "error names the typo'd skill" "no" "yes";; esac
