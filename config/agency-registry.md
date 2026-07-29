# Agency registry — committed slice

Sanitized, committed mirror of the routing registry so lint checks 13 (registry parity) and
17 (verifier-branch parity) run in CI, not only on the maintainer's machine (VIBE-016).
Instance configuration (cloud id, account ids, real status names, transition ids) stays in the
gitignored internal config. When you register a producer there, register it HERE too — the
CI forward-check fails if a producer skill is missing from this file.

## Producer-capability registry

| Type label | Producer | Stack / surface covered |
|---|---|---|
| `backend`, `api` | jarvis-agency-build-backend | Kotlin/Micronaut JVM services + APIs |
| `frontend` | jarvis-agency-build-frontend | React/Next.js/TypeScript web UI, dashboards, consoles, web pages |
| `web` | jarvis-agency-build-web | Framework-less/vanilla web — plain HTML/CSS/JS, no-build widgets, Web Components, non-React SPAs |
| `data` | jarvis-agency-build-data | SQL migrations/schema/repositories (Postgres/Exposed) |
| `native` | jarvis-agency-build-native | C/C++/Rust kernel modules, drivers, usermode agents/sensors |
| `ios` | jarvis-agency-build-ios | Swift/SwiftUI/UIKit apps, view models, app logic |
| `ml` | jarvis-agency-build-ml | Python training + evaluation pipelines, data transforms, model code |
| `docs` | jarvis-agency-build-docs | Documentation-only changes — README, guides, tutorials, comments, wording |
| `go` | jarvis-agency-build-go | Go services, CLIs, HTTP handlers, libraries |
| `stream` | jarvis-agency-build-stream | Kafka/Flink/Spark/Beam stream processors and ingestion/ETL pipelines |
| `analytics` | jarvis-agency-build-analytics | Analytical/search/time-series stores — Elasticsearch/OpenSearch, ClickHouse, data lakes |
| `detection` | jarvis-agency-build-detection | Detection-as-code — Sigma/YARA/Suricata/Zeek and correlation rules, ATT&CK-mapped |
| `agent` | jarvis-agency-build-agent | Agentic/LLM-application code — orchestration, tool-use, RAG, eval harnesses, guardrails |
| `integration` | jarvis-agency-build-integration | Third-party connectors + SOAR playbooks/workflow automation |
| `infra` | jarvis-agency-build-infra | Infrastructure/platform — Terraform/OpenTofu IaC, Kubernetes/Helm manifests, containers, CI/CD |

## Label values

| Type label | label values | `backend`, `api`, `frontend`, `web`, `data`, `native`, `ios`, `ml`, `go`, `stream`, `analytics`, `detection`, `agent`, `integration`, `infra`, `docs`, `research`, `design`, `architecture` |

## Work tier

| Work tier | marker comment | prefix `TIER:` — `docs` / `small` / `feature` / `product`, written by jarvis-agency-intake; the founder confirms or overrides it at the approval gate |
