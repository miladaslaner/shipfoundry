# STORY-92 — Design: vehicle pairing screen

Status: Backlog
Type label: design
Artifact-authored-by run: run-d4

## Design

A screen where a fleet compliance manager views and revokes their vehicle pairing tokens.

### Layout

A page titled "API Tokens". A table lists each token: a name, a masked key, the created date, and
a "Revoke" button per row. Above the table, a "Create token" button opens a dialog with a name
field and a "Generate" button; on generate, the new token's full value shows once in a success
banner.

The table is populated with the fleet's tokens. Colours: a blue (#3B6CF5) primary button, white
background, grey table borders. The body font is whatever the app already uses.

That is the screen.
