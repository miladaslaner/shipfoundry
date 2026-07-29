# STORY-60 — iOS: vehicle pairing screen

Status: Refined
Type label: ios

## AC Snapshot (frozen at Refined)

### Architecture constraints (epic)
- Deployment model: an iOS companion app for the fleet platform; the device may be shared or jailbroken.
- Secrets and tokens are stored in the Keychain, never UserDefaults or the bundle.
- All traffic over TLS; certificate pinning to the product backend.

### Acceptance criteria
- Given a signed-in admin, when they open the screen, then their vehicle pairing tokens load and display (name, masked value, created date).
- Given the tokens are loading, then a loading state shows; given none exist, then an empty state with a create prompt; given the load fails, then an error state with retry. (all states)
- Given the admin taps create, when a token is generated, then its full value is shown once and stored in the Keychain, never in UserDefaults.
- Given any screen element, then it is VoiceOver-labelled and respects Dynamic Type; user-facing strings are localized.
