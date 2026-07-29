# scan-secrets.sh — the content gate. Runs the real scanner against planted temp files.
# Uses $TMP, $ROOT, assert_eq / assert_ne.
#
# NOTE: the "caught" example secrets/PII are assembled at runtime from split literals so this
# tracked test file does not itself contain a scannable secret (which the repo-wide scan would
# otherwise flag). Allowlisted placeholders are safe to write literally — the scan suppresses them.

printf '%s-- Csecret scan-secrets content gate --%s\n' "$B" "$X"
scanrc() { "$ROOT/scan-secrets.sh" "$@" >/dev/null 2>&1; echo $?; }

printf 'just some ordinary text, nothing secret here.\n' > "$TMP/clean.txt"
assert_eq "clean file passes" "$(scanrc "$TMP/clean.txt")" "0"

printf 'key = AKIA%s\n' 'IOSFODNN7EXAMPLE' > "$TMP/aws.txt"
assert_ne "AWS access key is caught" "$(scanrc "$TMP/aws.txt")" "0"

printf 'tok = ghp_%s\n' 'aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789' > "$TMP/gh.txt"
assert_ne "GitHub token is caught" "$(scanrc "$TMP/gh.txt")" "0"

printf -- '-----BEGIN RSA %s-----\n' 'PRIVATE KEY' > "$TMP/pk.txt"
assert_ne "private key block is caught" "$(scanrc "$TMP/pk.txt")" "0"

printf 'reach me at john.smith%sacme-corp.com please\n' '@' > "$TMP/email.txt"
assert_ne "PII email is caught" "$(scanrc "$TMP/email.txt")" "0"

printf 'prod db at 198.18.%s\n' '7.42' > "$TMP/ip.txt"
assert_ne "PII IPv4 is caught" "$(scanrc "$TMP/ip.txt")" "0"

# Allowlisted placeholders must NOT trip the gate (safe to write literally — scan suppresses them).
printf 'bot tag noreply@anthropic.com is fine\n' > "$TMP/allow-email.txt"
assert_eq "allowlisted email passes" "$(scanrc "$TMP/allow-email.txt")" "0"
printf 'connect to 127.0.0.1 locally and 203.0.113.5 (doc range)\n' > "$TMP/allow-ip.txt"
assert_eq "allowlisted loopback + doc IPs pass" "$(scanrc "$TMP/allow-ip.txt")" "0"

# Source-regression: the scan is wired into all three enforcement layers.
if grep -q 'scan-secrets.sh' "$ROOT/hooks/pre-commit"; then assert_eq "pre-commit runs the scan" "yes" "yes"
else assert_eq "pre-commit runs the scan" "no" "yes"; fi
if grep -q 'scan-secrets.sh' "$ROOT/ci/run-checks.sh"; then assert_eq "CI runs the scan" "yes" "yes"
else assert_eq "CI runs the scan" "no" "yes"; fi
if grep -q 'scan-secrets.sh' "$ROOT/hooks/stop-lint.sh"; then assert_eq "Stop hook runs the scan" "yes" "yes"
else assert_eq "Stop hook runs the scan" "no" "yes"; fi

# Org-private identifiers (VIBE-008 guard) — org Jira issue keys must not ship, but generic
# CODE-NUMBER tokens (SHA-256, ISO-8601) must not false-positive.
printf 'harden after ACME%s per the retro\n' '-8' > "$TMP/jirakey.txt"
assert_ne "org Jira issue key is caught" "$(scanrc "$TMP/jirakey.txt")" "0"
printf 'the OPS%s benchmark story\n' '-14' > "$TMP/jirakey2.txt"
assert_ne "second org project key is caught" "$(scanrc "$TMP/jirakey2.txt")" "0"
printf 'SHA-256 and ISO-8601 are fine\n' > "$TMP/jirakey3.txt"
assert_eq "generic CODE-NUMBER tokens not caught" "$(scanrc "$TMP/jirakey3.txt")" "0"
