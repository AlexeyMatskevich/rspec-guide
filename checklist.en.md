# RSpec Test Code Review Checklist

Quick RSpec test checklist for code review. Based on rules from [main guide](guide.en.md).

## Philosophy and Structure

- [ ] **Tests behavior, not implementation** ([rule 1](guide.en.md#1-test-behavior-not-implementation))
  - Doesn't mock internal calls
  - Uses proper matchers (`match_array` vs `eq`)
  - Description reads as business requirement

- [ ] **One `it` — one behavior** ([rule 3](guide.en.md#3-one-it--one-behavior))
  - No multiple unrelated expects
  - Uses `aggregate_failures` for checking single interface

- [ ] **Context hierarchy by characteristics** ([rule 4](guide.en.md#4-structure-tests-by-characteristics))
  - Each level = one characteristic
  - Dependent characteristics nested correctly

## Code Organization

- [ ] **Happy path before corner cases** ([rule 4.2](guide.en.md#42-build-the-hierarchy-dependent--independent))
- [ ] **Has positive and negative tests** ([rule 4.3](guide.en.md#43-positive--negative-test))
- [ ] **Context contains setup** ([rule 4.4](guide.en.md#44-each-context--one-difference))
- [ ] **Explicit `subject` where needed** ([rule 6](guide.en.md#6-declare-subject-explicitly))

## Data Preparation

- [ ] **Three phases: Given/When/Then** ([rule 5](guide.en.md#5-three-phases-given--when--then))
- [ ] **FactoryBot used correctly** ([rule 9](guide.en.md#9-factorybot-factories-traits-methods))
  - Traits instead of explicit attributes
  - `attributes_for` for parameters
  - `build_stubbed` in unit tests

- [ ] **No programming in tests** ([rule 7](guide.en.md#7-dont-program-in-tests))
- [ ] **Explicitness over DRY** ([rule 8](guide.en.md#8-explicitness-over-dry))

## Description Language

- [ ] **Descriptions read as sentences** ([rule 10.1](guide.en.md#101-context--it--valid-sentence))
- [ ] **Understandable to anyone** ([rule 10.1](guide.en.md#101-context--it--valid-sentence))
- [ ] **Proper grammar** ([rule 10.2](guide.en.md#102-grammar-present-simple-active-voice))
  - Present Simple, active voice in `it`
  - Passive voice for contexts
  - Explicit NOT for negations
- [ ] **Proper context language** ([rule 10.3](guide.en.md#103-context-keywords-whenwithandbutnot))
  - when for base characteristic
  - with for positive clarification
  - and for additional positive states
  - without for binary characteristics (alternative)
  - but for happy path contrast
  - NOT in caps for explicit negation

## Technical Aspects

- [ ] **No `any_instance` used** ([rule 12](guide.en.md#12-dont-use-any_instance))
- [ ] **`aggregate_failures` for one interface** ([rule 11](guide.en.md#11-aggregate_failures-for-interface-tests))
- [ ] **Verifying doubles** ([rule 13](guide.en.md#13-prefer-verifying-doubles))
  - `instance_double` instead of `double`
- [ ] **Shared examples for contracts** ([rule 14](guide.en.md#14-shared-examples-for-contracts))
- [ ] **Request specs instead of controller specs** ([rule 15](guide.en.md#15-request-specs-over-controller-specs))
- [ ] **Time stabilized** ([rule 16](guide.en.md#16-stabilize-time))
- [ ] **Readable failure output** ([rule 17](guide.en.md#17-make-failure-output-readable))

## Anti-patterns

- [ ] No tests for private methods
- [ ] No checking internal calls via `receive`
- [ ] No `sleep` in tests
- [ ] No dependency on execution order
- [ ] No hardcoded IDs from database

## Final Check

- [ ] Test fails when functionality breaks ([rule 2](guide.en.md#2-verify-that-the-test-catches-bugs))
- [ ] Descriptions help find problem on failure
- [ ] Newcomer understands what's being tested
- [ ] Test won't break during refactoring
