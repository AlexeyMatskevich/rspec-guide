# rspec-implementer Agent Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Subagent
**Location:** `.claude/agents/rspec-implementer.md`

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

**Problem:** Test structure exists with it descriptions, but tests don't run - they need setup (let blocks), test subject, and expectations.

**Solution:** rspec-implementer analyzes SOURCE CODE to understand:
- What objects are needed (dependencies)
- How to set them up (factories, stubs, mocks)
- What the method does (behavior, not implementation)
- What to expect (return values, side effects, errors)

**Key Principle:** Test BEHAVIOR, not implementation (Rule 1). Don't check internal method calls unless they're part of the public interface.

**Value:**
- Transforms test skeleton into working test
- Follows guide.en.md rules (especially Rule 1, 4, 11-16)
- Uses appropriate factories (build_stubbed vs create based on test_level)
- Creates realistic, maintainable tests

## Prerequisites Check

### 🔴 MUST Check

```bash
# 1. Architect completed
if ! grep -q "architect_completed: true" "$metadata_path"; then
  echo "Error: rspec-architect has not completed" >&2
  echo "Run rspec-architect first" >&2
  exit 1
fi

# 2. Spec file has it blocks
if ! grep -q "it '" "$spec_file"; then
  echo "Error: Spec file has no it blocks" >&2
  echo "rspec-architect should have added them" >&2
  exit 1
fi

# 3. Source file accessible
if [ ! -f "$source_file" ]; then
  echo "Error: Source file not found: $source_file" >&2
  exit 1
fi
```

## Input Contract

**Reads:**
1. **metadata.yml** - test_level, characteristics (with source field), factories_detected
2. **Spec file** - structure with it descriptions (but no bodies) + `# Logic:` comments
3. **Source code** - method signature, dependencies, behavior

**IMPORTANT:** Spec file contains `# Logic: path:line` comments that point to source code locations:

```ruby
context 'when user is authenticated' do
  # Logic: app/services/payment_service.rb:45
  {SETUP_CODE}
```

These comments help you navigate to relevant code quickly. **You will remove them after implementation.**

**Example spec file (input):**
```ruby
RSpec.describe PaymentService do
  describe '#process_payment' do
    context 'when user is authenticated' do
      # Logic: app/services/payment_service.rb:45
      {SETUP_CODE}

      context 'and payment_method is card' do
        # Logic: app/services/payment_service.rb:52-58
        {SETUP_CODE}

        context 'with balance is sufficient' do
          # Logic: app/services/payment_service.rb:78
          {SETUP_CODE}

          it 'creates payment record' do
            {EXPECTATION}
          end

          it 'returns payment object' do
            {EXPECTATION}
          end
        end

        context 'but balance is insufficient' do
          # Logic: app/services/payment_service.rb:78
          {SETUP_CODE}

          it 'raises InsufficientFundsError' do
            {EXPECTATION}
          end
        end
      end
    end

    context 'when user is NOT authenticated' do
      # Logic: app/services/payment_service.rb:45
      {SETUP_CODE}

      it 'raises AuthenticationError' do
        {EXPECTATION}
      end
    end
  end
end
```

## Output Contract

**Writes:**
Updated spec file with:
- ✅ let/let!/before blocks (setup)
- ✅ subject definition
- ✅ expect statements (behavior checking)
- ✅ Follows test_level (build_stubbed for unit, create for integration)
- ✅ Uses factory traits where available
- ✅ **All `# Logic:` comments removed** (they were temporary scaffolding)

**Updates metadata.yml:**
```yaml
automation:
  implementer_completed: true
  implementer_version: '1.0'
```

**Example spec file (output):**
```ruby
RSpec.describe PaymentService do
  describe '#process_payment' do
    subject(:result) { described_class.new.process_payment(user, amount) }

    let(:amount) { 100.0 }

    context 'when user is authenticated' do
      let(:user) { build_stubbed(:user, :authenticated) }

      context 'and payment_method is card' do
        let(:user) { build_stubbed(:user, :authenticated, payment_method: :card) }

        context 'with balance is sufficient' do
          let(:user) { build_stubbed(:user, :authenticated, payment_method: :card, balance: 200.0) }

          it 'creates payment record' do
            expect { result }.to change(Payment, :count).by(1)
          end

          it 'returns payment object' do
            expect(result).to be_a(Payment)
            expect(result.amount).to eq(amount)
          end
        end

        context 'but balance is insufficient' do
          let(:user) { build_stubbed(:user, :authenticated, payment_method: :card, balance: 0) }

          it 'raises InsufficientFundsError' do
            expect { result }.to raise_error(InsufficientFundsError)
          end
        end
      end
    end

    context 'when user is NOT authenticated' do
      let(:user) { build_stubbed(:user) }

      it 'raises AuthenticationError' do
        expect { result }.to raise_error(AuthenticationError)
      end
    end
  end
end
```

## Decision Trees

### Decision Tree 1: build_stubbed vs create?

```
Check metadata test_level:

test_level == 'unit'?
  YES → Use build_stubbed (no database needed)
  NO → Continue

test_level == 'integration'?
  YES → Does method save/update records?
    YES → Use create (need database)
    NO → Use build_stubbed (read-only)

test_level == 'request'?
  YES → Use create (full stack)

test_level == 'e2e'?
  YES → Use create (full stack)
```

### Decision Tree 2: What to Expect?

```
Analyze it description and source code:

it description contains 'raises'?
  YES → expect { result }.to raise_error(ErrorClass)

it description contains 'returns'?
  YES → expect(result).to eq(value) or be_a(Class)

it description contains 'creates'?
  YES → expect { result }.to change(Model, :count).by(1)

it description contains 'updates'?
  YES → expect { result }.to change { object.reload.attr }

it description contains 'sends' or 'calls'?
  YES → expect(service).to receive(:method) (mock/stub)

it description is generic/unclear? (e.g., "works correctly", "processes successfully")
  YES → Analyze source code path:
    1. Read code from # Logic: comment
    2. Detect behavior patterns (creates/raises/returns)
    3. Infer expectation from code behavior
    4. Add comment: # TODO: verify expectation matches business intent

Multiple behaviors?
  YES → Use aggregate_failures or separate expectations
```

**Example: Generic Description Fallback**

```ruby
# Input from architect:
it 'processes payment successfully' do
  # Logic: app/services/payment_service.rb:78
  {EXPECTATION}
end

# Step 1: Description is generic (no specific verb)
# Step 2: Read source at line 78
# Step 3: Found: Payment.create!(...)
# Step 4: Infer: creates payment record
# Step 5: Generate expectation from code analysis

# Output:
it 'processes payment successfully' do
  # TODO: verify expectation matches business intent
  expect { result }.to change(Payment, :count).by(1)
end
```

### Decision Tree 3: Use Factory Trait or Attributes?

```
Check factories_detected in metadata:

Factory exists for this model?
  NO → Use attributes: build_stubbed(:model, attr: value)
  YES → Continue

Trait exists for this characteristic state?
  YES → Use trait: build_stubbed(:model, :trait_name)
  NO → Use attributes: build_stubbed(:model, attr: value)

Example:
  Characteristic: user_authenticated, state: authenticated
  Factory: user
  Traits: [:authenticated, :blocked]

  Decision: Use trait
  Result: build_stubbed(:user, :authenticated)
```

### Decision Tree 4: Where to Define let Block?

```
Is this variable used in multiple contexts at same level?
  YES → Define in parent context (DRY)
  NO → Continue

Is this variable overridden in child contexts?
  YES → Define in parent, override in children
  NO → Define at level where used

Example:
  context 'when user is authenticated' do
    let(:user) { build_stubbed(:user, :authenticated) }  # Base

    context 'with payment_method is card' do
      let(:user) { build_stubbed(:user, :authenticated, payment_method: :card) }  # Override
```

## State Machine

```
[START]
  ↓
[Check Prerequisites]
  ├─ Fail? → [Error] → [END: exit 1]
  └─ Pass? → Continue
      ↓
[Read All Inputs]
  (metadata, spec file, source code)
  ↓
[Analyze Method Signature]
  (parameters, return type)
  ↓
[Determine Subject Definition]
  (instance vs class method, parameters)
  ↓
[For Each Context Block]
  ├─ Analyze characteristic states
  ├─ Determine required setup (let blocks)
  ├─ Check for factory traits
  └─ Add setup to context
      ↓
[For Each it Block]
  ├─ Parse it description
  ├─ Analyze source code path
  ├─ Determine expected behavior
  └─ Write expect statement
      ↓
[Apply Rule 1: Test Behavior]
  (verify no implementation testing)
  ↓
[Apply Rule 14: FactoryBot Usage]
  (build_stubbed vs create based on test_level)
  ↓
[Write Updated Spec File]
  ↓
[Update Metadata]
  (mark implementer_completed = true)
  ↓
[END: exit 0]
```

## Algorithm

### Step-by-Step Process

**Step 1: Analyze Method Signature**

**What you do as Claude AI agent:**

1. **Read source file** using Read tool:
   ```
   source_file = metadata['target']['file']
   method_name = metadata['target']['method']
   ```

2. **Find method definition** - search for method in source:
   - Search for `def #{method_name}` for instance methods
   - Search for `def self.#{method_name}` for class methods

3. **Extract parameters** from definition:
   ```ruby
   # Found: def process_payment(user, amount)
   # Extract: ['user', 'amount']
   ```
   - Look at text between `(` and `)` after method name
   - Split by `,` to get parameter list
   - Handle keyword arguments: `def method(user, amount:)` → `['user', 'amount']`

4. **Determine method type**:
   - Contains `def self.` → class method
   - Just `def` → instance method

5. **Analyze return type** - scan method body for patterns:
   - Pattern `return something` → what does it return?
   - Pattern `raise ErrorClass` → raises error
   - Last meaningful expression → implicit return
   - Multiple branches → multiple return types

**Step 2: Determine Subject**

**What you do as Claude AI agent:**

**Decision: Instance or Class Method?**

```
Method type?
  instance method (def method_name) →
    subject(:result) { described_class.new.method_name(params) }

  class method (def self.method_name) →
    subject(:result) { described_class.method_name(params) }
```

**Placement:**
- Add subject at **top of outermost describe block** (before any context blocks)
- Use parameter names from Step 1 (e.g., `user, amount`)

**Example:**
```ruby
# For: def process_payment(user, amount)
# Parameters: ['user', 'amount']
# Type: instance

describe '#process_payment' do
  subject(:result) { described_class.new.process_payment(user, amount) }

  # contexts come below...
end
```

**Step 3: Setup - Add let Blocks**

**What you do as Claude AI agent:**

**For each context block:**

1. **Read `# Logic:` comment** to find source code location
2. **Read source code** at that location using Read tool
3. **Understand what this context checks** (which attribute/condition)
4. **Build context path** from nested context names
5. **Determine setup needed** using algorithm below

**Algorithm: determine_setup(characteristic, state, method_params, test_level, factories_detected)**

**Step 1: Map characteristic to parameter**

```
Characteristic name usually matches parameter prefix:
  user_authenticated → affects 'user' parameter
  payment_method → affects 'payment_method' or 'user.payment_method'
  balance → affects 'user.balance' or separate 'balance' parameter
```

**Step 2: Check if factory trait exists**

```
Look in factories_detected from metadata:
  Model: user
  Traits: [:authenticated, :blocked, :premium]

Trait exists for this state?
  YES → Use trait (e.g., :authenticated)
  NO → Use attribute (e.g., authenticated: true)
```

**Step 3: Determine factory method (from test_level)**

```
test_level == 'unit' → build_stubbed
test_level == 'integration' → create
test_level == 'request' → create
```

**Step 4: Combine multiple characteristics affecting same parameter**

**Example scenario:**
```
Context path:
  1. user_authenticated = authenticated
  2. payment_method = card
  3. balance = sufficient

All three affect 'user' parameter.

How to combine?

For user parameter:
  - base factory: :user
  - trait from char 1: :authenticated (if trait exists)
  - attribute from char 2: payment_method: :card (if no trait)
  - attribute from char 3: balance: 200 (sufficient → high value)

Result:
  let(:user) { build_stubbed(:user, :authenticated, payment_method: :card, balance: 200) }
```

**Combining algorithm:**

```
Group characteristics by parameter they affect:
  user: [user_authenticated=authenticated, payment_method=card, balance=sufficient]

For each parameter group:
  1. Collect all traits that exist in factory
  2. Collect all attributes that don't have traits
  3. Build let statement:
     let(:param) { factory_method(:model, *traits, **attributes) }
```

**Step 5: Handle context overrides**

Parent context may already define `let(:user)`. Child context overrides with more specific setup:

```ruby
context 'when user is authenticated' do
  let(:user) { build_stubbed(:user, :authenticated) }  # Base

  context 'and payment_method is card' do
    # Override: add payment_method attribute
    let(:user) { build_stubbed(:user, :authenticated, payment_method: :card) }
  end
end
```

**Complete workflow example:**

```
Input:
  Context path: ['user_authenticated=authenticated', 'payment_method=card', 'balance=sufficient']
  Method params: ['user', 'amount']
  Test level: 'unit'
  Factories: { user: { traits: [:authenticated, :blocked] } }

Step-by-step:

1. Map characteristics to parameters:
   user_authenticated → user
   payment_method → user
   balance → user

2. Check traits:
   :authenticated → EXISTS in user factory
   :card → NO trait for payment_method
   :sufficient → NO trait for balance

3. Factory method: build_stubbed (unit level)

4. Combine for user:
   Traits: [:authenticated]
   Attributes: { payment_method: :card, balance: 200 }

5. Result:
   let(:user) { build_stubbed(:user, :authenticated, payment_method: :card, balance: 200) }

6. Placement:
   Add to innermost context (balance = sufficient)
```

**Step 4: Implement Expectations**

**What you do as Claude AI agent:**

**For each `it` block:**

1. **Parse it description** to understand what behavior to verify
2. **Read source code** from parent context's `# Logic:` comment
3. **Detect behavior patterns** in source code
4. **Generate appropriate expectation**

**Algorithm: Behavior Detection Patterns**

Scan source code for these patterns:

**Behavior 1: Creates/saves records**
- **Pattern:** `.create`, `.create!`, `.save`, `.save!`, `.update`, `.update!`
- **Extract:** Model class name
- **Example:**
  ```ruby
  # Source: Payment.create!(user: user, amount: amount)
  # Detected: creates_record, model: Payment
  # Expectation: expect { result }.to change(Payment, :count).by(1)
  ```

**Behavior 2: Raises an error**
- **Pattern:** `raise ErrorClass` or `raise ErrorClass, "message"`
- **Extract:** Error class name
- **Example:**
  ```ruby
  # Source: raise InsufficientFundsError
  # Detected: raises_error, error_class: InsufficientFundsError
  # Expectation: expect { result }.to raise_error(InsufficientFundsError)
  ```

**Behavior 3: Returns a value**
- **Pattern:** `return something` or implicit return (last expression)
- **Extract:** Value type (object/boolean/literal)
- **Example:**
  ```ruby
  # Source: return payment
  # Detected: returns_value, value_type: object, class: Payment
  # Expectation: expect(result).to be_a(Payment)

  # Source: return true
  # Detected: returns_value, value_type: boolean
  # Expectation: expect(result).to be(true)
  ```

**Behavior 4: Sends notifications**
- **Pattern:** `Mailer.deliver`, `.send_email`, `.notify`, `.publish`
- **Extract:** Mailer/service class and method
- **Example:**
  ```ruby
  # Source: PaymentMailer.success(payment).deliver_now
  # Detected: sends_notification, mailer: PaymentMailer, method: success
  # Expectation: expect(PaymentMailer).to receive(:success).with(payment)
  ```

**Behavior 5: Calls external services**
- **Pattern:** `ServiceClass.call`, `Gateway.charge`, API client calls
- **Extract:** Service class and method name
- **Example:**
  ```ruby
  # Source: PayPalGateway.charge(amount)
  # Detected: calls_service, service: PayPalGateway, method: charge
  # Expectation: expect(PayPalGateway).to receive(:charge).with(amount)
  ```

**Handling Multiple Behaviors:**

If code has multiple behaviors, create multiple expectations:

```ruby
# Source code:
#   payment = Payment.create!(user: user, amount: amount)
#   PaymentMailer.success(payment).deliver_now
#   payment

# Detected behaviors:
#   1. creates_record (Payment)
#   2. sends_notification (PaymentMailer.success)
#   3. returns_value (payment object)

# Generate:
it 'creates payment record, sends email, and returns payment' do
  expect { result }.to change(Payment, :count).by(1)
  expect(PaymentMailer).to receive(:success)
  expect(result).to be_a(Payment)
end
```

Or use `aggregate_failures` for better readability:

```ruby
it 'processes payment successfully' do
  aggregate_failures do
    expect { result }.to change(Payment, :count).by(1)
    expect(PaymentMailer).to receive(:success)
    expect(result).to be_a(Payment)
  end
end
```

**Complete Workflow Example:**

```
Input:
  it 'creates payment record'
  Logic comment: app/services/payment_service.rb:78

Step 1: Read source code at line 78
  Source: Payment.create!(user: user, amount: amount)

Step 2: Detect pattern
  Pattern match: .create!
  → Behavior: creates_record
  → Model: Payment

Step 3: Generate expectation
  expect { result }.to change(Payment, :count).by(1)

Step 4: Write to it block using Edit tool
  it 'creates payment record' do
    expect { result }.to change(Payment, :count).by(1)
  end
```

**Step 5: Apply FactoryBot Rules**

```ruby
# For each let block using factories:

test_level = metadata['test_level']

factory_method = case test_level
                 when 'unit'
                   :build_stubbed
                 when 'integration', 'request', 'e2e'
                   :create
                 end

# Check if trait exists
trait = find_trait(factories_detected, model, characteristic_state)

if trait
  "let(:#{var}) { #{factory_method}(:#{model}, :#{trait}) }"
else
  "let(:#{var}) { #{factory_method}(:#{model}, #{attributes}) }"
end
```

**Step 6: Ensure Behavior Testing (Rule 1)**

**What you do as Claude AI agent:**

After generating all expectations, verify you're testing BEHAVIOR, not implementation.

**Forbidden Patterns (Implementation Testing):**

Search for these patterns in your generated expectations:

**Pattern 1: Checking .save/.create method calls**
```ruby
# ❌ BAD (tests implementation)
expect(user).to receive(:save)
expect(Payment).to receive(:create)

# ✅ GOOD (tests behavior)
expect { result }.to change { user.reload.updated_at }
expect { result }.to change(Payment, :count).by(1)
```

**Pattern 2: Using allow/stub unnecessarily**
```ruby
# ❌ BAD (over-stubbing)
allow(user).to receive(:valid?).and_return(true)
expect { result }.not_to raise_error

# ✅ GOOD (test real behavior)
let(:user) { build_stubbed(:user, :valid) }
expect { result }.not_to raise_error
```

**Pattern 3: expect_any_instance_of (deprecated)**
```ruby
# ❌ BAD (deprecated, tests implementation)
expect_any_instance_of(Payment).to receive(:process)

# ✅ GOOD (test observable behavior)
expect { result }.to change(Payment, :count)
```

**Pattern 4: Checking internal state**
```ruby
# ❌ BAD (tests implementation)
expect(payment.instance_variable_get(:@status)).to eq(:processed)

# ✅ GOOD (test public interface)
expect(payment.status).to eq(:processed)
```

**Pattern 5: Excessive method call verification**
```ruby
# ❌ BAD (couples test to implementation)
expect(service).to receive(:validate_user)
expect(service).to receive(:check_balance)
expect(service).to receive(:create_payment)

# ✅ GOOD (test end result)
expect { result }.to change(Payment, :count).by(1)
expect(result).to be_successful
```

**Detection Algorithm:**

Use Grep tool to search for forbidden patterns:

```bash
# Pattern 1: .receive(:save|create|update)
grep 'to receive(:save\|:create\|:update)' spec_file

# Pattern 2: expect_any_instance_of
grep 'expect_any_instance_of' spec_file

# Pattern 3: instance_variable_get
grep 'instance_variable_get' spec_file
```

**When pattern detected:**

1. **Identify the intent** - what behavior is actually being tested?
2. **Find behavioral alternative** - how can we verify this through observable outcomes?
3. **Replace or warn** - either fix automatically or warn user

**Example Transformation:**

```ruby
# Original (implementation testing):
it 'saves user' do
  expect(user).to receive(:save).and_return(true)
  result
end

# Transformed (behavior testing):
it 'saves user' do
  expect { result }.to change { user.reload.updated_at }
end
```

**Exceptions (when stubs ARE appropriate):**

- **External services**: `expect(PayPalGateway).to receive(:charge)` - OK, we don't want to call real API
- **Time-dependent**: `allow(Time).to receive(:now).and_return(fixed_time)` - OK for deterministic tests
- **Third-party dependencies**: Stubbing external gems is acceptable

**Step 7: Clean Up Source Comments**

**CRITICAL:** Remove all `# Logic:` comments before writing final spec.

These comments were temporary scaffolding for agents (architect, implementer). The final test must not contain them.

```ruby
# Find and remove all "# Logic:" comments
spec_content.gsub!(/^\s*# Logic: .+\n/, '')

# Example transformation:
# BEFORE:
#   context 'with balance is sufficient' do
#     # Logic: app/services/payment_service.rb:78
#     let(:user) { build_stubbed(:user, balance: 200) }
#
# AFTER:
#   context 'with balance is sufficient' do
#     let(:user) { build_stubbed(:user, balance: 200) }
```

**Validation:**

```bash
# Verify no Logic comments remain
if grep -q "# Logic:" "$spec_file"; then
  echo "Error: # Logic: comments still present in spec" >&2
  echo "Must remove all source location comments" >&2
  exit 1
fi
```

**Why remove them:**
- They were navigation aids for agents only
- Users don't need them (they have the actual code)
- Reduces noise in final test
- Comments become stale when code changes

**Step 8: Write Output**

```bash
# Write updated spec (with Logic comments removed)
echo "$spec_content" > "$spec_file"

# Update metadata
# Add: automation.implementer_completed = true

echo "✅ Implementation complete: $spec_file"
exit 0
```

## Error Handling (Fail Fast)

### Error 1: Cannot Determine Expected Behavior

```bash
echo "Error: Cannot determine expected behavior for test: $it_description" >&2
echo "" >&2
echo "Context path: $context_path" >&2
echo "Code analysis failed - unclear what method does in this path" >&2
echo "" >&2
echo "This may indicate:" >&2
echo "  1. it description doesn't match code behavior" >&2
echo "  2. Code path doesn't exist (unreachable code)" >&2
echo "  3. Code too complex to analyze" >&2
exit 1
```

### Error 2: Missing Factory

**Scenario 1: Factory exists but trait missing**

```bash
echo "Warning: Trait :$trait_name not found in $model_name factory" >&2
echo "" >&2
echo "Using attribute override instead" >&2
echo "Consider adding trait to spec/factories/${model_name}s.rb" >&2
# Continue with fallback (see algorithm below)
```

**Scenario 2: Factory doesn't exist at all**

```bash
echo "Warning: Factory not found for model: $model_name" >&2
echo "" >&2
echo "Attempting fallback strategies..." >&2
# Try fallback (see algorithm below)
```

**Fallback Algorithm:**

```
Factory missing entirely?
  Step 1: Try FactoryBot.build(model_name.to_sym, attributes)
    → Check if FactoryBot knows this factory (might be defined elsewhere)

  Step 2: If fails, try model_class.new(attributes)
    → Direct instantiation without factory

  Step 3: If still fails, raise error
    → Cannot proceed, need factory or valid model

Trait missing but factory exists?
  Step 1: Convert trait to attribute
    → Use trait → attribute mapping rules (see below)

  Step 2: Use build_stubbed(:model, attribute: value)
```

**Example 1: Missing Trait**

```ruby
# Needed: let(:user) { build_stubbed(:user, :authenticated) }
# But factory has no :authenticated trait

# Fallback:
let(:user) { build_stubbed(:user, authenticated: true) }

# stderr warning:
# Warning: Trait :authenticated not found in user factory
# Using attribute: authenticated: true
# Consider adding to spec/factories/users.rb:
#   trait :authenticated do
#     authenticated { true }
#   end
```

**Example 2: Missing Factory**

```ruby
# Needed: let(:payment) { build_stubbed(:payment) }
# But no payment factory exists

# Fallback attempt 1: Try FactoryBot
begin
  build_stubbed(:payment)
rescue FactoryBot::InvalidFactoryError
  # Fallback attempt 2: Direct instantiation
  Payment.new
end

# stderr warning:
# Warning: Factory not found for model: Payment
# Using direct instantiation: Payment.new
# Consider creating: spec/factories/payments.rb
```

**Trait → Attribute Mapping Rules:**

When trait is missing, convert to attribute using these rules:

**Rule 1: Binary characteristics (authenticated/valid/active)**
```
Trait: :authenticated
State indicates: user IS authenticated (positive state)
→ Attribute: authenticated: true

Trait: :not_authenticated (if needed)
State indicates: user is NOT authenticated (negative state)
→ Attribute: authenticated: false (or omit attribute entirely)
```

**Rule 2: Enum characteristics (payment_method: card/paypal)**
```
Trait: :card
State value: 'card'
→ Attribute: payment_method: :card

Trait: :paypal
State value: 'paypal'
→ Attribute: payment_method: :paypal
```

**Rule 3: Range/numeric characteristics (balance: sufficient/insufficient)**
```
Trait: :sufficient_balance
State indicates: balance is sufficient (high value needed)
→ Attribute: balance: 200 (or other reasonable high value)

Trait: :insufficient_balance
State indicates: balance is insufficient (low value)
→ Attribute: balance: 0 (or very small value)
```

**Rule 4: Complex/semantic states**
```
Trait: :premium_membership
→ Attribute: membership_level: :premium

Trait: :expired
→ Attribute: expires_at: 1.day.ago
```

**Decision Algorithm:**

```
1. Identify characteristic type:
   - Binary (true/false) → boolean attribute
   - Enum (one of set) → symbol/string attribute
   - Range (sufficient/high/low) → numeric attribute with appropriate value
   - Temporal (expired/active) → timestamp attribute

2. Extract attribute name from trait:
   - :authenticated → authenticated
   - :card → payment_method (from context)
   - :sufficient_balance → balance

3. Determine attribute value from state:
   - Positive binary → true
   - Negative binary → false
   - Enum → symbol matching state
   - Range → representative numeric value
   - Temporal → timestamp calculation

4. Generate attribute override:
   - let(:model) { factory_method(:model, attribute: value) }
```

**Complete Example:**

```
Context path: user_authenticated=authenticated, balance=sufficient

Factories available:
  user:
    traits: [:admin]  # No :authenticated or :sufficient_balance

Step 1: Identify missing traits
  - :authenticated (missing)
  - :sufficient_balance (missing)

Step 2: Map to attributes
  - authenticated → authenticated: true (binary, positive)
  - sufficient_balance → balance: 200 (range, high value)

Step 3: Generate let block
  let(:user) { build_stubbed(:user, authenticated: true, balance: 200) }
```

### Error 3: Method Signature Changed

```bash
echo "Error: Method signature doesn't match metadata" >&2
echo "" >&2
echo "Expected parameters: $(echo $metadata | jq '.method_params')" >&2
echo "Found in code: $actual_params" >&2
echo "" >&2
echo "Source file may have changed since analysis" >&2
echo "Re-run rspec-analyzer" >&2
exit 1
```

## Dependencies

**Must run after:**
- rspec-architect (needs it descriptions)

**Must run before:**
- rspec-factory-optimizer (can optimize what implementer created)

**Reads:**
- metadata.yml
- spec file (with it blocks)
- source code file

**Writes:**
- spec file (updated with bodies)
- metadata.yml (marks completion)

## Examples

### Example 1: Unit Test with build_stubbed

**Metadata:**
```yaml
test_level: unit
target:
  method: calculate_discount
  method_type: instance
```

**Source code:**
```ruby
def calculate_discount(customer_type)
  case customer_type
  when :regular then 0.0
  when :premium then 0.1
  when :vip then 0.2
  end
end
```

**Input spec:**
```ruby
describe '#calculate_discount' do
  context 'when customer_type is premium' do
    it 'returns 10% discount' do
    end
  end
end
```

**Output:**
```ruby
describe '#calculate_discount' do
  subject(:result) { described_class.new.calculate_discount(customer_type) }

  context 'when customer_type is premium' do
    let(:customer_type) { :premium }

    it 'returns 10% discount' do
      expect(result).to eq(0.1)
    end
  end
end
```

**Note:** No factories needed (simple parameter), returns value directly

---

### Example 2: Integration Test with create and Side Effects

**Metadata:**
```yaml
test_level: integration
factories_detected:
  user:
    traits: [authenticated]
```

**Source code:**
```ruby
def process_payment(user, amount)
  payment = Payment.create!(user: user, amount: amount)
  payment
end
```

**Input spec:**
```ruby
context 'with balance is sufficient' do
  it 'creates payment record' do
  end

  it 'returns payment object' do
  end
end
```

**Output:**
```ruby
subject(:result) { described_class.new.process_payment(user, amount) }

let(:user) { create(:user, :authenticated) }  # create for integration
let(:amount) { 100.0 }

context 'with balance is sufficient' do
  it 'creates payment record' do
    expect { result }.to change(Payment, :count).by(1)
  end

  it 'returns payment object' do
    expect(result).to be_a(Payment)
    expect(result.amount).to eq(amount)
  end
end
```

**Note:** Uses `create` (not `build_stubbed`) because test_level = integration

---

### Example 3: Error Handling

**Source code:**
```ruby
def process_payment(user, amount)
  raise AuthenticationError unless user.authenticated?
  # ...
end
```

**Input spec:**
```ruby
context 'when user is NOT authenticated' do
  it 'raises AuthenticationError' do
  end
end
```

**Output:**
```ruby
context 'when user is NOT authenticated' do
  let(:user) { build_stubbed(:user) }  # No :authenticated trait

  it 'raises AuthenticationError' do
    expect { result }.to raise_error(AuthenticationError)
  end
end
```

---

### Example 4: Missing Factory Trait (Fallback to Attributes)

**Metadata:**
```yaml
factories_detected:
  user:
    traits: [admin]  # No :authenticated trait
```

**Required setup:** authenticated user

**Output:**
```ruby
let(:user) { build_stubbed(:user, authenticated: true) }  # Attribute fallback
```

**stderr:**
```
Warning: Trait :authenticated not found in user factory
Using attribute override instead
Consider adding trait to spec/factories/users.rb
```

## Integration with Skills

### From rspec-write-new skill

```markdown
Sequential execution:
1. rspec-analyzer → metadata
2. spec_skeleton_generator → structure
3. rspec-architect → descriptions
4. rspec-implementer → bodies
5. rspec-factory-optimizer → optimize
```

## Testing Criteria

**Agent is correct if:**
- ✅ All it blocks have expectations
- ✅ subject defined correctly (instance vs class method)
- ✅ let blocks provide necessary setup
- ✅ Correct factory method (build_stubbed vs create)
- ✅ Uses traits when available
- ✅ Tests behavior, not implementation (Rule 1)
- ✅ Multiple behaviors = multiple expectations or aggregate_failures

**Common issues to test:**
- test_level = unit but uses create (should use build_stubbed)
- Missing let block (test will fail)
- Testing implementation (.receive(:save)) instead of behavior
- Expectation doesn't match it description

## Related Specifications

- **contracts/metadata-format.spec.md** - test_level, factories_detected
- **agents/rspec-architect.spec.md** - Previous agent (provides it descriptions)
- **agents/rspec-factory-optimizer.spec.md** - Next agent (optimizes factories)

---

**Key Takeaway:** Implementer writes working tests. Analyzes code for behavior, uses appropriate factories, follows test level guidance.
