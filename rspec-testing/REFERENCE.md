# RSpec Testing Reference

This document provides detailed workflows and extended examples for the RSpec Testing Skill. Use it when you need more detailed guidance than what's in SKILL.md.

## Table of Contents

- [Writing a New Test from Scratch](#writing-a-new-test-from-scratch)
- [Updating an Existing Test](#updating-an-existing-test)
- [Extended Examples](#extended-examples)
- [Decision Trees](#decision-trees)
- [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
- [Refactoring Patterns](#refactoring-patterns)

## Writing a New Test from Scratch

### Step 1: Identify What to Test

Test only the **public interface** (public methods). Ignore private methods and internal state.

**Example:**

```ruby
class OrderProcessor
  def process(order)    # Public - TEST THIS
    validate_order(order)
    charge_payment(order)
    send_confirmation(order)
  end

  private

  def validate_order(order)  # Private - SKIP
  end
end
```

**What to test:**
- `#process` method behavior
- Observable outcomes: return value, state changes, side effects (emails, jobs)

**What NOT to test:**
- `#validate_order` (private method)
- Internal method calls (`expect(processor).to receive(:validate_order)`)
- Instance variables

### Step 2: Map Characteristics

List **independent characteristics** that affect behavior:

**Questions to ask:**
- What user types interact with this? (admin, regular user, guest)
- What object states matter? (active, inactive, pending, blocked)
- What input variations affect outcome? (valid, invalid, nil, empty)
- What feature flags or settings apply? (enabled, disabled)

**Example for OrderProcessor:**

| Characteristic | States | Notes |
|---------------|--------|-------|
| Order validity | valid, invalid | Basic characteristic |
| Payment method status | valid, expired, insufficient funds | Depends on order being valid |
| User authentication | authenticated, not authenticated | Independent |

### Step 3: Create Test Structure

```ruby
RSpec.describe OrderProcessor do
  subject(:process) { described_class.new.process(order) }

  describe '#process' do
    context 'with valid order' do  # Happy path FIRST
      let(:order) { create(:order, :valid) }

      it 'charges payment' do
        expect { process }.to change { order.reload.status }.to('paid')
      end

      it 'sends confirmation email' do
        expect { process }.to have_enqueued_mail(OrderMailer, :confirmation)
      end
    end

    context 'with invalid order' do  # Edge case AFTER
      let(:order) { create(:order, :invalid) }

      it 'raises validation error' do
        expect { process }.to raise_error(ValidationError)
      end

      it 'does NOT send email' do
        expect { process rescue nil }.not_to have_enqueued_mail
      end
    end
  end
end
```

**Key points:**
- `subject` defined once at top level
- `describe` for method name
- Happy path context first
- Each context has its own `let` setup
- Each `it` tests one observable behavior

### Step 4: Follow Three Phases in Each Test

**Phase structure:**

1. **Preparation (Given)** — `let`, `before` (setup data/state)
2. **Action (When)** — Explicit call to method under test
3. **Verification (Then)** — `expect` (check outcomes)

**Example with action in `before`:**

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

**Example with action in `it`:**

```ruby
describe '#block_user' do
  # Phase 1: Preparation
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }

  it 'marks user as blocked' do
    # Phase 2: Action
    admin.block(user)

    # Phase 3: Verification
    expect(user.reload.blocked?).to be true
  end
end
```

**Choose action placement:**
- In `before`: when result is checked in multiple `it` blocks
- In `it`: when action is checked only once or varies per example

### Step 5: Write Happy Path, Then Edge Cases

**Structure:**

```ruby
describe '#calculate_discount' do
  # Happy path first
  context 'when user has premium membership' do
    let(:user) { create(:user, :premium) }

    it 'applies 20% discount' do
      expect(calculate_discount(user)).to eq(0.20)
    end
  end

  # Edge cases after
  context 'when user has no membership' do
    let(:user) { create(:user) }

    it 'applies no discount' do
      expect(calculate_discount(user)).to eq(0)
    end
  end

  context 'when user is nil' do
    let(:user) { nil }

    it 'raises ArgumentError' do
      expect { calculate_discount(user) }.to raise_error(ArgumentError)
    end
  end
end
```

## Updating an Existing Test

### Step 1: Read Existing Structure

**Questions to ask:**
- What characteristics are already tested?
- What's the context hierarchy?
- Which scenarios are covered?
- Are there any gaps in coverage?

**Read through:**
1. All `describe` and `context` blocks to understand structure
2. All `it` blocks to see what behaviors are tested
3. `let` and `before` setups to understand how states are prepared

### Step 2: Identify Where New Behavior Fits

#### Scenario A: Adding new edge case at same hierarchy level

**Before:** Only happy path exists

```ruby
context 'with valid input' do
  let(:input) { { name: 'John', email: 'john@example.com' } }

  it 'returns success' do
    expect(result).to be_success
  end
end
```

**After:** Add edge case at same level

```ruby
context 'with valid input' do
  let(:input) { { name: 'John', email: 'john@example.com' } }

  it 'returns success' do
    expect(result).to be_success
  end
end

context 'with nil input' do  # NEW - same hierarchy level
  let(:input) { nil }

  it 'raises ArgumentError' do
    expect { result }.to raise_error(ArgumentError)
  end
end
```

#### Scenario B: Adding new characteristic

**Before:** Tests only for regular users

```ruby
context 'when user is regular' do
  let(:user) { create(:user) }

  it 'allows limited access' do
    expect(result).to be_limited_access
  end
end
```

**After:** Add admin characteristic

```ruby
context 'when user is regular' do
  let(:user) { create(:user) }

  it 'allows limited access' do
    expect(result).to be_limited_access
  end
end

context 'when user is admin' do  # NEW - new characteristic
  let(:user) { create(:user, :admin) }

  it 'allows unrestricted access' do
    expect(result).to be_unrestricted_access
  end
end
```

#### Scenario C: Adding nested refinement

**Before:** Basic characteristic only

```ruby
context 'when user has payment card' do
  let(:user) { create(:user, :with_card) }

  it 'allows purchase' do
    expect(result).to be_allowed
  end
end
```

**After:** Add balance refinement (depends on having card)

```ruby
context 'when user has payment card' do
  let(:user) { create(:user, :with_card) }

  context 'and balance covers price' do  # NEW - nested refinement
    let(:balance) { 1000 }

    it 'charges card' do
      expect(result).to be_charged
    end
  end

  context 'but balance does NOT cover price' do  # NEW - negative refinement
    let(:balance) { 10 }

    it 'rejects purchase' do
      expect(result).to be_rejected
    end
  end
end
```

### Step 3: Preserve Existing Coverage

**Guidelines:**
- Keep existing passing tests unless they test implementation details
- Don't change test behavior unless fixing a bug in the test itself
- Maintain context hierarchy (don't nest unrelated characteristics)
- Keep happy path before corner cases when adding new contexts

**Example - Refactoring to preserve coverage:**

```ruby
# Before: Two separate contexts with duplication
context 'for admin user' do
  let(:user) { create(:user, :admin) }

  it 'allows access' do
    expect(subject).to be_allowed
  end
end

context 'for moderator user' do
  let(:user) { create(:user, :moderator) }

  it 'allows access' do  # DUPLICATE behavior
    expect(subject).to be_allowed
  end
end

# After: Extract to shared example
shared_examples 'allows access' do
  it 'allows access' do
    expect(subject).to be_allowed
  end
end

context 'for admin user' do
  let(:user) { create(:user, :admin) }
  it_behaves_like 'allows access'
end

context 'for moderator user' do
  let(:user) { create(:user, :moderator) }
  it_behaves_like 'allows access'
end
```

## Extended Examples

### Example 1: Complete Test from Scratch

**Class to test:**

```ruby
class PaymentProcessor
  def charge(amount, payment_method)
    return false if amount <= 0
    return false unless payment_method.valid?

    payment_method.charge(amount)
    true
  end
end
```

**Complete test:**

```ruby
RSpec.describe PaymentProcessor do
  subject(:charge) { processor.charge(amount, payment_method) }

  let(:processor) { described_class.new }
  let(:payment_method) { instance_double('PaymentMethod') }

  describe '#charge' do
    context 'with valid amount and payment method' do  # Happy path first
      let(:amount) { 100.0 }

      before do
        allow(payment_method).to receive(:valid?).and_return(true)
        allow(payment_method).to receive(:charge).with(amount).and_return(true)
      end

      it 'returns true' do
        expect(charge).to be true
      end

      it 'charges the payment method' do
        charge
        expect(payment_method).to have_received(:charge).with(amount)
      end
    end

    context 'with zero amount' do  # Edge case: boundary
      let(:amount) { 0.0 }

      before do
        allow(payment_method).to receive(:valid?).and_return(true)
      end

      it 'returns false' do
        expect(charge).to be false
      end

      it 'does NOT charge payment method' do
        charge
        expect(payment_method).not_to have_received(:charge)
      end
    end

    context 'with negative amount' do  # Edge case: invalid input
      let(:amount) { -10.0 }

      before do
        allow(payment_method).to receive(:valid?).and_return(true)
      end

      it 'returns false' do
        expect(charge).to be false
      end
    end

    context 'with invalid payment method' do  # Edge case: dependency failure
      let(:amount) { 100.0 }

      before do
        allow(payment_method).to receive(:valid?).and_return(false)
      end

      it 'returns false' do
        expect(charge).to be false
      end

      it 'does NOT attempt to charge' do
        charge
        expect(payment_method).not_to have_received(:charge)
      end
    end
  end
end
```

**What makes this test good:**
- All 28 rules followed
- Happy path clearly first (valid amount + valid method)
- Each characteristic in its own context (amount validity, method validity)
- Each `it` tests one behavior
- Three phases clearly separated
- Verifying doubles used (`instance_double`)
- Descriptions form readable sentences

### Example 2: Hierarchical Characteristics

**Class to test:**

```ruby
class DiscountCalculator
  def calculate(order)
    return 0 unless order.user.premium?

    base_discount = order.segment == :b2b ? 0.10 : 0.05

    if order.total > 1000
      base_discount + 0.05
    else
      base_discount
    end
  end
end
```

**Test with proper hierarchy:**

```ruby
RSpec.describe DiscountCalculator do
  subject(:discount) { described_class.new.calculate(order) }

  describe '#calculate' do
    let(:order) do
      build_stubbed(:order,
        user: user,
        segment: segment,
        total: total
      )
    end

    # Characteristic 1: User premium status (basic)
    context 'when user has premium membership' do
      let(:user) { build_stubbed(:user, :premium) }

      # Characteristic 2: Segment (depends on premium)
      context 'and segment is b2b' do
        let(:segment) { :b2b }

        # Characteristic 3: Order total (depends on segment)
        context 'and total exceeds 1000' do
          let(:total) { 1500 }

          it 'applies 15% discount' do
            expect(discount).to eq(0.15)
          end
        end

        context 'but total is under 1000' do
          let(:total) { 500 }

          it 'applies 10% discount' do
            expect(discount).to eq(0.10)
          end
        end
      end

      context 'and segment is b2c' do
        let(:segment) { :b2c }

        context 'and total exceeds 1000' do
          let(:total) { 1500 }

          it 'applies 10% discount' do
            expect(discount).to eq(0.10)
          end
        end

        context 'but total is under 1000' do
          let(:total) { 500 }

          it 'applies 5% discount' do
            expect(discount).to eq(0.05)
          end
        end
      end
    end

    # Characteristic 1: Non-premium (corner case)
    context 'when user does NOT have premium membership' do
      let(:user) { build_stubbed(:user) }
      let(:segment) { :b2b }
      let(:total) { 1500 }

      it 'applies no discount' do
        expect(discount).to eq(0)
      end
    end
  end
end
```

**What makes this hierarchy good:**
- Three levels of characteristics with clear dependencies
- Premium status (basic) → Segment (depends on premium) → Total (depends on segment)
- Happy path at each level comes first (premium before non-premium, b2b before b2c, high total before low)
- Each context has its own `let` immediately under declaration
- Corner cases clearly marked with "but" or "NOT"

### Example 3: Updating Test - Adding Edge Case

**Original test (incomplete):**

```ruby
describe '#calculate_total' do
  let(:calculator) { described_class.new }

  context 'with items' do
    let(:items) { [10, 20, 30] }

    it 'returns sum' do
      expect(calculator.calculate_total(items)).to eq(60)
    end
  end
end
```

**Identified gaps:**
- What happens with empty array?
- What happens with nil?
- What happens with negative numbers?

**Updated test (complete):**

```ruby
describe '#calculate_total' do
  subject(:calculate) { calculator.calculate_total(items) }

  let(:calculator) { described_class.new }

  context 'with items' do  # Happy path
    let(:items) { [10, 20, 30] }

    it 'returns sum' do
      expect(calculate).to eq(60)
    end
  end

  context 'with empty array' do  # NEW: boundary case
    let(:items) { [] }

    it 'returns zero' do
      expect(calculate).to eq(0)
    end
  end

  context 'with nil' do  # NEW: invalid input
    let(:items) { nil }

    it 'raises ArgumentError' do
      expect { calculate }.to raise_error(ArgumentError, /items cannot be nil/)
    end
  end

  context 'with negative numbers' do  # NEW: edge case in domain
    let(:items) { [10, -5, 20] }

    it 'includes negative values in sum' do
      expect(calculate).to eq(25)
    end
  end
end
```

**Changes made:**
- Added `subject` for clarity
- Added three new contexts for edge cases
- Each new context at same hierarchy level (sibling to 'with items')
- Preserved existing happy path test
- Each edge case has clear setup via `let`

## Decision Trees

### When to Use `create` vs `build_stubbed` vs `build`

```
START
  |
  ├─ Is this a model test?
  |    ├─ YES → Use `create` (needs DB validation)
  |    └─ NO → Continue
  |
  ├─ Does test need to check DB state/queries/callbacks?
  |    ├─ YES → Use `create` (integration test)
  |    └─ NO → Continue
  |
  ├─ Does test need associations to be persisted?
  |    ├─ YES → Use `create`
  |    └─ NO → Continue
  |
  └─ Is this a unit test (service/PORO/presenter)?
       ├─ YES → Use `build_stubbed` (fastest)
       └─ NO → Use `build` (rare, fallback)
```

**Examples:**

```ruby
# Model test - always create
RSpec.describe User, type: :model do
  subject(:user) { create(:user) }

  it { is_expected.to validate_presence_of(:email) }
end

# Service unit test - build_stubbed
RSpec.describe OrderProcessor do
  subject(:processor) { described_class.new }

  let(:order) { build_stubbed(:order, :pending) }

  it 'processes order' do
    result = processor.call(order)
    expect(result).to be_success
  end
end

# Integration test - create
RSpec.describe 'POST /api/orders', type: :request do
  let(:user) { create(:user) }
  let(:order_params) { attributes_for(:order) }

  before do
    sign_in(user)
    post '/api/orders', params: order_params
  end

  it 'creates order record' do
    expect(Order.count).to eq(1)
  end
end
```

### When to Use `:aggregate_failures`

```
START
  |
  ├─ Are you checking multiple INDEPENDENT side effects?
  |    ├─ YES → Use separate `it` blocks (Rule 3)
  |    └─ NO → Continue
  |
  ├─ Are you checking multiple attributes of ONE object/interface?
  |    ├─ YES → Continue
  |    |    |
  |    |    ├─ Can you use `have_attributes` matcher?
  |    |    |    ├─ YES → Use `have_attributes` (preferred)
  |    |    |    └─ NO → Use `:aggregate_failures`
  |    |    |
  |    └─ NO → Use separate `it` blocks
  |
  └─ Is this a CI-only or hard-to-reproduce flaky test?
       ├─ YES → Use `:aggregate_failures` (see all failures at once)
       └─ NO → Consider using separate `it` blocks
```

**Examples:**

```ruby
# ❌ WRONG: Independent side effects
it 'processes signup', :aggregate_failures do
  expect { post_signup }.to change(User, :count).by(1)  # Side effect 1
  expect { post_signup }.to have_enqueued_mail  # Side effect 2 - INDEPENDENT!
end

# ✅ CORRECT: Separate tests
it('creates user') { expect { post_signup }.to change(User, :count).by(1) }
it('sends email') { expect { post_signup }.to have_enqueued_mail }

# ✅ CORRECT: One object interface with have_attributes
it 'exposes profile attributes' do
  expect(profile).to have_attributes(
    full_name: 'John',
    email: 'john@example.com',
    type: 'premium'
  )
end

# ✅ ACCEPTABLE: aggregate_failures for HTTP response
it 'returns order details', :aggregate_failures do
  get "/orders/#{order.id}"

  expect(response).to have_http_status(:ok)
  expect(response.parsed_body['id']).to eq(order.id)
  expect(response.parsed_body['status']).to eq('pending')
  expect(response.parsed_body['total']).to eq(150.0)
end
```

### When to Extract to `shared_examples`

```
START
  |
  ├─ Do multiple CLASSES implement same contract?
  |    ├─ YES → Extract to shared_examples (Rule 25.1)
  |    |         Name: "a/an [adjective] noun"
  |    |         Example: 'a pageable API', 'an enumerable collection'
  |    |
  |    └─ NO → Continue
  |
  └─ Are identical `it` blocks repeated in ALL leaf contexts?
       ├─ YES → Extract to shared_examples (Rule 25.2)
       |         Name: contract description
       |         Example: 'valid booking search params'
       |
       └─ NO → Keep as separate `it` blocks
```

**Examples:**

```ruby
# Use case 1: Multiple classes, same contract
shared_examples 'a pageable API' do
  it('returns page') { expect(resource.paginate(page: 2).current_page).to eq(2) }
  it('limits size') { expect(resource.paginate(per_page: 5).items.count).to eq(5) }
end

describe OrdersQuery do
  subject(:resource) { described_class.new(scope: Order.all) }
  it_behaves_like 'a pageable API'
end

describe UsersQuery do
  subject(:resource) { described_class.new(scope: User.active) }
  it_behaves_like 'a pageable API'
end

# Use case 2: Invariant in all leaf contexts
shared_examples 'valid validator response' do
  it { is_expected.to respond_to(:valid?) }
  it { is_expected.to respond_to(:errors) }
  it { is_expected.to respond_to(:normalized_params) }
end

describe BookingSearchValidator do
  subject(:validator) { described_class.new(params, client_type: type) }

  context 'when client is b2c' do
    let(:type) { :b2c }
    it_behaves_like 'valid validator response'
    # ... specific b2c tests
  end

  context 'when client is b2b' do
    let(:type) { :b2b }
    it_behaves_like 'valid validator response'
    # ... specific b2b tests
  end
end
```

## Common Pitfalls and Solutions

### Pitfall 1: Testing Implementation Instead of Behavior

**Problem:**

```ruby
# ❌ BAD: Testing internal method call
it 'validates order' do
  expect(processor).to receive(:validate_order).with(order)
  processor.process(order)
end
```

**Solution:**

```ruby
# ✅ GOOD: Testing observable behavior
context 'with invalid order' do
  let(:order) { build_stubbed(:order, :invalid) }

  it 'raises validation error' do
    expect { processor.process(order) }.to raise_error(ValidationError)
  end
end
```

### Pitfall 2: Mixing Preparation and Action in `before`

**Problem:**

```ruby
# ❌ BAD: Given + When mixed in before
describe '#block' do
  before do
    user = create(:user)  # Given
    admin = create(:admin)  # Given
    admin.block(user)  # When - ACTION!
  end

  it 'true' do
    expect(User.find(1).blocked).to be(true)
  end
end
```

**Solution:**

```ruby
# ✅ GOOD: Clear three phases
describe '#block' do
  # Phase 1: Given
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }

  # Phase 2: When
  before { admin.block(user) }

  # Phase 3: Then
  it 'marks user as blocked' do
    expect(user.reload.blocked?).to be true
  end
end
```

### Pitfall 3: Context Without Distinguishing Setup

**Problem:**

```ruby
# ❌ BAD: Context doesn't show what distinguishes it
context 'when user is blocked by admin' do
  # No setup here - where's the blocking?

  context 'and blocking duration is over a month' do
    it 'allows unlocking' do
      expect(old_blocked_user.some_action).to be true
    end
  end
end
```

**Solution:**

```ruby
# ✅ GOOD: Each context has setup immediately below
context 'when user is blocked by admin' do
  let(:blocked) { true }  # Setup right here!

  context 'and blocking duration is over a month' do
    let(:blocked_at) { 2.months.ago }  # Setup right here!

    it 'allows unlocking' do
      expect(user.some_action).to be true
    end
  end
end
```

### Pitfall 4: Happy Path Buried Under Edge Cases

**Problem:**

```ruby
# ❌ BAD: Edge case first
describe '#purchase' do
  context 'when balance is insufficient' do  # Corner case first!
    it 'rejects purchase'
  end

  context 'when balance is sufficient' do  # Happy path buried
    it 'charges card'
  end
end
```

**Solution:**

```ruby
# ✅ GOOD: Happy path first
describe '#purchase' do
  context 'when balance is sufficient' do  # Happy path first
    it 'charges card'
  end

  context 'when balance is insufficient' do  # Corner case after
    it 'rejects purchase'
  end
end
```

### Pitfall 5: Mixing Phases in `it`

**Problem:**

Action and verification mixed in same `it` block:

```ruby
# ❌ BAD: Action + Verification mixed
it "creates setting" do
  test_class.setting :enabled  # Phase 2: When - ACTION!
  expect(test_class.find_setting(:enabled)).to be_present  # Phase 3: Then
end
```

**Why it's bad:**
- Unclear what test verifies (setup or result?)
- Hard to reuse action in multiple tests
- Violates Three Phases principle (Rule 11)

**Solution:**

Separate phases clearly:

```ruby
# ✅ GOOD: Phases separated
before { test_class.setting :enabled }  # Phase 2: When

it "creates setting" do  # Phase 3: Then only
  expect(test_class.find_setting(:enabled)).to be_present
end
```

**Better with named subject:**

```ruby
# ✅ EVEN BETTER: Named subject for reusability
subject(:create_setting) { test_class.setting :enabled }

before { create_setting }

it "creates setting" do
  expect(test_class.find_setting(:enabled)).to be_present
end
```

## Refactoring Patterns

Step-by-step guides for transforming bad tests into good ones.

### Pattern 1: From Mixed Phases to Separated

**Starting point:**

```ruby
# ❌ BAD: All phases mixed in it
it 'processes order' do
  order = create(:order)  # Phase 1: Given
  processor.process(order)  # Phase 2: When
  expect(order.reload.status).to eq('processed')  # Phase 3: Then
end
```

**Step 1: Extract Given to `let`**

```ruby
let(:order) { create(:order) }

it 'processes order' do
  processor.process(order)  # Phase 2: When
  expect(order.reload.status).to eq('processed')  # Phase 3: Then
end
```

**Step 2: Extract When to `before`**

```ruby
let(:order) { create(:order) }
before { processor.process(order) }

it 'processes order' do
  expect(order.reload.status).to eq('processed')  # Phase 3: Then only
end
```

**Step 3: Use named subject for clarity**

```ruby
subject(:process_order) { processor.process(order) }

let(:order) { create(:order) }
before { process_order }

it 'marks order as processed' do
  expect(order.reload.status).to eq('processed')
end
```

✅ **Result:** Clear three phases, reusable action, descriptive naming

---

### Pattern 2: From Multiple Assertions to Separate Tests

**Starting point:**

```ruby
# ❌ BAD: Multiple independent behaviors in one test
it 'handles signup' do
  post :create, params: signup_params
  expect(response).to have_http_status(:created)
  expect(User.count).to eq(1)
  expect(ActionMailer::Base.deliveries.size).to eq(1)
end
```

**Step 1: Identify independent behaviors**

Ask: "What independent side effects happen?"
- HTTP response status (interface test)
- User creation (side effect 1)
- Email sending (side effect 2)

**Step 2: Split into separate tests**

```ruby
# ✅ GOOD: Each test verifies one behavior
describe 'POST /signup' do
  let(:signup_params) { attributes_for(:user) }

  it 'returns created status' do
    post :create, params: signup_params
    expect(response).to have_http_status(:created)
  end

  it 'creates user' do
    expect { post :create, params: signup_params }.to change(User, :count).by(1)
  end

  it 'sends welcome email' do
    expect { post :create, params: signup_params }
      .to have_enqueued_mail(WelcomeMailer, :welcome)
  end
end
```

✅ **Result:** Each test verifies one behavior, clear failure messages, easy to debug

---

### Pattern 3: From Implementation Testing to Behavior Testing

**Starting point:**

```ruby
# ❌ BAD: Testing implementation (internal method call)
it 'sends notification' do
  expect(notifier).to receive(:send_email).with(user.email)
  service.notify(user)
end
```

**Step 1: Identify observable behavior**

Ask: "What actually happens that matters to business?"
- ✅ Email is sent (observable, matters to business)
- ✅ Notification record created (observable, matters to business)
- ❌ Internal method called (implementation detail, doesn't matter)

**Step 2: Test observable outcome**

```ruby
# ✅ GOOD: Testing behavior (email actually sent)
it 'sends notification email' do
  expect { service.notify(user) }
    .to have_enqueued_mail(NotificationMailer, :user_notification).with(user)
end
```

**Alternative: Test side effect in database**

```ruby
# ✅ ALSO GOOD: Testing behavior (notification created)
it 'creates notification record' do
  expect { service.notify(user) }
    .to change(Notification, :count).by(1)
end

it 'creates notification for user' do
  service.notify(user)
  expect(user.notifications.last).to have_attributes(
    type: 'email',
    status: 'pending'
  )
end
```

✅ **Result:** Tests behavior, resilient to refactoring, verifies what actually matters

---

### Pattern 4: From Implicit Setup to Explicit Context

**Starting point:**

```ruby
# ❌ BAD: Unclear what makes this test different
describe OrderProcessor do
  it 'processes premium order quickly' do
    user = create(:user, tier: 'premium')
    order = create(:order, user: user, priority: 'high')

    result = processor.process(order)

    expect(result.processing_time).to be < 5
  end
end
```

**Step 1: Identify characteristics**

What makes this test unique?
- User tier: premium (vs regular)
- Order priority: high (vs normal)

**Step 2: Create context hierarchy**

```ruby
# ✅ GOOD: Characteristics explicit in contexts
describe OrderProcessor do
  describe '#process' do
    context 'when user is premium' do
      let(:user) { create(:user, :premium) }

      context 'with high priority order' do
        let(:order) { create(:order, user: user, priority: 'high') }

        it 'processes quickly' do
          result = processor.process(order)
          expect(result.processing_time).to be < 5
        end
      end
    end
  end
end
```

✅ **Result:** Clear what's being tested, easy to add similar cases, characteristic-based hierarchy
