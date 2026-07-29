# Founder intent (raw, as given) — single feature

"Add a feature to the existing console: a fleet compliance manager can set how long their duty-status logs are
retained, between 30 and 365 days. It's a settings screen plus an API plus a stored value. Default
is 90 days. Only the fleet's own admins can change their own setting. This is the same React
console, Kotlin API, and SQL store we already use."

# Notes the founder added when pressed once

- Users: "fleet compliance managers set it; the platform reads it when it prunes old logs."
- Measurable launch: "an admin can set a value in range, it persists, it is scoped to their fleet,
  out-of-range is rejected, and a cross-fleet caller cannot read or change another fleet's value."
- Deployment / data: "same as the rest of the product, nothing new."
- Non-goals: not stated.
- Failure mode if the setting service is down: not stated.
- Success metric: "admins stop emailing support to change retention."
