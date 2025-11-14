# rspec-implementer Agent Specification

**Version:** 2.0
**Created:** 2025-11-07
**Updated:** 2025-11-15
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

**Coordination with rspec-factory (NEW in v2.0):**
- **rspec-factory** handles ActiveRecord models (setup.type = factory) before implementer runs
- **rspec-implementer** handles everything else:
  - PORO/hashes/primitives (setup.type = data)
  - Before hooks for session/state (setup.type = action)
  - Composite characteristics (multiple attributes)
  - Range calculations with threshold values
- Clean separation via setup.type field

**Value:**
- Transforms test skeleton into working test
- Follows guide.en.md rules (especially Rule 1, 4, 11-16)
- Coordinates with factory agent (skip factory-handled setup)
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

### 🟡 SHOULD Check (Warnings)

```bash
# Check if factory agent completed
# (Warning only - factory may be skipped if no factory-type characteristics)
if ! grep -q "factory_completed: true" "$metadata_path"; then
  echo "Warning: rspec-factory has not run or was skipped" >&2
  echo "This is normal if all characteristics are setup.type = data | action" >&2
  echo "Implementer will handle all {SETUP_CODE} placeholders" >&2
fi
```

## Input Contract

**Reads:**
1. **metadata.yml** - test_level, characteristics (with setup, type, source fields), factories_detected, threshold_value, threshold_operator
2. **Spec file** - structure with it descriptions (but no bodies) + `# Logic:` comments
3. **Source code** - method signature, dependencies, behavior

**IMPORTANT:** Spec file contains `# Logic: path:line` comments that point to source code locations:

```ruby
context 'when user is authenticated' do
  # Logic: app/services/payment_service.rb:45
  {SETUP_CODE}
```

These comments help you navigate to relevant code quickly. **You will remove them after implementation.**

**Spec file may also contain threshold hints for range characteristics:**

```ruby
context 'with balance is sufficient' do
  # Logic: app/services/payment_service.rb:78
  {SETUP_CODE}  # threshold-based: let(:balance) { 1050 }
```

or for float thresholds:

```ruby
context 'with percentage is high' do
  {SETUP_CODE}  # range threshold: above 0.5
```

These hints from skeleton-generator help you:
- Use calculated integer threshold values directly (1050 = 1000 + 5%)
- Know the comparison direction for float thresholds (above/below)
- You should **use the hint** when generating setup code, then **remove the hint comment** after implementation

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

### Decision Tree 1: Data Preparation Pattern (setup field)

```
For each characteristic, check setup field:

setup = 'data'?
  YES → Generate let block with factory/data structures
    test_level = 'unit' → build_stubbed(:model, attributes)
    test_level = 'integration' → create(:model, attributes)

    Combine multiple characteristics affecting same parameter:
      let(:user) { build_stubbed(:user, :trait1, attr1: val1, attr2: val2) }

setup = 'action'?
  YES → Generate before block with method calls
    test_level = 'unit' → Use stubs/mocks
      before { allow(subject).to receive(:method?).and_return(true) }

    test_level = 'integration' → Use real method calls
      Session/cookies: before { session[:key] = value }
      State transitions: before { subject.transition! }
      Sequential: before { subject.step1!; subject.step2! }

Mixed setup types in same context?
  YES → Generate both let and before blocks
    Example:
      let(:user) { build_stubbed(:user) }  # setup = data
      before { session[:user_id] = user.id }  # setup = action
```

### Decision Tree 2: build_stubbed vs create?

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

**Step 0: Check if factory agent handled this characteristic**

```
Read setup object from characteristic:
  setup.type = 'factory' AND characteristic.type != 'composite' AND characteristic.type != 'range':
    → SKIP (factory agent already filled {SETUP_CODE} for this)

  setup.type = 'factory' AND characteristic.type == 'composite':
    → PROCESS (composite setup needs multiple let blocks, factory agent skipped)

  setup.type = 'factory' AND characteristic.type == 'range' with threshold_value:
    → PROCESS (range needs value calculation, factory agent skipped)

  setup.type = 'data':
    → PROCESS (PORO/hashes/primitives, factory agent doesn't handle)

  setup.type = 'action':
    → PROCESS (before hooks for session/state machine, factory agent doesn't handle)
```

**Coordination principle:**
- Factory agent fills {SETUP_CODE} for **simple ActiveRecord** characteristics (setup.type = factory)
- Implementer fills {SETUP_CODE} for **everything else**:
  - PORO/hashes/primitives (setup.type = data)
  - Before hooks (setup.type = action)
  - Composite characteristics (multiple attributes, even if AR model)
  - Range with threshold calculations

**Step 1: Map characteristic to parameter**

```
Characteristic name usually matches parameter prefix:
  user_authenticated → affects 'user' parameter
  payment_method → affects 'payment_method' or 'user.payment_method'
  balance → affects 'user.balance' or separate 'balance' parameter
```

**Step 2: Check if factory trait exists (for setup = 'data' only)**

```
Look in factories_detected from metadata:
  Model: user
  Traits: [:authenticated, :blocked, :premium]

Trait exists for this state?
  YES → Use trait (e.g., :authenticated)
  NO → Use attribute (e.g., authenticated: true)
```

**Step 3: Determine factory method (for setup = 'data') or stub pattern (for setup = 'action')**

```
If setup = 'data':
  test_level == 'unit' → build_stubbed
  test_level == 'integration' → create
  test_level == 'request' → create

If setup = 'action':
  test_level == 'unit' → stub/mock (allow(...).to receive)
  test_level == 'integration' → before hook with action
  test_level == 'request' → before hook with action
```

**Step 3a: Check for threshold hints (range characteristics only)**

For range characteristics, skeleton-generator may leave hints in comments. Check if context has threshold hint:

```
Pattern 1: Integer threshold (concrete value calculated)
  {SETUP_CODE}  # threshold-based: let(:balance) { 1050 }

  Action: Use the calculated value directly
  → let(:balance) { 1050 }

Pattern 2: Float threshold (needs domain knowledge)
  {SETUP_CODE}  # range threshold: above 0.5

  Action: Generate appropriate value for domain
  - Money: 0.51, 0.49
  - Percentage: 0.6, 0.4
  - Probability: 0.7, 0.3
  - Time seconds: 0.6, 0.4

Pattern 3: No hint (threshold_value missing in metadata)
  {SETUP_CODE}

  Action: Read characteristic from metadata, check threshold_value/threshold_operator
  - If integer: calculate using ±5% offset
  - If float or nil: read source code to find threshold value
```

**After using hint, remove it from output:**
```ruby
# Input:
  {SETUP_CODE}  # threshold-based: let(:balance) { 1050 }

# Output (hint removed):
  let(:balance) { 1050 }
```

**Step 4: Generate setup code based on setup field**

**For setup = 'data':** Combine multiple characteristics affecting same parameter

**Example scenario (setup = 'data'):**
```
Context path:
  1. user_authenticated = authenticated (setup: data)
  2. payment_method = card (setup: data)
  3. balance = sufficient (setup: data)

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

**Combining algorithm (setup = 'data'):**

```
Group characteristics by parameter they affect:
  user: [user_authenticated=authenticated, payment_method=card, balance=sufficient]

For each parameter group:
  1. Collect all traits that exist in factory
  2. Collect all attributes that don't have traits
  3. Build let statement:
     let(:param) { factory_method(:model, *traits, **attributes) }
```

**For setup = 'action':** Generate before blocks with method calls

**Example scenario (setup = 'action'):**
```
Context path:
  1. user_authenticated = authenticated (setup: action)
     → before { session[:user_id] = user.id }

  2. order_status = shipped (setup: action, type: sequential)
     → before { order.process!; order.ship! }
```

**Action generation algorithm:**

```
1. Identify action type from characteristic:
   - Session/cookies → session[:key] = value
   - Sequential state machine → call transition methods in order
   - Method call → subject.method_name!
   - Computed value → subject.compute_method

2. For sequential + action:
   - Get all states up to current state
   - Generate transition calls in order
   - Example: pending → processed → shipped
     before do
       order.process!
       order.ship!
     end

3. For unit tests (setup = action, test_level = unit):
   - Use stubs instead of real calls
   - Example: allow(subject).to receive(:authenticated?).and_return(true)

4. For integration tests (setup = action):
   - Use real method calls
   - Example: before { user.authenticate!(password) }
```

**Step 5: Handle context overrides**

**For setup = 'data':**
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

**For setup = 'action':**
Parent context defines setup, child context adds more actions:

```ruby
context 'when user is authenticated' do
  before { session[:user_id] = user.id }  # Base

  context 'and order_status is shipped' do
    # Add more before blocks (don't override, accumulate)
    before do
      order.process!
      order.ship!
    end
  end
end
```

**Important:** `before` blocks accumulate (parent runs first, then child), while `let` blocks override.

**Complete workflow example 1 (setup = 'data'):**

```
Input:
  Characteristics:
    - user_authenticated = authenticated (setup: data)
    - payment_method = card (setup: data)
    - balance = sufficient (setup: data)
  Method params: ['user', 'amount']
  Test level: 'unit'
  Factories: { user: { traits: [:authenticated, :blocked] } }

Step-by-step:

0. Check setup fields: all are 'data' → use let pattern

1. Map characteristics to parameters:
   user_authenticated → user
   payment_method → user
   balance → user

2. Check traits:
   :authenticated → EXISTS in user factory
   :card → NO trait for payment_method
   :sufficient → NO trait for balance

3. Factory method: build_stubbed (unit level, setup = data)

4. Combine for user:
   Traits: [:authenticated]
   Attributes: { payment_method: :card, balance: 200 }

5. Result:
   let(:user) { build_stubbed(:user, :authenticated, payment_method: :card, balance: 200) }

6. Placement:
   Add to innermost context (balance = sufficient)
```

**Complete workflow example 2 (setup = 'action'):**

```
Input:
  Characteristics:
    - user_authenticated = authenticated (setup: action)
    - order_status = shipped (setup: action, type: sequential, states: [pending, processed, shipped])
  Method params: ['user', 'order']
  Test level: 'integration'

Step-by-step:

0. Check setup fields: all are 'action' → use before pattern

1. For user_authenticated (setup: action):
   - Detect: session-based authentication
   - Generate: before { session[:user_id] = user.id }

2. For order_status = shipped (setup: action, type: sequential):
   - Get states up to shipped: [pending, processed, shipped]
   - Transitions: process!, ship!
   - Generate: before { order.process!; order.ship! }

3. Result (integration test):
   context 'when user is authenticated' do
     before { session[:user_id] = user.id }

     context 'and order_status is shipped' do
       before do
         order.process!
         order.ship!
       end
     end
   end

4. If this were unit test instead:
   before { allow(user).to receive(:authenticated?).and_return(true) }
   before { allow(order).to receive(:status).and_return(:shipped) }
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

**Step 7: Clean Up Agent Comments**

**CRITICAL:** Remove all agent-to-agent comments before writing final spec.

These comments were temporary scaffolding for agents (architect, implementer, skeleton-generator). The final test must not contain them.

**Comment types to remove:**

**1. Logic location comments:**
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

**2. Threshold hint comments:**
```ruby
# Remove inline threshold hints after processing
# Pattern: "  # threshold-based: let(:var) { value }"
# Pattern: "  # range threshold: above/below N"

# Example transformation:
# BEFORE:
#   {SETUP_CODE}  # threshold-based: let(:balance) { 1050 }
#   let(:balance) { 1050 }
#
# AFTER:
#   let(:balance) { 1050 }
```

**3. Placeholder markers (should be replaced, not just removed):**
```ruby
# These should already be replaced by implementer
# If any remain, that's an ERROR
placeholders = ['{SETUP_CODE}', '{EXPECTATION}', '{THRESHOLD_VALUE}', '{BEHAVIOR_DESCRIPTION}']
```

**Validation:**

```bash
# Verify no agent comments remain
if grep -q "# Logic:" "$spec_file"; then
  echo "Error: # Logic: comments still present in spec" >&2
  exit 1
fi

if grep -q "# threshold-based:" "$spec_file"; then
  echo "Error: threshold hint comments still present" >&2
  exit 1
fi

if grep -q "# range threshold:" "$spec_file"; then
  echo "Error: range threshold comments still present" >&2
  exit 1
fi

if grep -E '\{(SETUP_CODE|EXPECTATION|THRESHOLD_VALUE|BEHAVIOR_DESCRIPTION)\}' "$spec_file"; then
  echo "Error: Placeholders not replaced in spec" >&2
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

---

### Example 5: Action-based Setup (before blocks)

**Metadata:**
```yaml
test_level: integration
characteristics:
  - name: user_authenticated
    setup: action  # Uses before, not let
    type: binary
    states: [authenticated, not_authenticated]
```

**Source code:**
```ruby
def process_order(order)
  raise AuthenticationError unless session[:user_id]
  order.process!
  order
end
```

**Input spec:**
```ruby
context 'when user is authenticated' do
  it 'processes order successfully' do
  end
end
```

**Output:**
```ruby
subject(:result) { described_class.new.process_order(order) }

let(:order) { create(:order, status: :pending) }

context 'when user is authenticated' do
  before { session[:user_id] = user.id }  # Action-based setup

  it 'processes order successfully' do
    expect { result }.to change { order.reload.status }.from(:pending).to(:processed)
  end
end
```

**Note:** Uses `before` hook for session (setup = action), but still uses `let` for order object (setup = data)

---

### Example 6: Sequential State Machine with Action Setup

**Metadata:**
```yaml
test_level: integration
characteristics:
  - name: order_status
    setup: action  # State machine transitions
    type: sequential
    states: [pending, processed, shipped, delivered]
```

**Source code:**
```ruby
def calculate_shipping_cost(order)
  return 0 if order.status == :delivered
  10.0
end
```

**Input spec:**
```ruby
context 'with order_status is delivered' do
  it 'returns zero cost' do
  end
end
```

**Output:**
```ruby
subject(:result) { described_class.new.calculate_shipping_cost(order) }

let(:order) { create(:order, status: :pending) }

context 'with order_status is delivered' do
  # Action-based: chain transitions to reach desired state
  before do
    order.process!
    order.ship!
    order.deliver!
  end

  it 'returns zero cost' do
    expect(result).to eq(0)
  end
end
```

**Note:** For sequential + action, generates transition chain instead of factory attribute

---

### Example 7: Range Characteristic with Threshold Hints

**Metadata:**
```yaml
test_level: unit
characteristics:
  - name: balance_sufficient
    setup: data
    type: range
    states: [sufficient, insufficient]
    threshold_value: 1000
    threshold_operator: '>='
```

**Input spec (from skeleton-generator):**
```ruby
context 'with balance is sufficient' do
  # Logic: app/services/payment_service.rb:120
  {SETUP_CODE}  # threshold-based: let(:balance) { 1050 }

  it 'processes payment' do
    {EXPECTATION}
  end
end

context 'with balance is insufficient' do
  # Logic: app/services/payment_service.rb:120
  {SETUP_CODE}  # threshold-based: let(:balance) { 950 }

  it 'raises InsufficientFundsError' do
    {EXPECTATION}
  end
end
```

**Output (after implementer):**
```ruby
subject(:result) { described_class.new.process_payment(user, balance) }

let(:user) { build_stubbed(:user) }

context 'with balance is sufficient' do
  let(:balance) { 1050 }  # Used hint: 1000 + 5% = 1050

  it 'processes payment' do
    expect { result }.not_to raise_error
  end
end

context 'with balance is insufficient' do
  let(:balance) { 950 }  # Used hint: 1000 - 5% = 950

  it 'raises InsufficientFundsError' do
    expect { result }.to raise_error(InsufficientFundsError)
  end
end
```

**Note:**
- Implementer used threshold hints from skeleton-generator (1050, 950)
- All agent comments removed (`# Logic:`, `# threshold-based:`)
- Values calculated as threshold ± 5%

---

### Example 8: Float Threshold Needs Domain Knowledge

**Metadata:**
```yaml
characteristics:
  - name: percentage_high
    type: range
    threshold_value: 0.5
    threshold_operator: '>'
```

**Input spec (from skeleton-generator):**
```ruby
context 'with percentage is high' do
  {SETUP_CODE}  # range threshold: above 0.5

  it 'returns discount' do
    {EXPECTATION}
  end
end
```

**Output (after implementer):**
```ruby
context 'with percentage is high' do
  let(:percentage) { 0.6 }  # Float: used domain knowledge (percentage)

  it 'returns discount' do
    expect(result).to be > 0
  end
end
```

**Note:**
- Skeleton-generator left hint "above 0.5" but no concrete value (float threshold)
- Implementer analyzed domain (percentage) and chose 0.6 (comfortably above 0.5)
- Hint comment removed from final output

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
- ✅ Setup code matches characteristic `setup` field (let for data, before for action)
- ✅ Correct factory method (build_stubbed vs create for setup = data)
- ✅ Uses traits when available (for setup = data)
- ✅ Tests behavior, not implementation (Rule 1)
- ✅ Multiple behaviors = multiple expectations or aggregate_failures
- ✅ Sequential + action = chained transitions in before block
- ✅ Threshold hints processed correctly (integer values used, float values with domain knowledge)
- ✅ All agent comments removed (# Logic:, # threshold-based:, # range threshold:)
- ✅ No placeholders remaining ({SETUP_CODE}, {EXPECTATION}, {THRESHOLD_VALUE})

**Common issues to test:**
- test_level = unit but uses create (should use build_stubbed)
- setup = 'data' but uses before block (should use let)
- setup = 'action' but uses let block (should use before)
- Missing let/before block (test will fail)
- Testing implementation (.receive(:save)) instead of behavior
- Expectation doesn't match it description
- Sequential + action but doesn't chain transitions
- Threshold hint not used (ignored skeleton-generator's calculated value)
- Agent comments still present in final spec
- Placeholders not replaced

## Related Specifications

- **contracts/metadata-format.spec.md** - test_level, factories_detected, characteristic.setup field, threshold_value, threshold_operator
- **ruby-scripts/spec-skeleton-generator.spec.md** - Generates structure with {SETUP_CODE}, {EXPECTATION} placeholders and threshold hints
- **agents/rspec-architect.spec.md** - Previous agent (provides it descriptions)
- **agents/rspec-analyzer.spec.md** - Provides characteristic.setup field and threshold detection
- **agents/rspec-factory-optimizer.spec.md** - Next agent (optimizes factories)

---

**Key Takeaway:** Implementer writes working tests. Analyzes code for behavior, uses appropriate factories (data) or before hooks (action), follows test level guidance, processes threshold hints from skeleton-generator, and removes all agent scaffolding comments.
