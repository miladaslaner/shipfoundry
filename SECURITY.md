# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for security reports.**

This project ships security-adjacent tooling — detection-as-code producers, an adversarial
red-team verifier, and agents that open pull requests against your repositories. A vulnerability
here may affect systems well beyond this repo.

Report privately to **m.aslaner@outlook.com**, or via
[GitHub private vulnerability reporting](https://github.com/miladaslaner/shipfoundry/security/advisories/new).

Please include: what you found, how to reproduce it, and what you think the impact is. I'll
acknowledge receipt and keep you updated on the fix.

## Scope

In scope: the skills, the gate suite (`lint-platform.sh`, `scan-secrets.sh`, `eval-runner.sh`),
the hooks, and the CI workflow.

Out of scope: vulnerabilities in Claude Code, the Atlassian or GitHub MCP servers, or Jira itself
— report those to their respective vendors.

## A note on what this project is

shipfoundry is a personal project maintained by one person. There is no SLA and no dedicated
security team. Reports are taken seriously and handled as promptly as one maintainer can.
