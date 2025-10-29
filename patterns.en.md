# Useful Patterns

Practical techniques for writing readable and maintainable RSpec tests.

## Table of Contents

1. [Named subject for method testing](#1-named-subject-for-method-testing)
2. [merge for context refinement](#2-merge-for-context-refinement)
3. [subject with lambda for side effects](#3-subject-with-lambda-for-side-effects)
4. [Traits in characteristic-based contexts](#4-traits-in-characteristic-based-contexts)
5. [Shared context: when to use and when it's a smell](#5-shared-context-when-to-use-and-when-its-a-smell)
6. [Nil object for empty context](#6-nil-object-for-empty-context)
7. [When to use each pattern](#when-to-use-each-pattern)

---

## 1. Named subject for method testing

### Problem

Repeating method calls in each test makes code verbose and less readable:

```ruby
# bad
describe '#premium?' do
  context 'when user has premium subscription' do
    let(:user) { create(:user, subscription: 'premium') }

    it 'returns true' do
      expect(user.premium?).to be true
    end
  end

  context 'when user has free subscription' do
    let(:user) { create(:user, subscription: 'free') }

    it 'returns false' do
      expect(user.premium?).to be false
    end
  end
end
```

### Solution

Use named subject to call method once and keep code DRY:

```ruby
# good
describe '#premium?' do
  subject(:premium_status) { user.premium? }

  context 'when user has premium subscription' do
    let(:user) { create(:user, subscription: 'premium') }

    it { is_expected.to be true }
  end

  context 'when user has free subscription' do
    let(:user) { create(:user, subscription: 'free') }

    it { is_expected.to be false }
  end
end
```

### Benefits

- **DRY**: method called in one place
- **Clarity**: name `premium_status` shows what's being tested
- **Reusability**: easy to use in different contexts
- **Readability**: one-liner tests with `is_expected`

### When to use

- Method is called in multiple `it` blocks
- Method has NO side effects (pure function)
- Need to test return value in different conditions

---

## 2. merge for context refinement

### Problem

When changing one or two parameters, you have to duplicate entire hash:

```ruby
# bad
describe ReportGenerator do
  let(:params) do
    {
      from: '2024-01-01',
      to: '2024-01-31',
      format: 'json',
      user_id: 123,
      include_details: true
    }
  end

  context 'when format is json' do
    let(:params) do
      {
        from: '2024-01-01',
        to: '2024-01-31',
        format: 'json',  # only this matters
        user_id: 123,
        include_details: true
      }
    end

    it 'returns json data' do
      expect(generator.call(params)).to be_a(Hash)
    end
  end

  context 'when format is csv' do
    let(:params) do
      {
        from: '2024-01-01',
        to: '2024-01-31',
        format: 'csv',  # only this changes
        user_id: 123,
        include_details: true
      }
    end

    it 'returns csv data' do
      expect(generator.call(params)).to be_a(String)
    end
  end
end
```

### Solution

Use `super().merge(...)` to show only what changes:

```ruby
# good
describe ReportGenerator do
  let(:params) do
    {
      from: '2024-01-01',
      to: '2024-01-31',
      format: 'json',
      user_id: 123,
      include_details: true
    }
  end

  context 'when format is json' do
    # uses base params

    it 'returns json data' do
      expect(generator.call(params)).to be_a(Hash)
    end
  end

  context 'when format is csv' do
    let(:params) { super().merge(format: 'csv') }  # clear what changes

    it 'returns csv data' do
      expect(generator.call(params)).to be_a(String)
    end
  end

  context 'when period is invalid' do
    let(:params) { super().merge(from: '2024-02-01', to: '2024-01-01') }

    it 'returns error' do
      result = generator.call(params)
      expect(result.error).to be_truthy
    end
  end
end
```

### Benefits

- **Focus on changes**: immediately see which parameter differs
- **No duplication**: base parameters defined once
- **Easy to maintain**: changes to base params propagate automatically
- **Reduces cognitive load**: no need to compare large hashes

### When to use

- Many parameters in base `let`
- Contexts change 1-3 parameters
- Base parameters are stable

---

## 3. subject with lambda for side effects

### Problem

RSpec memoizes `subject`, so method with side effects executes only once:

```ruby
# bad - test will fail
describe '#increment_counter' do
  subject(:increment) { counter.increment }

  let(:counter) { create(:counter, value: 0) }

  it 'increases counter on each call' do
    increment  # value becomes 1
    increment  # nothing happens (memoization!)
    expect(counter.reload.value).to eq(2)  # FAILS: expected 2, got 1
  end
end
```

### Solution

Wrap call in lambda `-> { ... }` to get fresh call each time:

```ruby
# good
describe '#increment_counter' do
  subject(:increment) { -> { counter.increment } }

  let(:counter) { create(:counter, value: 0) }

  it 'increases counter on each call' do
    increment.call  # value becomes 1
    increment.call  # value becomes 2
    expect(counter.reload.value).to eq(2)  # PASSES
  end

  context 'when counter reaches limit' do
    before { 98.times { increment.call } }

    it 'stops at 100' do
      increment.call  # 99
      increment.call  # 100
      increment.call  # still 100 (limit)
      expect(counter.reload.value).to eq(100)
    end
  end
end
```

### Alternative: just don't use subject

If lambda feels awkward, just define regular method:

```ruby
# good (alternative)
describe '#increment_counter' do
  let(:counter) { create(:counter, value: 0) }

  def increment
    counter.increment
  end

  it 'increases counter on each call' do
    increment  # value becomes 1
    increment  # value becomes 2
    expect(counter.reload.value).to eq(2)
  end
end
```

### When to use

- **subject with lambda**: when you need named subject for methods with side effects
- **Regular method**: when lambda feels excessive
- **Don't use regular subject**: for methods that change state

---

## 4. Traits in characteristic-based contexts

### Idea

Use factory traits to explicitly show characteristic state in context.

### Example

```ruby
# good
describe OrderProcessor do
  describe '#process' do
    subject(:process_order) { processor.process(order) }

    let(:processor) { described_class.new }

    context 'when order is pending' do
      let(:order) { create(:order, :pending) }  # trait matches context!

      context 'and user is premium' do
        let(:user) { create(:user, :premium) }  # trait matches context!
        let(:order) { create(:order, :pending, user: user) }

        it 'processes immediately' do
          expect(process_order.priority).to eq('high')
        end
      end

      context 'and user is regular' do
        let(:user) { create(:user, :regular) }  # trait matches context!
        let(:order) { create(:order, :pending, user: user) }

        it 'adds to queue' do
          expect(process_order.priority).to eq('normal')
        end
      end
    end

    context 'when order is completed' do
      let(:order) { create(:order, :completed) }  # trait matches context!

      it 'skips processing' do
        expect(process_order).to be_nil
      end
    end
  end
end
```

### Defining traits in factory

```ruby
# spec/factories/orders.rb
FactoryBot.define do
  factory :order do
    user
    product
    quantity { 1 }
    status { 'draft' }

    trait :pending do
      status { 'pending' }
      submitted_at { Time.current }
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end
  end
end

# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    subscription { 'free' }

    trait :premium do
      subscription { 'premium' }
      premium_since { 6.months.ago }
    end

    trait :regular do
      subscription { 'free' }
    end
  end
end
```

### Benefits

- **Readability**: `create(:order, :pending)` reads like specification
- **Documentation**: trait name documents characteristic state
- **Easy to extend**: new state = new trait
- **Matches Rule 4**: traits naturally map to characteristics

### When to use

- Characteristic states are clearly defined (pending/completed, premium/regular)
- State requires multiple attributes (not just `status: 'pending'`)
- Need to reuse states in different tests

---

## 5. Shared context: when to use and when it's a smell

### ✅ GOOD: Sharing between multiple files

Shared context is appropriate when setup is used in **multiple test files**:

```ruby
# spec/support/shared_contexts/with_authenticated_user.rb
RSpec.shared_context 'with authenticated user' do
  let(:user) { create(:user, :verified) }

  before { sign_in(user) }
end

# spec/controllers/orders_controller_spec.rb
RSpec.describe OrdersController do
  include_context 'with authenticated user'

  describe 'GET #index' do
    it 'shows user orders' do
      get :index
      expect(assigns(:orders)).to eq(user.orders)
    end
  end
end

# spec/controllers/invoices_controller_spec.rb
RSpec.describe InvoicesController do
  include_context 'with authenticated user'

  describe 'GET #index' do
    it 'shows user invoices' do
      get :index
      expect(assigns(:invoices)).to eq(user.invoices)
    end
  end
end

# spec/requests/api/v1/profile_spec.rb
RSpec.describe 'API V1 Profile' do
  include_context 'with authenticated user'

  describe 'GET /api/v1/profile' do
    it 'returns user profile' do
      get '/api/v1/profile'
      expect(json_response['email']).to eq(user.email)
    end
  end
end
```

**When to use shared context:**
- Setup is used in **3+ files**
- Common scenarios: authenticated user, api client setup, test database state
- Setup is stable and rarely changes

---

### ❌ BAD: Shared context for one describe (smell)

Shared context used only in one file is **design smell**:

```ruby
# bad
RSpec.describe OrderProcessor do
  shared_context 'with order setup' do  # only used here!
    let(:user) { create(:user) }
    let(:product) { create(:product, price: 100) }
    let(:order) { create(:order, user: user, product: product, quantity: 2) }
  end

  describe '#process' do
    include_context 'with order setup'

    it 'charges user' do
      expect { processor.process(order) }.to change { user.reload.balance }.by(-200)
    end
  end

  describe '#cancel' do
    include_context 'with order setup'

    it 'refunds user' do
      order.update(status: 'paid')
      expect { processor.cancel(order) }.to change { user.reload.balance }.by(200)
    end
  end
end
```

**Why it's bad:**
- **Hides setup**: need to search for what `user`, `product`, `order` are
- **Cognitive load**: unclear what variables are available
- **Complexity without benefit**: regular `let` would be simpler

**Correct solution** — regular `let` at `describe` level:

```ruby
# good
RSpec.describe OrderProcessor do
  let(:user) { create(:user) }
  let(:product) { create(:product, price: 100) }
  let(:order) { create(:order, user: user, product: product, quantity: 2) }

  describe '#process' do
    it 'charges user' do
      expect { processor.process(order) }.to change { user.reload.balance }.by(-200)
    end
  end

  describe '#cancel' do
    before { order.update(status: 'paid') }

    it 'refunds user' do
      expect { processor.cancel(order) }.to change { user.reload.balance }.by(200)
    end
  end
end
```

Setup is visible **right above tests**, no need to search for shared context definition.

---

## 6. Nil object for empty context

### Problem

Context describes "absence of something" but remains empty, violating Rule 9 (each context must have its own setup):

```ruby
# bad - empty context violates Rule 9
describe '#leaf?' do
  subject(:is_leaf) { setting.leaf? }

  let(:setting) { described_class.new(:parent, {}) }

  context 'when setting has no children' do
    # ❌ Empty context - no let, no before, no subject
    it { is_expected.to be true }
  end

  context 'when setting has children' do
    let(:child) { described_class.new(:child, {}, parent: setting) }
    before { setting.add_child(child) }

    it { is_expected.to be false }
  end
end
```

### Solution

Use explicit "empty" value (`nil`, `[]`, `{}`) as `let` in the context:

```ruby
# good - both contexts have explicit setup
describe '#leaf?' do
  subject(:is_leaf) { setting.leaf? }

  let(:setting) { described_class.new(:parent, {}) }

  before { setting.add_child(child) if child }  # Side benefit: lift action up

  context 'when setting has children' do  # Happy path first
    let(:child) { described_class.new(:child, {}, parent: setting) }

    it { is_expected.to be false }
  end

  context 'when setting has no children' do
    let(:child) { nil }  # ✅ Explicit "absence" via nil

    it { is_expected.to be true }
  end
end
```

### Benefits

- **Follows Rule 9**: Each context has explicit setup
- **Symmetry**: Both contexts show their data differences clearly
- **Side benefit**: Common action can be lifted to parent (but this is consequence, not the goal)
- **Explicitness**: Reader sees what makes contexts different

### When to use

- Context describes "absence" (no X, empty X, without X)
- Can express absence via obvious empty value: `nil`, `[]`, `{}`, explicit null object
- Code correctly handles empty value (no side effects, no exceptions)
- Prefer `nil` over `{}` or `[]` when both work (more explicit)

### When NOT to use

- Empty value is not obvious (e.g., `{}` meaning "no child" requires code knowledge)
- Code doesn't expect empty value (raises exceptions, has side effects)
- Better to use separate branch without the action
- Would violate Happy Path First without ability to reorder

---

## When to use each pattern

| Pattern | Use when | Don't use when |
|---------|----------|----------------|
| **Named subject** | Method called in multiple contexts, no side effects | Method with side effects needs multiple calls |
| **merge for params** | Many parameters, 1-3 change | All parameters unique to context |
| **subject with lambda** | Method with side effects, need multiple calls | Simple value read without state change |
| **Traits in contexts** | Characteristic states clearly map to factory traits | Unique one-off attribute combination |
| **Shared context** | Setup used in 3+ test files | Used only in one describe |
| **Nil object for empty context** | Context describes absence, can use obvious empty value (nil/[]/null object) | Empty value not obvious, code doesn't handle it, or violates happy path |

---

## Conclusion

These patterns help write tests that:
- **Read like specification** (named subject, traits)
- **Focus on changes** (merge for params)
- **Handle side effects correctly** (lambda subject)
- **Reuse code wisely** (shared context for real sharing, not hiding)

Use them when they improve readability and maintainability. Don't use them mechanically—each pattern solves specific problem.
