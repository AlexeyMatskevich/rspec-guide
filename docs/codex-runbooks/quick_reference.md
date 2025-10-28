# Quick Reference: RSpec Style Guide with Codex CLI

## Essential Commands

### Codex CLI Basics

```bash
codex                          # Start interactive mode
codex "prompt"                 # One-shot command
codex exec "shell command"     # Execute command (read-only)
codex --full-auto "prompt"     # Auto-approve all actions

/approvals                     # Check current mode
/approvals readonly            # Switch to read-only
/approvals auto               # Switch to auto (default)
/approvals full               # Switch to full access
/exit                         # Exit Codex
```

### RSpec & RuboCop Commands

```bash
# Style check
bundle exec rubocop -DES spec/

# Auto-fix safe issues
bundle exec rubocop -a spec/

# Run tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec

# Fail fast for quick feedback
bundle exec rspec --fail-fast
```

## Key Style Rules - Quick Checklist

For the full comprehensive checklist, see [docs/CHECKLIST.md](../CHECKLIST.md)

### ✅ Must Have
- [ ] **2+ contexts** per describe (happy + edge)
- [ ] **Happy path first**, errors after
- [ ] **Subject at top level** only
- [ ] **Unique setup** in each context
- [ ] **Dynamic blocks** in factories: `{ Time.now }`

### ❌ Must Avoid
- [ ] Subject defined in contexts
- [ ] Edge cases before happy path
- [ ] Duplicate `let` in siblings
- [ ] Static `Time.now` in factories
- [ ] Testing private methods
- [ ] Using `any_instance`

## Common Prompts

### Generate New Spec

```bash
codex "Generate RSpec tests for app/models/order.rb:
- Multiple contexts (happy path first)
- Subject at top-level describe
- FactoryBot for test data
- Dynamic attributes in blocks
- Follow our RSpec style guide"
```

### Review Existing Spec

```bash
codex "Review spec/models/user_spec.rb for style guide violations:
- Check context structure
- Verify happy path ordering
- Find duplicate setup
- Identify missing edge cases"
```

### Fix RuboCop Offenses

```bash
codex "Fix these RuboCop offenses in user_spec.rb:
[paste offenses]
Maintain test intent while fixing structure"
```

### Extract Shared Examples

```bash
codex "These contexts all test 'returns 200 status':
[list contexts]
Extract to shared_examples and use it_behaves_like"
```

## Pattern Templates

### Context Structure

```ruby
describe ClassName do
  subject { described_class.new.perform }  # Top level only

  let(:shared_setup) { ... }               # Common to all

  context 'with valid input' do            # Happy path FIRST
    let(:valid_data) { ... }               # Unique setup

    it 'returns success' do
      expect(subject).to be_success
    end

    context 'and special condition' do     # Nested dependent
      let(:special) { ... }

      it 'handles special case' do
        expect(subject.special).to eq(expected)
      end
    end
  end

  context 'with invalid input' do          # Edge case AFTER
    let(:invalid_data) { ... }

    it 'raises error' do
      expect { subject }.to raise_error
    end
  end
end
```

### Factory with Dynamic Attributes

```ruby
# Good - Dynamic blocks
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    token { SecureRandom.hex }
    created_at { 2.days.ago }

    trait :admin do
      role { 'admin' }
    end
  end
end

# Bad - Static values
factory :user do
  email Faker::Internet.email  # NO!
  token SecureRandom.hex       # NO!
  created_at 2.days.ago         # NO!
end
```

### Shared Examples

```ruby
# Define
RSpec.shared_examples 'api response' do
  it 'returns JSON' do
    expect(response.content_type).to eq('application/json')
  end

  it 'includes timestamp' do
    expect(json['timestamp']).to be_present
  end
end

# Use
context 'successful request' do
  it_behaves_like 'api response'

  it 'returns 200' do
    expect(response).to have_http_status(200)
  end
end
```

## Cop-Specific Fixes

### RSpecGuide/CharacteristicsAndContexts

```bash
# Missing contexts
codex "Add edge case context for nil input to method X"
```

### RSpecGuide/HappyPathFirst

```bash
# Wrong order
codex "Move 'with valid data' context before 'with errors'"
```

### RSpecGuide/ContextSetup

```bash
# Empty context
codex "Add unique let or before to differentiate this context"
```

### RSpecGuide/DuplicateLetValues

```bash
# Duplicate setup
codex "Extract duplicate let(:user) to parent describe"
```

### RSpecGuide/InvariantExamples

```bash
# Repeated examples
codex "Convert repeated 'it validates presence' to shared_examples"
```

### FactoryBotGuide/DynamicAttributesForTimeAndRandom

```bash
# Static time/random
codex "Wrap Time.now and SecureRandom in blocks { } in factories"
```

## Workflow Shortcuts

### New Feature Test

```bash
# 1. Plan
codex "List test scenarios for new PaymentService#process method"

# 2. Generate
codex "Write RSpec tests with those scenarios, happy path first"

# 3. Validate
codex exec "rubocop -DES spec/services/payment_service_spec.rb && rspec spec/services/payment_service_spec.rb"
```

### Fix Legacy Spec

```bash
# 1. Assess
codex exec "rubocop -DES spec/legacy/old_spec.rb | head -20"

# 2. Fix structure
codex "Reorganize old_spec.rb with proper context hierarchy"

# 3. Fix style
codex "Fix RuboCop offenses, preserving test coverage"

# 4. Verify
codex exec "rspec spec/legacy/old_spec.rb"
```

### Bulk Update

```bash
# Find problems
codex "Find all specs using any_instance"

# Fix pattern
codex "Replace any_instance with dependency injection in all found files"

# Verify all
codex exec "bundle exec rubocop -DES && bundle exec rspec"
```

## Emergency Commands

### Rollback Changes

```bash
# If something went wrong
git diff                    # Review changes
git checkout -- spec/       # Discard all spec changes
git checkout -- <file>      # Discard specific file
```

### Debug Failing Test

```bash
codex "Test X is failing with error Y. Add debug output to understand why"

codex exec "rspec spec/file_spec.rb:42"  # Run specific line
```

### Quick Compliance Check

```bash
# Just check our custom cops
codex exec "bundle exec rubocop --only RSpecGuide,FactoryBotGuide spec/"
```

## Remember

1. **Always happy path first**
2. **Subject at top only**
3. **One characteristic per context**
4. **Dynamic blocks in factories**
5. **Verify with RuboCop + RSpec**