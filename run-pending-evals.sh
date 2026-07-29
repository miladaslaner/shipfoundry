#!/usr/bin/env bash
# The eval work deferred on 2026-07-21 when the weekly model-call limit was reached.
# Founder decision that day: "probes + the 12 stale skills (~$30)" — recorded in
# docs/_governance/founder-decision-queue.md.
#
#   ./run-pending-evals.sh probes    # the two stall probes only (~$5) — DO THIS FIRST
#   ./run-pending-evals.sh stale     # the 12 skills whose fixed bodies nothing has replayed (~$25)
#   ./run-pending-evals.sh all       # both, probes first
#
# WHY PROBES FIRST. The stall probe is a METHOD that has never caught a real defect. `intake-900`
# was written to fail against the pre-fix body and the limit was hit before it could be scored, so
# it is a hypothesis, not a test. If the probes do not behave as designed, the stale re-runs tell
# you less than you think they do — validate the instrument before trusting its readings.
#
# WHY THESE 12. Each carries a behaviour fix that NOTHING has replayed. They pass CHECK 29 only
# because the fixes were under-versioned as patches (see CLAUDE.md maintenance convention #2), so
# the check cannot see them. config/eval-receipts.md names them under "Known stale despite passing
# check 29". eval-runner writes a fresh receipt per skill as each completes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
MODE="${1:-}"

PROBES=(
  "jarvis-agency-intake:jarvis-agency-intake-900-stall-probe-missing-prfaq"
  "jarvis-agency-build-backend:jarvis-agency-build-backend-900-stall-probe-missing-precondition"
)
# Ordered by consequence: the front door and the foundation contract first.
STALE=(
  jarvis-agency-intake
  jarvis-agency-jira-contract
  jarvis-agency-pm
  jarvis-agency-verify-artifact
  jarvis-agency-qa
  jarvis-agency-perf
  jarvis-agency-author-prd
  jarvis-agency-architect
  jarvis-agency-critique-acceptance
  jarvis-agency-design
  jarvis-agency-research
  jarvis-vault-governance
)

usage() { sed -n '2,20p' "$0"; exit 2; }
case "$MODE" in probes|stale|all) ;; *) usage ;; esac

run_probes() {
  echo "== stall probes (validating the method) =="
  local pair skill sid rc=0
  for pair in "${PROBES[@]}"; do
    skill="${pair%%:*}"; sid="${pair##*:}"
    echo "-- $skill / $sid"
    # 3 samples: this harness has demonstrated single-sample variance repeatedly, and a probe
    # verdict is only worth acting on as a majority.
    ./eval-runner.sh "$skill" --scenario "$sid" --samples 3 || rc=1
  done
  cat <<'NOTE'

READ THE PROBE RESULTS BEFORE CONTINUING.
  Both PASS   -> the method does not false-positive, but has still never CAUGHT anything. To prove
                 it has teeth, run intake-900 against the PRE-FIX body — and do it on a COPY of the
                 repo, never by swapping the file in place (that was done on 2026-07-21 and left a
                 broken body in the tree when the run died).
  A probe FAILS -> read the miss. A stall-shaped miss ("bounces", "defers", "produces nothing") is
                 a real defect in that skill; a narration miss is usually the query not asking for
                 what the assertion grades (evaluation-strategy.md rule 4).
NOTE
  return $rc
}

run_stale() {
  echo "== replaying the 12 skills whose fixed bodies have never been evaluated =="
  local s rc=0
  for s in "${STALE[@]}"; do
    echo "-- $s"
    ./eval-runner.sh "$s" || rc=1
  done
  cat <<'NOTE'

A NON-ZERO FAILURE COUNT IS NOT AUTOMATICALLY A DEFECT. Triage before fixing (lessons.md, G1):
  - "no parseable judge output" is TOOLING, not a grade. A run reporting 100% failure at $0.00
    means every model call was rejected — re-run it; do not report it as findings.
  - A compound assertion packing 4-5 facts wobbles by design. Split it rather than editing a body.
  - A body change fixes a defect; an assertion change fixes a scenario. Decide which before typing.
NOTE
  return $rc
}

rc=0
case "$MODE" in
  probes) run_probes || rc=$? ;;
  stale)  run_stale  || rc=$? ;;
  all)    run_probes || rc=$?; echo; run_stale || rc=$? ;;
esac

echo
echo "Receipts updated in config/eval-receipts.md (eval-runner writes one per completed full-skill run)."
echo "Re-run ./lint-platform.sh to see CHECK 29 pick them up."
exit $rc
