# The front door — capture and the PM discovery step

Extracted from `SKILL.md` for body-line headroom. The skills themselves own this behaviour
(`jarvis-agency-capture`, `jarvis-agency-pm`); this is the orchestrator's view of how a chat-filed
ask reaches the loop.

## Capture

The operator can file work from chat instead of creating a Jira issue by hand. A phrase like "let's
create a feature X" or "I found a bug Y" routes to **`jarvis-agency-capture`**, which classifies the
ask, confirms it, creates the right issue (an **Epic** for a feature or a small change, a **Bug** for a
defect), and asks whether to **wait for the next loop pass or pick it up now**. On "now", capture hands
the new key to the orchestrator, which routes it: an **Epic** through intake, a **Bug** through
the bug path. Capture does not create standalone Stories — a small change is a small Epic, so
every captured unit has a pickup route. Capture never builds or interrogates; it is the create-and-route
step only.

## PM discovery door (optional, above capture)

A *decided* ask goes straight to capture. A *fuzzy or exploratory* one ("I'm thinking about X", "help
me shape this") routes first to **`jarvis-agency-pm`** (contract "Product manager"): it runs
discovery, challenges whether to build, and shapes the smallest slice.

**Vault-first ordering.** The PM writes the shaped intent as a **vault requirement note**
(`authored_by: agency`, `decision_type: requirement`, `review: pending`) *before* any issue exists —
intent is born in the vault, so there is no longer a dependency on capture creating the Epic first.
Capture then creates the Epic carrying a `## Shaped Intent` **pointer comment** that backlinks the
note, and the issue key is written back into the note so the chain resolves both ways. Intake
resolves that pointer, reads the note, and presses only the gaps. The PM does not create the issue
or lock the scope, and never sets `review: founder-confirmed`.
