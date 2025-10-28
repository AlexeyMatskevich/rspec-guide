# RSpec Style Guide Review Checklist

Use this checklist to review RSpec tests for compliance with our style guide.

## Structure & Organization

- [ ] **Multiple contexts present**: At least 2 contexts per describe (happy path + edge case)
  - Enforced by: `RSpecGuide/CharacteristicsAndContexts`

- [ ] **Happy path first**: Success scenarios come before error/edge cases
  - Enforced by: `RSpecGuide/HappyPathFirst`

- [ ] **Characteristic-based hierarchy**: Each context level represents one independent characteristic
  - Check: No mixing of multiple conditions in one context name

- [ ] **Context naming conventions**: Uses "when/with/without/and/but" appropriately
  - "when" for states/actions
  - "with/without" for presence/absence
  - "but" for exceptions to happy path

## Setup & Configuration

- [ ] **Subject placement**: Defined at top-level describe only, never in contexts
  - Enforced by: `RSpec/LeadingSubject`, `RSpecGuide/ContextSetup`

- [ ] **Unique context setup**: Each context has distinct `let`, `let!`, or `before`
  - Enforced by: `RSpecGuide/ContextSetup`

- [ ] **No duplicate setup**: No identical `let` or `before` in sibling contexts
  - Enforced by: `RSpecGuide/DuplicateLetValues`, `RSpecGuide/DuplicateBeforeHooks`

- [ ] **Common setup lifted**: Shared setup moved to parent context/describe
  - Check: No partial duplication warnings

## Examples & Expectations

- [ ] **Behavior-focused tests**: Tests verify outcomes, not implementation
  - Check: No `expect(obj).to receive(:internal_method)`
  - Check: No testing of private methods

- [ ] **Clear descriptions**: `it` blocks form complete sentences with context
  - Example: context + it = "with valid input, it returns success"

- [ ] **No duplicate examples**: Identical tests across contexts use `shared_examples`
  - Enforced by: `RSpecGuide/InvariantExamples`

- [ ] **One behavior per test**: Each `it` tests a single observable outcome
  - Exception: Can use `aggregate_failures` for related assertions

## Data & Factories

- [ ] **Dynamic attributes**: Time/random in factories use blocks `{ }`
  - Enforced by: `FactoryBotGuide/DynamicAttributesForTimeAndRandom`
  - Good: `created_at { Time.now }`
  - Bad: `created_at Time.now`

- [ ] **FactoryBot usage**: Uses factories instead of hand-coded data
  - Check: Uses traits for variations
  - Check: `build_stubbed` for unit tests, `create` for integration

- [ ] **Time stability**: Time-dependent tests use helpers like `travel_to`
  - Check: No dependency on wall-clock time

## Integration Tests

- [ ] **High-level focus**: Tests layer integration, not unit details
  - Check: Not duplicating model validations
  - Check: Testing end-to-end flow

- [ ] **Domain-based combining**: Groups auth → authorization → business logic
  - Check: One scenario per layer maximum

## Anti-patterns to Avoid

- [ ] **No `any_instance`**: Doesn't use `allow_any_instance_of`
  - Use dependency injection instead

- [ ] **No `should` syntax**: Uses modern `expect` syntax
  - Check: No deprecated RSpec features

- [ ] **No sleep in tests**: No `sleep` or time-based waits
  - Use proper test doubles or time helpers

- [ ] **No test order dependency**: Tests run independently
  - Check: Random test order doesn't cause failures

## Final Validation

- [ ] **RuboCop clean**: `bundle exec rubocop` shows 0 offenses
  - All `RSpecGuide/*` cops pass
  - All `FactoryBotGuide/*` cops pass

- [ ] **Tests pass**: `bundle exec rspec` is 100% green
  - No pending or skipped tests without reason

- [ ] **Readable flow**: Spec file tells coherent story of behavior
  - Can understand behavior without reading implementation

## Quick Command

Run these commands to validate:
```bash
bundle exec rubocop -DES
bundle exec rspec
```

Both should complete successfully with no errors or warnings.