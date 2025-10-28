# Runbook: Review Existing RSpec Tests with Codex CLI

This runbook guides you through reviewing and fixing existing RSpec tests to comply with our style guide.

## Purpose

Use this when you have existing tests that need to be brought into compliance with the RSpec style guide.

## Step-by-Step Process

### 1. Initial Assessment

Start in **Read-Only mode** to analyze without changes:

```bash
codex
```

Get an overview:

> "Review `spec/models/user_spec.rb` and list any violations of our RSpec style guide. Check for:
> - Missing contexts (needs happy + edge cases)
> - Wrong ordering (edge cases before happy path)
> - Subject defined in contexts instead of top level
> - Duplicate let/before in siblings
> - Identical examples that should be shared
> - Static Time.now in factories"

### 2. Run Automated Checks

Execute RuboCop with our custom cops:

```bash
codex exec "bundle exec rubocop -DES spec/models/user_spec.rb"
```

Save the output for reference.

### 3. Create Fix Plan

Based on the assessment, create a prioritized fix list:

```bash
codex "Based on these RuboCop offenses:
[paste offenses]

Create a prioritized fix plan:
1. Critical (breaks style guide rules)
2. Important (duplication, clarity)
3. Nice-to-have (minor improvements)"
```

### 4. Fix Critical Issues

Switch to **Auto mode** for fixes:

```bash
/approvals auto
```

Fix issues one category at a time:

#### Fix Context Structure

```bash
codex "Fix the context structure in user_spec.rb:
- Add missing edge case contexts
- Reorder to put happy paths first
- Ensure one characteristic per context level"
```

#### Fix Setup Issues

```bash
codex "Fix setup problems in user_spec.rb:
- Move subject to top-level describe
- Extract duplicate let(:user) to parent
- Add unique setup to empty contexts"
```

#### Fix Examples

```bash
codex "Fix example issues in user_spec.rb:
- Convert duplicate 'responds with success' to shared_examples
- Improve vague it descriptions
- Remove tests of private methods"
```

### 5. Fix Factory Issues

If there are factory problems:

```bash
codex "Update the user factory:
- Wrap Time.now in blocks: { Time.now }
- Wrap SecureRandom in blocks: { SecureRandom.hex }
- Use traits for variations instead of inline overrides"
```

### 6. Verify Each Fix

After each fix, verify it worked:

```bash
codex exec "bundle exec rubocop -DES spec/models/user_spec.rb | grep 'RSpecGuide'"
```

### 7. Run Tests

Ensure tests still pass after changes:

```bash
codex exec "bundle exec rspec spec/models/user_spec.rb"
```

If any fail:

```bash
codex "Test 'validates email format' is now failing after reorganization.
Fix it while maintaining the new structure."
```

### 8. Final Review

Do a final compliance check:

```bash
codex exec "bundle exec rubocop -DES spec/models/user_spec.rb && bundle exec rspec spec/models/user_spec.rb"
```

Should see:
- **0 offenses detected**
- **All tests green**

Also verify against the comprehensive checklist:

```bash
codex "Review the spec file against docs/CHECKLIST.md and confirm all items pass"
```

Or manually review using [docs/CHECKLIST.md](../CHECKLIST.md)

## Common Patterns to Fix

### Pattern 1: No Contexts

**Before:**
```ruby
describe User do
  it 'creates user' do ... end
  it 'fails without email' do ... end
end
```

**Fix Command:**
```bash
codex "Reorganize the User tests into contexts:
- context 'with valid attributes' (happy path first)
- context 'with missing email' (edge case after)"
```

### Pattern 2: Implementation Testing

**Before:**
```ruby
it 'calls validate_email method' do
  expect(user).to receive(:validate_email)
  user.save
end
```

**Fix Command:**
```ruby
codex "Change implementation test to behavior test:
Instead of expecting method calls, test the outcome
(e.g., user.valid? is false, user.errors includes message)"
```

### Pattern 3: Duplicate Setup

**Before:**
```ruby
context 'as admin' do
  let(:user) { create(:user) }
  let(:role) { 'admin' }
  ...
end

context 'as moderator' do
  let(:user) { create(:user) }  # duplicate!
  let(:role) { 'moderator' }
  ...
end
```

**Fix Command:**
```bash
codex "Extract duplicate let(:user) to parent describe block"
```

### Pattern 4: Wrong Order

**Before:**
```ruby
describe '#process' do
  context 'with invalid data' do ... end  # error first
  context 'with valid data' do ... end    # happy path second
end
```

**Fix Command:**
```bash
codex "Reorder contexts to put 'with valid data' before 'with invalid data'"
```

## Bulk Operations

For multiple files, use **Full Access** mode carefully:

### Review All Specs

```bash
codex "List all spec files that likely violate our style guide based on:
- File has no 'context' blocks
- File has 'should' syntax
- File uses any_instance"
```

### Fix Common Issues Across Files

```bash
# Careful: Full Access mode
/approvals full

codex "For all files in spec/models/:
- Replace 'should' syntax with 'expect'
- Replace any_instance with dependency injection
- Add missing 'require rails_helper' statements"
```

### Generate Report

```bash
codex exec "bundle exec rubocop -DES spec/ --format json > rubocop_report.json"

codex "Parse rubocop_report.json and create a summary:
- Files with most offenses
- Most common violations
- Estimated effort to fix"
```

## Incremental Migration Strategy

For large codebases:

### Phase 1: Critical Specs
```bash
# Start with most important specs
codex "Review spec/models/order_spec.rb and spec/models/payment_spec.rb"
```

### Phase 2: Shared Examples
```bash
# Extract common patterns
codex "Identify repeated examples across specs and create spec/support/shared_examples/"
```

### Phase 3: Factories
```bash
# Fix all factories at once
codex "Update all factories in spec/factories/ to use dynamic blocks for time/random"
```

### Phase 4: Full Compliance
```bash
# Systematic fix of remaining issues
codex "Fix remaining RSpecGuide violations in spec/, one directory at a time"
```

## Verification Commands

Quick checks to run frequently:

```bash
# Check specific cop
codex exec "bundle exec rubocop --only RSpecGuide/HappyPathFirst spec/"

# Check test coverage didn't drop
codex exec "COVERAGE=true bundle exec rspec"

# Check for broken tests
codex exec "bundle exec rspec --fail-fast"

# Full validation
codex exec "bundle exec rubocop -DES && bundle exec rspec"
```

## Tips

1. **Fix One Type at a Time**: Don't mix structural and content changes
2. **Preserve Test Intent**: Keep the same test coverage while reorganizing
3. **Use Git Branches**: Create a branch for each file or directory
4. **Document Changes**: Add comments explaining non-obvious reorganizations
5. **Run Often**: Verify after each change, not at the end

## Success Criteria

The spec file is compliant when:
- [ ] All RSpecGuide/* cops pass
- [ ] All FactoryBotGuide/* cops pass
- [ ] Tests are green
- [ ] Structure follows characteristic hierarchy
- [ ] Happy paths come first
- [ ] No duplicate setup
- [ ] Clear behavior descriptions