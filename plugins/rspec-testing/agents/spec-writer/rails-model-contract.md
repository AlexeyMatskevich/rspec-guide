# Rails Model Contract (Spec Writer)

This document applies when `project_type: rails` and the `source_file` is under `app/models/`.

## What “Model Contract” Means

Model contract specs should verify **declarative guarantees** exposed by the model:

- Validations
- Associations
- Enums

These specs are not meant to test business logic methods (those remain in method-level specs driven by metadata behaviors/characteristics).

## Default Coverage

When working on a Rails model, prefer covering:

1. **Associations** (belongs_to/has_many/has_one/HABTM)
2. **Validations** (presence/length/numericality/inclusion/uniqueness)
3. **Enums** (if present)

Optional (only when explicit and stable in the codebase):
- Attribute normalization (e.g., downcasing an email) — prefer a focused behavior example, not a broad “valid/invalid” test.

## How to Implement Contract Checks

### With shoulda-matchers (preferred)

If `.claude/rspec-testing-config.yml` has `integrations.shoulda_matchers.enabled: true` and it is configured, use shoulda-matchers.
Read `spec-writer/shoulda-matchers.md` and use Context7 for exact syntax.

### Without shoulda-matchers

If shoulda-matchers is not available, do not try to recreate it.
Prefer:

- Minimal, behavior-focused specs for the parts that matter to the change
- Or ask the user whether to add shoulda-matchers for contract-level coverage

## Placement in the Spec File

Keep contract checks grouped and readable:

- `describe 'associations'`
- `describe 'validations'`
- `describe 'enums'` (if needed)

Do not mix these with method-level describe blocks that are generated from metadata.

