# RSpec Style Guide

## Table of Contents

### About RSpec and Three Ideas of the Guide
- [About RSpec](#about-rspec)
- [Three Ideas of This Guide](#three-ideas-of-this-guide)
- [Quick Diagnostics: "Why Does My Test Smell?"](#quick-diagnostics-why-does-my-test-smell)

### Part 1: What to Test

- [1. Test behavior, not implementation](#1-test-behavior-not-implementation)
- [2. Verify that the test catches bugs](#2-verify-that-the-test-catches-bugs)
- [3. One `it` — one behavior](#3-one-it--one-behavior)

### Part 2: Structure by Characteristics

- [4. Structure tests by characteristics](#4-structure-tests-by-characteristics)
  - [4.1 Identify characteristics and states](#41-identify-characteristics-and-states)
  - [4.2 Build the hierarchy: dependent → independent](#42-build-the-hierarchy-dependent--independent)
  - [4.3 Positive + negative test](#43-positive--negative-test)
  - [4.4 Each context = one difference](#44-each-context--one-difference)
  - [4.5 Audit: duplicates and invariants](#45-audit-duplicates-and-invariants)

### Part 3: How to Write a Test

- [5. Three phases: Given / When / Then](#5-three-phases-given--when--then)
- [6. Declare `subject` explicitly](#6-declare-subject-explicitly)
- [7. Don't program in tests](#7-dont-program-in-tests)
- [8. Explicitness over DRY](#8-explicitness-over-dry)

### Part 4: Data Preparation

- [9. FactoryBot: factories, traits, methods](#9-factorybot-factories-traits-methods)
  - [9.1 Traits for characteristics](#91-traits-for-characteristics)
  - [9.2 `attributes_for` for parameters](#92-attributes_for-for-parameters)
  - [9.3 `build_stubbed` for unit tests](#93-build_stubbed-for-unit-tests)

### Part 5: Specification Language

- [10. Write readable specifications](#10-write-readable-specifications)
  - [10.1 context + it = valid sentence](#101-context--it--valid-sentence)
  - [10.2 Grammar: Present Simple, active voice](#102-grammar-present-simple-active-voice)
  - [10.3 Context keywords: when/with/and/but/NOT](#103-context-keywords-whenwithandbutnot)
  - [10.4 RuboCop naming rules](#104-rubocop-naming-rules)

### Part 6: Tools

- [11. `aggregate_failures` for interface tests](#11-aggregate_failures-for-interface-tests)
- [12. Don't use `any_instance`](#12-dont-use-any_instance)
- [13. Prefer verifying doubles](#13-prefer-verifying-doubles)
- [14. Shared examples for contracts](#14-shared-examples-for-contracts)
- [15. Request specs over controller specs](#15-request-specs-over-controller-specs)
- [16. Stabilize time](#16-stabilize-time)
- [17. Make failure output readable](#17-make-failure-output-readable)

### Conclusion and Reference Materials
- [What You Get](#what-you-get)
- [API Contract Testing](#api-contract-testing-rspec-applicability-boundaries)
- [External Services](#external-services)
- [Time Nuances Between Ruby and PostgreSQL](#time-nuances-between-ruby-and-postgresql)
- [Migrating Legacy Tests](#migrating-legacy-tests)
- [Learning Resources](#learning-resources)
- [Glossary](#glossary)

---

## About RSpec

RSpec is a Ruby testing library with a DSL designed for describing behavior. Its `describe/context/it` follows BDD methodology: tests formulate [domain](#domain) rules in natural language rather than checking internal code structure. Given (context preparation via `let`/`before`) → When (action) → Then (expectation via `expect`) — three phases familiar from Gherkin underlie every test.

<a id="testing-pyramid-and-level-selection"></a>
<details>
<summary>BDD, TDD, and Gherkin — more details</summary>

**TDD** (test-driven development) — the Red → Green → Refactor cycle: write a test capturing the desired behavior; write minimal code to make the test pass; refactor while keeping the green state.

**BDD** (behaviour-driven development) grew from TDD and shifts focus to [domain](#domain) behavior and the language of business conversation. Tests become a readable specification, not just code verification.

RSpec embodies BDD in the Ruby ecosystem: `describe/context/it` help formulate behavior uniformly and clearly.

**Gherkin** — a formal syntax for describing scenarios: Given (initial context) → When (action) → Then (result). RSpec doesn't execute `.feature` files, but follows the same semantic phases:

| Gherkin | RSpec |
| --- | --- |
| Feature / Story | `describe` — behavior scope |
| Scenario | `it` — specific example |
| Given | `let`, `before` — context preparation |
| When | Method call / HTTP request |
| Then | `expect` — expected result |
| And / But | Nested `context` |

**Testing pyramid.** BDD puts behavior first, but checks live at different levels: fast unit tests at the base, service/integration tests in the middle, end-to-end and contract tests at the top. Choosing the right level helps avoid drifting into implementation checks.

| Level | Question | Typical Tools |
| --- | --- | --- |
| Unit (model, service) | How does a small piece of logic behave? | `expect`, doubles |
| Integration / service | How do several components interact? | Request specs, mailers |
| Request / API contracts | What does the client see? | Request specs, Pact |
| System (E2E) | Does the user story work? | Capybara, Cypress |

</details>

## Three Ideas of This Guide

All 17 rules below are united by three cross-cutting ideas. Not every idea appears in every rule — only where it fits naturally.

**Cognitive load.** Tests are read more often than written. Rules for organizing structure, writing, and language reduce *extraneous* load (artificial complexity from poor organization) and amplify *germane* load (effort spent building a mental model of the domain). When reading a test raises the question "what does this mean?" or "where does this come from?" — extraneous load is too high.

**Tests as a mirror of design.** Complex tests aren't a testing problem; they honestly reflect problems in the code under test. If data preparation bloats, contexts go 5+ levels deep, and you can't do without `any_instance` — the issue is in design: encapsulation violations, God Objects, tight coupling. The first question when struggling: not "how do I work around this in tests?" but "what's wrong with the code design?". In rare cases it's not the code — the behavior itself is too complex for the user, and the test honestly shows it.

**Tests as documentation.** When the rules are followed, the test suite reads like a system specification in natural language. The RSpec report becomes a business document: a manager opens the output and understands what the system does without knowing Ruby. Well-written specs approach QA test cases in structure and wording — and can serve as their source.

## Quick Diagnostics: "Why Does My Test Smell?"

**If the test is hard to read:**
- ✅ Are loops/conditions used? → [Rule 7](#7-dont-program-in-tests)
- ✅ Do describe/context/it form a sentence? → [Rule 10](#10-write-readable-specifications)
- ✅ Are data details hidden in factories? → [Rule 9](#9-factorybot-factories-traits-methods)

**If the test runs slowly:**
- ✅ Are you using `create` in unit tests? → [Rule 9.3](#93-build_stubbed-for-unit-tests)
- ✅ Are there unnecessary HTTP calls? → [External Services](#external-services)

**If the test flakes (fails intermittently):**
- ✅ Are you testing implementation instead of behavior? → [Rule 1](#1-test-behavior-not-implementation)
- ✅ Is time stabilized? → [Rule 16](#16-stabilize-time) and [Time Nuances](#time-nuances-between-ruby-and-postgresql)
- ✅ Does it depend on record ordering? → [Rule 1](#1-test-behavior-not-implementation)

**If the test breaks during refactoring:**
- ✅ Are you testing implementation? → [Rule 1](#1-test-behavior-not-implementation)
- ✅ Are details hidden in factories? → [Rule 9](#9-factorybot-factories-traits-methods)

**If the test doesn't fail when it should:**
- ✅ Is test-first working? → [Rule 2](#2-verify-that-the-test-catches-bugs)

---

## Part 1: What to Test

### 1. Test behavior, not implementation

A test describes observable [behavior](#behavior) — a result that matters to the business. If the `it` description doesn't explain *what* the system does, the test is tied to implementation and will become useless during refactoring.

Take order placement. A bad test verifies that an internal method was called; a good one verifies that the order was placed:

```ruby
# bad — testing implementation
describe OrderService do
  it "true" do
    expect(service).to receive(:charge)
    service.place(order)
  end
end
```

```ruby
# good — testing behavior
describe OrderService do
  it "places the order" do
    service.place(order)
    expect(order.status).to eq("placed")
  end
end
```

In the bad example, it's unclear what "true" means, and the `receive(:charge)` check will break on any internal method rename. In the good one, `it "places the order"` immediately explains the business meaning, and the test passes regardless of how the charge is implemented internally.

If you struggle to write a behavior test and have to test implementation — this signals an encapsulation violation: the public API doesn't express business operations.

The same logic applies to collections. Use `match_array` or `contain_exactly` when order doesn't matter:

```ruby
# bad — tied to order
expect(some_action).to eq [1, 2, 3]
```

```ruby
# good — checking composition
expect(some_action).to match_array [2, 3, 1]
expect(some_action).to contain_exactly(1, 2, 3)
```

Comparing with `eq` ties the test to element order and leads to false failures — if the array order changed due to a DB refactoring, dozens of tests will fail. `match_array` checks composition, not order.

On failure, `eq` gives an unclear diff ("expected [1,2,3] got [2,1,3]" — what's wrong?), while `match_array` gives a clear "missing elements" / "extra elements":

```
# failure output with match_array:
expected collection contained: [1, 2, 3]
actual collection contained:   [2, 3]
the missing elements were:     [1]
```

In general, every time you work with a collection and use `eq` — it's a warning sign. There might be a matcher from `RSpec Expectations` better suited for defining your expectation, or you might be testing the wrong thing.

### 2. Verify that the test catches bugs

If you break the code and the test stays green — it verifies nothing. After writing a test, make sure it actually works: break the code and check that the test fails.

In an ideal TDD world, the Red → Green → Refactor cycle guarantees the test fails first. But in real development, code is often written before tests. This creates a risk of "fitting the test to the implementation".

```ruby
# bad — doesn't verify arguments
describe NotificationService do
  let(:user) { double(email: 'user@example.com') }
  let(:mailer) { double(deliver_later: true) }

  before { allow(UserMailer).to receive(:notification).and_return(mailer) }

  it 'sends notification to user' do
    service.notify_user(user, 'Hello')
    expect(UserMailer).to have_received(:notification)
  end
end
```

The test only verifies that `notification` was called, but not the arguments. If the code starts passing `nil` instead of email — the test stays green.

```ruby
# good — verifies arguments
it 'sends notification to user' do
  service.notify_user(user, 'Hello')
  expect(UserMailer).to have_received(:notification).with(user.email, 'Hello')
end
```

Now if `nil` is passed instead of `user.email`, the test fails with a clear message.

**"Manual Red" checklist** after writing each test:

1. ✅ Test passes (Green)
2. 🔨 Break the code: return a wrong value, comment out a key line, change a condition
3. ❌ Test should fail (Red)
4. 🔄 Restore the code to its original state
5. ✅ Test passes again (Green)

If the test stays green at step 3 — rewrite it: it doesn't verify real behavior.

Manual Red is essentially manual code mutation. For automation, there's mutation testing: the [mutant](https://github.com/mbj/mutant) gem introduces mutations automatically (changes conditions, substitutes `nil`, deletes lines) and verifies that tests fail. If a mutation survives — the test doesn't catch that class of errors. Mutation testing doesn't replace manual verification, but helps find blind spots in the test suite.

### 3. One `it` — one behavior

The description in `it` should be unique and tell about one business truth. One `it` = one situation from the specification = one key observation. When you need to verify multiple consequences of one rule, split them into separate `it` blocks.

Continuing with `OrderService`:

```ruby
# bad — two behaviors in one it
describe OrderService do
  it "processes order successfully" do
    expect { service.place(order) }.to change(Order, :count).by(1)
    expect(ActionMailer::Base.deliveries.count).to eq(1)
  end
end
```

```ruby
# good — each behavior separately
describe OrderService do
  it "creates the order" do
    expect { service.place(order) }.to change(Order, :count).by(1)
  end

  it "sends confirmation email" do
    expect { service.place(order) }.to change { ActionMailer::Base.deliveries.count }.by(1)
  end
end
```

"processes order successfully" fails in CI. What broke — is the order not created or the email not sent? If you need to think when seeing a failed test — it's worth splitting. "creates the order — FAILED" needs no decoding. Simple criterion: if an `it` needs two sentences ("creates the order" and "sends the email") — that's two `it` blocks.

When `it` describes a unified object interface (all attributes from one source), multiple `expect` statements are acceptable — that's the topic of [Rule 11](#11-aggregate_failures-for-interface-tests).

If many `expect` statements appear in an `it`, it's usually a signal: you're trying to capture side effects instead of behavior. To separate behaviors, it helps to distinguish three types:

- **Primary result** — what the method was called for: order created, payment processed, report generated.
- **Side effects** — accompanying actions: sending email, enqueuing background job, publishing event.
- **Terminal states** — failures and edge cases: insufficient funds, invalid address, 403 Forbidden.

For `OrderService#place` this looks like:

```ruby
describe OrderService, '#place' do
  context 'when order is valid' do
    # primary result — what the method was called for
    it 'creates the order' do
      expect { service.place(order) }.to change(Order, :count).by(1)
    end

    # side effect — accompanying action
    it 'sends confirmation email' do
      expect { service.place(order) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    # side effect — another accompanying action
    it 'enqueues inventory sync job' do
      expect { service.place(order) }.to have_enqueued_job(InventorySyncJob)
    end
  end

  # terminal state — failure
  context 'when card balance is insufficient' do
    it 'rejects the order' do
      expect(service.place(order).status).to eq('rejected')
    end
  end
end
```

Each `it` is one type. When reading, it's immediately clear: primary result answers "what happened", side effects — "what fired along the way", terminal states — "what went wrong". Side effects are tested in separate `it` blocks, and often at a different pyramid level: the fact of email delivery is better verified in a mailer unit test, while in a request spec — the status and API response.

---

You know what to test and how many behaviors belong in one `it`. The next question is how to organize dozens of tests so you don't get lost in them.

## Part 2: Structure by Characteristics

### 4. Structure tests by characteristics

This rule covers the entire process of turning requirements into a `context` hierarchy: from identifying characteristics to the final duplicate audit.

Five steps: (1) identify [characteristics](#characteristics-and-states) and states, (2) build the hierarchy from dependent to independent, (3) add positive and negative tests, (4) set up each context with configuration, (5) audit for duplicates and invariants. In manual QA, this approach is known as Decision Table Testing (ISTQB) — business rules are turned into a matrix of conditions and expected results. Characteristics in RSpec are the table conditions, `context` blocks are rows, `it` blocks are expected results.

First — the finished result, then — how to get there. A typical starting point is a flat describe where all tests sit in one block:

```ruby
# bad — flat list, no contexts
describe OrderService, '#place' do
  it 'places the order with card and sufficient balance' do
    order = build(:order, :with_card, card_balance: 10_000, address: build(:address, :valid))
    expect(described_class.new.place(order).status).to eq('placed')
  end

  it 'rejects the order with insufficient balance' do
    order = build(:order, :with_card, card_balance: 0, address: build(:address, :valid))
    expect(described_class.new.place(order).status).to eq('rejected')
  end

  it 'rejects the order without card' do
    order = build(:order, :without_card)
    expect(described_class.new.place(order).status).to eq('rejected')
  end

  it 'rejects the order with invalid address' do
    order = build(:order, :with_card, card_balance: 10_000, address: build(:address, :invalid))
    expect(described_class.new.place(order).status).to eq('rejected')
  end
end
```

Characteristics (payment, balance, address) are buried in each test's parameters — the reader has to figure out how one test differs from another. Here's a well-structured version:

```ruby
describe OrderService, '#place' do
  subject(:result) { described_class.new.place(order) }

  let(:order) { build(:order, :with_card, card_balance: card_balance, address: address) }

  context 'when user has a payment card' do
    context 'and card balance covers the price' do
      let(:card_balance) { order.total + 100 }

      context 'with valid shipping address' do
        let(:address) { build(:address, :valid) }

        it 'places the order' do
          expect(result.status).to eq('placed')
        end
      end

      context 'with invalid shipping address' do
        let(:address) { build(:address, :invalid) }

        it 'rejects the order' do
          expect(result.status).to eq('rejected')
          expect(result.error).to include('address')
        end
      end
    end

    context 'but card balance does NOT cover the price' do
      let(:card_balance) { 0 }
      let(:address) { build(:address, :valid) }

      it 'rejects the order with insufficient funds' do
        expect(result.status).to eq('rejected')
        expect(result.error).to include('insufficient')
      end
    end
  end

  context 'when user has NO payment card' do
    let(:order) { build(:order, :without_card) }

    it 'rejects the order' do
      expect(result.status).to eq('rejected')
    end
  end
end
```

Characteristics are visible in the context hierarchy (payment method → balance → address), happy path comes first, each context sets its difference through `let`. Below — how to get there step by step.

#### 4.1 Identify characteristics and states

A [characteristic](#characteristic) is a domain aspect that affects the behavior outcome (user role, payment method, order status). A [state](#state) is a specific value variant (subscription is active, balance is below limit).

How to find a characteristic: ask "if I change this aspect, will the expected result change?". Make sure it's a business fact, not a technical detail (`user has subscription`, not `premium_flag`).

How to choose states: list all variants the business distinguishes. Group numeric values into ranges that affect the decision. Express each state as a separate `context`.

For `OrderService#place` the characteristics are:

| Characteristic | States | Type |
| --- | --- | --- |
| Payment method | has card / no card | binary |
| Card balance | sufficient / on the boundary / insufficient | range |
| Shipping address | valid / invalid | binary |

**Boundary values for ranges.** In the table, balance is listed as a range — meaning there's a transition point somewhere. If the business rule is `balance >= order.total`, does the order go through when `balance == order.total` or not? Without a test at the boundary, you don't know.

For each range, find the business rule and test three points: confidently within the range, exactly on the boundary, and just beyond it.

```ruby
context 'and card balance covers the price' do
  let(:card_balance) { order.total + 100 }

  it 'places the order' do
    expect(result.status).to eq('placed')
  end
end

context 'and card balance exactly equals the price' do
  let(:card_balance) { order.total }

  it 'places the order' do
    expect(result.status).to eq('placed')  # boundary — same behavior
  end
end

context 'but card balance does NOT cover the price' do
  let(:card_balance) { order.total - 1 }

  it 'rejects the order with insufficient funds' do
    expect(result.status).to eq('rejected')
  end
end
```

In the main example above, balance is simplified to two states for clarity; in real tests, add the boundary value. In manual QA, this approach is called Boundary Value Analysis — testing exactly at the transition point where behavior changes.

**Internal and external characteristics.** Characteristics differ by the source of state, and this determines the test preparation strategy.

- **Internal characteristic** — the state is determined by the object itself: `account.verified?`, `order.cancelled?`, `user.role`. Configured via factory or `let` directly.
- **External characteristic** — the result comes from a dependency: the payment gateway returned an error, an external API didn't respond, a queue is unavailable. Configured via stubbing the dependency.

```ruby
# internal — configured via factory
context 'when user has a payment card' do
  let(:user) { create(:user, :with_card) }
  # ...
end

# external — stub the dependency
context 'when payment gateway accepts the charge' do
  before { allow(gateway).to receive(:charge).and_return(Success.new) }
  # ...
end
```

Key principle for external characteristics: test **your** branches, not the dependency's behavior. If `PaymentGateway` can return 10 different errors, but `OrderService#place` only distinguishes "success", "insufficient funds", and "everything else" — that's three states, not ten. The number of contexts is determined by **your branching**, not the dependency's interface.

This implies a preparation strategy: internal state is configured via factory, external result is stubbed via `allow`. For more on working with stubs and doubles — [Rules 12-13](#12-dont-use-any_instance).

<a id="42-build-the-hierarchy-dependent--independent"></a>

#### 4.2 Build the hierarchy: dependent → independent

Characteristics can be:

- **dependent** — without the base characteristic, the qualifying one is meaningless (no card → no balance);
- **independent** — they don't affect each other (user role and beta test flag).

Algorithm:

1. List characteristics and states.
2. Mark dependencies: B depends on A if B is meaningful only at a specific state of A.
3. For each branch, create nested `context` blocks from base to qualifying, ordered: **happy path first**, corner cases below.

**Dependent characteristics:**

```ruby
describe '#purchase' do
  context 'when user has a payment card' do               # happy path: card present
    context 'and card balance covers the price' do         # happy path: sufficient balance
      it 'charges the card'
    end

    context 'but card balance does NOT cover the price' do # corner case
      it 'rejects the purchase'
    end
  end

  context 'when user has NO payment card' do               # corner case: no card
    it 'rejects the purchase'
  end
end
```

Order matters: the reader first sees the main scenario ("card present, sufficient balance, all good"), then exceptions. If happy path is buried at the bottom — it's a structural problem:

```ruby
# bad — happy path buried
describe '#enroll' do
  context 'when enrollment is rejected because email is invalid' do
    it('shows a validation error') { ... }
  end

  context 'when enrollment is rejected because plan is sold out' do
    it('puts the user on the waitlist') { ... }
  end

  context 'when enrollment is accepted' do # ← happy path at the bottom
    it('activates the membership') { ... }
  end
end
```

```ruby
# good — happy path first
describe '#enroll' do
  context 'when enrollment is accepted' do
    it('activates the membership') { ... }
  end

  context 'when enrollment is rejected because email is invalid' do
    it('shows a validation error') { ... }
  end

  context 'when enrollment is rejected because plan is sold out' do
    it('puts the user on the waitlist') { ... }
  end
end
```

**Independent characteristics:**

```ruby
describe '#feature_access' do
  context 'when user role is admin' do
    it('grants access to admin tools') { ... }

    context 'and beta feature is enabled' do
      it('grants access to beta tools') { ... }
    end

    context 'but beta feature is disabled' do
      it('falls back to standard tools') { ... }
    end
  end

  context 'when user role is customer' do
    it('denies access to admin tools') { ... }

    context 'and beta feature is enabled' do
      it('grants access to beta tools') { ... }
    end

    context 'but beta feature is disabled' do
      it('denies access to beta tools') { ... }
    end
  end
end
```

When there are more than 3-4 independent characteristics, exhaustive combination is impractical (2⁴ = 16 contexts). Focus on pairs that actually affect behavior and on boundary combinations. More on coverage optimization — [Pairwise Testing](https://www.pairwise.org/).

**At the integration level**, independent conditions within one business domain can be combined into a single context:

```ruby
# request spec: domain details combined
describe 'POST /api/payments' do
  context 'when user is authenticated' do
    context 'with valid payment prerequisites' do
      let(:user) { create(:user, :authenticated, :with_verified_card, :with_sufficient_balance) }

      it 'processes payment successfully' do
        post "/api/payments", params: { amount: 100 }
        expect(response).to have_http_status(:created)
      end
    end

    context 'when card is not verified' do
      let(:user) { create(:user, :authenticated, :with_unverified_card) }

      it 'returns 422 Unprocessable Entity' do
        post "/api/payments", params: { amount: 100 }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  context 'when user is not authenticated' do
    it 'returns 401 Unauthorized' do
      post "/api/payments", params: { amount: 100 }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

**Typical layer structure for request specs:**

```ruby
context 'when user is authenticated' do               # Authentication layer
  context 'when user is authorized' do                 # Authorization layer
    context 'with valid domain prerequisites' do       # Domain layer
      it 'performs the action' do ... end               # happy path
    end

    context 'when domain prerequisite violated' do
      it 'returns domain error' do ... end              # domain corner case
    end
  end

  context 'when user is NOT authorized' do
    it 'returns 403 Forbidden' do ... end               # authorization corner case
  end
end

context 'when user is NOT authenticated' do
  it 'returns 401 Unauthorized' do ... end              # authentication corner case
end
```

Each nesting level = transition to the next responsibility layer. The combining marker: if a unit test exists for the domain (`PaymentService`), then domain details can be combined in the request spec. For corner cases, one critical scenario per level is usually sufficient — all combinations stay in unit tests.

**When nesting is too deep:** If the context hierarchy goes deeper than 3-4 levels — the issue isn't the test but the code: the method does too much. Typical causes:
- **Mixing abstraction levels** — the method handles both business logic and low-level details. Extract low-level logic into a separate method.
- **Multiple responsibilities** — the method solves several independent tasks. Split into multiple methods, each doing one thing.
- **Unclear layer boundaries** — the controller contains business logic, or a service handles HTTP. Separate layers (controller → service → repository).

#### 4.3 Positive + negative test

If only the happy path exists — you won't know the code silently accepts invalid data. Each context branch describes a specific combination of states, and for each you need at least one example confirming the behavior and one showing rejection. This protects against regressions in both directions (see also [Rule 2](#2-verify-that-the-test-catches-bugs) — manual verification of each test).

```ruby
# bad — only positive test
describe "#some_action" do
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  context "when user is blocked by admin" do
    let(:blocked) { true }

    context "and blocking duration is over a month" do
      let(:blocked_at) { 2.month.ago }

      it "allows unlocking the user" do
        expect(some_action).to be(true)
      end
    end
  end
end
```

```ruby
# good — both directions
describe "#some_action" do
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  context "when user is blocked by admin" do
    let(:blocked) { true }

    context "and blocking duration is over a month" do
      let(:blocked_at) { 2.month.ago }
      it("allows unlocking the user") { ... }
    end

    context "but blocking duration is under a month" do
      let(:blocked_at) { 1.month.ago }
      it("does NOT allow unlocking the user") { ... }
    end
  end

  context "when user is NOT blocked by admin" do
    let(:blocked) { false }
    it("does NOT allow unlocking the user") { ... }
  end
end
```

Without negative tests, you can't rely on such tests: they won't reflect regressions when the code changes.

#### 4.4 Each context = one difference

If understanding a context requires searching for `let` higher up the file — the setup is in the wrong place. The `let` that makes the context true should appear right after `context "..." do`. If the space between `context` and `it` is empty — the context has no setup and probably isn't needed.

```ruby
# very bad — setup far from context
describe "#some_action" do
  let(:user) { build :user }
  let(:blocked_user) { build :user, blocked: true }
  let(:old_blocked_user) { build :user, blocked: true, blocked_at: 2.month.ago }

  it "does NOT allow unlocking the user" do
    expect(user.some_action).to be(false)
  end

  context "when user is blocked by admin" do
    # empty — where does blocked_user come from?
    it "allows unlocking the user" do
      expect(blocked_user.some_action).to be(true)
    end

    context "and blocking duration is over a month" do
      # also empty — what state is being tested?
      it "allows unlocking the user" do
        expect(old_blocked_user.some_action).to be(true)
      end
    end
  end
end
```

```ruby
# good — setup in place
describe "#some_action" do
  let(:blocked) { false }
  let(:blocked_at) { nil }
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }
  subject(:result) { user.some_action }

  it "does NOT allow unlocking the user" do
    expect(result).to be(false)
  end

  context "when user is blocked by admin" do
    let(:blocked) { true } # ← setup in the right place

    context "and blocking duration is over a month" do
      let(:blocked_at) { 2.month.ago } # ← here too

      it "allows unlocking the user" do
        expect(result).to be(true)
      end
    end

    context "but blocking duration is under a month" do
      let(:blocked_at) { 1.month.ago }

      it "does NOT allow unlocking the user" do
        expect(result).to be(false)
      end
    end
  end
end
```

In the bad example, the reader has to search for `blocked_user` across the file to understand what state is being tested. In the good one, `let(:blocked) { true }` appears right under the context and instantly explains how this context differs from the outer one.

For parameter hashes where a context needs to change one or two keys out of five, instead of overriding the entire `let` you can use `super().merge()` — see [patterns.en.md](patterns.en.md#supermerge-for-context-refinement).

#### 4.5 Audit: duplicates and invariants

After writing tests, check the structure for two types of duplicates.

**Duplicate `let`/`before` reveal missing states.** If sibling branches repeat the same values — the characteristic needs to be raised higher or extracted into a separate context.

```ruby
# bad — duplicating let(:loyalty_status) in each context
describe Billing::DiscountEvaluator do
  subject(:discount) { described_class.call(order) }
  let(:order) { build(:order, segment: segment, loyalty_status: loyalty_status) }

  context 'when segment is b2c' do
    let(:segment) { :b2c }

    context 'with gold loyalty' do
      let(:loyalty_status) { :gold }
      it('returns 0.15') { expect(discount).to eq(0.15) }
    end

    context 'with silver loyalty' do
      let(:loyalty_status) { :silver }
      it('returns 0.10') { expect(discount).to eq(0.10) }
    end

    context 'with no loyalty' do
      let(:loyalty_status) { :none }
      it('returns 0') { expect(discount).to eq(0) }
    end
  end

  context 'when segment is b2b' do
    let(:segment) { :b2b }

    context 'with gold loyalty' do
      let(:loyalty_status) { :gold }    # ← duplicate!
      it('returns 0.12') { expect(discount).to eq(0.12) }
    end
    # ...
  end
end
```

```ruby
# good — currency placed at its proper position in the hierarchy
describe Billing::DiscountEvaluator do
  subject(:discount) { described_class.call(order) }
  let(:order) { build(:order, segment: segment, currency: currency, loyalty_status: loyalty_status) }

  context 'when segment is b2c' do
    let(:segment) { :b2c }

    context 'with USD currency' do
      let(:currency) { :usd }

      context 'and loyalty is gold' do
        let(:loyalty_status) { :gold }
        it('returns 0.15') { ... }
      end

      context 'and loyalty is silver' do
        let(:loyalty_status) { :silver }
        it('returns 0.10') { ... }
      end
    end
  end

  context 'when segment is b2b' do
    let(:segment) { :b2b }

    context 'with USD currency' do
      let(:currency) { :usd }
      # ...
    end

    context 'with EUR currency' do
      let(:currency) { :eur }
      # ...
    end
  end
end
```

**Duplicate `it` blocks with identical expectations reveal invariant contracts.** If several `it` blocks repeat across all leaf contexts — these are interface invariants. Extract them into `shared_examples` (see [Rule 14](#14-shared-examples-for-contracts)).

**How to conduct the audit:**
1. Go through `let`/`before` in siblings — raise repeated values one level up. If tests break, you've found a hidden state: add a context.
2. Compare context structure with the list of characteristics. If a state is never tested — a scenario is missing.
3. Go through `it` blocks in leaf contexts — expectations repeated across all branches should be extracted into `shared_examples`.

---

The context hierarchy is ready. Now — how to write each individual test: phases, subject, what's allowed and not in the test body.

## Part 3: How to Write a Test

### 5. Three phases: Given / When / Then

If reading a test doesn't make clear where preparation ends and action begins — the phases are mixed. `let`/`let!` prepare data (Given), `before` brings the system to the required state or invokes the action (When), expectations inside `it` capture the result (Then).

```ruby
# very bad — everything in one place
describe "#block" do
  before do
    user = create :user
    admin = create :admin
    admin.block(user)
  end

  it "true" do
    expect(User.find(1).blocked).to be(true)
  end
end
```

```ruby
# good — phases separated
describe "#block" do
  # Given: data preparation
  let(:user) { create :user }
  let(:admin) { create :admin }

  # When: action
  before { admin.block(user) }

  # Then: verification
  it "marks the user as blocked" do
    expect(user.blocked).to be(true)
  end
end
```

Returning to `OrderService` — the phases are clearly visible:

```ruby
describe OrderService, '#place' do
  # Given
  let(:order) { build(:order, :with_card, :sufficient_balance) }

  # When
  subject(:result) { described_class.new.place(order) }

  # Then
  it 'places the order' do
    expect(result.status).to eq('placed')
  end
end
```

In the bad example, Given/When/Then are mixed inside `before`, the test accesses `User.find(1)` instead of `let`, and the description `it "true"` says nothing about behavior.

The action can be placed directly in `it` if it reads more clearly:

```ruby
# okay — action in it
describe "#block" do
  let(:user) { create :user }
  let(:admin) { create :admin }

  it "marks the user as blocked" do
    admin.block(user)
    expect(user.blocked).to be(true)
  end
end
```

`let` is lazy: the value is computed on first access. If the context state must exist before `it`, use `before` or `let!`.

```ruby
# bad — calling let in before for eager initialization
let(:product) { create(:product) }
let(:order) { create(:order, product: product) }

before do
  product  # ← forced call so product exists before test
  order
end

# good — let! was made for this
let!(:product) { create(:product) }
let!(:order) { create(:order, product: product) }
```

`let!` = Given (data preparation). `before` = When (action). Don't use `before` just to work around `let` laziness.

In heavy tests where `create` is called many times, the [test-prof](https://test-prof.evilmartians.io/) gem provides `let_it_be` and `before_all` — data is created once per test group, not per each `it`. The Given phase remains the same, but `let_it_be` replaces `let` for data that doesn't change between examples:

```ruby
# instead of let(:user) { create(:user) } — created once
let_it_be(:user) { create(:user, :verified) }
let_it_be(:product) { create(:product, :active) }

context 'when order is valid' do
  # mutable data still uses let
  let(:order) { create(:order, user: user, product: product) }

  it 'places the order' do
    expect(service.place(order).status).to eq('placed')
  end
end
```

Data that the test modifies (updates status, deletes) still requires `let` or `create` in each `it` — otherwise one test's mutation will affect the next.

### 6. Declare `subject` explicitly

If the first question when reading an `it` is "what are we testing?" — `subject` isn't declared. An explicit `subject` immediately shows what's being verified, without searching through expectations.

```ruby
# bad — subject hidden, currency comes from default factory
describe CurrencyConverter do
  let(:amount) { build(:money) }   # factory creates Money.new(100, :usd) — but :usd isn't visible

  it 'converts to EUR' do
    expect(described_class.convert(amount, :eur)).to eq(Money.new(92, :eur))
  end
end

# good — source currency visible in the test
describe CurrencyConverter do
  subject(:result) { described_class.convert(amount, :eur) }

  let(:amount) { build(:money, currency: :usd) }

  it 'converts to EUR' do
    expect(result).to eq(Money.new(92, :eur))
  end
end
```

`subject` is useful when:
- The same result is checked in multiple `it` blocks across different contexts
- The action requires preparation or calling a method with parameters
- You need to name the result being verified via `subject(:result)`

### 7. Don't program in tests

If understanding the setup requires reading helper code — the test has stopped being a specification. A test should read as a behavior description, not a program. When private utilities with direct DB access appear instead of `let` and factories, it's a signal.

```ruby
# terrible — SQL in test, private methods
describe SomeService do
  it 'stores report' do
    result = described_class.call(raw_payload)

    expect(result).to be_success
    expect(find_report(result.id)).to have_attributes(status: 'done', rows: 3)
  end

  private

  def raw_payload
    DB[:reports].insert(name: 'daily', data: '{"rows":[1,2,3]}')
    DB[:reports].where(name: 'daily').first
  end

  def find_report(id)
    DB[:reports].where(id: id).first
  end
end
```

```ruby
# good — factories and RSpec DSL
describe SomeService do
  let(:report) { create(:report, :daily, :with_rows) }
  subject(:result) { described_class.call(report.payload) }

  it 'stores report' do
    expect(result).to be_success
    expect(report.reload).to have_attributes(status: 'done', rows_count: 3)
  end
end
```

Private methods hide how states are set up: the reader has to "execute" the code mentally. Direct DB access bypasses factories and creates tight coupling to the schema.

If tests require complex preparation (direct DB access, private helpers, workarounds) — this signals an encapsulation violation: the object should be easy to create through the public API.

A separate pitfall is `subject` memoization with side effects: calling `subject` a second time won't re-execute the block. Workarounds — wrapping in a lambda or using a plain `def` — are described in [patterns.en.md](patterns.en.md#subject-with-lambda-for-side-effects).

### 8. Explicitness over DRY

In BDD tests, it's important to immediately see WHAT is being tested. If extracting a method or variable makes the test less obvious — keep the duplication.

Tests are behavior documentation for the system. When a reader opens a spec file, they should understand the context and the behavior being verified without jumping to helper method definitions.

```ruby
# bad — helper hides the essence of the check
def create_paid_order(user)
  order = create(:order, user: user, status: :paid)
  create(:payment, order: order, amount: order.total)
  order
end

it 'refunds paid order' do
  order = create_paid_order(user)
  expect { service.refund(order) }.to change(order, :status).to('refunded')
end

# good — duplication, but the behavior being tested is immediately visible
it 'refunds paid order' do
  order = create(:order, :paid, user: user)
  create(:payment, order: order, amount: order.total)

  expect { service.refund(order) }.to change(order, :status).to('refunded')
end
```

When DRY is needed — use RSpec DSL: `let`, `before`, `subject`, traits, shared contexts. This is a common language understood by the whole team, and there's no need to invent custom helpers (see [Rule 7](#7-dont-program-in-tests)). But if an abstraction hides an important verification detail — it's better to write it explicitly.

---

The Given phase requires data. FactoryBot is the primary preparation tool; how you use it determines the readability of the entire setup section.

## Part 4: Data Preparation

### 9. FactoryBot: factories, traits, methods

FactoryBot helps describe [characteristics](#characteristic) of [domain](#domain) objects through traits and parameterized hashes, so tests speak about behavior rather than technical attributes.

#### 9.1 Traits for characteristics

The default factory should create an "average" object suitable for the happy path. Everything that doesn't participate in describing the context should be hidden inside the factory. Recurring states should be expressed through traits: `:blocked`, `:with_verified_email`, `:expired`.

```ruby
# bad — all attributes in the test
describe '#unlock' do
  let(:user) do
    create(:user,
           blocked: true,
           blocked_at: 2.months.ago,
           email_confirmed: true
           # ... 2 more attributes
    )
  end

  it 'allows unlocking the user' do
    expect(UserUnlocker.call(user)).to be_allowed
  end
end
```

```ruby
# good — traits show characteristics
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'secret123' }

    trait :blocked do
      blocked { true }
      blocked_at { 2.months.ago }
    end

    trait :verified do
      email_confirmed { true }
    end
  end
end

describe '#unlock' do
  let(:user) { create(:user, :blocked, :verified) }

  it 'allows unlocking the user' do
    expect(UserUnlocker.call(user)).to be_allowed
  end
end
```

The reader sees only the important characteristics (`:blocked`, `:verified`) and maps them to the context description. Changes to default attributes happen in the factory — tests stay clean.

In `OrderService`, traits help too: instead of `create(:order, card_type: 'visa', card_balance: 1000, card_verified: true)` write `create(:order, :with_card, :sufficient_balance)` — domain characteristics are visible, technical details are hidden.

#### 9.2 `attributes_for` for parameters

If the test doesn't care about specific field values — why spell them out? `attributes_for` generates a valid parameter hash from the factory and removes noise from setup.

```ruby
# bad — duplicating factory in the test
describe 'POST /api/orders' do
  let(:order_params) do
    { customer_email: 'user@example.com', total: 150.0 }
  end

  before { post '/api/orders', params: order_params }

  it('creates new order') { expect(response).to have_http_status(:created) }
end
```

```ruby
# good — standard parameters from factory
describe 'POST /api/orders' do
  let(:order_params) { attributes_for(:order) }
  before { post '/api/orders', params: order_params }

  it('creates new order') { expect(response).to have_http_status(:created) }
end
```

If a specific value matters for behavior — override explicitly:

```ruby
let(:order_params) { attributes_for(:order, segment: 'b2b', discount: 0.15) }
```

Traits work too: `attributes_for(:order, :international, :with_insurance)`.

**Nested associations.** `attributes_for` doesn't return nested associations. If the API accepts nested attributes (e.g., `order[items_attributes]`), nested object parameters must be assembled separately:

```ruby
# attributes_for(:order) won't include items_attributes
let(:order_params) do
  attributes_for(:order).merge(
    items_attributes: [attributes_for(:item), attributes_for(:item)]
  )
end
```

**When NOT to use:** If the API interface differs from the model interface (request parameters have different names/structure), build parameters explicitly:

```ruby
# API expects { email: '...', amount: 150.0 },
# but the model factory uses { customer_email: '...', total_cents: 15000 }
let(:order_params) do
  { email: 'user@example.com', amount: 150.0 }
end
```

If understanding the test requires the reader to open the factory — critical parameters are better spelled out explicitly.

#### 9.3 `build_stubbed` for unit tests

Unit specs for services, policies, presenters, and form objects shouldn't depend on the DB. `build_stubbed` creates an ActiveRecord object without `INSERT`/`UPDATE`, but with populated `id`, `created_at`, `updated_at` and a prohibition on `save`.

```ruby
# bad — writing to DB just for data
describe Orders::PriceCalculator do
  let(:order) { create(:order, items_count: 3, total_cents: 100_00) }
  let(:discount) { create(:discount, percent: 10) }

  it 'applies discount to order total' do
    result = described_class.new(order, discount).calculate
    expect(result).to eq(90_00)
  end
end
```

```ruby
# good — DB not needed
describe Orders::PriceCalculator do
  let(:order) { build_stubbed(:order, items_count: 3, total_cents: 100_00) }
  let(:discount) { build_stubbed(:discount, percent: 10) }

  it 'applies discount to order total' do
    result = described_class.new(order, discount).calculate
    expect(result).to eq(90_00)
  end
end
```

If a test unexpectedly requires `save` or reading from the database, you're testing higher-level behavior — move the example to the integration layer.

When `build_stubbed` doesn't fit: model tests, scopes, callbacks, validations with uniqueness or foreign keys — these need `create`.

<a id="choosing-factorybot-method-decision-tree"></a>
<details>
<summary>Choosing FactoryBot Method: Decision Tree</summary>

```
┌─────────────────────────────────────────────────────────────┐
│ Do you need an object to verify behavior?                    │
└─────────────┬───────────────────────────────────────────────┘
              │
              ├─── NO (only parameters for API/controller)
              │    └─→ attributes_for(:user)
              │
              └─── YES (need an object)
                   │
                   ├─── Must the object be saved to DB?
                   │    │
                   │    ├─── YES (persistence, associations, callbacks)
                   │    │    └─→ create(:order, :with_items)
                   │    │
                   │    └─── NO (in-memory only)
                   │         │
                   │         ├─── Testing object BEHAVIOR?
                   │         │    (validations, model methods)
                   │         │    └─→ build(:user)
                   │         │
                   │         └─── Object needed only as DATA?
                   │              (passing to another service)
                   │              └─→ build_stubbed(:user)
```

</details>

If factories become complex (dozens of required attributes, complex callbacks) — this is a signal: the model does too much. Extract business logic into services, reduce coupling through Dependency Injection.

---

Structure and data are ready. The final layer — how to name contexts and examples so the RSpec report reads like a specification.

## Part 5: Specification Language

### 10. Write readable specifications

The rules in this section turn the RSpec report into a document understandable without knowing Ruby. Compare:

```
# unreadable report
#some_action blocked month ago /it/ true

# readable report
#some_action when user is blocked by admin and blocking duration is over a month
  allows unlocking the user
```

The difference lies in the naming rules below. Four aspects: how to compose sentences from context + it, what grammar to use, which keywords to choose, and how to automate checking via RuboCop.

#### 10.1 context + it = valid sentence

Write `describe`/`context`/`it` descriptions in English: this keeps RSpec reports readable in CI and the team uses a unified language.

```ruby
# atrocious
describe "#some_action" do
  context "blocked" do          # what's blocked, when, by whom?
    context "month ago" do      # a month ago what?
      it("true") { test }      # true — what does this mean?
    end
  end
end
# output: #some_action blocked month ago /it/ true
```

```ruby
# ideal
describe "#some_action" do
  context "when user is blocked by admin" do
    context "and blocking duration is over a month" do
      it("allows unlocking the user") { test }
    end
  end
end
# output: #some_action when user is blocked by admin and blocking duration is over a month
#   allows unlocking the user
```

The description should be understandable to anyone — not just a developer. A manager reading the test output should understand the business rules without knowing the code:

```ruby
when user is blocked by admin and blocking duration is over a month /it/ allows unlocking the user
when user is blocked by admin but blocking duration is under a month /it/ does NOT allow unlocking the user
```

If `when`/`with`/`but` appears in the `it` description — you've lost the context. Extract that state into a `context`.

Avoid technical jargon in descriptions. `when premium_flag is true` → `when user has premium subscription`. `when role_id = 3` → `when user is admin`.

#### 10.2 Grammar: Present Simple, active voice

If `it` sounds like a request ("should return") rather than a fact ("returns") — the description doesn't capture a contract. We describe stable system behavior, so formulations sound like domain rules.

1. **Present Simple.** Behavior is always true: `it 'returns the summary'`.
2. **Active voice in `it`, third person.** The subject is a system object: `it 'places the order'`, `it 'sends confirmation email'`. For states: `it 'has parent'`, `it 'is valid'`.
3. **Passive voice for contexts.** Context sets a state: `when user is blocked`, `when account has balance`.
4. **Zero conditional.** `context/it` stay in Present Simple: `when payment is confirmed, it issues receipt`.
5. **No modal verbs.** No `should`, `can`, `must`: `it 'creates an order'`, not `it 'should create an order'`.
6. **Explicit `NOT` in caps.** `when user is NOT verified`, `it 'does NOT unlock user'`.

```ruby
# minimal template
describe OrderMailer do
  context 'when invoice is generated' do
    it 'sends the invoice email'
  end
end
```

```ruby
# bad
it 'should send email'         # → it 'sends email'
context 'if user paid'         # → context 'when user has paid'
it 'returns'                   # → it 'returns the summary'
```

#### 10.3 Context keywords: when/with/and/but/NOT

Each connector corresponds to a state type and nesting level:

- **`when …`** — opens a branch, describes a base characteristic: `context 'when user has a payment card'`
- **`with …`** — introduces the first qualifying positive state: `context 'with verified email'`
- **`and …`** — adds another positive state: `context 'and balance covers the price'`
- **`without …`** — binary opposite: `context 'without verified email'`
- **`but …`** — contrast to happy path: `context 'but balance does NOT cover the price'`
- **`NOT`** — in caps within context or `it` for negation: `context 'when user does NOT have a payment card'`

Recommended sequence: `when` → `with` → `and` → `but`/`without` → `it`.

```ruby
describe '#charge' do
  context 'when user has a payment card' do                    # base characteristic
    context 'with verified email' do                           # happy path qualifier
      context 'and balance covers the price' do                # another happy path state
        it 'charges the card'
      end

      context 'but balance does NOT cover the price' do        # corner case
        it 'does NOT charge the card'
      end
    end

    context 'without verified email' do                        # corner case
      it 'does NOT charge the card'
    end
  end

  context 'when user does NOT have a payment card' do          # different branch
    it 'does NOT charge the card'
  end
end
```

Domain objects have a natural state: account is active, user isn't blocked, order isn't cancelled. Happy path runs on this state, and a separate context for it is redundant — `when account is NOT blocked` inverts the logic, creating an impression that "not blocked" is an edge case. Contexts describe deviations from the norm:

```ruby
describe '#authenticate' do
  context 'when account exists' do
    it 'signs the user in'                                     # happy path immediately

    context 'but account is blocked' do
      it 'denies the sign-in'
    end
  end

  context 'when account does NOT exist' do
    it 'denies the sign-in'
  end
end
```

#### 10.4 RuboCop naming rules

RuboCop RSpec automatically catches typical naming mistakes:

```ruby
# bad — RSpec/ExampleWording: violation
it 'should send email' do ...          # should → Present Simple
it 'will return 42' do ...             # will → Present Simple

# good
it 'sends email' do ...
it 'returns 42' do ...
```

Full set of rules — [RSpec Style Guide: Naming](https://rspec.rubystyle.guide/#naming).

---

The rules above are about thinking when writing tests. This section is about RSpec tools that help follow the rules and debug problems.

## Part 6: Tools

### 11. `aggregate_failures` for interface tests

By default, one `it` contains one check (Rule 3). But when multiple `expect` statements describe a **unified interface** of an object — all attributes from one source — they can be combined into one `it` with `:aggregate_failures`. Without it, RSpec stops at the first failed `expect`, and you lose the context of the rest.

**Behavioral testing** (creating a record + sending email) — these are different behaviors, different `it` blocks. **Interface testing** (Value Object attributes, HTTP response fields, computed values) — a single behavior "object provides a correct interface", one `it`.

**When applicable:**
- Value objects (Money, Address, Coordinate)
- Configuration objects (Settings, Config)
- Presenter/Decorator objects
- HTTP response structure (status + headers + key fields)
- Related computed values (subtotal + tax + total)

```ruby
# bad — over-splitting the interface
describe ProductPresenter do
  let(:product) { create(:product, name: 'Laptop', price: 999.99, stock: 5) }
  subject(:presenter) { described_class.new(product) }

  it('returns product name') { expect(presenter.display_name).to eq('Laptop') }
  it('returns formatted price') { expect(presenter.formatted_price).to eq('$999.99') }
  it('returns availability') { expect(presenter.availability).to eq('In Stock') }
end
```

```ruby
# okay — aggregate_failures
describe ProductPresenter do
  let(:product) { create(:product, name: 'Laptop', price: 999.99, stock: 5) }
  subject(:presenter) { described_class.new(product) }

  it 'exposes product display interface', :aggregate_failures do
    expect(presenter.display_name).to eq('Laptop')
    expect(presenter.formatted_price).to eq('$999.99')
    expect(presenter.availability).to eq('In Stock')
  end

  context 'when product is out of stock' do
    let(:product) { create(:product, stock: 0) }
    it('indicates unavailability') { expect(presenter.availability).to eq('Out of Stock') }
  end
end
```

```ruby
# ideal — have_attributes
it 'exposes product display interface' do
  expect(presenter).to have_attributes(
    display_name: 'Laptop',
    formatted_price: '$999.99',
    availability: 'In Stock'
  )
end
```

`have_attributes` automatically shows all mismatches — `aggregate_failures` isn't needed.

**Why `aggregate_failures` matters in practice.** Without it, RSpec stops at the first failure. This creates an expensive debugging cycle, especially in CI:

```ruby
# without aggregate_failures
it 'returns order details' do
  get "/api/orders/#{order.id}"

  expect(response.parsed_body['id']).to eq(order.id)      # ❌ nil — test stopped
  expect(response.parsed_body['status']).to eq('pending')  # won't execute
  expect(response.parsed_body['total']).to eq(150.0)       # won't execute
end
```

Seeing only one error ("expected order.id, got nil"), you assume the problem is with ID. Fix it, wait 15 minutes for CI — `status` fails. Fix it, another 15 minutes — `total` fails. Finally you realize: the serializer isn't working at all. **45+ minutes wasted** due to incomplete context.

```ruby
# with aggregate_failures — everything visible at once
it 'returns order details', :aggregate_failures do
  get "/api/orders/#{order.id}"

  expect(response.parsed_body['id']).to eq(order.id)
  expect(response.parsed_body['status']).to eq('pending')
  expect(response.parsed_body['total']).to eq(150.0)
end
```

**Three questions for decision-making:**

1. "Can all checks be described in one sentence?" — Yes → one `it`. No → split.
2. "Does each expectation test an independent code path?" — Yes → split. No → one `it`.
3. "Am I checking one interface or different parts of the API?" — One → combine. Different → split.

| Criterion | Split | Combine |
|----------|-------|---------|
| Each check can be described as a separate sentence | ✅ | ❌ |
| Checks touch independent code paths | ✅ | ❌ |
| All attributes from one source/state | ❌ | ✅ |
| Testing object interface (value object, presenter) | ❌ | ✅ |

When in doubt — split.

**For JSON APIs with large nested structures**, use decomposition through `let`:

```ruby
describe 'GET /api/orders/:id' do
  let(:order) { create(:order, customer: customer) }
  let(:customer) { create(:customer) }

  let(:expected_customer) do
    { 'id' => customer.id, 'name' => 'John Doe', 'email' => 'john@example.com' }
  end

  let(:expected_response) do
    { 'id' => order.id, 'status' => 'pending', 'customer' => expected_customer }
  end

  it 'returns complete order details' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body).to match(expected_response)
  end
end
```

For full API structure fixation, use specialized tools (JSON Schema, rswag, Pact). Details — [guide.api.en.md](guide.api.en.md).

**Warnings:**
- Keep the `it` description specific even with `aggregate_failures` — "works correctly" won't do.
- If one `it` has accumulated 10-15+ expectations — split. That's no longer one interface.
- Expensive context preparation doesn't justify mixing different behaviors: if `it` checks both response status, email delivery, and log entry — that's three behaviors, not one interface.
- `aggregate_failures` is not a way to verify half the pyramid in one `it`.

### 12. Don't use `any_instance`

`allow_any_instance_of` / `expect_any_instance_of` is a global substitution that affects all instances of a class. This is almost always a signal of a Dependency Injection violation.

```ruby
# bad — global mock
describe HighLevelClass do
  before do
    allow_any_instance_of(LowLevelClass).to receive(:foo).and_return({ some_key: :some_value })
  end

  it "returns the processed value" do
    expect(HighLevelClass.new.some_method).to eq(:some_expected_value)
  end
end
```

```ruby
# good — dependency injection
describe HighLevelClass do
  let(:low_level_dependency) { instance_double(LowLevelClass) }
  subject(:instance) { described_class.new(low_level_dependency) }

  before do
    allow(low_level_dependency).to receive(:foo).and_return({ some_key: :some_value })
  end

  it "returns the processed value" do
    expect(instance.some_method).to eq(:some_expected_value)
  end
end
```

The class doesn't accept the dependency explicitly, so you have to force the mock through global configuration. The solution is to pass dependencies through the constructor.

More details: [why any_instance is not recommended](https://rspec.info/features/3-13/rspec-mocks/working-with-legacy-code/any-instance/).

### 13. Prefer verifying doubles

`double` creates an "anonymous" test double without interface verification — it allows mocking non-existent methods. `instance_double` verifies the real class's interface and catches regressions.

```ruby
# bad — double accepts any methods
let(:gateway) { double('PaymentGateway', charge: true) }
```

```ruby
# good — instance_double verifies interface
let(:gateway) { instance_double(PaymentGateway, charge: true) }
```

Imagine: `PaymentGateway` renamed `charge` → `process_charge`. With `double`, the test stays green — you'll learn about the problem in production. With `instance_double`, the test fails instantly:

```
PaymentGateway does not implement #charge
```

- `instance_double(SomeClass)` — verifies instance methods
- `class_double(SomeClass)` — class methods (`.find`, `.call`)
- `object_double(existing_object)` — interface of a specific object

**When verifying doubles don't fit:** dynamically created classes, interfaces via `method_missing`, external services without a Ruby class. In these cases, document the reason and add an integration test.

**What to stub and what not to.** Rules 12-13 explain *how* to stub, but equally important is *when*. The isolation principle: stub external things, don't stub your own.

Stub dependencies beyond your application boundary: HTTP calls to payment gateways, third-party APIs, message queues, file storage. Don't stub your own models, services, and repositories — use factories for those.

```ruby
describe OrderService, '#place' do
  # PaymentGateway — HTTP call to external service → stub
  let(:gateway) { instance_double(PaymentGateway) }

  before { allow(gateway).to receive(:charge).and_return(charge_result) }

  # Order, User — own models → configure via factory
  let(:order) { create(:order, :with_card) }
  let(:user) { create(:user, :verified) }

  # ...
end
```

If testing your own class requires stubbing another of your own classes — this signals tight coupling. The issue isn't the test but the code (see [Rule 4.2](#42-build-the-hierarchy-dependent--independent) — "when nesting is too deep"). Extract the dependency behind an interface or loosen the coupling.

This principle closes the loop: [external characteristics](#41-identify-characteristics-and-states) determine **what** to stub in test structure, Rules 12-13 — **how** to do it technically.

### 14. Shared examples for contracts

If during the [audit](#45-audit-duplicates-and-invariants) identical `it` blocks repeat across several contexts — that's an implicit contract. `shared_examples` make it explicit. This isn't DRY for the sake of fewer lines — it's contract description.

**For shared behavior of different objects:**

```ruby
RSpec.shared_examples 'a pageable API' do
  it('returns the second page') { expect(resource.paginate(page: 2).current_page).to eq 2 }
  it('limits page size') { expect(resource.paginate(page: 1, per_page: 5).items.count).to eq 5 }
end

describe OrdersQuery do
  subject(:resource) { described_class.new(scope: Order.all) }
  it_behaves_like 'a pageable API'
end

describe UsersQuery do
  subject(:resource) { described_class.new(scope: User.active) }
  it_behaves_like 'a pageable API'
end
```

Name using the formula: **`'a/an + [adjective] + noun'`**. Check: "it behaves like [your_name]" should sound like a natural sentence.

**`it_behaves_like` vs `include_examples`.** `it_behaves_like` creates a nested context — in the RSpec output, examples are grouped under the heading "behaves like ...". `include_examples` inserts examples into the current context (inline, without nesting).

For contracts, `it_behaves_like` is appropriate — the contract is visible as a separate "role" in the report:

```
BookingSearchValidator when client is b2c and region is domestic
  behaves like a booking search validator
    responds to valid?
    responds to errors
  validates check_in date
```

`include_examples` is convenient when shared checks are part of the current context (e.g., common validations within one `describe`) and a nested group in the output isn't needed.

`shared_context` is a different tool: it groups setup (`let`, `before`), not expectations. When a `shared_context` is only used within a single file, it's usually a smell; details in [patterns.en.md](patterns.en.md#shared-context-when-to-use-and-when-its-a-smell).

**For invariant expectations within one test** (discovered during the [audit](#45-audit-duplicates-and-invariants)):

```ruby
RSpec.shared_examples 'a booking search validator' do
  it('responds to valid?') { expect(validator).to respond_to(:valid?) }
  it('responds to errors') { expect(validator).to respond_to(:errors) }
  it('responds to normalized_params') { expect(validator).to respond_to(:normalized_params) }
end

describe BookingSearchValidator do
  subject(:validator) { described_class.new(params, client_type: client_type, region: region) }

  context 'when client is b2c' do
    let(:client_type) { :b2c }

    context 'and region is domestic' do
      let(:region) { :domestic }
      let(:params) { { check_in: '2025-11-01', check_out: '2025-11-03', guests: 2 } }

      it_behaves_like 'a booking search validator'

      it 'validates check_in date' do
        expect(validator.valid?).to be true
      end
    end
    # ...
  end
end
```

Each leaf context now contains only checks specific to its characteristics. Invariants are verified automatically.

### 15. Request specs over controller specs

Controller specs are considered deprecated: Rails core and RSpec core officially recommend Request specs starting from RSpec 3.5 and Rails 5.0. Request specs verify the HTTP contract through the full Rack → middleware → controller stack — what the client sees. Controller specs bypass middleware, routing, and serialization — the test can pass while the real request is rejected.

```ruby
# deprecated controller spec
describe UsersController do
  it 'shows user' do
    get :show, params: { id: 1 }
    expect(assigns(:user)).to be_present
  end
end
```

```ruby
# request spec — HTTP contract
describe 'GET /users/:id' do
  let(:user) { create(:user) }

  it 'returns user data' do
    get "/users/#{user.id}"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['id']).to eq(user.id)
  end
end
```

**Observe through the HTTP contract, not through the DB.** Request spec verifies what the API client sees. Side effects in the DB are a valid observation, but at a different abstraction level; unit tests of the model exist for that.

```ruby
# bad — API client doesn't know about Session.count
it "creates a session" do
  post "/sessions", params: creds
  expect(Session.count).to eq 1
end
```

```ruby
# good — verify HTTP contract
it "returns an access token" do
  post "/sessions", params: creds
  expect(response).to have_http_status(:created)
  expect(response.parsed_body.fetch("token")).to be_present
end
```

For new tests, choose Request specs. Mark legacy controller specs with a `:legacy` tag and plan for migration.

### 16. Stabilize time

If a test mysteriously fails around midnight, during DST changes, or at the end of the month — time isn't stabilized. Rails provides [`ActiveSupport::Testing::TimeHelpers`](https://api.rubyonrails.org/v5.2.3/classes/ActiveSupport/Testing/TimeHelpers.html) — use it.

```ruby
# bad — flaky test with Time.now
describe 'daily report' do
  it 'includes today transactions' do
    create(:transaction, created_at: Time.now)
    report = DailyReport.generate
    expect(report.transactions).not_to be_empty
  end
end
# If the test runs at 23:59:59 and report.generate executes at 00:00:00 —
# the transaction ends up "yesterday" and the test fails.
```

```ruby
# good — time is stabilized
describe 'daily report' do
  it 'includes today transactions' do
    freeze_time do
      create(:transaction, created_at: Time.current)
      report = DailyReport.generate
      expect(report.transactions).not_to be_empty
    end
  end
end
```

- `freeze_time` / `travel_to` without a block require `after { travel_back }` — otherwise global state leaks.
- Rely on `Time.zone.now`/`Time.current`, not `Time.now`/`Date.today` (they ignore the zone).
- Stabilize time at midday (`travel_to(Time.zone.parse('2024-03-25 12:00'))`). Midnight is a risk zone: DST transition shifts the clock by ±1 hour, `Date.today` can become `Date.yesterday`, timezone offset changes. If the test is fixed at 23:30 and DST shifts time +1 hour — you end up in the next day. 12:00 guarantees that ±1 hour (typical DST shift) won't throw time into a different day.

### 17. Make failure output readable

If on failure you see a wall of escaped JSON or an unclear diff — the output hinders rather than helps. Switch to structural matchers: the output should instantly explain the discrepancy.

```ruby
# bad — escaped JSON wall
it 'returns response payload' do
  expect(response.body).to eq(
    "{\"meta\":{\"status\":\"ok\",\"total\":3},\"data\":[...]}"
  )
end
# failure output:
# expected: "{\"meta\":{\"status\":\"ok\",\"total\":3},\"data\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"},{\"id\":3,\"name\":\"Carol\"}],\"errors\":[]}"
#      got: "{\"meta\":{\"status\":\"ok\",\"total\":2},\"data\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":3,\"name\":\"Carol\"}],\"errors\":[]}"
# — spot the two differences
```

```ruby
# good — structural diff
describe 'GET /users' do
  subject(:payload) { JSON.parse(response.body, symbolize_names: true) }

  it 'returns metadata and users' do
    expect(payload.fetch(:meta)).to include(status: 'ok', total: 3)
    expect(payload.fetch(:data)).to match_array([
      include(id: 1, name: 'Alice'),
      include(id: 2, name: 'Bob'),
      include(id: 3, name: 'Carol')
    ])
    expect(payload.fetch(:errors)).to be_empty
  end
end
# failure output:
# expected collection contained: [{id: 1, name: "Alice"}, {id: 2, name: "Bob"}, {id: 3, name: "Carol"}]
# actual collection contained:   [{id: 1, name: "Alice"}, {id: 3, name: "Carol"}]
# the missing elements were:     [{id: 2, name: "Bob"}]
```

Use structural expectations (`match_array`, `include`, `have_attributes`) so RSpec shows a meaningful diff. Format complex data before comparison (`JSON.parse`, `deep_symbolize_keys`).

---

## What You Get

When the rules work together, tests acquire three qualities simultaneously:

**Easy to read.** Each context sets one difference, each `it` describes one behavior, factories hide technical routine, and description grammar creates a predictable reading rhythm. Extraneous cognitive load is minimal — effort is spent on understanding the domain, not decoding test code.

**Signal design problems.** Deep context nesting, the need for `any_instance`, bloated factories with dozens of attributes — each of these symptoms points to a specific problem in the code under test (Do One Thing, tight coupling, God Object). Tests are an honest mirror of architecture.

**Work as a specification.** The RSpec report reads like a business document: a manager opens the output and sees `OrderService#place when user has a payment card and card balance covers the price places the order` — no Ruby, only domain rules. The test suite becomes living documentation that never goes stale.

---

## API Contract Testing: RSpec Applicability Boundaries

Detailed breakdown in [guide.api.en.md](guide.api.en.md).

- Use RSpec Request specs for behavior: HTTP statuses, key fields, and side effects.
- For JSON response structure, use specialized tools (JSON Schema, rswag, Pact).
- Don't try to store the contract in dozens of `expect` statements: keep it in one place, and in RSpec verify only observable rules.

## External Services

- **HTTP requests.** Real calls in tests are forbidden: enable WebMock and explicitly allow only emulated hosts.
- **Contract fixation.** With a stable protocol, use VCR. When documenting the format matters more — contract tests: Pact for consumer ↔ provider scenarios, `rspec-openapi` or RSwag for an up-to-date OpenAPI specification.
- **Queues and background jobs.** Verify the fact of enqueueing (`expect { ... }.to have_enqueued_job`) and arguments. Business logic of the job — in a separate unit test.

## Time Nuances Between Ruby and PostgreSQL

- `Date#wday` returns 0 for Sunday; `EXTRACT(DOW FROM ...)` in PostgreSQL also returns 0 for Sunday, but 1 for Monday. When combining Ruby and SQL checks, fix the expected day of the week explicitly.
- `Date.current.beginning_of_week` respects `Rails.application.config.beginning_of_week`, while `date_trunc('week', ...)` in PostgreSQL per ISO always starts from Monday.
- `Date.parse`/`Time.parse` ignore `Time.zone`, while ActiveRecord stores `timestamp` in UTC. Use `Time.zone.parse`, `Time.zone.local`, and `in_time_zone`.
- Transitions across midnight and DST: stabilize time at midday and write separate examples for transitions if the business process touches edge points.

## Migrating Legacy Tests

<details>
<summary>Migrating from implementation-focused to behavior-focused tests</summary>

1. Don't rewrite everything at once — start with files that change or break most often.
2. On each change: find tests with `receive`/`allow`/private methods → rewrite through the public interface.
3. Mark legacy tests with a `:legacy` tag for tracking progress.

```ruby
# before: testing implementation
it 'calls notification service' do
  expect(NotificationService).to receive(:send_email).with(user.email)
  subject.process_order(order)
end

# after: testing behavior
it 'sends confirmation email to user' do
  expect { subject.process_order(order) }
    .to change { ActionMailer::Base.deliveries.count }.by(1)

  email = ActionMailer::Base.deliveries.last
  expect(email.to).to include(user.email)
  expect(email.subject).to include('Order Confirmation')
end
```

</details>

<details>
<summary>Refactoring deep context hierarchies</summary>

1. List all conditions from nested `context` blocks and identify real [characteristics](#characteristic).
2. Combine independent conditions into a single state.
3. Use `shared_examples` for repeating checks.
4. If deep nesting remains — refactor the code (Do One Thing).

```ruby
# before: 6 levels
describe '#process_payment' do
  context 'when user is authenticated' do
    context 'when user has payment card' do
      context 'when card is verified' do
        context 'when balance is sufficient' do
          context 'when transaction is not duplicate' do
            context 'when fraud check passes' do
              it 'processes payment'
            end
          end
        end
      end
    end
  end
end

# after: logical groups
describe '#process_payment' do
  context 'when all payment prerequisites are met' do
    let(:user) { create(:user, :authenticated, :with_verified_card) }
    before { user.payment_card.update(balance: 1000) }

    it 'processes payment successfully'
  end

  context 'when payment is blocked' do
    # fraud/duplicate checks
  end

  context 'when payment fails' do
    # failure cases
  end
end
```

</details>

<details>
<summary>Introducing characteristic-based structure into existing tests</summary>

1. Choose a spec file of medium complexity and apply Rule 4.
2. Show the team the readability difference.
3. Focus on problem areas: flaky tests, complex files, frequently breaking ones.
4. Don't demand immediate migration — make improvements with each code touch.

</details>

## Learning Resources

- **Better Specs** — style and formulations: readable `describe/context/it`, choosing matchers, and anti-patterns. <https://www.betterspecs.org>
- **Testing for Beginners** — introductory book: what to test, how to think in scenarios, and analyzing red tests. <http://testing-for-beginners.rubymonstas.org/index.html>
- **Pluralsight: RSpec Ruby Application Testing** — hands-on course: BDD cycle, `describe/context/it` structure, and three test phases. <https://www.pluralsight.com/courses/rspec-ruby-application-testing>
- **Everyday Rails Testing with RSpec** — practices and tools: factory_bot, VCR/WebMock, everyday patterns. <https://leanpub.com/everydayrailsrspec>

## Glossary

<details>
<summary>Core Concepts</summary>

<a id="behavior"></a>

##### Behavior

An observable change in system state or its reaction to external input that can be described in one sentence in natural language.

**Examples of behaviors:**
- "Creates an order in the database"
- "Sends a confirmation email"
- "Blocks access for an unauthorized user"
- "Calculates the final price including discount"

**NOT separate behaviors:**
- Each individual attribute of a configuration object
- Each field in an API response structure
- Each getter of a value object

If you can't describe the check as an independent action or result in natural language, it's likely part of a larger behavior.

<a id="domain"></a>

##### Domain

The subject area or business domain. A concept from Domain-Driven Design (DDD). In tests, we formulate domain rules in domain language instead of technical terms.

##### Behavioral Testing

Verifying business logic through observable side effects. Each action triggers an independent effect important to the business. Each effect can be described as a separate sentence: "the system does X".

##### Interface Testing

Verifying a set of object attributes in a given state. All attributes derive from a single source and represent unified behavior. Described as "the object provides interface X". For HTTP APIs, use specialized tools (see [guide.api.en.md](guide.api.en.md)).

</details>

<a id="characteristics-and-states"></a>
<details>
<summary>Characteristics and States</summary>

<a id="characteristic"></a>

##### Characteristic

A [domain](#domain) aspect that affects the behavior outcome (user role, payment method, order status). *How to find:* ask "if I change this characteristic, will the expected result change?".

<a id="state"></a>

##### State

A specific value variant of a characteristic important for the rule (subscription is active, balance is below limit). Types: binary (yes/no), multiple (enum), ranges (number/date).

##### Context

A `context` block that fixes one or more characteristic states. Types: positive (state holds), negative (violated/negated), nested (qualifies the outer one).

##### Case

A minimal scenario (`it` block) verifying behavior for a chosen set of states. Happy path — the main flow; corner case — a deviation.

##### State Assignment

A declaration (`let`/`before`) that makes the context's formulation true. Placed immediately under `context`.

##### Flaky Test

A test that's sometimes green, sometimes red with unchanged code. Most often related to unstable time, global state, or dependencies on external services.

</details>

<a id="design-principles"></a>
<details>
<summary>Design Principles</summary>

##### Do One Thing

A principle from Clean Code: a function/method/class should do only one thing. **Signal in tests:** deep context nesting (5+ levels), dozens of combinations for one method.

##### Single Responsibility Principle

A class should have only one reason to change. **Signal in tests:** complex factories with dozens of required fields.

##### Encapsulation

Hiding details behind a public interface. **Signal in tests:** tests verify internal calls (`receive`), you need to know DB schema details.

##### Dependency Injection

Dependencies are passed to an object from outside rather than created internally. **Signal in tests:** `any_instance_of` is needed, testing in isolation is impossible.

##### Tight Coupling

Classes depend on each other too heavily. **Signal in tests:** testing one class requires creating many related objects.

##### Leaky Abstraction

Lower-level details "leak" through the interface. **Signal in tests:** you need to know DB schema details to work with the domain model.

If tests are complex — the problem is in code design. Don't complicate the tests, simplify the code.

</details>
