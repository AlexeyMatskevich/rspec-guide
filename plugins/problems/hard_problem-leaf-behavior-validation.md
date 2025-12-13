# Hard Problem: Early validation of leaf behavior_id

## Context
- Leaves are identified by presence of `behavior_id` (terminal and success).
- Currently the generator assumes correctness; validation happens late.

## Why Hard
- Needs coordination between code-analyzer (assigns behavior_id) and test-architect (consumes).
- Validation should fail fast with actionable feedback before generation.
- Must avoid double work when multiple methods/characteristics are present.

## Impact
- Missing `behavior_id` on leaf → generator may emit placeholders or skip, producing incomplete tests.
- Late detection wastes agent cycles; better to catch immediately after analysis.

## Proposal Directions
- Add a validation phase in code-analyzer output build:
  - Assert: every leaf (terminal or last branching value) has `behavior_id`.
  - Report per-method errors with source_line.
- Add a pre-flight check in test-architect:
  - Re-validate metadata before calling generator; stop with clear error listing offending values.
- Decide whether to auto-fill `{BEHAVIOR_DESCRIPTION}` placeholder vs hard stop; for hard_problem lean to hard stop.

## Open Questions
- Should validation be strict (hard stop) or allow fallback placeholders?
- Where to surface errors (ask user vs stop pipeline)?
- Do we need a “force” mode for legacy metadata without behavior_id?
