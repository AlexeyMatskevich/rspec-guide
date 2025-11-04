# Algorithm for Writing BDD Tests in RSpec

## Introduction: Philosophy of the Approach

This algorithm is built on the principles of **Behaviour-Driven Development (BDD)** and aims to create tests that:
- Serve as executable documentation of business rules
- Minimize cognitive load when reading and maintaining tests
- Reveal code design problems through test complexity
- Focus on behavior, not implementation

**Learn more:** [About RSpec](../guide.en.md#about-rspec) | [Cognitive Load](../guide.en.md#why-we-write-tests-this-way-cognitive-load) | [Tests as Code Quality Indicators](../guide.en.md#how-tests-reveal-design-problems)

## Stage 1: Determine Testing Level

### Goal
Determine which level of the testing pyramid your test belongs to, so you understand the scope of checks and level of detail.

### Why This Matters
Different test levels have different responsibilities. Unit tests check **all combinations**, integration tests check **happy path + critical corner cases**.

**Learn more:** [Testing Pyramid and Level Selection](../guide.en.md#testing-pyramid-and-level-selection)

### How to Determine Level

| Level | What We Test | Scope | Example |
|-------|--------------|-------|---------|
| **Unit** | Independent class/model | All combinations of characteristics | `PriceCalculator`, `User` model |
| **Integration** | Component interactions | Happy path + critical cases | Service calling repository |
| **Request/API** | HTTP contract | Main scenarios + errors | `POST /api/orders` |

### Example Solution
```ruby
# Testing PriceCalculator#calculate
# This is an independent class → UNIT TEST
# We'll test all combinations of discounts, taxes, promo codes

# Testing POST /api/payments
# This is an HTTP endpoint → REQUEST SPEC
# We'll combine payment prerequisites into one characteristic
```

### ⚠️ Important
System (E2E) tests in modern Rails projects are rarely written in RSpec due to separation into API + React frontend.

---

## Stage 2: Gather Characteristics

### Goal
Identify all domain aspects that influence the behavior of the code being tested.

### Why This Matters
Characteristics are business facts, not technical details. They form the language for communicating with business and structure tests.

**Learn more:** [Rule 4: Identify Behavior Characteristics and Their States](../guide.en.md#4-identify-behavior-characteristics-and-their-states)

### How to Gather Characteristics

#### For unit tests: all characteristics in detail
```ruby
# Class: OrderDiscountCalculator
# Characteristics:
# 1. Customer type (b2c/b2b)
# 2. Order amount (< 100 / >= 100)
# 3. Promo code presence (yes/no)
# 4. Seasonal discount (active/inactive)
```

#### For integration tests: combine by domain
```ruby
# Endpoint: POST /api/payments
# Top-level characteristics:
# 1. Authentication (authenticated/not authenticated)
# 2. Payment prerequisites (combines: card verified + sufficient balance)
#    ↳ Details are hidden in PaymentService unit test
# 3. Idempotency (new request/retry)
```

### Technique: Combining Characteristics

**Before combining (excessive detail in integration test):**
```ruby
# ❌ Bad for request spec
- User is authenticated
- Card is attached
- Card is verified
- Balance is sufficient
- Limits are not exceeded
```

**After combining by domain:**
```ruby
# ✅ Good for request spec
- User is authenticated
- Payment prerequisites met (includes everything above)
```

### ✅ Checklist
- [ ] Does the characteristic describe a business fact, not a technical detail?
- [ ] Can you state the characteristic in business language?
- [ ] For integration tests: did you combine details from one domain?

**See also:** [Glossary: Characteristics and States](../guide.en.md#characteristics-and-states)

---

## Stage 3: Identify Characteristic Dependencies

### Goal
Build a hierarchy of characteristics, determining which are dependent and which are independent.

### Why This Matters
Dependencies define context structure. A proper hierarchy reduces cognitive load — the reader immediately sees logical connections.

**Learn more:** [Rule 5: Build Context Hierarchy by Characteristic Dependencies](../guide.en.md#5-build-context-hierarchy-by-characteristic-dependencies-happy-path--corner-cases)

### Types of Dependencies

| Type | Description | Example |
|------|-------------|---------|
| **Base** | Without it, others don't make sense | Having a card |
| **Dependent** | Only makes sense in certain state of base | Card balance (only if card exists) |
| **Independent** | Doesn't depend on other characteristics | User role and beta access |

### Building the Hierarchy

```ruby
# Example of dependent characteristics
Card payment
├── Card presence (base)
│   └── Card balance (depends on card presence)
│       └── Transaction limit (depends on balance)
└── [No card → other characteristics not considered]

# Example of independent characteristics (can change order)
Feature access
├── User role
│   └── Beta access
or
├── Beta access
│   └── User role
```

### Important Clarification
Stage 3 is about finding dependencies for **all levels** of the hierarchy, not just the top. Each characteristic can have its own dependent sub-characteristics.

### ⚠️ Problem Signal
If the hierarchy goes deeper than 4-5 levels — your code violates the "Do One Thing" principle. This is a code problem, not a test problem.

**See also:** [Glossary: Design Principles — Do One Thing](../guide.en.md#design-principles)

---

## Stage 4: Determine Characteristic Types

### Goal
Classify each characteristic to properly determine the number of states.

### Why This Matters
Characteristic type determines the number of contexts and helps you avoid missing edge cases.

### Classification of Types

| Type | States | Example | Number of Contexts |
|------|--------|---------|-------------------|
| **Binary** | 2 options | Card yes/no | 2 |
| **Multiple enum** | N options | Role: admin/manager/user | 3+ |
| **Range** | Value groups | Balance: sufficient/insufficient | 2+ |
| **Sequential** | Ordered states | Status: draft→pending→paid | 3+ |

### Special Case: Ranges

Ranges should be split into business-meaningful groups:

```ruby
# ❌ Bad: technical boundaries
balance == 0
balance == 99
balance == 100
balance == 101

# ✅ Good: business states
balance < price    # Insufficient for payment
balance >= price   # Sufficient for payment
```

### Example Analysis
```ruby
# Characteristic: User subscription
# Type: Multiple enum
# States: trial / basic / premium / expired
# Number of contexts: 4
```

---

## Stage 5: Determine States and Defaults

### Goal
List all possible states for each characteristic and identify defaults.

### Why This Matters
A default state doesn't require a separate context, simplifying test structure. Explicit state listing guarantees complete coverage.

### Rules for Determining Defaults

| Situation | Default | Example |
|-----------|---------|---------|
| New object | Initial state | User: `blocked: false` |
| Typical scenario | Most common | Order: `status: 'pending'` |
| Happy path | Successful state | Payment: `successful: true` |

### Example State Table

```ruby
# Service: PaymentProcessor
# Characteristics and states:

| Characteristic      | Type    | States              | Default   |
|-------------------|---------|---------------------|-----------|
| User authentication | Binary  | authenticated/guest | guest     |
| Payment method     | Enum    | card/paypal/crypto | card      |
| Amount             | Range   | valid/exceeded      | valid     |
| Fraud check        | Binary  | passed/failed       | passed    |
```

### Impact on Context Structure

```ruby
# Characteristic with default (card — default)
describe '#process_payment' do
  # Default doesn't need a context
  it 'processes card payment'

  context 'when payment method is paypal' do
    it 'processes paypal payment'
  end
end

# Characteristic without default
describe '#apply_discount' do
  context 'when customer is b2c' do
    it 'applies consumer discount'
  end

  context 'when customer is b2b' do
    it 'applies business discount'
  end
end
```

---

## Stage 6: Build Context Tree

### Goal
Transform the characteristic hierarchy into RSpec context structure.

### Why This Matters
Proper context structure makes tests self-documenting and reflects business logic.

**Learn more:** [Rule 20: Context Language: when / with / and / without / but / NOT](../guide.en.md#20-context-language-when--with--and--without--but--not)

### Rules for Building

1. **One characteristic level = one `context` level**
2. **Default state = no context**
3. **Non-default states = separate contexts**
4. **Follow when/with/and/without/but language**

### Context Language (by priority)

| Keyword | Usage | Example |
|---------|-------|---------|
| `when` | Opens a branch, base characteristic | `when user has a card` |
| `with` | Positive clarification (happy path) | `with sufficient balance` |
| `and` | Additional positive state | `and card is verified` |
| `without` | Absence (for binary) | `without email verification` |
| `but` | Contrast to happy path | `but balance is insufficient` |

### Example Building

```ruby
# Characteristics:
# 1. Card presence (binary, no default)
#    └── 2. Balance (range: sufficient/insufficient)

describe PaymentService do
  context 'when user has a payment card' do           # Level 1
    context 'with sufficient balance' do               # Level 2, happy path
      # it goes here at stage 7
    end

    context 'but balance is insufficient' do           # Level 2, corner case
      # it goes here at stage 7
    end
  end

  context 'when user does NOT have a payment card' do  # Level 1, alternative
    # it goes here at stage 7
  end
end
```

### Note
At this stage we only build context structure. Concrete `it` with behavior descriptions come at Stage 7.

---

## Stage 7: Identify Expected Behaviors

### Goal
For each leaf context, identify observable behavior and classify it as happy path or corner case.

### Why This Matters
1. **Consistency check:** Ensure happy path and corner cases don't mix in one context
2. **Preparation for sorting:** Understanding each `it`'s type helps for proper sorting at Stage 8
3. **Readability:** Clear separation helps reader quickly understand main scenario and deviations

**Learn more:**
- [Rule 1: Test Behavior, Not Implementation](../guide.en.md#1-test-behavior-not-implementation)
- [Rule 3: Each Example (it) Describes One Observable Behavior](../guide.en.md#3-each-example-it-describes-one-observable-behavior)

### How It Works
- If leaf `it` describes successful/expected behavior → it's happy path
- Context containing happy path `it` → it's happy path context
- Context with corner case `it` → it's corner case context
- Default state without context + happy path `it` → will be elevated at stage 8

### Behavior Classification

| Type | Description | Markers |
|------|-------------|---------|
| **Happy path** | Main successful scenario | "successfully", "creates", "returns" |
| **Corner case** | Deviation, error, protection | "rejects", "fails", "raises", "denies" |

### Formulation Technique for `it`

```ruby
# Formula: [verb in 3rd person] + [object] + [qualifier]

# Happy path
it 'creates user account'
it 'sends confirmation email'
it 'returns success status'

# Corner cases
it 'rejects invalid data'
it 'raises AuthenticationError'
it 'does NOT create duplicate'  # NOT in caps for negation
```

### Example of Identifying Behaviors

```ruby
describe OrderService do
  # Happy path contexts
  context 'when all prerequisites met' do
    it 'creates order'                    # ✅ happy path
    it 'charges payment method'           # ✅ happy path
    it 'sends confirmation'               # ✅ happy path
  end

  # Corner case contexts
  context 'when payment fails' do
    it 'does NOT create order'            # ⚠️ corner case
    it 'returns error message'            # ⚠️ corner case
  end
end
```

---

## Stage 8: Sort by Happy Path First Principle

### Goal
Order contexts and examples so successful scenarios come first.

### Why This Matters
Reader understands "how it should work" first, then "what can go wrong".

**Learn more:** [Rule 7: Place Happy Path Before Corner Cases](../guide.en.md#7-place-happy-path-before-corner-cases)

### Sorting Rules

1. **At each level: happy path contexts first**
2. **Within context: positive tests first**
3. **Corner cases: from less to more critical**

### Example Before and After

```ruby
# ❌ Before sorting (chaotic)
describe '#process_order' do
  context 'when payment fails' do
    it 'cancels order'
  end

  context 'when inventory insufficient' do
    it 'puts on backorder'
  end

  context 'when everything valid' do
    it 'completes order'
  end
end

# ✅ After sorting
describe '#process_order' do
  context 'when everything valid' do          # 1. Happy path
    it 'completes order'
  end

  context 'when inventory insufficient' do    # 2. Soft failure
    it 'puts on backorder'
  end

  context 'when payment fails' do            # 3. Hard failure
    it 'cancels order'
  end
end
```

---

## Stage 9: Polish Description Language

### Goal
Ensure all descriptions follow BDD principles and describe behavior, not implementation.

### Why This Matters
1. **Tests are executable documentation:** Should read as business rule specification
2. **Readable failure output:** Good descriptions help quickly understand which rule broke
3. **Common business language:** Descriptions should be understood by non-developers

**Learn more:**
- [Rule 17: Description Should Form a Valid Sentence](../guide.en.md#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english)
- [Rule 18: Description Should Be Understandable to Anyone](../guide.en.md#18-description-of-contexts-context-and-test-cases-it-together-including-it-should-be-written-so-that-anyone-understands)
- [Rule 19: Grammar of describe/context/it Formulations](../guide.en.md#19-grammar-of-describe-context-it-formulations)

### Language Checklist

#### 9.1 Check for Behavior vs Implementation

```ruby
# ❌ Implementation
it 'sets status attribute to paid'
it 'calls EmailService.send'
it 'returns true'

# ✅ Behavior
it 'marks order as paid'
it 'notifies customer about payment'
it 'allows order processing'
```

#### 9.2 Grammar Check

| Element | Rule | Example |
|---------|------|---------|
| `describe` | Noun or #method | `describe User`, `describe '#calculate'` |
| `context` | when/with/and/without/but + state | `when user is admin` |
| `it` | 3rd person verb + result | `returns calculated price` |

#### 9.3 Check Readability Chain

```ruby
# Combine descriptions into a sentence:
# PaymentService
#   when customer has premium account
#     and payment amount exceeds limit
#       but manager approved override
#         it processes payment with override flag

# ✅ Reads like a story? Yes!
```

### Anti-patterns in Descriptions

| Anti-pattern | Example | Fix |
|--------------|---------|-----|
| Technical jargon | `when flag is true` | `when feature is enabled` |
| Unclear descriptions | `when condition met` | `when user has sufficient balance` |
| Excessive should | `it should create user` | `it creates user` |

---

## Stage 10: Implement Contexts (Given)

### Goal
Make data changes that make each context description true.

### Why This Matters
Context should explicitly prepare only what's described. This is the principle of explicitness and description truthfulness.

**Learn more:**
- [Rule 11: Each Test Should Be Divided Into 3 Stages](../guide.en.md#11-each-test-should-be-divided-into-3-phases-in-strict-order)
- [Rule 12: Use FactoryBot Capabilities](../guide.en.md#12-use-factorybot-capabilities-to-hide-test-data-details)

### Placement Rules

```ruby
context 'when user is blocked' do
  let(:blocked) { true }          # ← Place immediately under context
  let(:blocked_at) { 2.days.ago } # ← All let together

  # Not here! Don't hide at bottom
end
```

### Three Stages of a Test

```ruby
describe Calculator do
  # 1️⃣ GIVEN (Stage 10): Data preparation
  let(:tax_rate) { 0.1 }
  let(:discount) { 0.2 }

  # 2️⃣ WHAT (Stage 11): What we test
  subject(:result) { described_class.calculate(100, tax: tax_rate, discount: discount) }

  # 3️⃣ THEN (Stage 12): Verification
  it 'applies tax and discount' do
    expect(result).to eq(88) # (100 - 20%) + 10% = 88
  end
end
```

### Using Factories

**Learn more:**
- [Rule 12: Use FactoryBot Capabilities](../guide.en.md#12-use-factorybot-capabilities-to-hide-test-data-details)
- [Rule 14: Use build_stubbed in Unit Tests](../guide.en.md#14-in-unit-tests-except-models-use-build-stubbed)
- [Choosing FactoryBot Method: Decision Tree](../guide.en.md#choosing-factorybot-method-decision-tree)

```ruby
# ❌ Bad: technical details
let(:user) do
  create(:user,
    email: 'test@example.com',
    password: 'password123',
    confirmed_at: Time.current,
    role: 'admin',
    blocked: false)
end

# ✅ Good: business characteristics through traits
let(:user) { create(:user, :admin, :confirmed) }
```

---

## Stage 11: Determine Subject of Testing

### Goal
Clearly indicate what we test using named `subject(:name)`.

### Why This Matters
- Reader immediately sees what's being tested
- Avoid repeating method calls in each `it`
- Complete the three-phase structure: Given (let) → What (subject) → Then (expect)

**Learn more:** [Rule 10: Specify Subject](../guide.en.md#10-specify-subject-to-explicitly-designate-what-is-being-tested)

### Rules

1. **Subject always named:** `subject(:name)`, not unnamed
2. **Defined once:** at `describe` level
3. **Changes through let:** redefine `let`, not `subject`

### Example

```ruby
describe PriceCalculator do
  subject(:total) { calculator.calculate(order, tax_rate) }
  
  let(:calculator) { described_class.new }
  let(:order) { build(:order, subtotal: 100) }
  
  context 'with standard tax' do
    let(:tax_rate) { 0.2 }
    it { expect(total).to eq(120) }
  end
  
  context 'with reduced tax' do
    let(:tax_rate) { 0.1 }
    it { expect(total).to eq(110) }
  end
end
```

### ✅ Checklist
- [ ] Subject always named: `subject(:name)`?
- [ ] Defined once at `describe` level?
- [ ] Changes through `let` redefinition?

---

## Stage 12: Write Expectations (Then)

### Goal
Record observable results as RSpec expectations.

### Why This Matters
1. **Readable failure output:** Good matchers provide clear error messages
2. **Prevent flaky specs:** Wrong matcher locks to implementation details, creating unstable tests
3. **Check accuracy:** Matcher should check exactly the behavior described in `it`

**Learn more:** [Rule 28: Make Test Failure Output Readable](../guide.en.md#28-make-test-failure-output-readable)

### Consequences of Wrong Matcher Choice

| Problem | Example | Consequence |
|---------|---------|-------------|
| Order lock-in | `eq([1, 2, 3])` for array | Flaky test if query order changes |
| Over-checking | `eq(full_hash)` for API | Test fails when new field added |
| Unreadable output | JSON string comparison | Wall of text without diffs |

### Choosing the Right Matcher

| What to Check | Bad Matcher | Good Matcher | Why |
|---------------|-------------|--------------|-----|
| Array composition | `eq([1, 2, 3])` | `match_array([1, 2, 3])` | Order-independent |
| Presence of keys | `eq(hash)` | `include(key: value)` | Checks only important |
| Object attributes | Many `expect` | `have_attributes(...)` | Compact + aggregate_failures |
| State change | Before/after | `change { }.from().to()` | Shows change explicitly |

### Examples of Expectations

```ruby
# State change
it 'creates order' do
  expect { process_order }
    .to change(Order, :count).by(1)
    .and change { user.orders.count }.by(1)
end

# Object interface
it 'builds complete profile' do
  expect(profile).to have_attributes(
    name: 'John Doe',
    email: 'john@example.com',
    premium: true
  )
end

# HTTP response
it 'returns success response' do
  expect(response).to have_http_status(:created)
  expect(response.parsed_body).to include(
    'status' => 'success',
    'order_id' => kind_of(Integer)
  )
end
```

---

## Stage 13: Run and Debug

### Goal
Ensure tests work and actually check behavior.

### Why This Matters
A test that never failed proves nothing. Verify it catches bugs.

**Learn more:** [Rule 2: Check That Your Test Tests](../guide.en.md#2-verify-what-the-test-actually-tests)

### Verification Process

#### 13.1 First Run
```bash
rspec spec/services/payment_service_spec.rb
```

#### 13.2 If Tests Fail

| Check | Action |
|-------|--------|
| Correct contexts? | Check let/before in contexts |
| Correct expectations? | Check expect and matchers |
| Does code work? | Might have found a bug |
| Missed edge case? | Tests often find uncovered cases |

#### 13.3 Manual Red Check

```ruby
# Temporarily break the code
def calculate_discount
  return 0  # ← Return wrong value
  # ... rest of code
end

# Run test - it SHOULD fail
# If it passes, test isn't working!
```

---

## Stage 14: Check for Duplication

### Goal
Identify hidden characteristics and invariant contracts through duplication analysis.

### Why This Matters
Duplication in tests signals missing abstractions or improper structure.

**Learn more:**
- [Rule 6: Final Context Audit](../guide.en.md#6-final-context-audit-two-types-of-duplicates)
- [Rule 25: Use Shared Examples to Declare Contracts](../guide.en.md#25-use-shared-examples-to-declare-contracts)

### 14.1 Duplication of Preparation (let/before)

```ruby
# ❌ Signal: identical let at same level
context 'when order is small' do
  let(:shipping_cost) { 10 }  # ← duplicated
  it 'charges standard shipping'
end

context 'when order is large' do
  let(:shipping_cost) { 10 }  # ← duplicated
  it 'charges for heavy items'
end

# ✅ Solution: lift one level up or create separate context
let(:shipping_cost) { 10 }  # Default

context 'when order is small' do
  it 'charges standard shipping'
end

context 'when order is large' do
  context 'with free shipping promo' do
    let(:shipping_cost) { 0 }  # Override
    it 'waives shipping charges'
  end
end
```

### 14.2 Duplication of Expectations

```ruby
# If same checks in all leaf contexts
# ❌ Before
context 'when payment by card' do
  it 'returns transaction object' do
    expect(result).to respond_to(:id)
    expect(result).to respond_to(:status)
    expect(result).to respond_to(:amount)
  end
end

context 'when payment by paypal' do
  it 'returns transaction object' do
    expect(result).to respond_to(:id)      # ← same checks
    expect(result).to respond_to(:status)
    expect(result).to respond_to(:amount)
  end
end

# ✅ After: shared_examples
shared_examples 'a transaction result' do
  it { is_expected.to respond_to(:id, :status, :amount) }
end

context 'when payment by card' do
  it_behaves_like 'a transaction result'
  it 'includes card details' do
    expect(result.card_last_four).to eq('1234')
  end
end
```

---

## Stage 15: Final Quality Check

### Goal
Ensure tests follow all best practices and produce readable output on failure.

**Learn more:**
- [Rule 3: Each it Describes One Observable Behavior](../guide.en.md#3-each-example-it-describes-one-observable-behavior)
- [Rule 23: Use aggregate_failures Only For Interfaces](../guide.en.md#23-use-aggregate_failures-only-when-describing-one-rule)

### 15.1 One Behavior Per it

```ruby
# ❌ Multiple behaviors
it 'processes order' do
  expect { process }.to change(Order, :count).by(1)
  expect(mailer).to receive(:send_confirmation)
  expect(inventory).to receive(:decrease)
end

# ✅ Separated
it 'creates order' do
  expect { process }.to change(Order, :count).by(1)
end

it 'sends confirmation' do
  expect { process }.to have_enqueued_job(ConfirmationJob)
end

it 'updates inventory' do
  expect { process }.to change { product.reload.stock }.by(-1)
end
```

### 15.2 Proper Use of aggregate_failures

```ruby
# ✅ When to use: object interface
it 'provides complete user data', :aggregate_failures do
  expect(user.name).to eq('John')
  expect(user.email).to eq('john@example.com')
  expect(user.age).to eq(30)
end

# ❌ When NOT to use: independent behaviors
it 'creates and notifies', :aggregate_failures do  # ← NO!
  expect { service.call }.to change(User, :count)
  expect { service.call }.to have_enqueued_job
end
```

### 15.3 Readable Failure Output

```ruby
# ❌ Poor output
expect(response.body).to eq("{\"status\":\"ok\"}")
# Failure: expected: "{\"status\":\"ok\"}"
#              got: "{\"status\":\"error\"}"

# ✅ Good output
expect(response.parsed_body).to include('status' => 'ok')
# Failure: expected hash to include {"status" => "ok"}
#          got: {"status" => "error", "message" => "Invalid"}
```

---

## Stage 16: Final Polish

### Goal
Bring tests to production-ready state.

### Checklist

- [ ] **Tests pass:** `rspec --format documentation`
- [ ] **Linter happy:** `rubocop spec/`
- [ ] **No flaky tests:** run multiple times
- [ ] **Time stable:** use `freeze_time` where needed
- [ ] **Factories optimal:** `build_stubbed` > `build` > `create`
- [ ] **Reads as documentation:** show to colleague
- [ ] **Follows guideline:** check against checklist
- [ ] **Subject always named:** `subject(:name)`?
- [ ] **Three stages clear:** Given (Stage 10) → Subject (Stage 11) → Then (Stage 12)

### Commands to Check

```bash
# Full run with documentation
bundle exec rspec --format documentation

# Style check
bundle exec rubocop spec/

# Find slow tests
bundle exec rspec --profile 10

# Random order (check independence)
bundle exec rspec --order random
```

---

## Examples: From Algorithm to Code

### Example 1: Unit Test of Discount Calculator

```ruby
# Stage 1: Level = Unit (independent class)
# Stages 2-5: Characteristics, hierarchy, types, states

describe DiscountCalculator do
  subject(:discount) { described_class.new(order).calculate }

  let(:order) { build(:order, customer_type: customer_type, total: total, coupon: coupon) }
  let(:coupon) { nil } # Default: no coupon

  # Level 1: Customer type (no default)
  context 'when customer is regular' do
    let(:customer_type) { :regular }

    # Level 2: Order amount
    context 'with order under $100' do
      let(:total) { 50 }
      it('returns no discount') { expect(discount).to eq(0) }
    end

    context 'with order over $100' do
      let(:total) { 150 }
      it('returns 5% discount') { expect(discount).to eq(7.50) }

      # Level 3: Coupon (deviation from default)
      context 'and has coupon' do
        let(:coupon) { build(:coupon, value: 10) }
        it('adds coupon to percentage discount') { expect(discount).to eq(17.50) }
      end
    end
  end

  context 'when customer is premium' do
    let(:customer_type) { :premium }

    context 'with any order amount' do
      let(:total) { 50 }
      it('returns 10% discount') { expect(discount).to eq(5.00) }

      context 'and has coupon' do
        let(:coupon) { build(:coupon, value: 10) }
        it('adds coupon to percentage discount') { expect(discount).to eq(15.00) }
      end
    end
  end
end
```

### Example 2: Request Spec with Domain Combination

```ruby
# Stage 1: Level = Request/Integration
# Stage 2: Combine characteristics by payment domain

describe 'POST /api/payments' do
  subject(:request) { post '/api/payments', params: params, headers: headers }

  let(:params) { { amount: 100, currency: 'USD' } }
  let(:headers) { {} }

  # Level 1: Authentication
  context 'when user is authenticated' do
    let(:user) { create(:user) }
    let(:headers) { { 'Authorization' => "Bearer #{user.token}" } }

    # Level 2: Payment prerequisites (combine!)
    context 'with valid payment setup' do
      # Combine: verified card + sufficient balance + passed fraud check
      let(:user) { create(:user, :authenticated, :payment_ready) }

      it 'processes payment successfully' do
        request
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include(
          'status' => 'success',
          'transaction_id' => kind_of(String)
        )
      end
    end

    context 'when payment is blocked' do
      let(:user) { create(:user, :authenticated, :payment_blocked) }

      it 'returns payment error' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to include('payment blocked')
      end
    end
  end

  context 'when user is NOT authenticated' do
    it 'returns unauthorized' do
      request
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

---

## Common Mistakes and How to Avoid Them

| Mistake | Symptom | Solution |
|---------|---------|----------|
| Testing implementation | Lots of `receive`, `allow` | Test public API |
| Deep nesting | 5+ levels of context | Refactor code (Do One Thing) |
| Hidden dependencies | Tests fail when order changes | Isolate contexts |
| Duplication | Copy-paste in setup/expects | Shared examples, factories |
| Unreadable output | Wall of text on failure | Use right matchers |

**See also:** [Quick Diagnosis: "Why does my test smell bad?"](../guide.en.md#quick-diagnostics-why-does-my-test-smell)

---

## Conclusion

This algorithm is not dogma, but a guide for thinking. With experience, some steps become automatic, but core principles remain:

1. **Test behavior, not implementation**
2. **Build tests by domain characteristics**
3. **Happy path first, corner cases after**
4. **Tests are documentation of business rules**
5. **Test complexity = signal of code problems**

Remember: good tests make code better, revealing design problems and documenting intent.

---

**Full guide:** [RSpec Style Guide (../guide.en.md)](../guide.en.md)  
**Review checklist:** [checklist.en.md](../checklist.en.md)  
**Testing patterns:** [patterns.en.md](../patterns.en.md)
