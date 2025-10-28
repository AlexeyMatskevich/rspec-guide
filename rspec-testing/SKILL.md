---
name: rspec-testing
description: Write and update RSpec tests following BDD principles with behavior-first approach, characteristic-based context hierarchy, and happy path priority. Use when creating new test files, adding test cases, or refactoring existing specs. Ensures tests describe observable behavior, not implementation details.
---

# RSpec Testing Skill

## When to Use This Skill

Use this skill when you need to:
- Create new test files for classes or modules
- Add test coverage for new methods or behaviors
- Update existing tests when adding features or fixing bugs
- Refactor tests to improve clarity or remove duplication
- Fix failing tests after code changes

## Core Principles

1. **Test behavior, not implementation** — Verify observable outcomes (return values, state changes, side effects), never internal method calls or instance variables
2. **One example, one behavior** — Each `it` tests a single observable rule
3. **Characteristic-based contexts** — Organize by conditions affecting behavior (user role, state, input type)
4. **Happy path first** — Write successful scenarios before edge cases and errors
5. **Clear descriptions** — `describe` + `context` + `it` form readable English sentences

## All 28 Rules

### Behavior and Test Structure

**Rule 1: Test behavior, not implementation**
- Check observable results: return values, HTTP responses, database state changes, side effects (emails, jobs)
- NEVER check: internal method calls with `receive`, private methods, instance variables
- If test needs `allow(...).to receive` for setup (not verification), that's acceptable

**Rule 2: Verify what test actually tests**
- After writing test, break the code intentionally (return wrong value, comment out logic, change condition)
- Test must fail (Red). If stays green, rewrite it
- This ensures test checks real behavior, not implementation accidents

**Rule 3: One `it` — one behavior**
- Each `it` describes one business rule with unique description
- Multiple independent side effects = separate `it` blocks
- Exception: interface testing (Rule 23) — use `:aggregate_failures` for related attributes of one object

**Rule 4: Identify characteristics**
- Characteristic = condition affecting behavior (user role, payment method, order status, input validity)
- List all characteristics, then list states for each (role: admin/customer; validity: valid/invalid)
- Each characteristic state = separate `context`

**Rule 5: Hierarchy by dependencies**
- Build `context` hierarchy from basic to refining characteristics
- One characteristic = one `context` level
- Happy path first, corner cases nested below
- Independent characteristics can be ordered flexibly, but always happy path before corner cases

**Rule 6: Final context audit**
- Check for duplicate `let`/`before` across sibling contexts → merge common setup to parent
- Check for identical `it` in all leaf contexts → extract to `shared_examples` (Rule 25)

**Rule 7: Happy path before corner cases**
- First context = successful scenario (authenticated user, valid input, sufficient balance)
- Then corner cases (unauthenticated, invalid, insufficient)
- Reader sees main scenario first, then exceptions

**Rule 8: Positive and negative tests**
- Check both successful result AND failure when applicable
- Example: valid input → success; invalid input → error

**Rule 9: Context differences**
- Each nested `context` must have its own setup (`let`, `before`, `subject`)
- Setup should be immediately under context declaration, not far away
- Context description must clearly reflect what distinguishes it from parent

### Syntax and Readability

**Rule 10: Specify `subject`**
- Declare `subject` explicitly at top level (not in nested contexts)
- Use named subject for clarity: `subject(:result) { user.some_action }`
- Especially useful when same result checked in multiple `it` across contexts

**Rule 11: Three test phases**
- Phase 1 (Given): Data preparation via `let` or factories
- Phase 2 (When): Action via `before` or explicit call in `it`
- Phase 3 (Then): Verification via `expect`
- NEVER mix phases (no data preparation + action + verification in one `before`)

### Context and Data Preparation

**Rule 12: Use FactoryBot**
- Hide data details unimportant for behavior in factories
- Use traits to document characteristic states (`:blocked`, `:verified`, `:premium`)
- Override only attributes critical for tested behavior

**Rule 13: `attributes_for` for parameters**
- Use `attributes_for(:model)` when generating parameter hashes (API requests, form objects, service calls)
- Override only critical attributes: `attributes_for(:order, segment: 'b2b')`
- DO NOT use when API interface differs from model attributes

**Rule 14: `build_stubbed` in units**
- Unit tests (except models): prefer `build_stubbed` (fastest, no DB)
- Integration tests: use `create` (DB interactions needed)
- Decision tree: model test → `create`; service/PORO test → `build_stubbed`

**Rule 15: Don't program in tests**
- NEVER use loops, conditionals, complex logic in tests
- Tests should be declarative, not procedural
- Avoid private helper methods with DB queries or complex calculations
- Use RSpec DSL (`let`, factories, matchers), not custom mini-framework

**Rule 16: Explicitness over DRY**
- Duplicate code if it makes test clearer
- Tests are behavior documentation — clarity > reducing duplication
- `let`, factories, shared examples are acceptable abstractions
- Avoid custom helper methods that hide important check details

### Specification Language

**Rule 17: Valid sentence**
- `describe` + `context` + `it` form grammatically correct English sentence
- Use Present Simple tense
- Example: "when user is blocked and duration is over a month, it allows unlocking"

**Rule 18: Understandable to anyone**
- Descriptions should be understandable without programming knowledge
- Use business language, not technical jargon
- Anyone should be able to read test descriptions and understand business rules

**Rule 19: Grammar**
- `describe`: noun or method name (`describe OrderProcessor`, `describe '#calculate'`)
- `context`: use "when/with/and/without/but" + state description
- `it`: verb in 3rd person, present tense (`it 'creates order'`, `it 'sends email'`)
- Avoid "should", "can", "must" — just state behavior directly

**Rule 20: Context language: when / with / and / without / but / NOT**

Follow Gherkin logic so branch reads as sequence of context clarifications:

- **`when …`** — Opens branch and describes base characteristic state. At this level often no `it` because branch clarifies further. Example: `context 'when user has a payment card'`
- **`with …`** — Introduces first clarifying positive state and continues happy path: `context 'with verified email'`
- **`and …`** — Adds another positive state in same direction. Can use several in a row while branch remains part of happy path: `context 'and balance covers the price'`
- **`without …`** — Use for binary characteristics when explicitly showing both polarities. Happy path described by positive state, so `without …` branch immediately contains test demonstrating alternative outcome: `context 'without verified email'`
- **`but …`** — Emphasizes happy path contrast. Often applied when happy path based on default state (separate `with` context not needed). Context `but …` must contain test showing how behavior changes when base context stops holding: `context 'but balance does NOT cover the price'`
- **`NOT`** — Use in CAPS inside context or `it` name to emphasize binary characteristic negative state or highlight negative test: `context 'when user does NOT have a payment card'`, `it 'does NOT charge the card'`

**Recommended sequence:** `when` → `with` → `and` (as needed) → `but`/`without` → `it`

**Important:** If `when`/`with`/`and`/`without`/`but` appears in `it` description, you lost corresponding context. Extract this state into `context`, otherwise example will mix Given and Then. Exception: negative formulations with `does NOT`, where `NOT` emphasizes result, not context.

**Pattern 1: Full hierarchy (when happy path needs explicit clarification):**
```ruby
context 'when user has a payment card' do        # base characteristic
  context 'with verified email' do               # happy path clarification
    context 'and balance covers the price' do    # another happy path state
      it 'charges the card'                      # happy path case
    end

    context 'but balance does NOT cover the price' do  # corner case: contrast
      it 'does NOT charge the card'                    # negative test
    end
  end

  context 'without verified email' do            # corner case: required state absence
    it 'does NOT charge the card'
  end
end
```

**Pattern 2: Happy path under `when` (when default state is sufficient):**
```ruby
context 'when account exists' do          # base branch
  it 'signs the user in'                  # happy path directly under when

  context 'but account is blocked' do     # corner case at same level
    it 'denies the sign-in'
  end
end
```

**Rule 21: Enforce naming with linter**
- Run project's linter (RuboCop or Standard) to check naming conventions
- Fix all naming violations before considering tests complete
- Linter output will show specific naming issues to correct

### Tools and Support

**Rule 22: Don't use `any_instance`**
- NEVER use `allow_any_instance_of` or `expect_any_instance_of`
- Use dependency injection instead: pass collaborators as parameters
- Refactor code if it requires `any_instance` — it's a design smell

**Rule 23: `:aggregate_failures` only for interfaces**
- One behavior = one `it`
- Multiple independent side effects = separate `it` blocks
- Use `:aggregate_failures` ONLY when checking multiple attributes of one object/interface
- Better: use `have_attributes` matcher (automatically shows all mismatches)
- Useful for CI-only or flaky tests where you need to see all failures at once

**Rule 24: Verifying doubles**
- Use `instance_double(Class)` instead of `double`
- Use `class_double(Class)` for class methods
- Use `object_double(object)` for specific object interfaces
- Verifying doubles check real interfaces and catch typos/contract changes

**Rule 25: Shared examples for contracts**
- Extract repeating contract checks to `shared_examples`
- Two use cases:
  1. Common behavior across classes (`shared_examples 'a pageable API'`)
  2. Invariant expectations in all leaf contexts (Rule 6)
- Name with formula: "a/an [adjective] noun" or abstract noun
- Connect with `it_behaves_like`

**Rule 26: Request specs over controller specs**
- Controller specs are deprecated
- Use Request specs — they check HTTP contract end-to-end
- For new tests, always choose Request specs

**Rule 27: Stabilize time**
- Use `ActiveSupport::Testing::TimeHelpers`: `freeze_time`, `travel_to`, `travel`
- ALWAYS add `after { travel_back }` when using non-block form
- Use `Time.zone.now`/`Time.current`, not `Time.now`
- In factories, use blocks for time: `created_at { 1.day.ago }`

**Rule 28: Readable failure output**
- Use structural matchers (`match_array`, `include`, `have_attributes`)
- NEVER compare JSON as strings — parse first, then use structural expectations
- Parse complex data before comparison (`JSON.parse`, `response.parsed_body`)
- Failure output should instantly explain expected vs actual behavior

## Common Patterns

### Characteristic Hierarchy (Rules 4-5)

```ruby
describe '#calculate_discount' do
  # Level 1: Segment (basic characteristic)
  context 'when segment is b2c' do
    let(:segment) { :b2c }

    # Level 2: Premium status (depends on segment existing)
    context 'with premium subscription' do
      let(:premium) { true }
      it('applies 20% discount') { expect(discount).to eq(0.20) }
    end

    context 'without premium subscription' do
      let(:premium) { false }
      it('applies 5% discount') { expect(discount).to eq(0.05) }
    end
  end
end
```

### Three Phases (Rule 11)

```ruby
describe '#block_user' do
  # Phase 1: Preparation
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }

  # Phase 2: Action
  before { admin.block(user) }

  # Phase 3: Verification
  it 'marks user as blocked' do
    expect(user.reload.blocked?).to be true
  end
end
```

### FactoryBot Strategy (Rule 14)

```ruby
# Unit test (service/PORO): build_stubbed
let(:user) { build_stubbed(:user, :premium) }

# Integration test: create
let(:user) { create(:user, :premium) }

# Model test: always create
let(:user) { create(:user, :premium) }
```

### Context Language (Rule 20)

```ruby
context 'when user has card' do              # introduces characteristic
  context 'and balance covers price' do      # adds characteristic (happy path)
    it 'charges card'
  end

  context 'but balance does NOT cover price' do  # negation (corner case)
    it 'rejects purchase'
  end
end
```

### aggregate_failures vs Separate Tests (Rule 23)

```ruby
# Use aggregate_failures for ONE object interface
it 'exposes profile attributes', :aggregate_failures do
  expect(profile.full_name).to eq('John')
  expect(profile.email).to eq('john@example.com')
  expect(profile.type).to eq('premium')
end

# Better: use have_attributes
it 'exposes profile attributes' do
  expect(profile).to have_attributes(
    full_name: 'John',
    email: 'john@example.com',
    type: 'premium'
  )
end

# Separate tests for INDEPENDENT side effects
it('creates user') { expect { action }.to change(User, :count).by(1) }
it('sends email') { expect { action }.to have_enqueued_mail }
```

## Validation Workflow

After writing or updating tests:

### 1. Run Linter

Use project's configured linter (RuboCop, Standard, or custom):

```bash
bundle exec rubocop spec/path/to/file_spec.rb
# OR
bundle exec standardrb spec/path/to/file_spec.rb
```

Fix all style violations before proceeding.

### 2. Run Tests

```bash
# Run specific file
bundle exec rspec spec/path/to/file_spec.rb

# Run all tests if changes might affect other files
bundle exec rspec
```

### 3. Verify Red (Rule 2)

Break the code intentionally and ensure tests fail:
- Comment out key logic
- Return wrong value (`return nil`, `return 0`)
- Change condition (`if` → `unless`, `>` → `<`)

If test stays green when code is broken, rewrite the test.

### 4. Iterate Until Green

If tests fail:
- Read error message carefully — it tells you what's wrong
- Fix test or code as needed
- Rerun until all green

If linter reports issues:
- Fix style issues
- Rerun linter until 0 offenses

## Quick Checklist

Before considering tests complete:

### Structure and Behavior
- [ ] Tests describe **behavior** (observable outcomes), not implementation
- [ ] Each `it` tests **one behavior** with unique description
- [ ] **Happy path comes first** in each context group
- [ ] Each context has **unique setup** (`let` or `before`)
- [ ] `subject` defined **at top level** only (not in nested contexts)

### Final Context Audit (Rule 6)
- [ ] **Check `let`/`before` duplicates:** Review sibling contexts for identical `let`/`before` values — if found, lift common setup to parent context
- [ ] **Check `it` duplicates:** Review all leaf contexts — if same `it` appears in ALL leaf contexts, extract to `shared_examples` (these are interface invariants)
- [ ] **Verify characteristic coverage:** Cross-check that all identified characteristic states have corresponding contexts

### Language and Style
- [ ] Descriptions form **valid English sentences**
- [ ] Context names use **when/with/and/without/but/NOT**
- [ ] Three phases: Preparation → Action → Verification
- [ ] FactoryBot used to hide unimportant data details
- [ ] `build_stubbed` in unit tests (except models)
- [ ] No programming in tests (no loops, conditionals, complex logic)

### Tools and Verification
- [ ] Verifying doubles (`instance_double`) instead of `double`
- [ ] Time stabilized with `freeze_time`/`travel_to` + `travel_back`
- [ ] **Linter shows 0 offenses**
- [ ] **All tests are green**
- [ ] **Tests verified by breaking code (Rule 2)** — intentionally break code, ensure tests fail
