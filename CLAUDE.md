# shipfoundry — Claude project context

You're working in shipfoundry: a starter kit for authoring, linting, packaging, and shipping Claude Skills, organised into **workbenches** (themed groups of related skills that share a foundation). This file is the project context; [README.md](./README.md) is the human-facing onboarding.

The repo is two things at once: a **reusable platform** (the tooling, conventions, and governance for running a skills library as a product) and the home of its **flagship workbench, `jarvis-agency`** — a near-autonomous product agency run from Jira (38 skills), proven on a real run. The `jarvis-example` skill is the minimal worked example to copy from. The platform is template-grade — rename the `jarvis-` prefix and you can grow your own workbenches — but it is also a live system, not just a starter kit.

The agency workbench is documented for operators in [docs/jarvis-agency-operator-guide.md](docs/jarvis-agency-operator-guide.md). It currently shares this repo with the platform; the plan of record is to split it into its own repo at go-public time (one private repo until then). See [lessons.md](lessons.md) for the cross-cutting operating lessons.

## Source of truth and how changes land

This repo is version-controlled. **Source of truth = the git repository** (wire it to your own remote). Changes land via **Pull Request**, not direct commits to `main` (protected by an active ruleset: PR required, the `lint` check must be green, no force-push — GitHub refuses direct pushes and red merges; admins keep an emergency bypass): branch (`<type>/<slug>`) → run the close-out gate (`./lint-platform.sh`) → open a PR → CI runs the lint gate → a maintainer merges. `CONTRIBUTING.md` is the contributor guide.

Publishing built skills to the claude.ai org Skills panel is a separate maintainer step after merge (from `dist/*.zip`); there is no API for that surface.

## Before you start — what kind of work is this?

Almost every task is one of four types. **Route to the playbook, follow it, run the gate.** Full contract: [docs/platform/operating-model.md](docs/platform/operating-model.md).

**Fastest start — type the slash command** (it loads the right process automatically): `/new-skill` (A) · `/improve-skill` (B) · `/new-workbench` (C). These live in `.claude/commands/`.

| If you're… | Read first | Gate before "done" |
|---|---|---|
| **A · adding a skill** (`/new-skill`) | [new-skill-playbook.md](docs/platform/new-skill-playbook.md) (+ `./new-skill.sh` to scaffold) | `./lint-platform.sh <skill>` = 0 · `./build-dist.sh <skill>` · update CLAUDE.md counts |
| **B · improving a skill** (`/improve-skill`) | [skill-optimization-playbook.md](docs/platform/skill-optimization-playbook.md) | `./lint-platform.sh <skill>` = 0 · `./eval-runner.sh <skill>` if behaviour changed |
| **C · adding a workbench** (`/new-workbench`) | [workbench-creation-playbook.md](docs/platform/workbench-creation-playbook.md) — **propose architecture before building** | extend the lint if a new invariant is warranted + add the foundation eval |
| **D · platform/tooling change** | [governance-model.md](docs/platform/governance-model.md) — change the check first, then the doc | `./lint-platform.sh --strict` = 0 |

Reflexes: read first · reuse before creating · propose before implementing · **run `./lint-platform.sh` before claiming done** (a Stop hook also runs it automatically — see `.claude/settings.json`). When you write "remember to also update X", build the check instead.

## Project structure

```
.
├── CLAUDE.md          # this file — Claude project context
├── README.md          # human-facing onboarding
├── CONTRIBUTING.md    # contributor guide
├── lessons.md         # cross-cutting operating lessons (read at session start)
├── skills/            # skill source folders (source-of-truth)
│   ├── jarvis-example/                # the worked example skill — copy it / replace it
│   │   ├── SKILL.md
│   │   ├── reference/example-reference.md   # a reference file with a TOC
│   │   ├── reference/notes-internal.md      # internal-only; excluded from dist
│   │   ├── evaluations/baseline-evals.json
│   │   └── .distignore
│   ├── jarvis-agency-jira-contract/   # agency workbench — foundation (Jira-state contract)
│   │   ├── SKILL.md
│   │   ├── reference/_internal/jira-config-internal.md  # instance IDs + MCP tool names; excluded from dist
│   │   ├── evaluations/baseline-evals.json (+ fixtures/, excluded from dist)
│   │   └── .distignore
│   ├── jarvis-agency-onboard/         # agency workbench — first-run preflight (resolve + validate a Jira project, configure gaps via Atlassian MCP + Chrome UI, validate the repo, write the per-project config block)
│   │   ├── SKILL.md
│   │   ├── reference/jira-setup-recipes.md   # Chrome-UI recipes: add the nine statuses + the GA-guard rule
│   │   ├── evaluations/baseline-evals.json
│   │   └── .distignore
│   ├── jarvis-agency-capture/         # agency workbench — conversational front door (chat "create a feature / I found a bug" → classify → confirm → create the right Jira issue → offer wait-or-pickup)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-pm/              # agency workbench — product-manager role, both ends (front: natural-language discovery → Shaped Intent that seeds capture/intake; back: product acceptance at RC vs the frozen intent, advisory into the RC advisory; never gates/signs GA)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-triage-bug/      # agency workbench — bug upstream (reproduce + root-cause + scope a defect → fixed-shape AC → founder fix-scope confirmation gate; a Bug skips the feature pipeline)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-orchestrate/     # agency workbench — orchestrator (the dispatcher)
│   │   ├── SKILL.md
│   │   ├── evaluations/baseline-evals.json (+ fixtures/, excluded from dist)
│   │   └── .distignore
│   ├── jarvis-agency-build-backend/   # agency workbench — delivery (backend + API producer)
│   │   ├── SKILL.md
│   │   ├── evaluations/baseline-evals.json (+ fixtures/, excluded from dist)
│   │   └── .distignore
│   ├── jarvis-agency-build-frontend/  # agency workbench — delivery (React/Next.js producer)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-build-web/       # agency workbench — delivery (framework-less/vanilla web producer: plain HTML/CSS/JS, Web Components, non-React SPAs; DOM-XSS the sharp edge)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-data/      # agency workbench — delivery (migrations/schema/repository producer)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-build-native/    # agency workbench — delivery (native/systems producer: C/C++/Rust kernel/driver/agent, the EDR/sensor sharp end)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-build-ios/       # agency workbench — delivery (iOS/Apple producer: Swift/SwiftUI/UIKit)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-build-ml/        # agency workbench — delivery (ML producer: Python training/eval pipelines, reproducibility + no-leakage)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-build-stream/    # agency workbench — delivery (streaming/data-pipeline producer: Kafka/Flink/Spark/Beam stream processors + ingestion/ETL; delivery-semantics + bounded-state + dead-letter)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-analytics/ # agency workbench — delivery (analytics/search-store producer: Elasticsearch/OpenSearch/ClickHouse/data-lake mappings, ILM/retention, bounded queries)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-detection/ # agency workbench — delivery (detection-as-code producer: Sigma/YARA/Suricata/correlation rules, ATT&CK-mapped, fires-on-malicious/silent-on-benign corpus; + verify-detection efficacy)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-agent/     # agency workbench — delivery (agentic/LLM-application producer: orchestration, tool-use, RAG, eval harness, guardrails; distinct from build-ml training)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-integration/ # agency workbench — delivery (integration/connector + SOAR producer: resilient connectors, normalized schema, idempotent playbooks)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-infra/     # agency workbench — delivery (infrastructure/platform producer: Terraform/K8s/Helm/CI-CD, least-privilege, plan+policy-checked, never applies)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-go/        # agency workbench — delivery (Go producer: services/CLIs/handlers/libraries, explicit errors + race-clean concurrency)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-build-docs/      # agency workbench — delivery (documentation producer: docs-tier prose-only stories, claims verified against the source, single content-accuracy gate)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-review-code/     # agency workbench — governance verifier (code review)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-run-tests/       # agency workbench — governance verifier (test re-run + coverage)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-redteam-security/ # agency workbench — governance verifier (security/red-team)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-qa/              # agency workbench — governance verifier (functional QA: drives the running product for smoke/regression/exploratory, files Bugs, epic-level + per-story-when-runnable)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-perf/            # agency workbench — governance verifier (performance testing: load/stress-tests the assembled product vs SLOs at epic completion on a representative non-prod env, files Bugs; the sixth QA category)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-audit/           # agency workbench — governance sweep (founder-invoked on-demand whole-product reality audit: static stub-hunt + behavioral sweep + claims-vs-reality across BE/API/FE/web, files Bugs; does not trust the per-story/epic record)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-critique-acceptance/ # agency workbench — governance (AC critic, refinement gate)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-verify-detection/ # agency workbench — governance verifier (detection efficacy: replays the attack corpus + evasion variants — does the rule actually catch the attack; fourth RC gate for a detection story + epic coverage)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-verify-artifact/ # agency workbench — governance verifier (artifact quality: research/PRD/design/architecture)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-watch-cost/      # agency workbench — governance guardrail (cost/token watcher)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-retro/           # agency workbench — governance learning organ (post-GA run harvest → Run Report scorecard + evidence-cited, founder-gated skill-improvement proposals; never edits/re-grades/gates)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   ├── jarvis-agency-intake/          # agency workbench — upstream delivery (requirements-lock gate, NOT the opener: interrogate, lock requirements, decompose, coverage map, founder-approval gate)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-research/        # agency workbench — upstream delivery (epic research)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-author-prd/      # agency workbench — upstream delivery (PRD + decompose, AC author)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-design/          # agency workbench — upstream delivery (UX/screen design)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-architect/       # agency workbench — upstream delivery (solution architect, cross-cutting constraints)
│   │   └── SKILL.md + evaluations/baseline-evals.json (+ fixtures/) + .distignore
│   ├── jarvis-agency-hydrate/         # agency workbench — upstream delivery (codebase hydration: scan an existing repo once → verified codebase digest the architect + producers inherit; greenfield skips)
│   │   └── SKILL.md + evaluations/baseline-evals.json + .distignore
│   └── jarvis-vault-governance/       # governance workbench — the universal Vault-as-Source-of-Truth law (platform-owned, founder-only, versioned by law_version) + the bootstrap that deploys it into any work repo as a read-only mirror with three local slots
│       ├── SKILL.md                              # deployment contract + the platform/repo boundary
│       ├── reference/contract-template.md        # THE LAW — law_version 1.2.1; per-repo values appear only as {{SLOTS}}
│       ├── reference/repo-config-template.md     # the per-repo slot file (vault_root, jira_project_key, quarantine_list)
│       └── evaluations/baseline-evals.json + .distignore
├── dist/              # versioned distribution zips + MANIFEST.json (built by build-dist.sh)
├── config/            # committed sanitized registry slice (agency-registry) + stated-defaults — lets lint checks 13/17/23 run in CI too
├── docs/platform/     # the platform playbooks + governance + architecture
├── lint-platform.sh   # the structural gate (37 checks) — the close-out checklist (also: --verify-mirror <path>)
├── scan-secrets.sh    # the content gate — refuses secrets + PII (allowlist: .secretignore)
├── build-dist.sh      # builds dist zips from each .distignore + the manifest
├── new-skill.sh       # scaffolds a new skill correct-by-construction
├── eval-runner.sh     # the behavioural gate (replays baseline-evals.json)
├── tests/            # dependency-free test suite: run-tests.sh runner + cases/*.sh (one per feature)
├── lib/internal-convention.sh # single source of the internal-only content convention (INTERNAL_RE)
├── install-hooks.sh   # wires the lint into .git/hooks/pre-commit
├── hooks/             # pre-commit + Stop-hook lint runners
├── ci/run-checks.sh   # CI entrypoint (lint --strict)
├── .github/workflows/lint.yml # CI wiring (GitHub Actions) — runs ci/run-checks.sh
└── .claude/
    ├── commands/      # /new-skill /improve-skill /new-workbench
    └── settings.json  # Stop hook → auto-runs the lint gate
```

Personal install: symlink the source folders into `~/.claude/skills/` so edits propagate immediately to Claude Code sessions:

```bash
for d in skills/*/; do ln -sfn "$(pwd)/$d" "$HOME/.claude/skills/$(basename "$d")"; done
```

## Vault governance (universal law — auto-bootstrap)
On every run, before work, ensure this repo is governed:
1. Detect the vault root (default ./docs; a repo may override in its repo-config).
2. If {vault}/_governance/repo-config.md is ABSENT → first run: create it with slots — jira_project_key (this repo's Jira project), quarantine_list (default empty), vault_root. If you cannot determine the Jira key, write quarantine_list: [] and jira_project_key: UNSET and surface a request for it in the run summary; do not guess.
3. Generate {vault}/_governance/SOURCE-OF-TRUTH.md from the platform contract-template, filling slots from repo-config. Mark it read-only mirror.
4. If the mirror exists but its law_version < the platform's, regenerate it (preserving repo-config slots) and log the version bump.
5. Ensure founder-decision-queue.md and run-counter.md exist.
6. Obey docs/_governance/SOURCE-OF-TRUTH.md for all vault↔Jira behavior: vault is source of truth for intent; act only on intent in an ACTIONABLE state — review: founder-confirmed OR founder-delegated — and never on review: pending (queue + surface); code contradicting a claim is a hard stop; every Jira write carries a vault backlink; (If jira_project_key is set:) run the two reconciliation triggers.
Never edit the universal law locally — change it only in the platform skill with a bumped law_version.

The law itself lives in [`skills/jarvis-vault-governance/reference/contract-template.md`](skills/jarvis-vault-governance/reference/contract-template.md) (law_version 1.2.1); the repo-config template lives beside it. The mirror is authoritative over this summary — three clauses to read there before acting:

- **Three review states, not two (since 1.2.0).** `pending` is inert. `founder-confirmed` is the founder's own act and only theirs. `founder-delegated` is actionable — intent pre-authorized as a *class* by a recorded standing grant — but it is never a claim the founder read that item, and an agency role may never set it on intent it authored itself. Naming a delegation in the run summary is required, so an audit can separate what shipped on delegation from what a human actually read.

- **Jira-less repos (since 1.1.0).** With `jira_project_key: UNSET` the repo is still fully governed (intent, provenance stamps, pending-intent-inert) but performs **no Jira writes** and **skips both reconciliation triggers** — so step 6's Jira half is conditional, not unconditional. Code-contradicts-claim stays a hard stop wherever code exists. Setting the key later activates the Jira half automatically.
- **"Never edit the law locally" is enforced, not promised.** `./lint-platform.sh --verify-mirror {path}` (check 21) compares a deployed mirror against the platform template with the per-repo slots masked: slot-only differences pass, an edited law sentence fails and prints the diverging lines, a mirror ahead of the platform fails, a mirror behind warns as stale.

## Maintenance conventions (do this every time you edit a skill)

1. **Edit the SKILL.md or reference file** in `skills/<skill-name>/`.
2. **Bump the version** in the skill's frontmatter (`version:` line) per semver: patch = clarifications; minor = additive structural improvements; major = breaking changes. **A change to what the skill DOES in any case is MINOR, never patch** — even when the edit reads like a clarification. On 2026-07-21 eight skills that had been refusing to work were fixed and versioned as patches; the fixes were material behaviour changes, and patch-versioning them hid them from lint check 29, whose whole premise is that a minor/major bump means behaviour moved. If in doubt, it is minor.
3. **Add a changelog entry** at the top of the `changelog:` field describing what changed and why.
4. **Update `updated:` date** if you're crossing into a new day.
5. **Rebuild the dist zip** — `./build-dist.sh <skill>` (see Build pattern below).
6. **Verify nothing else needs the same change** — if you're changing a structural rule, grep the rest of `skills/` for stale references.
7. **Verify the SKILL.md body line count is under 500** (Anthropic best-practice cap). If over, split the heaviest section into `reference/<name>.md` with a table of contents at the top.
8. **Run the close-out gate:** `./lint-platform.sh` (or `./lint-platform.sh <skill>`) must exit 0.

## Build pattern

The build script reads each skill's `.distignore` as the **single source** of exclusions and regenerates `dist/MANIFEST.json` (skill→version→sha256):

```bash
./build-dist.sh jarvis-<name>    # rebuild one skill + refresh the manifest
./build-dist.sh                  # rebuild all skills + refresh the manifest
./build-dist.sh --manifest-only  # just regenerate dist/MANIFEST.json
```

Internal-only content (never shipped in a dist zip) goes in `*-internal.md` files or `_internal/` paths, listed in the skill's `.distignore`. The safety net is automatic: `lint-platform.sh` check 2 scans every built zip for leaks, check 8 verifies the `.distignore` exists, check 7 verifies the manifest matches the zips.

## Claude.ai org-upload constraints on SKILL.md frontmatter

The claude.ai org Skills uploader validates frontmatter and rejects zips that violate these — `lint-platform.sh` enforces each:

- **`description:` — max 1024 characters.** (check 4)
- **`description:` — no angle-bracket tags.** `<Product>` parses as XML and the upload is rejected; use `{Product}` braces. (check 5)
- **Filenames inside the zip — no `[` or `]`.** (check 3)
- **Frontmatter must parse as strict YAML.** An unquoted scalar containing `": "` (colon-space) reads as a nested mapping and is rejected. (check 10)

## Anthropic best practices we follow

1. **SKILL.md body under 500 lines** (soft target 380–450). It loads into context on every trigger. Over the cap → extract to `reference/<name>.md`. (lint check 6)
2. **Progressive disclosure, one level deep.** SKILL.md links to `reference/` files; a reference file must NOT link to another reference file.
3. **Reference files over 100 lines get a table of contents** at the top.
4. **Time-sensitive content goes in `<details>` collapsibles** (validation dates, coverage counts) so the body states the durable rule.
5. **Per-skill `evaluations/baseline-evals.json`** — 3 scenarios minimum, written before extensive docs.
6. **Description field discipline** — third person, "Use when …" opening, describe triggers + symptoms (not the workflow), include a "Does not trigger" clause, ≤1024 chars, `{braces}` not angle brackets.
7. **Concise = scarcity discipline.** Every line competes. Assume Claude is already smart; delete anything that doesn't add information.
8. **A constraint states its PERMITTED cases, not only its forbidden one.** A rule that says only what to refuse gets applied as refuse-by-default — the author has the counterexamples in mind, the agent reading it does not. Write the decision table: *this case → do X · that case → do Y · only this case → stop*. On 2026-07-21 a single absolute clause ("an unresolvable pointer is a stop") produced **seven** denial-of-service defects across seven skills, including the front door refusing to interrogate a founder's intent and a verifier failing an artifact for honestly declaring an unknown. Every fix was the same move: replace the prohibition with the cases. **Corollary — a skill that inherits a shared constraint CITES it and adds no prohibition of its own**; a local restatement is what survives the central fix and keeps doing the damage. If you need different wording, the shared rule is underspecified — fix it there.

The canonical reference is the `superpowers:writing-skills` skill and Anthropic's skill-authoring best-practices doc.

## When to plan first

**Plan first when:** the edit touches ≥3 skills; a frontmatter convention changes; a new cross-cutting rule needs propagation; or the change warrants a `lessons.md` entry. **Direct edit is fine for:** a single-skill change with no cross-references, a typo/wording fix, or a changelog-only entry. Planning means: write the plan, surface it, get a nod, then execute.

## Before declaring a skill edit complete

Run `./lint-platform.sh` — it must exit 0. It encodes the machine-checkable close-out items (source↔dist parity, dist-leak, bracket filenames, description length/tags, body cap, `.distignore` coverage, manifest sync, trigger collisions, frontmatter YAML, symlink coverage, CLAUDE.md inventory parity, agency registry parity, model-tier parity, operator-guide inventory parity, eval-id uniqueness, verifier-branch parity, version-format, todo-placeholder, producer-skeleton, vault-governance mirror fidelity, source-of-truth contradiction). `--strict` treats warnings as failures. Then: confirm the version bump + changelog, the dist rebuild, and (if a cross-cutting lesson was learned) a `lessons.md` entry.

## When in doubt

- Read the relevant `skills/<skill>/SKILL.md` — it's the definitive spec for that skill.
- Read [README.md](./README.md) for onboarding, [docs/platform/](docs/platform/) for the playbooks and governance.
- For operating lessons that span multiple skills, `lessons.md` is the source of truth — read it at session start; append when something bites you.
