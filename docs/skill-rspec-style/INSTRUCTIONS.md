# RSpec Style Guide Instructions for Claude

## Core Rules (DO's and DON'Ts)

### DO's:
- ✅ Test observable behavior and outcomes, not internal implementation
- ✅ Define `subject` at the top-level `describe` only
- ✅ Structure contexts by independent characteristics (one per level)
- ✅ Write happy path examples before edge cases
- ✅ Provide unique setup in each context using `let` or `before`
- ✅ Use FactoryBot with dynamic blocks for time/random: `{ Time.now }`
- ✅ Extract identical examples across contexts into `shared_examples`
- ✅ Use descriptive context naming: "when/with/without"
- ✅ Ensure at least 2 contexts per describe (happy + edge)
- ✅ Run RuboCop and RSpec to validate before completion

### DON'Ts:
- ❌ Don't test private methods or internal state
- ❌ Don't define `subject` inside contexts
- ❌ Don't put edge cases before happy path
- ❌ Don't create empty contexts without setup
- ❌ Don't duplicate `let` or `before` in sibling contexts
- ❌ Don't use static time/random in factories: `Time.now` (bad)
- ❌ Don't use `any_instance` or `allow_any_instance_of`
- ❌ Don't over-DRY tests at the cost of clarity
- ❌ Don't test implementation details in integration specs

## Step-by-Step Algorithm

### 1. Identify the SUT (Subject Under Test)
- Determine the class/method being tested
- Create top-level `describe` block
- Define `subject` at describe level only

### 2. Map Characteristics and Contexts
- List independent characteristics (user type, state, input)
- Create context hierarchy (one characteristic per level)
- Plan dependent characteristics as nested contexts

### 3. Implement Happy Path First
- Write successful/normal case scenario first
- Add context "with valid input" or similar
- Include minimal setup needed

### 4. Add Edge Cases
- Add at least one negative/edge case context
- Place after happy path (order matters!)
- Test error conditions, boundaries, nil inputs

### 5. Provide Distinct Setup
- Each context must have unique `let`, `let!`, or `before`
- Extract common setup to parent level
- Never redefine `subject` in contexts

### 6. Write Behavior-Focused Examples
- Each `it` describes one observable outcome
- Use clear, present-tense descriptions
- Verify results, not method calls

### 7. Handle Duplication
- Move duplicate `let` to parent context
- Convert repeated examples to `shared_examples`
- Use `it_behaves_like` to include shared behavior

### 8. Use Factories Correctly
- Use FactoryBot for test data
- Dynamic attributes in blocks: `{ SecureRandom.hex }`
- Use traits for variations: `create(:user, :admin)`
- Stabilize time with helpers: `travel_to`

### 9. Integration Test Focus
- Test layer integration, not unit details
- Combine auth → authorization → business logic
- Avoid duplicating unit test coverage

### 10. Run Automated Checks
- Execute: `bundle exec rubocop -DES`
- Fix all RSpecGuide/* offenses
- Execute: `bundle exec rspec`
- Iterate until 0 offenses and all green

## Context Structure Pattern

```ruby
describe SomeClass do
  subject { described_class.new.perform }  # At top level only!

  context 'when characteristic A' do    # Independent
    let(:setup_a) { ... }               # Unique setup

    context 'with characteristic B' do  # Dependent on A
      let(:setup_b) { ... }

      it 'successful behavior' do       # Happy path first
        expect(subject).to ...
      end

      it 'handles edge case' do         # Edge cases after
        expect { subject }.to raise_error
      end
    end
  end
end
```

## Quick Validation

Before considering tests complete, ensure:
- [ ] At least 2 contexts (happy + edge)
- [ ] Happy path listed first
- [ ] Each context has unique setup
- [ ] No duplicate let/before across siblings
- [ ] Subject defined at top level only
- [ ] Factories use dynamic blocks for time/random
- [ ] RuboCop shows 0 offenses
- [ ] All tests pass (green)