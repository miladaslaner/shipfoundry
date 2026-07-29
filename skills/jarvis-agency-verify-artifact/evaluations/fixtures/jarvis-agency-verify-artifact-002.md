# STORY-91 — Research: choosing the rate-limiter for the public API gateway

Status: Backlog
Type label: research
Artifact-authored-by run: run-r7

## Research

We should use the GatewayGuard token-bucket limiter for the gateway.

GatewayGuard handles very high request volumes with negligible latency overhead, and its
sliding-window mode is more accurate than the alternatives. Their documentation describes it as the
standard choice for security products, and it meets the compliance requirements our customers care
about. Integration is quick and it scales well.

Recommendation: adopt GatewayGuard.
