# Jira setup recipes — onboarding a project to the agency

The exact, repeatable steps the onboard skill uses to validate a project and to configure the two
pieces the Atlassian API cannot change (workflow statuses, the GA-guard automation rule). Drive these
through the **Chrome MCP** on the Jira UI; fall back to handing the operator the same steps as a manual
checklist when Chrome is unavailable. Every concrete instance value (site URL, the agent account name,
account ids) lives in the contract's internal config — read it there, do not hardcode it here.

## Contents

- [1. Validation queries (Atlassian MCP — read-only)](#1-validation-queries)
- [2. Recipe: add the nine statuses to a team-managed workflow (Chrome)](#2-add-statuses)
- [3. Recipe: the GA-guard automation rule (Chrome)](#3-ga-guard-rule)
- [4. Re-validation after a fix](#4-re-validation)

<a id="1-validation-queries"></a>

## 1. Validation queries (Atlassian MCP — read-only)

Run these to build the green/red checklist. All are reads; none change anything.

- **Resolve the project:** `getVisibleJiraProjects` (filter by the name/key the operator gave) →
  the project key + numeric id. Ambiguous name → list matches, ask.
- **Acting identity:** `atlassianUserInfo` → the accountId must equal the **dedicated agent account**
  in the internal config, not the human signer. Mismatch → stop, re-auth as the agent.
- **Issue types:** `getJiraProjectIssueTypesMetadata` for the project → confirm a **Story** type and an
  **Epic** type exist; record their type ids for the config block.
- **Workflow statuses:** the nine canonical states must exist on the project's workflow —
  `Backlog` (or the project's existing initial status — often Jira's default `To Do`; map it, don't
  rename it), `Refined`, `In Progress`, `In Review`, `RC`, `GA Signed`, `Done`, `Rejected`,
  `Blocked`. Read them from the issue-type metadata's status list, or create one throwaway issue and call
  `getTransitionsForJiraIssue` to see the reachable statuses. Record which of the nine are **missing**.
  (Transition ids themselves are read live at loop time, so only the **statuses** must pre-exist.)
- **GA-guard automation:** the API cannot list automation rules. Verify in the UI (§3 below) or
  empirically: on a throwaway issue, as the agent account, `transitionJiraIssue` it to `GA Signed` and
  confirm a rule reverts it to `RC` within seconds and posts an audit comment; then delete the throwaway.
  Record this as **browser/empirically verified**, never as API-verified.

<a id="2-add-statuses"></a>

## 2. Recipe: add the nine statuses to a team-managed workflow (Chrome)

Team-managed projects each carry their own board workflow, so missing statuses are added per project.
Drive the project's workflow editor in the Jira UI — find it from the project's settings; the exact
navigation moves with Jira's UI, so the **outcome below is the spec** and §4's re-validation is the
guarantee. The outcome that must hold when you are done:

- Every **missing** canonical status (from §1) exists under its **exact** canonical name (`Refined`,
  `RC`, `GA Signed`, `Blocked`, …). Naming must be exact: the contract maps canonical states to Jira
  status **names** — `Release Candidate` instead of `RC`, or `GA-Signed` instead of `GA Signed`,
  will not be recognised.
- Each new status carries the right **status category**: `To Do` (blue-gray) for `Refined`;
  `In Progress` (yellow) for `In Progress`, `In Review`, `RC`, `GA Signed`, `Blocked`; `Done`
  (green) for `Done`, `Rejected`. (Category drives colour and board placement; it does not change
  the contract, which sequences state itself.)
- Transitions **into** each new status are allowed (team-managed defaults to any-to-any/global
  transitions, which the contract relies on — confirm they are not restricted).
- The workflow is **saved/published**, then re-validated via §1's status read — never trust the UI
  save alone.

<a id="3-ga-guard-rule"></a>

## 3. Recipe: the GA-guard automation rule (Chrome)

This is the compensating control that keeps GA human-only: it reverts any transition into `GA Signed`
performed by the agent account. One rule per project (team-managed automation is project-scoped unless
you have a multi-project/global rule). Build it in the project's Automation settings — the navigation
moves with Jira's UI; the **rule spec below is what matters**, and §1's empirical test is the
guarantee. The rule, exactly:

- **Trigger:** `Work item transitioned`, with **To status** = `GA Signed` (From unset).
- **Condition:** the user who triggered the event **is** the **dedicated agent account** (the
  account in the internal config — the agent, not the human signer).
- **Actions, in this order:** `Transition work item` → to `RC`; then `Add comment` → an audit note
  naming the agent as an unauthorized signer and that the transition was reverted (so every revert
  is logged).
- **Duplicate-prevention / "only once" is OFF**, so every offending transition is reverted and
  logged, not just the first.
- **Named clearly** (e.g. "GA guard - revert agent GA transition to RC") and **enabled**.
- **Verified empirically** (the test in §1): as the agent, transition a throwaway issue to
  `GA Signed`, confirm the revert-to-`RC` + audit comment within seconds, then delete the throwaway.

This is revert-after, not a pre-block. A hard pre-block (a workflow validator on the `RC → GA Signed`
transition) needs company-managed Jira; record the control honestly as compensating.

<a id="4-re-validation"></a>

## 4. Re-validation after a fix

Never call a gap fixed on the strength of a UI save. After configuring:

- **Statuses:** re-run §1's status read; the previously-missing names must now be present.
- **GA-guard:** re-run the §1 empirical test (or re-read the automation list in the UI); it must revert.
- Only when the checklist is **all-green** does the onboard skill write the per-project config block and
  hand the project to the orchestrator. A red item means the project is not onboarded and the loop must
  not run on it.
