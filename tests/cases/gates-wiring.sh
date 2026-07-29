# gates-wiring.sh — the platform's own test suite must be wired into the enforcement layers.
# Textual wiring checks (like secret-scan.sh's) — the invariant IS the wiring line existing.

printf '%s-- Cgates test suite wired into gates --%s\n' "$B" "$X"
if grep -q 'tests/run-tests.sh' "$ROOT/ci/run-checks.sh"; then assert_eq "CI entrypoint runs the test suite" "yes" "yes"
else assert_eq "CI entrypoint runs the test suite" "no" "yes"; fi

# behavioral: a failing FIRST gate must fail the whole entrypoint even if later gates pass
mkdir -p "$TMP/ci/ci" "$TMP/ci/tests"
cp "$ROOT/ci/run-checks.sh" "$TMP/ci/ci/"
printf '#!/bin/sh\nexit 1\n' > "$TMP/ci/lint-platform.sh"
printf '#!/bin/sh\nexit 0\n' > "$TMP/ci/scan-secrets.sh"
printf '#!/bin/sh\nexit 0\n' > "$TMP/ci/tests/run-tests.sh"
chmod +x "$TMP/ci/lint-platform.sh" "$TMP/ci/scan-secrets.sh" "$TMP/ci/tests/run-tests.sh"
( "$TMP/ci/ci/run-checks.sh" >/dev/null 2>&1 ); rc=$?
assert_ne "red first gate propagates through the CI entrypoint" "$rc" "0"

printf '%s-- Cpipefail no early-exit grep -q pipelines in pipefail gate scripts --%s\n' "$B" "$X"
# Under `set -o pipefail`, `writer | grep -q` is a race: -q exits on first match, the writer
# takes EPIPE, and a SUCCESSFUL match becomes a pipeline failure (or, in an if-condition, a
# silent wrong branch). Flaked CI red on an unchanged file (2026-07-13) and would have
# silently disabled eval-runner's clean room. Rule: in a pipefail script, grep in a pipeline
# reads its whole input (`grep ... >/dev/null`), never `-q`.
for gate in lint-platform.sh eval-runner.sh ci/run-checks.sh scan-secrets.sh build-dist.sh; do
  [ -f "$ROOT/$gate" ] || continue
  if grep -q 'pipefail' "$ROOT/$gate"; then
    n=$(grep -c '| grep -q' "$ROOT/$gate" || true)
    assert_eq "no '| grep -q' pipeline in pipefail script $gate" "${n:-0}" "0"
  fi
done
