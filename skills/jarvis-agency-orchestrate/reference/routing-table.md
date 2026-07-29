# Producer routing table

The type-label → delivery-skill routing the orchestrator applies. The **producer-capability registry**
in the workbench internal config is the authoritative source of what is `installed`/`covered`; this
table is the orchestrator's dispatch view of it. If a type label has no installed skill here, the
orchestrator routes the story to the human queue (never guesses or substitutes).

| Type label | Delivery skill | Installed |
|---|---|---|
| `backend` | jarvis-agency-build-backend | installed |
| `api` | jarvis-agency-build-backend (owns backend + API; a slice's endpoint and its service are one producer's job, not split) | installed |
| `frontend` | jarvis-agency-build-frontend | installed (React/Next.js/TypeScript web UI) |
| `web` | jarvis-agency-build-web | installed (framework-less / vanilla web — plain HTML/CSS/JS, Web Components, non-React SPAs; security verifier weighs DOM-based XSS heaviest) |
| `data` | jarvis-agency-build-data | installed |
| `native` | jarvis-agency-build-native | installed (C/C++/Rust kernel/driver/agent; security verifier is the heaviest gate) |
| `ios` | jarvis-agency-build-ios | installed (Swift/SwiftUI/UIKit; storage + states + accessibility) |
| `ml` | jarvis-agency-build-ml | installed (Python training/eval; test + security verifiers weigh leakage/provenance) |
| `go` | jarvis-agency-build-go | installed (Go service/CLI/handler/library; test verifier requires `go test -race`, security verifier weighs path traversal + injection + data races) |
| `stream` | jarvis-agency-build-stream | installed (Kafka/Flink/Spark/Beam stream processors + ingestion/ETL; test verifier requires the pipeline harness, security verifier weighs unbounded-state/OOM + offset-commit-before-sink data loss + replay/duplication; GENERAL/UNVALIDATED) |
| `analytics` | jarvis-agency-build-analytics | installed (Elasticsearch/OpenSearch/ClickHouse/data-lake store; test verifier requires the store test suite vs a test cluster, security verifier weighs query injection + tenant isolation + expensive-query DoS; GENERAL/UNVALIDATED) |
| `detection` | jarvis-agency-build-detection | installed (Sigma/YARA/Suricata/correlation rules; test verifier requires the fires-on-malicious/silent-on-benign corpus; a `detection` story additionally gets the jarvis-agency-verify-detection efficacy verdict; GENERAL/UNVALIDATED) |
| `agent` | jarvis-agency-build-agent | installed (agentic/LLM-application; test verifier requires the eval harness with mocked tools, security verifier weighs prompt injection + tool abuse + exfiltration; GENERAL/UNVALIDATED) |
| `integration` | jarvis-agency-build-integration | installed (connectors + SOAR; test verifier requires contract tests vs recorded fixtures, security verifier weighs SSRF + credential leakage + playbook escalation; GENERAL/UNVALIDATED) |
| `infra` | jarvis-agency-build-infra | installed (Terraform/K8s/Helm/CI-CD; test verifier re-runs validate/plan + policy/conftest, security verifier weighs IAM + secrets + public exposure + supply-chain; never applies to a real environment; GENERAL/UNVALIDATED) |
| `docs` | jarvis-agency-build-docs | installed (documentation-only; the contract's **docs tier** — In Review dispatches the **single docs gate** (review-code, docs mode) instead of the trio; a producer mis-tier bounce routes the story back for re-tiering into a code label + the full trio) |
| `research` | jarvis-agency-research | installed (upstream artifact) |
| `design` | jarvis-agency-design | installed (upstream artifact) |
| `architecture` | jarvis-agency-architect | installed (upstream artifact) |
