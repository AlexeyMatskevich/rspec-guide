# RSpec Test Code Review Checklist

Quick RSpec test checklist for code review. Based on rules from [main guide](guide.en.md).

## 🎯 Philosophy and Structure

- [ ] **Tests behavior, not implementation** ([rule 1](guide.en.md#1-test-behavior-not-implementation))
  - Doesn't mock internal calls
  - Uses proper matchers (`match_array` vs `eq`)
  - Description reads as business requirement

- [ ] **One `it` — one behavior** ([rule 3](guide.en.md#3-each-example-it-describes-one-observable-behavior))
  - No multiple unrelated expects
  - Uses `aggregate_failures` for checking single interface

- [ ] **Context hierarchy by characteristics** ([rule 5](guide.en.md#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases))
  - Each level = one characteristic
  - Dependent characteristics nested correctly

## 📝 Code Organization

- [ ] **Happy path before corner cases** ([rule 7](guide.en.md#7-place-happy-path-before-corner-cases))
- [ ] **Has positive and negative tests** ([rule 8](guide.en.md#8-write-positive-and-negative-tests))
- [ ] **Context contains setup** ([rule 9](guide.en.md#9-each-context-should-reflect-the-difference-from-the-outer-scope))
- [ ] **Explicit `subject` where needed** ([rule 10](guide.en.md#10-specify-subject-to-explicitly-designate-what-is-being-tested))

## 🔧 Data Preparation

- [ ] **Three phases: Given/When/Then** ([rule 11](guide.en.md#11-each-test-should-be-divided-into-3-phases-in-strict-order))
- [ ] **FactoryBot used correctly** ([rules 12-14](guide.en.md#12-use-factorybot-capabilities-to-hide-test-data-details))
  - Traits instead of explicit attributes
  - `attributes_for` for parameters
  - `build_stubbed` in unit tests

- [ ] **No programming in tests** ([rule 15](guide.en.md#15-dont-program-in-tests))
- [ ] **Explicitness over DRY** ([rule 16](guide.en.md#16-explicitness-over-dry))

## 💬 Description Language

- [ ] **Descriptions read as sentences** ([rule 17](guide.en.md#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english))
- [ ] **Understandable to anyone** ([rule 18](guide.en.md#18-description-of-contexts-context-and-test-cases-it-together-including-it-should-be-written-so-that-anyone-understands))
- [ ] **Proper grammar** ([rule 19](guide.en.md#19-grammar-of-describecontextit-formulations))
  - Present Simple, active voice in `it`
  - Passive voice for contexts
  - Explicit NOT for negations
- [ ] **Proper context language** ([rule 20](guide.en.md#20-context-language-when--with--and--without--but--not))
  - when for base characteristic
  - with for positive clarification
  - and for additional positive states
  - without for binary characteristics (alternative)
  - but for happy path contrast
  - NOT in caps for explicit negation

## ⚙️ Technical Aspects

- [ ] **No `any_instance` used** ([rule 22](guide.en.md#22-dont-use-any_instance-allow_any_instance_of-expect_any_instance_of))
- [ ] **`aggregate_failures` for one rule** ([rule 23](guide.en.md#23-use-aggregate_failures-only-when-describing-one-rule))
- [ ] **Verifying doubles** ([rule 24](guide.en.md#24-prefer-verifying-doubles-instance_double-class_double-object_double))
  - `instance_double` instead of `double`
- [ ] **Shared examples for contracts** ([rule 25](guide.en.md#25-use-shared-examples-to-declare-contracts))
- [ ] **Request specs instead of controller specs** ([rule 26](guide.en.md#26-prefer-request-specs-over-controller-specs))
- [ ] **Time stabilized** ([rule 27](guide.en.md#27-stabilize-time-with-activesupporttestingtimehelpers))
- [ ] **Readable failure output** ([rule 28](guide.en.md#28-make-test-failure-output-readable))

## 🚫 Anti-patterns

- [ ] No tests for private methods
- [ ] No checking internal calls via `receive`
- [ ] No `sleep` in tests
- [ ] No dependency on execution order
- [ ] No hardcoded IDs from database

## ✅ Final Check

- [ ] Test fails when functionality breaks ([rule 2](guide.en.md#2-verify-what-the-test-actually-tests))
- [ ] Descriptions help find problem on failure
- [ ] Newcomer understands what's being tested
- [ ] Test won't break during refactoring
