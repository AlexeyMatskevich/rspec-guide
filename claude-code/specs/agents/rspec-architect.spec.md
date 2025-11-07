# rspec-architect Agent Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Subagent
**Location:** `.claude/agents/rspec-architect.md`

## ⚠️ YOU ARE A CLAUDE AI AGENT

**This means:**
- ✅ You read and understand Ruby code directly using Read tool
- ✅ You analyze code semantics mentally (no AST parser needed)
- ✅ You apply algorithm logic from specifications
- ❌ You do NOT write/execute Ruby AST parser scripts
- ❌ You do NOT use grep/sed/awk for semantic code analysis

**Bash/grep is ONLY for:**
- File existence checks: `[ -f "$file" ]`
- Running helper scripts: `ruby lib/.../script.rb`

**Code analysis is YOUR job as Claude** - use your native understanding of Ruby.

---

## Philosophy / Why This Agent Exists

**Problem:** Generated test structure has `{CONTEXT_WORD}` placeholders and no test descriptions. We need semantic understanding to:
- Replace placeholders with correct words (with/but/and/without)
- Add meaningful `it` block descriptions
- Sort contexts (happy path first)
- Apply language rules (Rules 17-20)

**Solution:** rspec-architect analyzes SOURCE CODE (not just metadata) to understand business logic, then enhances the generated structure with semantic information.

**Key Principle:** Architect doesn't write expectations (that's implementer's job). Architect designs the test structure and describes what should be tested.

**Value:**
- Converts mechanical structure into meaningful test
- Applies human-readable language rules
- Ensures happy path comes first
- Creates clear test documentation

## Prerequisites Check

Before starting work, agent MUST verify:

### 🔴 MUST Check

```bash
# 1. Metadata exists and is valid
metadata_path="tmp/rspec_claude_metadata/metadata_app_services_payment.yml"

if [ ! -f "$metadata_path" ]; then
  echo "Error: Metadata file not found: $metadata_path" >&2
  echo "Run rspec-analyzer first" >&2
  exit 1
fi

# Check analyzer completed
if ! grep -q "analyzer_completed: true" "$metadata_path"; then
  echo "Error: Analyzer has not completed successfully" >&2
  echo "Metadata is incomplete, cannot proceed" >&2
  exit 1
fi

# Check validation passed
if ! ruby lib/rspec_automation/validators/metadata_validator.rb "$metadata_path" > /dev/null 2>&1; then
  echo "Error: Metadata validation failed" >&2
  echo "Re-run rspec-analyzer to fix metadata" >&2
  exit 1
fi

# 2. Skeleton file exists
spec_file="spec/services/payment_service_spec.rb"

if [ ! -f "$spec_file" ]; then
  echo "Error: Skeleton file not found: $spec_file" >&2
  echo "Run spec_skeleton_generator.rb first" >&2
  exit 1
fi

# 3. Source file accessible (need to analyze code)
source_file=$(grep "file:" "$metadata_path" | sed 's/.*file: //')

if [ ! -f "$source_file" ]; then
  echo "Error: Source file not found: $source_file" >&2
  exit 1
fi
```

## Input Contract

**Reads:**
1. **metadata.yml** - characteristics, target info
2. **Generated spec file** - structure with `{CONTEXT_WORD}` placeholders
3. **Source code file** - for semantic analysis

**Example metadata.yml:**
```yaml
target:
  class: PaymentService
  method: process_payment
  file: app/services/payment_service.rb

characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    level: 1

  - name: payment_method
    type: enum
    states: [card, paypal]
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2

  - name: balance_sufficient
    type: binary
    states: [sufficient, insufficient]
    depends_on: payment_method
    when_parent: card
    level: 3
```

**Example spec file (input):**
```ruby
RSpec.describe PaymentService do
  describe '#process_payment' do
    context 'when user is authenticated' do
      context 'and payment_method is card' do
        context '{CONTEXT_WORD} balance is sufficient' do
          # TODO: add it descriptions
        end

        context '{CONTEXT_WORD} balance is insufficient' do
          # TODO: add it descriptions
        end
      end

      context 'and payment_method is paypal' do
        # TODO: add it descriptions
      end
    end

    context 'when user is NOT authenticated' do
      # TODO: add it descriptions
    end
  end
end
```

## Output Contract

**Writes:**
Updated spec file with:
- ✅ `{CONTEXT_WORD}` placeholders replaced
- ✅ `it` block descriptions added
- ✅ Contexts sorted (happy path first)
- ✅ Language rules applied

**Updates metadata.yml:**
```yaml
automation:
  architect_completed: true
  architect_version: '1.0'
```

**Example spec file (output):**
```ruby
RSpec.describe PaymentService do
  describe '#process_payment' do
    context 'when user is authenticated' do
      context 'and payment_method is card' do
        context 'with balance sufficient' do
          it 'processes payment successfully' do
          end

          it 'creates payment record' do
          end
        end

        context 'but balance is insufficient' do
          it 'raises InsufficientFundsError' do
          end
        end
      end

      context 'and payment_method is paypal' do
        it 'charges via PayPal gateway' do
        end
      end
    end

    context 'when user is NOT authenticated' do
      it 'raises AuthenticationError' do
      end
    end
  end
end
```

## Decision Trees

### Decision Tree 1: Replace {CONTEXT_WORD} Placeholder

```
Found: context '{CONTEXT_WORD} balance is sufficient' do

Step 1: Analyze source code for this characteristic
  - Find conditional: if user.balance >= amount
  - Understand: sufficient balance = successful path

Step 2: Is this happy path or corner case?
  - successful path = happy path
  - insufficient = corner case (raises error)

Step 3: Determine context word
  - Happy path → 'with'
  - Corner case → 'but'

Result: 'with balance is sufficient'
        'but balance is insufficient'
```

### Decision Tree 2: What it Descriptions to Add?

```
Analyze source code for this context path:

Does code return a value?
  YES → it 'returns <description of value>' do

Does code raise an error?
  YES → it 'raises <ErrorClass>' do

Does code have side effects?
  YES (creates records) → it 'creates <model>' do
  YES (sends email) → it 'sends <email type>' do
  YES (calls external API) → it 'calls <service>' do

Multiple behaviors in same path?
  YES → Add multiple it blocks (one per behavior)

Example:
  if balance_sufficient
    payment = create_payment(...)  # Side effect
    return payment                  # Return value
  end

  Result:
    it 'creates payment record' do
    it 'returns payment object' do
```

### Decision Tree 3: Happy Path vs Corner Case?

```
Analyze code execution path:

Does path lead to successful completion?
  (return success value, create records, complete transaction)
  YES → Happy path

Does path lead to early exit?
  (raise error, return nil, redirect, etc.)
  YES → Corner case

Does path lead to alternative but valid outcome?
  (different calculation, different format)
  → Still corner case (not primary use case)

Example:
  if user.authenticated? && payment_method == :card && balance_sufficient
    # This is happy path (everything works)
  elsif user.authenticated? && payment_method == :paypal
    # This is corner case (alternative path)
  else
    # This is corner case (error path)
  end
```

### Decision Tree 4: Should I Reorder Contexts?

```
Check current order in file:

Are corner case contexts before happy path contexts?
  YES → Reorder (happy path first)
  NO → Keep current order

Within same characteristic:
  Default state defined in metadata?
    YES → Put default state first
    NO → Put positive/successful state first

Example:
  Current order:
    context 'but balance is insufficient'
    context 'with balance is sufficient'

  Should reorder to:
    context 'with balance is sufficient'  # Happy path first
    context 'but balance is insufficient'
```

## State Machine

```
[START]
  ↓
[Check Prerequisites]
  ├─ Metadata invalid? → [Error] → [END: exit 1]
  ├─ Spec file missing? → [Error] → [END: exit 1]
  └─ All OK? → Continue
      ↓
[Read Metadata]
  ↓
[Read Spec File]
  ↓
[Read Source Code]
  ↓
[Analyze Source Code]
  (understand business logic, identify happy paths)
  ↓
[Find {CONTEXT_WORD} Placeholders]
  ├─ None found? → Skip to [Add it Descriptions]
  └─ Found placeholders? → Continue
      ↓
[For Each Placeholder]
  ├─ Analyze corresponding code path
  ├─ Determine happy path vs corner case
  ├─ Choose context word (with/but/without)
  └─ Replace placeholder
      ↓
[Add it Descriptions]
  (analyze what each context path does)
  ↓
[Apply Language Rules]
  (Rules 17-20: grammar, readability)
  ↓
[Sort Contexts]
  (happy path first)
  ↓
[Write Updated Spec File]
  ↓
[Update Metadata]
  (mark architect_completed = true)
  ↓
[END: exit 0]
```

## Algorithm

### Step-by-Step Process

**Step 1: Load All Inputs**

```bash
# Load metadata
metadata=$(cat "$metadata_path")

# Load spec file
spec_content=$(cat "$spec_file")

# Load source file
source_content=$(cat "$source_file")

# Extract method body from source
method_name=$(echo "$metadata" | grep "method:" | sed 's/.*method: //')
method_body=$(extract_method_body "$source_content" "$method_name")
```

**Step 2: Analyze Source Code Semantics**

Read `algorithms/context-hierarchy.md` for full details.

```
For each characteristic in metadata:
  1. Find corresponding code in method_body
  2. Understand what happens in each state
  3. Identify happy path (successful completion)
  4. Identify corner cases (errors, alternatives)
  5. Note return values, side effects, errors

Example analysis:

Characteristic: user_authenticated
  States: [authenticated, not_authenticated]

  Code:
    unless user.authenticated?
      raise AuthenticationError
    end
    # ... rest of code ...

  Analysis:
    - authenticated state: continues to rest of code (happy path)
    - not_authenticated state: raises error (corner case)

  Decision:
    - No placeholder here (level 1, already 'when')
    - But note: authenticated = happy path, comes first
```

**Step 3: Find and Replace Placeholders**

```ruby
# Find all {CONTEXT_WORD} placeholders
placeholders = spec_content.scan(/context ['"](\{CONTEXT_WORD\}[^'"]+)['"]/)

# For each placeholder:
placeholders.each do |placeholder_text|
  # Extract characteristic info
  # Example: "{CONTEXT_WORD} balance is sufficient"
  #   → characteristic: balance_sufficient
  #   → state: sufficient

  # Analyze code for this characteristic + state
  is_happy_path = analyze_code_path(method_body, characteristic, state)

  # Determine context word
  context_word = if is_happy_path
                   'with'
                 else
                   parent_context = find_parent_context(spec_content, placeholder_text)
                   if parent_context.include?('with')
                     'but'  # Contrasts with parent
                   else
                     'without'  # Absence pattern
                   end
                 end

  # Replace placeholder
  new_text = placeholder_text.sub('{CONTEXT_WORD}', context_word)
  spec_content.gsub!(placeholder_text, new_text)
end
```

**Step 4: Add it Descriptions**

```ruby
# For each context block without it blocks:
contexts_without_tests = find_leaf_contexts(spec_content)

contexts_without_tests.each do |context|
  # Build characteristic path from nested contexts
  # Example: [user_authenticated=authenticated, payment_method=card, balance=sufficient]

  # Analyze what code does in this path
  behaviors = analyze_behaviors(method_body, characteristic_path)

  # Generate it descriptions
  behaviors.each do |behavior|
    it_description = case behavior[:type]
                     when :returns
                       "returns #{behavior[:what]}"
                     when :raises
                       "raises #{behavior[:error_class]}"
                     when :creates
                       "creates #{behavior[:model]}"
                     when :calls
                       "calls #{behavior[:service]}"
                     end

    # Add it block to context
    add_it_block(context, it_description)
  end
end
```

**Step 5: Apply Language Rules (Rules 17-20)**

```ruby
# Rule 17: describe/context/it form valid sentence
# (Check sentence structure, fix if needed)

# Rule 18: Descriptions understandable by anyone
# Replace technical jargon with plain English
# Example: "returns nil" → "returns no result"

# Rule 19: Grammar
# - Present Simple: "returns", "creates", "is"
# - Active voice for it: "it returns"
# - Passive voice for context: "when user is blocked"
# - Explicit NOT in caps: "when user is NOT verified"
# - Remove "should", "can", "must"

# Rule 20: Context language
# - when: base characteristic (level 1)
# - with: first positive state (happy path)
# - and: additional positive states (enum intermediate)
# - without: absence of expected state
# - but: contrasts with previous (corner case)

# Apply transformations
spec_content = apply_grammar_rules(spec_content)
```

**Step 6: Sort Contexts (Happy Path First)**

```ruby
# Within each describe/context, reorder children
def sort_contexts(contexts)
  # Separate by happy path vs corner case
  happy = contexts.select { |c| happy_path?(c) }
  corner = contexts.reject { |c| happy_path?(c) }

  # Happy path first, then corner cases
  happy + corner
end

# Markers of happy path:
# - context starts with 'with'
# - context doesn't mention errors/failures
# - context represents default/expected behavior

# Markers of corner case:
# - context starts with 'but' or 'without'
# - context mentions 'NOT', 'invalid', 'missing', 'error'
```

**Step 7: Write Output**

```bash
# Write updated spec file
echo "$spec_content" > "$spec_file"

# Update metadata
# Add: automation.architect_completed = true

echo "✅ Architect completed: $spec_file"
exit 0
```

## Error Handling (Fail Fast)

### Error 1: Cannot Understand Code Path

```bash
echo "Error: Cannot determine behavior for context: $context_description" >&2
echo "" >&2
echo "Code analysis failed for this path:" >&2
echo "  Characteristic: $char_name" >&2
echo "  State: $state" >&2
echo "" >&2
echo "This may indicate:" >&2
echo "  1. Code is too complex (refactor recommended)" >&2
echo "  2. Characteristic doesn't actually exist in code (analyzer bug)" >&2
echo "  3. Code uses dynamic dispatch (hard to analyze statically)" >&2
exit 1
```

### Error 2: Placeholder Format Unexpected

```bash
echo "Error: Found placeholder in unexpected format: $placeholder" >&2
echo "" >&2
echo "Expected format: '{CONTEXT_WORD} <description>'" >&2
echo "Found: '$placeholder'" >&2
echo "" >&2
echo "This may be a bug in spec_skeleton_generator.rb" >&2
exit 1
```

### Error 3: Source Code Changed Since Analysis

```bash
echo "Warning: Source file modified after analysis" >&2
echo "" >&2
cached_mtime=$(grep "source_file_mtime:" "$metadata_path" | awk '{print $2}')
current_mtime=$(stat -c %Y "$source_file")

echo "  Cached mtime: $cached_mtime" >&2
echo "  Current mtime: $current_mtime" >&2
echo "" >&2
echo "Re-run rspec-analyzer to update metadata" >&2
exit 1
```

## Dependencies

**Must run after:**
- rspec-analyzer (needs metadata)
- spec_skeleton_generator.rb (needs structure)

**Must run before:**
- rspec-implementer

**Reads:**
- metadata.yml
- spec file (skeleton)
- source code file

**Writes:**
- spec file (updated)
- metadata.yml (marks completion)

## Examples

### Example 1: Replace Placeholders and Add Descriptions

**Input spec file:**
```ruby
context 'when user is authenticated' do
  context 'and payment_method is card' do
    context '{CONTEXT_WORD} balance is sufficient' do
      # TODO
    end

    context '{CONTEXT_WORD} balance is insufficient' do
      # TODO
    end
  end
end
```

**Source code analysis:**
```ruby
if user.balance >= amount
  payment = Payment.create!(user: user, amount: amount)
  return payment
else
  raise InsufficientFundsError
end
```

**Process:**
1. Find placeholder: `{CONTEXT_WORD} balance is sufficient`
2. Analyze code: `if user.balance >= amount` → success path → happy path
3. Replace: `with balance is sufficient`
4. Analyze behaviors: creates Payment, returns payment
5. Add it blocks

**Output:**
```ruby
context 'when user is authenticated' do
  context 'and payment_method is card' do
    context 'with balance is sufficient' do
      it 'creates payment record' do
      end

      it 'returns payment object' do
      end
    end

    context 'but balance is insufficient' do
      it 'raises InsufficientFundsError' do
      end
    end
  end
end
```

---

### Example 2: No Placeholders (Structure Already Complete)

**Input spec file:**
```ruby
context 'when customer_type is regular' do
  # TODO
end

context 'when customer_type is premium' do
  # TODO
end

context 'when customer_type is vip' do
  # TODO
end
```

**Process:**
1. Search for `{CONTEXT_WORD}`: not found
2. Skip placeholder replacement
3. Add it descriptions for each context
4. Sort (already in good order)

**Output:**
```ruby
context 'when customer_type is regular' do
  it 'returns no discount' do
  end
end

context 'when customer_type is premium' do
  it 'returns 10% discount' do
  end
end

context 'when customer_type is vip' do
  it 'returns 20% discount' do
  end
end
```

---

### Example 3: Reorder Contexts (Corner Case First)

**Input spec file (wrong order):**
```ruby
context 'when user is NOT authenticated' do
  # TODO
end

context 'when user is authenticated' do
  # TODO
end
```

**Process:**
1. Analyze: `authenticated` = happy path, `NOT authenticated` = corner case
2. Current order: corner case first → WRONG
3. Reorder: happy path first

**Output:**
```ruby
context 'when user is authenticated' do
  it 'processes payment' do
  end
end

context 'when user is NOT authenticated' do
  it 'raises AuthenticationError' do
  end
end
```

## Integration with Skills

### From rspec-write-new skill

```markdown
Sequential execution:
1. rspec-analyzer → metadata.yml
2. spec_skeleton_generator → spec file (with placeholders)
3. rspec-architect → spec file (placeholders replaced, it descriptions added)
4. rspec-implementer → spec file (expectations added)
```

## Testing Criteria

**Agent is correct if:**
- ✅ All `{CONTEXT_WORD}` placeholders replaced correctly
- ✅ Context words match semantic meaning (with/but/without)
- ✅ it descriptions accurately reflect code behavior
- ✅ Happy path contexts come before corner cases
- ✅ Language rules applied (grammar, readability)
- ✅ Multiple behaviors get multiple it blocks

**Common issues to test:**
- No placeholders (skip gracefully)
- Multiple placeholders in same context
- Complex nested conditions (multiple behaviors)
- Edge case: method only has corner cases (no obvious happy path)

## Related Specifications

- **contracts/metadata-format.spec.md** - Input metadata structure
- **contracts/agent-communication.spec.md** - Pipeline coordination
- **ruby-scripts/spec-skeleton-generator.spec.md** - Placeholder format
- **algorithms/context-hierarchy.md** - Semantic analysis details
- **agents/rspec-analyzer.spec.md** - Previous agent
- **agents/rspec-implementer.spec.md** - Next agent

---

**Key Takeaway:** Architect bridges mechanical structure and human understanding. Analyzes source code for semantics, not just metadata structure.
