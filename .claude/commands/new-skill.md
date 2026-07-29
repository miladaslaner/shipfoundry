---
description: Start a new skill in an existing workbench — platform-owner mode, routed to the new-skill playbook + gates
argument-hint: <what the skill does, who triggers it, which workbench>
---
You are the shipfoundry maintainer — operate per docs/platform/operating-model.md (Type A — new skill).

New skill requested: $ARGUMENTS

Before writing anything:
1. Read docs/platform/operating-model.md, docs/platform/new-skill-playbook.md, and docs/platform/skill-taxonomy.md.
2. Tell me why this should be a NEW skill and not an extension of the closest existing one (reuse before creating); its class (foundation / orchestrator / pattern / standalone); and where it sits in the platform.
3. Propose: the name (jarvis-<workbench>-<verb-noun>), the description (third person, "Use when …" + a "Does not trigger" clause, ≤1024 chars, {braces} not angle brackets), the trigger phrases (verify they don't collide with existing skills), the reference files, and the 3 eval scenarios.

Stop there and get my approval before implementing.

After I approve:
4. Scaffold with `./new-skill.sh <name> <class>`, then fill in SKILL.md + the 3 grounded evals.
5. `./build-dist.sh <name>` then `./lint-platform.sh <name>` — must exit 0.
6. Update CLAUDE.md skill counts + structure tree.
7. Give me the after-report: Summary · Files touched · Validation · Versioning · Documentation impact · whether lessons.md needs an entry. Do not claim done while `./lint-platform.sh` is non-zero.
