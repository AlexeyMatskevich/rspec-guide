# Algorithm for Optimizing Test Data Preparation with FactoryBot

## Prerequisites

This algorithm is applied **after** the main BDD test writing algorithm, when:
- ✅ Context structure is already built ([Rule 5](../guide.en.md#5-build-context-hierarchy-by-characteristic-dependencies-happy-path--corner-cases))
- ✅ Characteristics and states are defined ([Rule 4](../guide.en.md#4-identify-behavior-characteristics-and-their-states))
- ✅ Behavior descriptions are written ([Rules 17-18](../guide.en.md#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english))
- ✅ Test data preparation needs optimization

**Important:** FactoryBot is not used in all tests. This algorithm is applicable for most cases in Ruby on Rails, typically whenever models are involved in the logic.

---

## Stage 1: Audit Current Data Preparation

### Goal
Identify all places where test data is prepared and determine where FactoryBot can be applied.

### Why This Matters
Explicit object initialization with dozens of attributes creates technical complexity and obscures business characteristics.

### What to Look For

```ruby
# ❌ Signals for optimization:

# 1. Creating models with many attributes
let(:user) do
  User.create(
    email: 'test@example.com',
    password: 'password123',
    first_name: 'John',
    last_name: 'Doe',
    phone: '+1234567890',
    confirmed_at: Time.current,
    role: 'customer',
    newsletter: true,
    timezone: 'UTC'
  )
end

# 2. Repeating attribute sets
context 'when user is premium' do
  let(:user) { User.create(email: '...', role: 'premium', subscription_ends_at: 1.year.from_now) }
end

context 'when user is trial' do
  let(:user) { User.create(email: '...', role: 'trial', trial_ends_at: 14.days.from_now) }
end

# 3. Creating related objects manually
let(:order) { Order.create(user: user, status: 'pending') }
let(:item1) { OrderItem.create(order: order, product: product1, quantity: 2) }
let(:item2) { OrderItem.create(order: order, product: product2, quantity: 1) }
```

### Audit Checklist
- [ ] List all `let` blocks that create objects
- [ ] Find repeating initialization patterns
- [ ] Identify technical vs business attributes
- [ ] Mark places with manual creation of related objects

---

## Stage 2: Mapping Characteristics to Traits

### Connection to Main Algorithm

At [Stage 4](test.en.md#stage-4-determine-characteristic-types) and [Stage 5](test.en.md#stage-5-determine-states-and-defaults) of the main algorithm, you defined characteristic types and their states.

Now each **non-default state** of a characteristic becomes a trait in the factory:
- If characteristic has a default state → trait only for non-default states
- If characteristic has no default → traits for all states

**Example:** "Blocked status" characteristic has states `blocked`/`active` (default: `active`) → create only `:blocked` trait.

### Goal
Transform identified characteristic states from the main algorithm into FactoryBot traits.

### Why This Matters
Traits document characteristic states and make tests readable at the business language level ([Rules 17-18](../guide.en.md#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english)).

**See also:** [Pattern #4: Traits in characteristic-based contexts](../patterns.en.md#4-traits-in-characteristic-based-contexts)

### Trait Creation Rules

| Characteristic Type | Trait in Factory | Example |
|------------------------|-----------------|---------|
| Binary (2 states) | Trait for non-default state | `:blocked`, `:unverified` |
| Enum (N states) | Trait for each state | `:admin`, `:manager`, `:customer` |
| Range (value groups) | Trait for each business state | `:with_sufficient_balance`, `:overdue` |
| State combination | Composite trait | `:payment_ready` (= verified + with_balance) |

### Trait Naming

Trait names should be self-documenting and unambiguously reflect the characteristic state:

- ✅ `:verified`, `:blocked`, `:premium` — clear without comments
- ❌ `:special`, `:ready`, `:custom` — unclear what this means

**Add comments** only for complex composite traits or non-obvious business logic:

```ruby
# Composite trait: user ready for payment processing
# Includes: email verified + payment card attached + sufficient balance + passed KYC
trait :payment_ready do
  verified
  with_payment_card
  with_sufficient_balance
  kyc_passed
end
```

### Mapping Example

```ruby
# From test analysis, identified characteristics:
# - Subscription status: trial/basic/premium
# - Email verification: verified/unverified (default: unverified)
# - Blocking: blocked/active (default: active)

# Create factory with traits:
FactoryBot.define do
  factory :user do
    # Default values - "average" user
    email { Faker::Internet.email }
    password { 'SecurePass123!' }
    subscription_type { 'basic' }
    email_verified { false }
    blocked { false }

    # Traits for characteristic states
    trait :trial do
      subscription_type { 'trial' }
      trial_ends_at { 14.days.from_now }
    end

    trait :premium do
      subscription_type { 'premium' }
      subscription_ends_at { 1.year.from_now }
    end

    trait :verified do
      email_verified { true }
      email_verified_at { 1.day.ago }
    end

    trait :blocked do
      blocked { true }
      blocked_at { 2.days.ago }
      blocked_reason { 'Terms violation' }
    end

    # Composite trait for integration tests
    trait :ready_for_purchase do
      verified
      premium
      after(:create) do |user|
        create(:payment_method, user: user, verified: true)
      end
    end
  end
end
```

---

## Stage 3: Choosing FactoryBot Method (Decision Tree)

### Goal
Choose the optimal FactoryBot method for each object creation place.

### Why This Matters
The correct method choice affects test speed and isolation.

**More details:** [Rule 13: attributes_for](../guide.en.md#13-use-attributes_for-to-generate-parameters-that-are-not-important-details-in-behavior-testing), [Rule 14: build_stubbed](../guide.en.md#14-in-unit-tests-except-models-use-build_stubbed)

### Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│ Do you need an object to test behavior?                     │
└─────────────┬───────────────────────────────────────────────┘
              │
              ├─── NO (only parameters for API/controller)
              │    └─→ attributes_for(:user)
              │       # Returns { name: "...", email: "..." }
              │
              └─── YES (need an object)
                   │
                   ├─── Should the object be saved in DB?
                   │    │
                   │    ├─── YES (need persistence, associations, callbacks)
                   │    │    │
                   │    │    ├─── Need related objects?
                   │    │    │    ├─── YES → create(:order, :with_items)
                   │    │    │    │         # Use traits
                   │    │    │    │
                   │    │    │    └─── NO → create(:user)
                   │    │    │              # Simple creation
                   │    │    │
                   │    │    └─→ Always use create() when DB is needed
                   │    │
                   │    └─── NO (only in memory, DB not needed)
                   │         │
                   │         ├─── Testing THIS object's BEHAVIOR?
                   │         │    (validations, model methods, business logic)
                   │         │    │
                   │         │    └─→ build(:user)
                   │         │        # new_record? = true
                   │         │        # Validations work correctly
                   │         │
                   │         └─── Object only needed as DATA?
                   │              (passing to another service/method)
                   │              │
                   │              └─→ build_stubbed(:user)
                   │                  # Faster, id stubbed
                   │                  # persisted? = true
```

### Application Examples

```ruby
# attributes_for - parameters for Request spec
describe 'POST /api/users' do
  let(:user_params) { attributes_for(:user, :verified) }

  it 'creates user' do
    post '/api/users', params: user_params
    expect(response).to have_http_status(:created)
  end
end

# build_stubbed - service unit test
describe PriceCalculator do
  let(:order) { build_stubbed(:order, total: 100) }
  let(:coupon) { build_stubbed(:coupon, discount: 10) }

  it 'applies discount' do
    result = described_class.new(order, coupon).calculate
    expect(result).to eq(90)
  end
end

# build - testing validations
describe User do
  let(:user) { build(:user, email: nil) }

  it 'requires email' do
    expect(user).not_to be_valid
    expect(user.errors[:email]).to include("can't be blank")
  end
end

# create - integration test
describe OrderService do
  let(:user) { create(:user, :with_payment_method) }

  it 'processes order' do
    service = described_class.new(user)
    expect { service.process }.to change(Order, :count).by(1)
  end
end
```

---

## Stage 4: Optimizing Default Values

### Goal
Configure factories so default values correspond to the "average" happy path object.

### Why This Matters
Correct defaults reduce the need for explicit parameters and make tests cleaner.

### Default Value Rules

| Attribute Type | Strategy | Example |
|--------------|-----------|---------|
| Required technical | Minimally valid | `email { Faker::Internet.email }` |
| Business characteristics | Happy path value | `status { 'active' }` |
| Optional | nil or minimum | `middle_name { nil }` |
| Timestamps | Automatically by Rails | Don't specify explicitly |

### Optimization Analysis

```ruby
# 1. Collect usage statistics
# If in 80% of tests we write create(:user, verified: true)
# → Make verified default

# 2. Check Happy Path
# If most happy path tests require a specific state
# → It's a candidate for default

# ❌ Before optimization
let(:user) { create(:user, verified: true, active: true, newsletter: false) }
# Repeats in 15 out of 20 tests

# ✅ After optimization in factory
factory :user do
  verified { true }      # New default
  active { true }        # New default
  newsletter { false }   # New default

  trait :unverified do
    verified { false }
  end
end

# Now in tests
let(:user) { create(:user) }  # Already has needed defaults
```

---

## Stage 5: Hiding Technical Details

### Goal
Move all technical attributes not related to the tested behavior inside the factory.

### Why This Matters
Tests should show only business-important characteristics, not technical validation requirements.

**More details:** [Rule 12: Use FactoryBot capabilities](../guide.en.md#12-use-factorybot-capabilities-to-hide-test-data-details)

### What to Hide in Factory

| Hide | Keep Explicit | Rationale |
|----------|-----------------|-------------|
| Required fields for validity | Characteristics from context | Context defines what's important |
| Formats (phone, email) | States for verification | States are part of specification |
| Service fields (tokens, uuids) | Boundary values | Boundary values are the essence of test |

### Hiding Techniques

```ruby
# 1. Sequences for uniqueness
factory :user do
  sequence(:email) { |n| "user#{n}@example.com" }
  sequence(:username) { |n| "user_#{n}" }
end

# 2. Faker for realism
factory :address do
  street { Faker::Address.street_address }
  city { Faker::Address.city }
  postal_code { Faker::Address.postcode }
end

# 3. Callbacks for complex logic
factory :order do
  after(:create) do |order|
    create_list(:order_item, 3, order: order) unless order.items.any?
  end
end

# 4. Transient attributes for control
factory :user do
  transient do
    posts_count { 5 }
  end

  after(:create) do |user, evaluator|
    create_list(:post, evaluator.posts_count, user: user)
  end
end
```

---

## Stage 6: Creating Composite Traits for Integration

### Goal
Create traits that combine multiple characteristics for integration tests.

### Why This Matters
In integration tests we combine details of a single domain. Composite traits document these combinations.

**More details:** [Rule 5: Domain-based combining at integration level](../guide.en.md#5-build-context-hierarchy-by-characteristic-dependencies-happy-path--corner-cases), [Pattern #4: Traits in characteristic-based contexts](../patterns.en.md#4-traits-in-characteristic-based-contexts)

### Composite Trait Patterns

```ruby
factory :user do
  # Base traits
  trait :verified do
    email_verified { true }
  end

  trait :with_payment_card do
    after(:create) do |user|
      create(:payment_card, user: user)
    end
  end

  trait :with_sufficient_balance do
    after(:create) do |user|
      user.payment_card.update(balance: 1000)
    end
  end

  # Composite trait for Request specs
  trait :payment_ready do
    verified
    with_payment_card
    with_sufficient_balance

    after(:create) do |user|
      user.payment_card.update(verified: true)
    end
  end
end

# Usage in integration test
describe 'POST /api/payments' do
  # Instead of creating all preconditions manually
  let(:user) { create(:user, :payment_ready) }

  it 'processes payment' do
    post '/api/payments', headers: auth_headers(user)
    expect(response).to have_http_status(:created)
  end
end
```

### Naming Convention for Composite Traits

| Pattern | Usage | Example |
|---------|---------------|---------|
| `:ready_for_X` | All prerequisites for action X | `:ready_for_checkout` |
| `:with_complete_X` | Complete set of X | `:with_complete_profile` |
| `:X_eligible` | Suitable for X | `:discount_eligible` |

### Anti-pattern: Excessive Composite Traits

Don't create a composite trait if the combination is used rarely (1-2 times in tests). Direct composition is more readable and doesn't create unnecessary abstraction.

#### When Composite Trait is NOT Needed

```ruby
# ❌ Bad: over-engineering for rare combination
trait :admin_with_posts do
  admin
  with_posts
end

# Used only in one test
let(:user) { create(:user, :admin_with_posts) }
```

```ruby
# ✅ Good: explicit composition for rare cases
let(:user) { create(:user, :admin, :with_posts) }
```

#### When Composite Trait IS Needed

```ruby
# ✅ Good: frequent combination in integration tests
trait :payment_ready do
  verified
  with_payment_card
  with_sufficient_balance
end

# Used in 10+ request specs
let(:user) { create(:user, :payment_ready) }
```

**Empirical rule:** If trait combination repeats 3+ times in different tests → create composite trait. If 1-2 times → use composition directly.

---

## Stage 7: Refactoring Tests with New Factories

### Goal
Replace explicit object initialization with factory usage with traits.

### Why This Matters
After creating factories, tests need to be updated to benefit from the work done.

### Refactoring Process

```ruby
# ❌ Before: explicit initialization
describe OrderService do
  let(:user) do
    User.create(
      email: 'test@example.com',
      verified: true,
      subscription: 'premium'
    )
  end

  let(:payment_card) do
    PaymentCard.create(
      user: user,
      verified: true,
      balance: 500
    )
  end

  context 'when user has sufficient balance' do
    it 'processes order' do
      # ...
    end
  end
end

# ✅ After: factories with traits
describe OrderService do
  let(:user) { create(:user, :premium, :payment_ready) }

  context 'when user has sufficient balance' do
    it 'processes order' do
      # ...
    end
  end
end
```

### Refactoring Checklist
- [ ] Replace `Model.create(...)` with `create(:model, traits)`
- [ ] Replace parameter hashes with `attributes_for`
- [ ] Replace `create` with `build_stubbed` where possible
- [ ] Remove duplicate `let` blocks
- [ ] Verify tests still pass

---

## Stage 8: Performance Optimization

### Goal
Speed up tests through correct FactoryBot method usage.

### Why This Matters
Slow tests reduce productivity and motivation to run them frequently.

### Optimization Techniques

#### 8.1 Replacing create with build_stubbed

```ruby
# Analysis: where is object used only for reading?
describe DiscountCalculator do
  # ❌ Before: unnecessary DB access
  let(:order) { create(:order, total: 100) }

  # ✅ After: object in memory
  let(:order) { build_stubbed(:order, total: 100) }
end
```

#### 8.2 Lazy Loading via let

```ruby
# ❌ let! creates object immediately
let!(:admin) { create(:user, :admin) }
let!(:moderator) { create(:user, :moderator) }

# ✅ let creates only when used
let(:admin) { create(:user, :admin) }
let(:moderator) { create(:user, :moderator) }
```

#### 8.3 Object Reuse

```ruby
# ⚠️ For read-only objects can use let_it_be (test-prof gem)
# WARNING: Use only for reference data that is GUARANTEED
# not to change in tests. Can break isolation and complicate debugging.
let_it_be(:category) { create(:category) }

# Safer: regular let (created for each test)
let(:category) { create(:category) }

# Or before(:all) for test group (also with isolation risks)
before(:all) do
  @shared_config = create(:app_config)
end
```

### Tracking Metrics

```bash
# Profile slow examples
rspec --profile 10

# Count SQL queries (with test-prof)
TPROF=sql rspec spec/models/user_spec.rb

# Analyze factory creation
FPROF=1 rspec spec/
```

---

## Stage 9: Final Verification

### Goal
Ensure FactoryBot optimization achieved its goals.

### Verification Checklist

#### Readability
- [ ] Only business characteristics visible in tests
- [ ] Traits named after characteristic states
- [ ] No attribute duplication in tests

#### Performance
- [ ] Used `build_stubbed` where possible
- [ ] `attributes_for` for request parameters
- [ ] No unnecessary `create` for read-only data

#### Maintainability
- [ ] Traits have self-documenting names
- [ ] Composite traits for integration tests
- [ ] Defaults correspond to happy path

#### Rule Compliance
- [ ] Rule 12: Technical details hidden
- [ ] Rule 13: `attributes_for` for parameters
- [ ] Rule 14: `build_stubbed` in unit tests
- [ ] Rule 16: Explicitness of characteristics preserved

### Verification Commands

```bash
# Ensure tests pass
bundle exec rspec

# Check speed
bundle exec rspec --profile 10

# Find unused factories (with factory_bot_rails)
bundle exec rake factory_bot:lint
```

---

## FactoryBot Anti-patterns

| Anti-pattern | Problem | Solution |
|-------------|----------|---------|
| Monster factory | One factory with 50+ traits | Split into multiple factories |
| Implementation traits | `:with_5_posts` instead of state | Use transient attributes (see [Pattern #4](../patterns.en.md#4-traits-in-characteristic-based-contexts)) |
| Divine defaults | Default creates full object graph | Minimal defaults + traits |
| Mystery guest | Factory creates hidden associations | Explicit associations in traits |
| Fragile factories | Break when model changes | Minimum required attributes ([Rule 12](../guide.en.md#12-use-factorybot-capabilities-to-hide-test-data-details)) |

---

## Migration Examples: Before and After

### Example 1: Simple Model

```ruby
# ❌ Before optimization
describe User do
  let(:user) do
    User.create!(
      email: 'john@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      confirmed: true,
      role: 'customer',
      created_at: 2.days.ago
    )
  end

  context 'when user is admin' do
    let(:admin) do
      User.create!(
        email: 'admin@example.com',
        password: 'password123',
        first_name: 'Admin',
        last_name: 'User',
        confirmed: true,
        role: 'admin',
        created_at: 1.year.ago
      )
    end
    # ...
  end
end

# ✅ After optimization
describe User do
  let(:user) { create(:user) }

  context 'when user is admin' do
    let(:admin) { create(:user, :admin) }
    # ...
  end
end
```

### Example 2: Request spec with parameters

```ruby
# ❌ Before optimization
describe 'POST /api/users' do
  let(:user_params) do
    {
      email: 'test@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      phone: '+1234567890',
      role: 'customer',
      newsletter: true,
      timezone: 'UTC'
    }
  end

  it 'creates user' do
    post '/api/users', params: user_params
    expect(response).to have_http_status(:created)
  end
end

# ✅ After optimization
describe 'POST /api/users' do
  let(:user_params) { attributes_for(:user, :customer) }

  it 'creates user' do
    post '/api/users', params: user_params
    expect(response).to have_http_status(:created)
  end

  context 'when creating premium user' do
    let(:user_params) { attributes_for(:user, :premium) }
    
    it 'creates user with premium subscription' do
      post '/api/users', params: user_params
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['subscription_type']).to eq('premium')
    end
  end
end
```

---

## Conclusion

Optimization with FactoryBot is not just DRY, but creating a test data description language that:

1. **Corresponds to characteristics from tests** — traits = states ([Rule 4](../guide.en.md#4-identify-behavior-characteristics-and-their-states))
2. **Hides technical complexity** — focus on business logic ([Rule 12](../guide.en.md#12-use-factorybot-capabilities-to-hide-test-data-details))
3. **Speeds up execution** — right methods for right tasks ([Rules 13-14](../guide.en.md#13-use-attributes_for-to-generate-parameters-that-are-not-important-details-in-behavior-testing))
4. **Simplifies maintenance** — changes in one place

Remember: factories are part of your domain documentation. They should be understandable to new team members and reflect business rules, not technical implementation details.

**Additional materials:**
- [All FactoryBot rules in main guide](../guide.en.md#factorybot-and-data-preparation)
- [Pattern #4: Traits in characteristic-based contexts](../patterns.en.md#4-traits-in-characteristic-based-contexts)
