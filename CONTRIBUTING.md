# Contributing to shipfoundry

This repo is the **source of truth** for a set of Claude Skills, organised into
workbenches. Everything ships from here.

New to the project? Start with [README.md](./README.md) for the full story, and
`docs/platform/operating-model.md` for how work is structured.

## How changes land

`main` is protected. Nobody commits to it directly — every change comes in as a
**pull request** and must pass the validation gate before it can merge.

1. Branch off `main`. Use the convention: `<type>/<short-slug>` where type is `new-skill`, `improve-skill`, `new-workbench`, or `platform`.
2. Make the change (see "The four work types" below).
3. Run the close-out gate locally (see below).
4. Open a pull request against `main`. CI runs the structural lint automatically.
5. A maintainer reviews and merges. For hands-off merge, add the `automerge` label: the PR squash-merges itself once `lint` passes **and** it carries an approving review from someone other than the author (squash + delete branch). The approval requirement means the label alone can't self-merge unreviewed code — apply it *after* an approval exists (an approval doesn't re-trigger CI). A solo maintainer can't approve their own PR, so the label is a no-op for them; merge manually. For server-side enforcement, enable a GitHub branch-protection ruleset requiring a review.

Commit messages follow Conventional Commits: `feat(<skill>): …`, `fix(<skill>): …`, `docs(platform): …`, `chore: …`.

## The four work types

Almost every change is one of four. The fastest correct start is the matching Claude Code slash command (in `.claude/commands/`), typed inside the repo — it loads the right playbook and the gates for you.

| Type | Command | What it is |
|---|---|---|
| A — new skill | `/new-skill` | a new skill in an existing workbench |
| B — improve a skill | `/improve-skill` | change or fix an existing skill |
| C — new workbench | `/new-workbench` | propose a whole new workbench (architecture proposal first) |
| D — platform/tooling | _(no command)_ | change a check, script, or convention — change the check first, then the doc |

The full contract for each is in `docs/platform/operating-model.md` and the playbooks under `docs/platform/`.

## The close-out gate — run before you open a pull request

1. **Structural lint must be clean:** `./lint-platform.sh` (or `./lint-platform.sh <skill>` for one skill). `--strict` treats warnings as failures; CI runs `--strict`. This is the gate CI enforces.
2. **Content scan must be clean:** `./scan-secrets.sh` — refuses secrets (API keys, tokens, private keys) and PII (emails, IPs). A known-safe value (a sandbox key, a public address, a documentation IP) goes in `.secretignore`, never inline. CI runs this too; the pre-commit hook runs `--staged`.
3. **Rebuild the affected dist package(s):** `./build-dist.sh <skill>` (or `./build-dist.sh` for all). The built `dist/*.zip` and `dist/MANIFEST.json` are committed.
4. **If a skill's behaviour changed, run the behavioural gate locally:** `./eval-runner.sh <skill>`. This needs model access (headless `claude -p`) and so does **not** run in CI — run it on your machine. See `docs/platform/evaluation-strategy.md`.
5. **If the change taught something cross-cutting,** append a note to `lessons.md`.

A local pre-commit hook runs the lint **and** the secret/PII scan for you automatically — enable it once with `./install-hooks.sh`.

## Running the skills in Claude Code (optional local setup)

To exercise the skills in your own Claude Code sessions, symlink the source folders into your personal skills directory:

```bash
for d in skills/*/; do ln -sfn "$(pwd)/$d" "$HOME/.claude/skills/$(basename "$d")"; done
```

Edits to `skills/` then propagate immediately to your sessions.

## What does NOT live here

- **Truly-confidential content** (`**/_internal/`) is git-ignored — kept maintainer-side, never pushed. No skill reads it from the distribution bundle.
- **Personal Claude Code permissions** (`.claude/settings.local.json`) are git-ignored.
- **Internal-only reference files** (`*-internal.md`) may be tracked in source but are excluded from the distribution bundle by each skill's `.distignore`.

## Publishing to the claude.ai org

Merging here does not publish skills to the claude.ai org Skills panel — that upload is a separate maintainer step performed after merge, from the built `dist/*.zip`. This repo is where contribution, review, and validation happen; the org panel is the distribution endpoint.

## Optional: run the gates automatically

The repo ships no auto-running hooks by default. If you want the gate suite to run at the end of
every Claude Code session, add this to `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
                     "command": "\"$CLAUDE_PROJECT_DIR/hooks/stop-lint.sh\"",
                     "timeout": 120 } ] }
    ]
  }
}
```

Or wire the git pre-commit hook instead: `./install-hooks.sh`.
