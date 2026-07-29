# EPIC-61 — Fleet compliance manager can review and revoke active sessions

Type: Epic · Status: Refined · TIER: feature

## Intent
A fleet compliance manager needs to see every active session for their own fleet and end any of them
immediately — the control they reach for first when a laptop is lost or a contractor leaves.

## Requirements Brief — docs/intent/EPIC-61-scope.md (vault scope note, review: founder-confirmed)
Resolved note content (reproduced here for this offline exercise):
- Users: fleet compliance managers. Auditors read the resulting duty events; they never revoke.
- Locked answers: sessions are listed for the caller's own fleet only; revocation takes effect on
  the next request, not lazily at token expiry; every revocation emits an duty events naming the
  actor, the subject session, and the reason.
- Failure modes: a partial revoke must fail closed — never report a session as ended if it was not.
- Non-goals: no cross-fleet session view, no bulk "revoke all fleets", no session replay/forensics.

## Prototype
ARTIFACT-AUTHORED-BY: human
Founder-supplied, high-fidelity, on the **Midnight Sovereign** design system.
Link: `.agency/prototype/SessionsConsole.jsx`

Screens and states the prototype specifies:
1. **Sessions list** — table of active sessions (device, location, IP, started-at, last-seen),
   sorted by last-seen descending. Row action: "Revoke".
2. **Revoke confirmation** — a hold-to-confirm control (the design system's `HoldToSign`), naming
   the session being ended and requiring a typed reason before the action enables.
3. **Empty state** — "No active sessions for this fleet", with the last-checked timestamp.
4. **Error state** — revoke failed: the row returns to active, an inline error names the failure,
   and the list is re-fetched rather than optimistically updated.
5. **In-flight state** — the revoked row is disabled with a spinner; the rest of the table stays
   interactive.

Tokens the prototype fixes: spacing scale, the destructive-action colour, the table density, and the
`HoldToSign` component's timing.

## Notes
No Design lane has been produced yet — the founder prototype is the authoritative visual input.
