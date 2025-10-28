# Runbook: Generate RSpec Tests with Codex CLI

This runbook guides you through generating RSpec tests using OpenAI's Codex CLI while following our strict style guide.

## Prerequisites

- Codex CLI installed and configured
- Project is a Git repository (required by Codex)
- `rubocop-rspec-guide` gem in Gemfile
- `.rubocop.yml` configured with custom cops

## Step-by-Step Process

### 1. Plan Contexts and Examples

Start Codex in **Read-Only mode** to plan the test structure:

```bash
codex
```

Then ask:

> "List the public methods of `app/services/payment_processor.rb` and propose RSpec contexts and examples for each, following our RSpec style guide. Include happy paths first, then edge cases. Structure contexts by independent characteristics."

Review the proposed plan. Ensure it includes:
- Happy path scenarios first
- At least one edge case per method
- Characteristic-based context hierarchy

Refine if needed:

> "Combine the expired and invalid coupon contexts since they have the same behavior"

### 2. Enable Style Guide Cops

Ensure `.rubocop.yml` has the custom cops enabled:

```bash
codex "Check if .rubocop.yml includes rubocop-rspec-guide. If not, add it with these cops enabled: CharacteristicsAndContexts, HappyPathFirst, ContextSetup, DuplicateLetValues, DuplicateBeforeHooks, InvariantExamples, DynamicAttributesForTimeAndRandom"
```

Expected configuration:

```yaml
require:
  - rubocop-rspec
  - rubocop-factory_bot
  - rubocop-rspec-guide

RSpecGuide/CharacteristicsAndContexts:
  Enabled: true
RSpecGuide/HappyPathFirst:
  Enabled: true
# ... etc
```

### 3. Generate Spec File

Switch to **Auto mode** for file generation:

```bash
/approvals auto
```

Or use a single command:

```bash
codex "Write the RSpec spec for PaymentProcessor according to the plan:
- Use contexts per characteristic (one per level)
- Happy path first, edge cases after
- Subject at top-level describe only
- Use FactoryBot with traits for test data
- Dynamic attributes in blocks { Time.now }
- Extract duplicate examples to shared_examples"
```

The agent will create `spec/services/payment_processor_spec.rb`.

### 4. Run Linters

Execute RuboCop to check style compliance:

```bash
codex exec "bundle exec rubocop -DES spec/services/payment_processor_spec.rb"
```

If there are offenses, fix them:

```bash
codex "Fix these RuboCop offenses in payment_processor_spec.rb:
[paste offenses here]
Focus on RSpecGuide/* cops - these are critical for our style guide."
```

### 5. Run Tests

Execute the generated tests:

```bash
codex exec "bundle exec rspec spec/services/payment_processor_spec.rb"
```

If tests fail, analyze and fix:

```bash
codex "The test 'handles expired coupon' is failing with:
  Expected: false
  Got: nil

Update the test to handle nil return values appropriately."
```

### 6. Iterate Until Clean

Repeat steps 4-5 until:
- RuboCop shows **0 offenses**
- All tests are **green**

```bash
# Final verification
codex exec "bundle exec rubocop -DES && bundle exec rspec"
```

### 7. Review Final Code

Optional - Ask Codex to summarize compliance:

```bash
codex "Review payment_processor_spec.rb and confirm it follows our RSpec style guide:
- At least 2 contexts (happy + edge)
- Happy path first
- Unique setup per context
- Subject at top level only
- No duplicate let/before
- Factories use dynamic blocks"
```

For a comprehensive check, use the full checklist:

```bash
codex "Verify payment_processor_spec.rb against all items in docs/CHECKLIST.md"
```

See [docs/CHECKLIST.md](../CHECKLIST.md) for the complete validation checklist.

## Common Issues and Fixes

### Issue: Missing Contexts

```bash
# Offense: RSpecGuide/CharacteristicsAndContexts
codex "Add an edge case context for the calculate_total method when order has no items"
```

### Issue: Wrong Order

```bash
# Offense: RSpecGuide/HappyPathFirst
codex "Reorder contexts in payment_processor_spec.rb to put success scenarios before error scenarios"
```

### Issue: Duplicate Setup

```bash
# Offense: RSpecGuide/DuplicateLetValues
codex "Extract the duplicate let(:user) definition to the parent describe block"
```

### Issue: Static Time in Factory

```bash
# Offense: FactoryBotGuide/DynamicAttributesForTimeAndRandom
codex "Fix the payment factory to use { Time.now } instead of Time.now for created_at"
```

## Automation Script

Save this as `generate_spec.sh`:

```bash
#!/bin/bash
FILE=$1
SPEC_FILE=${FILE/app/spec}
SPEC_FILE=${SPEC_FILE/.rb/_spec.rb}

echo "Generating spec for $FILE..."

# Generate
codex --full-auto "Generate RSpec tests for $FILE following our style guide with contexts, happy paths first, and FactoryBot"

# Lint
codex exec "bundle exec rubocop -DES $SPEC_FILE"

# Test
codex exec "bundle exec rspec $SPEC_FILE"

echo "Spec generation complete: $SPEC_FILE"
```

Usage:

```bash
./generate_spec.sh app/models/order.rb
```

## Tips for Better Results

1. **Be Specific**: Include style guide requirements in every prompt
2. **Use Examples**: Show Codex good/bad patterns from the guide
3. **Verify Incrementally**: Check after each step rather than at the end
4. **Save Good Prompts**: Keep prompts that work well for reuse
5. **Review Diffs**: Always `git diff` before committing

## Quick Reference Card

### Approval Modes

- **Read-Only**: Planning, reviewing (safe)
- **Auto**: Generating, editing (balanced)
- **Full Access**: Bulk changes (use sparingly)

```bash
/approvals readonly  # For planning
/approvals auto     # For generating
/approvals full     # For bulk fixes
```

### Essential Commands

```bash
codex                   # Interactive mode
codex exec "command"    # Run command (read-only by default)
codex --full-auto "..." # One-shot generation
git diff               # Review changes
```

### Style Guide Cops

Must pass all of these:
- `RSpecGuide/CharacteristicsAndContexts`
- `RSpecGuide/HappyPathFirst`
- `RSpecGuide/ContextSetup`
- `RSpecGuide/DuplicateLetValues`
- `RSpecGuide/DuplicateBeforeHooks`
- `RSpecGuide/InvariantExamples`
- `FactoryBotGuide/DynamicAttributesForTimeAndRandom`