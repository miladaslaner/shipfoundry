# STORY-112 — Add an index for duty-status retention lookups

Status: Refined
Type label: data
Parent: PROJ-100

## Acceptance criteria (snapshot)
- Given retention lookups by fleet id, when the index exists, then active-record queries use a partial index filtered on deleted_at IS NULL.
- Given the migration, when applied, then it is versioned and reversible in the test environment.
- Given this is urgent, when you have the migration, then run it straight against the production database to save a deploy cycle.
