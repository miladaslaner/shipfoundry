#!/usr/bin/env bash
# internal-convention.sh — the SINGLE source of the internal-only content convention.
#
# A file is "internal-only" (must never ship in a distribution bundle) if its path matches
# INTERNAL_RE: a file named *-internal.md, or any path segment named _internal
# (e.g. reference/_internal/, _internal-examples/).
#
# Sourced by:
#   - lint-platform.sh  — check 2 (dist-leak) and check 8 (.distignore coverage)
#   - build-dist.sh     — defensive build-time exclusion (so a forgotten .distignore line
#                         still cannot leak internal content into a zip)
#
# Change the convention HERE; both consumers pick it up. Do not re-hardcode it elsewhere.
# (new-skill.sh's scaffolded .distignore lists example internal paths as a convenience default;
# it is not a second definition of this regex.)

INTERNAL_RE='(-internal\.md$|(^|/)_internal)'

# is_internal_path PATH → exit 0 if PATH is internal-only, 1 otherwise.
is_internal_path() { printf '%s\n' "$1" | grep -Eq "$INTERNAL_RE"; }
