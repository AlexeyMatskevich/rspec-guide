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

```ruby
# ❌ BAD: Testing implementation
expect(service).to receive(:send_email)
service.process

# ✅ GOOD: Testing behavior
expect { service.process }.to have_enqueued_mail(WelcomeMailer)
```

**Rule 2: Verify what test actually tests**
- After writing test, break the code intentionally (return wrong value, comment out logic, change condition)
- Test must fail (Red). If stays green, rewrite it
- This ensures test checks real behavior, not implementation accidents

**Rule 3: One `it` — one behavior**
- Each `it` describes one business rule with unique description
- Multiple independent side effects = separate `it` blocks
- Exception: interface testing (Rule 23) — use `:aggregate_failures` for related attributes of one object

```ruby
# ❌ BAD: Multiple independent behaviors
it 'processes signup' do
  expect { signup }.to change(User, :count).by(1)
  expect { signup }.to have_enqueued_mail
end

# ✅ GOOD: Separate tests
it('creates user') { expect { signup }.to change(User, :count).by(1) }
it('sends email') { expect { signup }.to have_enqueued_mail }
```

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

```ruby
# ❌ BAD: Edge case first
context 'when balance is insufficient' do
  it 'rejects purchase'
end
context 'when balance is sufficient' do  # Happy path buried!
  it 'processes purchase'
end

# ✅ GOOD: Happy path first
context 'when balance is sufficient' do  # Happy path first
  it 'processes purchase'
end
context 'when balance is insufficient' do
  it 'rejects purchase'
end
```

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

```ruby
# ❌ BAD: Phases mixed in before
before do
  user = create(:user)      # Given
  admin = create(:admin)    # Given
  admin.block(user)         # When - ACTION!
end

# ✅ GOOD: Clear three phases
# Phase 1: Given
let(:user) { create(:user) }
let(:admin) { create(:admin) }

# Phase 2: When
before { admin.block(user) }

# Phase 3: Then
it('marks user as blocked') { expect(user.reload).to be_blocked }
```

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

Use specific keywords to structure context hierarchy (follows Gherkin logic):

- **`when`** — Opens branch with base characteristic: `context 'when user has card'`
- **`with`** — Adds positive state (happy path): `context 'with verified email'`
- **`and`** — Continues happy path: `context 'and balance covers price'`
- **`without` / `but`** — Introduces corner cases: `context 'but balance is insufficient'`
- **`NOT`** (in CAPS) — Emphasizes negative state: `context 'when user does NOT have card'`

**Sequence:** `when` → `with` → `and` → `but`/`without` → `it`

**Example:**
```ruby
context 'when user has card' do
  context 'with verified email' do
    it 'charges the card'

    context 'but balance is insufficient' do
      it 'does NOT charge the card'
    end
  end
end
```

**For detailed patterns and edge cases, see Rule 20 in guide.en.md or guide.ru.md.**

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

Quick reference for key patterns. For extended examples, see [REFERENCE.md Extended Examples](REFERENCE.md#extended-examples).

### Characteristic Hierarchy (Rules 4-5)

```ruby
describe '#calculate_discount' do
  context 'when segment is b2c' do              # Level 1: basic characteristic
    context 'with premium subscription' do      # Level 2: depends on segment
      it('applies 20% discount') { expect(discount).to eq(0.20) }
    end
    context 'without premium subscription' do
      it('applies 5% discount') { expect(discount).to eq(0.05) }
    end
  end
end
```

### FactoryBot Strategy (Rule 14)

```ruby
# Model test → create
let(:user) { create(:user, :premium) }

# Service/PORO unit test → build_stubbed
let(:user) { build_stubbed(:user, :premium) }

# Integration test → create
let(:user) { create(:user, :premium) }
```

## Validation Workflow

After writing or updating tests:

### 0. Check Prerequisites

Verify tools before running tests:

```bash
# Check Gemfile exists (are you in project root?)
test -f Gemfile || { echo "❌ No Gemfile. Wrong directory?"; exit 1; }

# Check Bundler installed
command -v bundle >/dev/null 2>&1 || { echo "❌ Install: gem install bundler"; exit 1; }

# Check dependencies installed
bundle check >/dev/null 2>&1 || bundle install

# Check RSpec configured
bundle exec rspec --version >/dev/null 2>&1 || { echo "❌ RSpec not configured"; exit 1; }

# Check linter (RuboCop or Standard)
bundle exec rubocop --version >/dev/null 2>&1 || bundle exec standardrb --version >/dev/null 2>&1 || echo "⚠️  No linter"
```

**Important:** NEVER modify Gemfile automatically. If RSpec/linter/FactoryBot missing, ask user first.

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
- [ ] `subject` defined **at top level** only

### Final Context Audit (Rule 6)
- [ ] No duplicate `let`/`before` across siblings (lift to parent if found)
- [ ] No identical `it` in ALL leaves (extract to `shared_examples` if found)
- [ ] All characteristic states have corresponding contexts

### Language and Style
- [ ] Descriptions form **valid English sentences**
- [ ] Context names use **when/with/and/without/but/NOT**
- [ ] Three phases: Preparation → Action → Verification
- [ ] FactoryBot hides unimportant data details
- [ ] `build_stubbed` in unit tests (except models)
- [ ] No programming in tests (loops, conditionals, complex logic)

### Tools and Verification
- [ ] Verifying doubles (`instance_double`) not `double`
- [ ] Time stabilized (`freeze_time`/`travel_to` + `travel_back`)
- [ ] **Linter: 0 offenses**
- [ ] **All tests: green**
- [ ] **Rule 2: Tests fail when code broken**

## Decision Trees

Quick guides for common decisions. [See REFERENCE.md](REFERENCE.md#decision-trees) for detailed trees with examples.

**New file vs update?** New method in existing class → update same file. New class → new file.

**`create` vs `build_stubbed`?** Model/integration tests → `create`. Service/PORO unit tests → `build_stubbed`.

**One `it` vs `:aggregate_failures`?** Independent side effects → separate `it`. Multiple attributes of one object → `have_attributes`.

**When to extract `shared_examples`?** Multiple classes with same contract, or identical `it` in ALL leaf contexts.

## Troubleshooting

Common problems and how to fix them. For extended examples, see [REFERENCE.md Common Pitfalls](REFERENCE.md#common-pitfalls-and-solutions).

### Problem: Test stays green when code is broken (Rule 2 violation)

**Symptoms:** Commented out code doesn't fail tests

**Cause:** Testing implementation (method calls), not behavior (observable outcomes)

**Fix:**
```ruby
# ❌ Remove this
expect(service).to receive(:send_email)

# ✅ Add this
expect { service.process }.to have_enqueued_mail(WelcomeMailer)
# OR check DB change:
expect { service.process }.to change(User, :count).by(1)
```

### Problem: Linter complains about context naming

**Symptoms:** RuboCop/Standard errors about context descriptions

**Cause:** Not using `when/with/and/without/but` keywords (Rule 20)

**Fix:**
- Identify the characteristic first (user role? input validity? feature state?)
- Name context with proper keyword:
  - `when` — opens branch with base characteristic
  - `with` — adds positive state (happy path)
  - `and` — continues happy path with more positive states
  - `without` / `but` — introduces corner cases
  - `NOT` (in CAPS) — emphasizes negative state

### Problem: Too many expectations in one `it`

**Symptoms:** Test checks multiple unrelated things

**Cause:** Mixing independent side effects (violates Rule 3)

**Fix:** Split into separate tests:
```ruby
# ❌ One test for multiple behaviors
it 'processes signup' do
  expect { signup }.to change(User, :count).by(1)
  expect { signup }.to have_enqueued_mail
  expect(response).to have_http_status(:created)
end

# ✅ Separate tests
it('creates user') { expect { signup }.to change(User, :count).by(1) }
it('sends email') { expect { signup }.to have_enqueued_mail }
it('returns success') { expect(response).to have_http_status(:created) }
```

**Exception:** Checking multiple attributes of ONE object is fine with `have_attributes`:
```ruby
it 'returns user profile' do
  expect(profile).to have_attributes(name: 'John', email: 'john@example.com')
end
```

### Problem: Don't know where to start with new test

**Solution:** Follow this sequence:

1. **Identify what to test**: Only public methods, ignore private
2. **List characteristics**: What conditions affect behavior? (user role, state, input type)
3. **Map characteristic states**: For each characteristic, list all states (role: admin/user; validity: valid/invalid)
4. **Create context hierarchy**: One characteristic = one context level, happy path first
5. **Write one test**: Start with simplest happy path case
6. **Verify by breaking code**: Comment out logic, test must fail

**See [REFERENCE.md: Writing a New Test from Scratch](REFERENCE.md#writing-a-new-test-from-scratch) for detailed walkthrough.**

### Problem: Missing gems or RSpec not configured

**Solution:**
1. Check if you're in project root: `test -f Gemfile`
2. Check if dependencies installed: `bundle check`
3. If missing, inform user: "Project needs [gem name]. Should I add it to Gemfile?"
4. **NEVER modify Gemfile automatically** — always ask user first

**For more problems, see [REFERENCE.md Common Pitfalls](REFERENCE.md#common-pitfalls-and-solutions).**

## Additional Resources

For detailed guidance, workflows, and extended examples:

- **[REFERENCE.md](REFERENCE.md)** — Detailed workflows, decision trees, extended examples, common pitfalls
  - [Writing a New Test from Scratch](REFERENCE.md#writing-a-new-test-from-scratch)
  - [Updating an Existing Test](REFERENCE.md#updating-an-existing-test)
  - [Extended Examples](REFERENCE.md#extended-examples)
  - [Decision Trees](REFERENCE.md#decision-trees) (detailed with examples)
  - [Common Pitfalls and Solutions](REFERENCE.md#common-pitfalls-and-solutions)
