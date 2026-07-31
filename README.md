# shipfoundry

**An agentic software development agency you run from your terminal.** A crew of 40 specialized
AI skills takes a feature from idea to shipped, reviewed code — coordinated the way a PM runs an
engineering team, not the way a chatbot answers a prompt.

You describe intent. The agency runs PM discovery → requirements lock → architecture → build →
code review → security → QA, and stops at the gates where a human must decide.

## Why this is different

Plenty of tools let AI write code. The problem was never writing code — it was **trusting it**.

shipfoundry's answer is enforced discipline, not good intentions:

- **A producer can never verify its own work.** Every story is built by one agent and judged by
  three independent ones — code review, an independent test re-run, and an adversarial security
  pass. Identity collisions are detected mechanically, not promised.
- **38 executable checks** gate the platform itself (`lint-platform.sh`). Conventions that are
  merely written down drift; these exit non-zero.
- **Evaluations are recorded, not optional.** Every skill ships a behavioural baseline, and a skill
  whose behaviour changed without a recorded eval run is flagged by the lint. The run itself makes
  live model calls, so it happens on a maintainer machine rather than in CI — the receipt is the
  enforceable part, not the run.
- **A human signs GA. Always.** No agent can move work past the release gate — the ceiling is
  behavioural and holds even in unattended runs.
- **Intent lives in your vault, not in an agent's context.** A decision the founder never
  confirmed is inert; work never proceeds on it.
- **You choose where you sign.** GA sign-off sits at the epic by default — you validate a working
  capability, not a code slice — or per story if you want tighter control. Either way, security,
  auth, tenant-boundary, data-migration and payment changes always take a per-story signature.
- **It configures its own governance.** Onboarding doesn't just ask you to set up a release guard;
  it builds the rule, then proves it works by trying to violate it.

If you are a founder or PM who wants to ship software without being the engineer, the pitch is
not "AI writes your code." It is: **AI writes your code under discipline you can audit.**

## What kind of system is this?

If you place agent systems on a map — **harness engineering** (scaffolding around the model),
**loop engineering** (one agentic loop with tools), **graph engineering** (a compiled DAG of nodes)
— shipfoundry is all three at different layers, and the interesting part is where it isn't any of
them.

- **A loop, at runtime.** One pass reads the board, selects what's ready, routes it, dispatches,
  collects, writes back, and stops at the ceiling. Then it ends. Nothing is carried forward:
  *"every pass is stateless — Jira holds the execution truth, the vault holds intent."* That is
  why a run survives compaction, a crashed session, or a machine reboot.
- **A graph, but the graph is data.** There is a real state machine — nine statuses, a routing
  table of status × stack label, gate predicates, a human-only edge into GA. It is not compiled
  into node objects. It is a markdown table, re-read every pass, and the state lives in a system
  you can open in a browser and edit by hand.
- **A harness, but pointed at authoring.** The 38 checks, the secret scan, the eval runner — none
  of them run during an agency loop. They gate how skills are *written*, not how they *execute*.

**What it actually is: externalized-state engineering.** Most frameworks keep the graph and its
state inside the process. shipfoundry deliberately puts both outside — in a Jira board and a folder
of markdown notes. That one choice is what buys statelessness, auditability, resumability, and a
human-in-the-loop surface that needs no custom UI, all at once. Your project management tool *is*
the agent's memory.

**And the material it's built from is governance.** The unit of work isn't a node or a tool call —
it's a role with a verdict. Who may judge whom, what a machine may never sign, which intent is
inert until a human confirms it. Most agent frameworks engineer capability. This one engineers
*distrust*, and lets capability follow.

## What's in the box

**40 skills.** The orchestrator reads your board, routes each unit to the right specialist, spawns
it with clean context, and writes results back.

| Group | Skills |
|---|---|
| **Front door & discovery** | `capture` (chat → work item), `pm` (shape the idea, and product-accept the result), `intake` (lock GA-grade requirements), `triage-bug` |
| **Spine** | `orchestrate` (the loop), `jira-contract` (the state contract every skill obeys), `onboard`, `hydrate` (learn an existing codebase first) |
| **Upstream delivery** | `research`, `author-prd`, `design`, `architect` |
| **Producers** (routed by stack label) | `backend` · `frontend` · `web` · `go` · `data` · `native` · `ios` · `ml` · `stream` · `analytics` · `detection` · `agent` · `integration` · `infra` · `docs` |
| **Verifiers** | `review-code`, `run-tests`, `redteam-security`, `verify-artifact`, `critique-acceptance`, `verify-detection`, `qa`, `perf`, `audit` |
| **Governance** | `vault-governance` (source-of-truth law), `watch-cost` (budget brake), `retro` (turns a closed run into proposals) |

**A note on the two names.** **shipfoundry** is the platform — the tooling, gates, and conventions
that author, lint, package, and ship skills. **Jarvis** is the crew it ships: the agency workbench,
whose skills carry a `jarvis-` prefix on disk (`jarvis-agency-orchestrate`, `jarvis-agency-capture`
— the table above drops it for readability). It's a platform/workbench split rather than a rename
in progress: shipfoundry can host other workbenches, and Jarvis is simply the first and flagship
one. Building your own crew means adding a workbench with its own prefix — `build-dist.sh`,
`eval-runner.sh`, and `scan-secrets.sh` are prefix-agnostic, while the agency-specific lint checks
name `jarvis-agency-*` directly and self-skip when it isn't there.

**The gate suite.** `lint-platform.sh` (38 checks), `scan-secrets.sh` (secret/PII content gate),
`eval-runner.sh` (behavioural baselines), plus a dependency-free test suite. All wired into
pre-commit, a session-stop hook, and CI.

## Requirements

- **Claude Code**
- **Jira** via the Atlassian MCP — the agency's execution ledger is a real Jira board. Connect it
  as a **dedicated agent account**, not your personal one; the release guard keys on the actor.
- **GitHub** via MCP — producers open real pull requests.
- **Claude in Chrome** — the Atlassian API cannot edit workflows or create automation rules, so the
  agency drives the Jira UI in a browser to configure them itself. Optional: without it you get a
  precise manual checklist instead, and the same re-validation afterwards.

## Quick start

```bash
git clone https://github.com/miladaslaner/shipfoundry.git
cd shipfoundry

# install the skills into Claude Code
for d in skills/*/; do ln -sfn "$(pwd)/$d" "$HOME/.claude/skills/$(basename "$d")"; done
```

> **The agency has no slash commands.** You drive it in plain English — the phrases below are the
> triggers. (`/new-skill`, `/improve-skill` and `/new-workbench` exist, but they are for *extending*
> shipfoundry itself, not for running it.)

Then, from a Claude Code session **inside your own product's repo**:

```
set up the agency for <your-jira-project>
```

`jarvis-agency-onboard` resolves the project, validates it against the contract via the Atlassian
API, reports what's missing — and then **configures the gaps for you.** What the API can do, it does
through the API; what the API cannot do, it does by driving the Jira UI in Chrome:

- **Nine workflow statuses, exact names** — `Backlog`, `Refined`, `In Progress`, `In Review`, `RC`,
  `GA Signed`, `Done`, `Rejected`, `Blocked`, each with the right category. Matched literally:
  `Release Candidate` is not `RC`.
- **The GA guard** — a Jira Automation rule reverting any transition into `GA Signed` made by the
  agent account back to `RC`, with an audit comment. Then **verified empirically**: transition a
  throwaway issue as the agent, confirm the revert lands, clean up. This is a compensating control
  — revert-after, not pre-block; a true pre-block needs company-managed Jira.
- **Branch protection** on the paired repo — checked, and offered where missing.

It never records a fix it cannot re-verify, and it will not hand a half-configured project to the
loop. Recipes: [jira-setup-recipes.md](skills/jarvis-agency-onboard/reference/jira-setup-recipes.md)

Once it's green:

```
run the agency loop on <your-jira-project>
```

One pass: pick up what's ready, route it, build, verify, report. To keep the board moving:

```
/loop 10m run the agency loop on <your-jira-project>
```

> Before leaving a loop unattended, set your Anthropic account spend limit. The workbench's own
> cost watcher parks a run at its budget, but an account-level cap is the one brake a misbehaving
> loop cannot talk past.

## How it works

**Orchestrator → producer → verifier.** Each pass reads the board fresh — no state accumulates in
an agent's context, so a run survives compaction, restarts, and crashes. Work is routed by status
and stack label. The producer builds one story and terminates. The verifiers spawn afterwards as
separate identities and judge the pull request against the frozen acceptance criteria. Every
verdict must pass before a story reaches release-candidate; a human signs from there.

**Vault governance.** Intent lives as plain markdown notes in your repo — no special tooling
required (open them in Obsidian if that's your habit; the platform neither knows nor cares). Jira holds execution
truth; the vault holds intent. Agency-authored intent the founder has not confirmed is *inert* —
readable, but never actionable. Code that contradicts a claim is a hard stop, not a warning.

Depth: [operator's guide](docs/jarvis-agency-operator-guide.md) ·
[configuration reference](docs/platform/configuration.md) ·
[governance model](docs/platform/governance-model.md) ·
[evaluation strategy](docs/platform/evaluation-strategy.md) ·
[architecture](docs/platform/skills-platform-architecture.md)

## Point it at your own project

shipfoundry is a platform, not a product you use hosted. One Jira project per product, all on your
own instance. Greenfield repos start immediately; for an existing codebase, `jarvis-agency-hydrate`
scans it first and produces a verified digest so the architect and producers follow *your*
conventions instead of generic defaults.

Extending it is the same story: `./new-skill.sh` scaffolds a skill correct-by-construction, and
the gate suite tells you when it isn't.

## About this project

shipfoundry is a **personal project**, built by one person — [Milad Aslaner](https://github.com/miladaslaner) —
in collaboration with AI. Claude wrote most of the code and much of the prose; I set the direction,
made the calls, and rejected a great deal.

That is not a disclaimer, it's the point. The repo is the product of the method it describes: work
shaped by a human, produced by agents, and held to gates that neither could skip alone. If you want
to know whether the approach works, the honest answer is that this repository is the evidence
available — a system that builds software, built that way.

It comes with no support commitment and no roadmap promises. Issues and pull requests are welcome;
so is forking it and taking it somewhere I wouldn't.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Changes land by pull request with the lint gate green.
