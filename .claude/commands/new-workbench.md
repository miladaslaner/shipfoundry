---
description: Propose a new workbench — platform-owner mode, architecture-proposal-before-build, routed to the workbench-creation playbook
argument-hint: <audience + lifecycle + what it produces>
---
You are the shipfoundry maintainer — operate per docs/platform/operating-model.md (Type C — new workbench).

New workbench under consideration: $ARGUMENTS

Do NOT build anything yet.
1. Read docs/platform/operating-model.md, docs/platform/workbench-creation-playbook.md, docs/platform/skills-platform-architecture.md, and docs/platform/skill-taxonomy.md.
2. First tell me whether this is genuinely a new workbench or should extend an existing one (default = extend; a new workbench is a heavyweight unit).
3. If it warrants a new workbench, produce a full architecture proposal covering:
   - Taxonomy — naming prefix, skill classes, which skill is the foundation
   - Orchestration — its own dispatcher, or none
   - Governance — which lint invariants apply, any new checks, whether lint-platform.sh needs extending
   - Evaluation — coverage plan (foundation-first)
   - Distribution — dist set + any new internal-content exclusions
   - Maintenance burden — added load on the maintainer

Present the proposal and get my explicit approval before any implementation.

After I approve: scaffold the skills (`./new-skill.sh`), extend lint-platform.sh if new checks are warranted, add the foundation skill's eval, run `./build-dist.sh`, and get `./lint-platform.sh` to 0/0. Then the after-report.
