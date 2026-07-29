# Founder intent (raw, as given) — new product

"I want to build an on-prem telemetry ingest appliance for haulage carriers. It ingests their
vehicle telemetry, runs compliance rules, and shows violation events in a console their operations
team uses. It needs to be secure and fast, and it should scale to large customers. We want to launch
next quarter. The ingestion has to keep up with very high event rates, so that part is a native
high-throughput collector written in Rust. The console and the rule definitions and the events API
are the usual web stack. Make it compliant. Let's get going — assume the obvious and start building
so we hit the quarter."

# Notes the founder added when pressed once

- Deployment: "on the customer's own servers, they run it themselves."
- Users: "the carrier's dispatch operators use the console; their platform team installs and operates it."
- Compliance: "whatever carriers need."
- Scale: "should handle big carriers."
- Threat model: not stated.
- Data residency / retention: not stated.
- Failure modes, rollback, observability: not stated.
- Success metrics: "customers stop missing violations."
