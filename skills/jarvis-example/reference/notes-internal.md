# Internal-only notes (NOT for distribution)

This file demonstrates the internal-content convention. Files named `*-internal.md` (or
any path containing `_internal`) hold content that must never ship in a distribution
bundle — confidential examples, named accounts, unredacted data.

`build-dist.sh` excludes this file because it is listed in the skill's `.distignore`, and
`lint-platform.sh` fails the build if a file like this ever leaks into a dist zip. Put
your own sensitive reference material here, or delete this file if you do not need it.
