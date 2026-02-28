# Useful Patterns

A supplement to the [main guide](guide.en.md). Three techniques that fall outside the 17 rules but come up regularly in real projects.

## Table of Contents

1. [super().merge() for context refinement](#supermerge-for-context-refinement)
2. [subject with lambda for side effects](#subject-with-lambda-for-side-effects)
3. [Shared context: when to use and when it's a smell](#shared-context-when-to-use-and-when-its-a-smell)

---

## super().merge() for context refinement

[Rule 4.4](guide.en.md#44-each-context--one-difference) shows how to override scalar `let` declarations — `let(:blocked) { true }` — to isolate a single difference between contexts. But when the method under test accepts a hash with five or six keys, overriding the entire hash in every context means duplicating four or five lines for the sake of one.

```ruby
# bad — entire hash repeated in every context
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

`super().merge()` solves this: each context overrides only the keys it cares about while inheriting the rest from the parent `let`.

```ruby
# good — each context shows only its difference
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

The technique works when the base `let` is stable and contexts change one to three keys. If every key is unique per context, `super().merge()` adds nothing — just override the whole hash.

---

## subject with lambda for side effects

RSpec memoizes `subject`: a second call returns the cached result instead of re-executing the block. For pure functions this is a benefit. For methods with side effects it's a trap that leads to green tests that don't check what they should. More on `subject` in [Rule 7](guide.en.md#7-dont-program-in-tests).

```ruby
# bad — test will fail
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

Wrapping in a lambda returns the procedure itself, not the call result — what gets memoized is the lambda, not the side effect:

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

If a lambda feels awkward, a plain method works just as well:

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

A regular `subject` (without lambda) is safe for methods without side effects — memoization doesn't get in the way there.

---

## Shared context: when to use and when it's a smell

`shared_context` groups setup (`let`, `before`) needed in multiple places. It's a useful tool, but often misapplied — for the difference between `shared_context` and `shared_examples` see [Rule 14](guide.en.md#14-shared-examples-for-contracts).

**Good case** — setup used across several files:

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

Authenticated user, API client setup, test database seeding — typical candidates. The common trait: setup is stable, rarely changes, and is needed in three or more files.

**Smell** — a `shared_context` used only within a single `describe`:

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

`include_context` hides which variables are available — the reader has to hunt for the definition. Plain `let` declarations at the `describe` level do the same job without the extra indirection:

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

Setup is visible right above the tests — no need to search for a shared context definition.
