#!/usr/bin/env bash
# ci/run-checks.sh — portable CI entrypoint. Platform-agnostic on purpose: it is the single
# command any CI needs to run, so porting to another provider means one line, not a rewrite.
#
# This repo ships GitHub Actions wiring at .github/workflows/lint.yml, which calls exactly:
#   - run: ./ci/run-checks.sh
#
# Any other provider is the same one-liner in its own syntax, e.g.:
#   lint:
#     image: alpine:latest
#     before_script: [ "apk add --no-cache bash jq zip unzip" ]
#     script: [ "./ci/run-checks.sh" ]
#
# Runs the STRUCTURAL gate (lint, strict) + the CONTENT gate (scan-secrets) + the dependency-free
# TEST SUITE (tests/run-tests.sh). The BEHAVIOURAL gate (eval-runner.sh) is NOT run here — it
# needs model calls (cost + auth) and is invoked deliberately, not on every push.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rc=0
echo "== ci: lint-platform.sh --strict =="
"$ROOT/lint-platform.sh" --strict || rc=1
echo "== ci: scan-secrets.sh =="
"$ROOT/scan-secrets.sh" || rc=1
echo "== ci: tests/run-tests.sh =="
"$ROOT/tests/run-tests.sh" || rc=1
exit "$rc"
