# Metadata Schema

Complete schema for metadata files used in agent communication.

**Location**: `{metadata_path}/rspec_metadata/{slug}.yml`

- `metadata_path` from `.claude/rspec-testing-config.yml` (default: `tmp`)
- Slug: `app/services/payment.rb` → `app_services_payment`

---

## Field Reference

| Field                                             | Writer               | Reader                 | Purpose                                                    |
| ------------------------------------------------- | -------------------- | ---------------------- | ---------------------------------------------------------- |
| **Discovery-agent fields**                        |                      |                        |                                                            |
| `complexity.zone`                                 | discovery-agent      | code-analyzer          | STOP decision for red+new                                  |
| `complexity.loc`                                  | discovery-agent      | debug                  | Lines of code                                              |
| `complexity.methods`                              | discovery-agent      | debug                  | Method count                                               |
| `dependencies`                                    | discovery-agent      | architect              | Classes to stub (within changed files)                     |
| `spec_path`                                       | discovery-agent      | implementer            | Where to write spec                                        |
| **Method-Level Fields**                           |                      |                        |                                                            |
| `methods_to_analyze[]`                            | discovery-agent      | code-analyzer          | Selected public methods for analysis                       |
| `methods_to_analyze[].name`                       | discovery-agent      | code-analyzer          | Method name                                                |
| `methods_to_analyze[].method_mode`                | discovery-agent      | test-architect         | `new`, `modified`, or `unchanged`                          |
| `methods_to_analyze[].wave`                       | discovery-agent      | debug                  | Wave number (0 = leaf)                                     |
| `methods_to_analyze[].line_range`                 | discovery-agent      | code-analyzer          | `[start, end]` line range                                  |
| `methods_to_analyze[].selected`                   | discovery-agent      | code-analyzer          | `true` if user selected for testing                        |
| `methods_to_analyze[].cross_class_deps[]`         | discovery-agent      | debug                  | Classes this method depends on                             |
| `methods_to_analyze[].absorbed_private_methods[]` | discovery-agent      | code-analyzer          | Private methods absorbed into this public method           |
| **Code-analyzer fields**                          |                      |                        |                                                            |
| `slug`                                            | code-analyzer        | all                    | Unique file identifier                                     |
| `source_file`                                     | code-analyzer        | cache                  | Original Ruby file path                                    |
| `source_mtime`                                    | code-analyzer        | cache                  | Unix timestamp for cache validation                        |
| `class_name`                                      | code-analyzer        | all                    | Class under test                                           |
| `methods[]`                                       | code-analyzer        | architect, implementer | Array of analyzed methods                                  |
| `methods[].name`                                  | code-analyzer        | all                    | Method name                                                |
| `methods[].type`                                  | code-analyzer        | implementer            | `instance` or `class`                                      |
| `methods[].analyzed`                              | code-analyzer        | all                    | `true` if fully analyzed                                   |
| `methods[].characteristics[]`                     | code-analyzer        | architect, implementer | Characteristics for this method                            |
| `methods[].dependencies[]`                        | code-analyzer        | architect              | Classes used in method                                     |
| `characteristics[].values[].behavior_id`          | code-analyzer        | architect              | Reference to behaviors[] for leaf values                   |
| `methods[].side_effects[]`                        | code-analyzer        | architect, implementer | Array of side effect objects                               |
| `methods[].side_effects[].type`                   | code-analyzer        | architect              | Type: `webhook`, `email`, `cache`, `event`, `external_api` |
| `methods[].side_effects[].behavior_id`            | code-analyzer        | architect              | Reference to behavior in `behaviors[]`                     |
| **Behavior Bank fields**                          |                      |                        |                                                            |
| `behaviors[]`                                     | code-analyzer        | architect, implementer | Centralized behavior bank                                  |
| `behaviors[].id`                                  | code-analyzer        | architect              | Semantic ID (e.g., `returns_nil`, `raises_unauthorized`)   |
| `behaviors[].description`                         | code-analyzer        | architect              | `it` description text                                      |
| `behaviors[].type`                                | code-analyzer        | architect              | `terminal`, `success`, or `side_effect`                    |
| `behaviors[].subtype`                             | code-analyzer        | architect              | For side_effects: `webhook`, `email`, `cache`, `event`     |
| `behaviors[].enabled`                             | code-analyzer (user) | architect              | `true` if behavior should generate tests                   |
| `behaviors[].used_by`                             | code-analyzer        | display                | Count of usages (for user display)                         |
| `characteristics[].name`                          | code-analyzer        | architect, implementer | Variable naming in let blocks                              |
| `characteristics[].description`                   | code-analyzer        | architect              | Human-readable description of characteristic               |
| `characteristics[].type`                          | code-analyzer        | architect              | Determines context structure                               |
| `characteristics[].values[]`                      | code-analyzer        | architect, implementer | Array of value objects                                     |
| `characteristics[].values[].value`                | code-analyzer        | implementer            | The actual value                                           |
| `characteristics[].values[].description`          | code-analyzer        | architect              | Human-readable description for this value                  |
| `characteristics[].values[].terminal`             | code-analyzer        | architect              | `true` if terminal state                                   |
| `characteristics[].values[].behavior_id`          | code-analyzer        | architect              | Reference to behavior in `behaviors[]` for terminal states |
| `characteristics[].threshold_value`               | code-analyzer        | implementer            | For range: numeric threshold (e.g., 1000)                  |
| `characteristics[].threshold_operator`            | code-analyzer        | implementer            | For range: comparison operator (>=, <, etc)                |
| `characteristics[].setup.type`                    | code-analyzer        | implementer            | `model`, `data`, or `action`                               |
| `characteristics[].setup.class`                   | code-analyzer        | implementer            | ORM class name or null                                     |
| `characteristics[].level`                         | code-analyzer        | architect              | Nesting depth (1 = root)                                   |
| `characteristics[].depends_on`                    | code-analyzer        | architect              | Parent characteristic name                                 |
| `characteristics[].when_parent`                   | code-analyzer        | architect              | Parent values that enable this                             |
| `characteristics[].source.kind`                   | code-analyzer        | implementer            | `internal` or `external`                                   |
| `characteristics[].source.class`                  | code-analyzer        | implementer            | Source class (external only)                               |
| `characteristics[].source.method`                 | code-analyzer        | implementer            | Source method (external only)                              |
| **Automation fields**                             |                      |                        |                                                            |
| `automation.*_completed`                          | each agent           | next agent             | Prerequisite check                                         |
| `automation.*_version`                            | each agent           | debug                  | Version tracking                                           |
| `automation.errors`                               | any agent            | user                   | Error list                                                 |
| `automation.warnings`                             | any agent            | user                   | Non-critical issues                                        |

---

## Method Mode Values

| method_mode | Condition                                   | test-architect Action       |
| ----------- | ------------------------------------------- | --------------------------- |
| `new`       | Method didn't exist before (or file is new) | Insert new describe block   |
| `modified`  | Method body changed (in git diff)           | Regenerate describe block   |
| `unchanged` | Method exists but wasn't touched            | Regenerate if user selected |

**Set by**: discovery-agent Phase 1.3
**Used by**: test-architect (to decide insert vs regenerate)

**Algorithm:**

1. Get git diff hunks (changed line ranges)
2. Get methods from base commit: `git show base:file_path`
3. Get current methods via Serena
4. For each method:
   - Not in base → `new`
   - Line range overlaps diff → `modified`
   - Otherwise → `unchanged`

---

## Method-Level Waves

Discovery-agent now builds waves at **method level** instead of file level. Each public method is a separate wave item with its own dependencies.

### How It Works

1. **Discovery-agent Phase 3** extracts all public methods from each file
2. **Phase 4** builds dependency graph on **cross-class** dependencies only (internal method calls don't create edges)
3. **Phase 5** presents methods to user grouped by file for selection
4. Selected methods are stored in `methods_to_analyze[]`

### Private Method Absorption

Private methods are NOT wave items. Their cross-class dependencies are "absorbed" into the public method that calls them:

```ruby
class Processor
  def process       # PUBLIC - wave item
    validate        # calls private
    Payment.charge  # cross-class dep
  end

  private
  def validate      # PRIVATE - NOT wave item
    User.active?    # cross-class dep → absorbed into #process
  end
end
```

**Result:** `Processor#process` depends on `[Payment, User]`, absorbed: `[validate]`

### Schema

```yaml
# Written by discovery-agent
methods_to_analyze:
  - name: process
    method_mode: modified # was in git diff
    wave: 1
    line_range: [10, 35]
    selected: true
    cross_class_deps:
      - class: Payment
      - class: User
    absorbed_private_methods: [validate]

  - name: refund
    method_mode: unchanged # not changed
    wave: 1
    line_range: [40, 55]
    selected: false
    skip_reason: "User deselected"
    cross_class_deps:
      - class: Payment

  - name: new_helper
    method_mode: new # didn't exist before
    wave: 0
    line_range: [60, 75]
    selected: true
    cross_class_deps: []
```

### Usage by code-analyzer

- `methods_to_analyze[]` present → analyze only methods with `selected: true`
- `methods_to_analyze[]` absent → fallback to full discovery via `get_symbols_overview`
- All methods `selected: false` → return `status: skipped`

### Wave Assignment

| Wave | Meaning                                                 |
| ---- | ------------------------------------------------------- |
| 0    | Leaf methods — no dependencies on other changed methods |
| 1+   | Methods that depend on classes in lower waves           |

Methods from the same class in the same wave are ordered by `line_range[0]` (source code order).

---

## Characteristic Types

| Type         | Description                       | Values                            | Terminal?        |
| ------------ | --------------------------------- | --------------------------------- | ---------------- |
| `boolean`    | Predicate method (ends with ?)    | `[true, false]`                   | Often yes        |
| `presence`   | Object presence check             | `[present, nil]`                  | Often yes        |
| `enum`       | 3+ discrete values                | `[:admin, :manager, :user]`       | Optional         |
| `range`      | Numeric threshold from comparison | semantic groups                   | Often yes        |
| `sequential` | Ordered states (state machine)    | `[:pending, :active, :completed]` | Final states yes |

**Note:** All types apply to both internal and external source characteristics. The `source.kind` field distinguishes the origin, not the type.

### Range Type Fields

For `range` type, additional fields capture the threshold:

| Field                | Type           | Description                                          |
| -------------------- | -------------- | ---------------------------------------------------- |
| `threshold_value`    | number or null | Concrete numeric value (e.g., `1000` from `>= 1000`) |
| `threshold_operator` | string or null | Comparison operator: `>=`, `>`, `<=`, `<`            |

**Example:**

```yaml
- name: balance
  description: "balance sufficiency"
  type: range
  values:
    - value: sufficient
      description: "enough balance"
      terminal: false
    - value: insufficient
      description: "not enough balance"
      terminal: true
  threshold_value: 1000
  threshold_operator: ">="
  setup:
    type: model
    class: Account
```

**Usage in tests:**

- `threshold_value: 1000` + `threshold_operator: '>='`
- Sufficient: `balance: 1000` (boundary)
- Insufficient: `balance: 999` (boundary - 1)

### External Source Characteristics

Characteristics with `source.kind: external` come from calling other classes. They use the same types (boolean, enum, etc.) as internal characteristics — the `source` field indicates the origin.

**Key differences from internal:**

- `source.kind: external` with `source.class` and `source.method`
- Type determined by OUR branching pattern (2 branches = boolean, 3+ = enum, etc.)
- Values extracted from OUR code's control flow

**Schema:**

```yaml
- name: billing_result
  description: "billing service call result"
  type: boolean # 2 branches = boolean
  source:
    kind: external
    class: BillingService
    method: charge
  values:
    - value: true
      description: "billing charge succeeds"
      behavior_id: billing_charge_succeeds
      terminal: false
    - value: false
      description: "billing charge fails"
      behavior_id: billing_charge_fails
      terminal: true
  setup:
    type: action
    class: null
  level: 2
  depends_on: authenticated
  when_parent: [true]
```

**Behavior bank entries:**

```yaml
behaviors:
  # Behaviors from external source characteristics use standard types
  - id: billing_charge_succeeds
    description: "billing charge succeeds"
    type: terminal
    enabled: true
    used_by: 1

  - id: billing_charge_fails
    description: "billing charge fails"
    type: terminal
    enabled: true
    used_by: 1
```

**Why flow-based collapse:**

- External dependencies have their own modular tests
- We don't duplicate their characteristic trees
- We test ALL flows in OUR code that branch on the external result
- The number of values = number of distinct branches in our code

**Generated test structure:**

```ruby
context "when billing succeeds" do
  before { allow(BillingService).to receive(:charge).and_return(Result.success(transaction_id: "txn_123")) }
  it "processes the payment" do ...
end

context "when billing fails (insufficient funds)" do
  before { allow(BillingService).to receive(:charge).and_return(Result.failure(error: :insufficient_funds)) }
  it "returns billing error" do ...
end
```

### Terminal States

Terminal states are values where no further context nesting makes sense. The `terminal` flag is set per-value in the `values[]` array.

**Examples of terminal values:**

- `false` for boolean checks → no point testing inner logic
- `nil` for presence checks → object doesn't exist
- `cancelled`, `failed` → final states in enum/sequential

**Usage by architect**: When building context hierarchy, values with `terminal: true` generate leaf contexts only.

**Ordering rules for values (generator/architect):**

- List non-terminal values first, then terminal values.
- For boolean/presence, positive/`true`/`present` goes first, negative/`false`/`nil` second.
- For enum/range/sequential, preserve the order produced by code-analyzer (no resorting).

### Behavior Fields

Behavior fields reference entries in the `behaviors[]` bank. See [Behavior Bank](#behavior-bank) for full documentation.

**`values[].behavior_id`** — attached to leaf values:

```yaml
values:
  - value: false
    description: "not authenticated"
    terminal: true
    behavior_id: returns_unauthorized # reference to behaviors[]

behaviors:
  - id: returns_unauthorized
    description: "returns unauthorized error"
    type: terminal # terminal value → terminal behavior
    enabled: true
    used_by: 1
```

**Leaf success values with `behavior_id`** — non-terminal leaves get success behaviors:

```yaml
methods:
  - name: process
    characteristics:
      - name: payment_valid
        type: boolean
        values:
          - value: true
            terminal: false
            behavior_id: processes_payment # leaf success flow (type: success)
          - value: false
            terminal: true
            behavior_id: returns_invalid_error # terminal branch (type: terminal)

behaviors:
  - id: processes_payment
    description: "processes the payment"
    type: success # success leaf → success behavior
    enabled: true
    used_by: 1
```

**Leaf value:** Identified by `behavior_id` presence. The analyzer assigns `behavior_id` on values that end branching:

- `terminal: true` → must have `behavior_id` with `type: terminal`
- `terminal: false` and no further branching → `behavior_id` with `type: success`
  Intermediate values have no `behavior_id`.

**Detection by code-analyzer:**

| Code pattern            | Behavior ID              | Description              |
| ----------------------- | ------------------------ | ------------------------ |
| `raise SomeError`       | `raises_some_error`      | "raises {error_name}"    |
| `return nil`            | `returns_nil`            | "returns nil"            |
| `return false`          | `returns_false`          | "returns false"          |
| `return { error: ... }` | `returns_error_result`   | "returns error result"   |
| `Model.create!(...)`    | `creates_model`          | "creates the {model}"    |
| `Service.call(...)`     | `calls_service`          | "calls {service}"        |
| successful completion   | `processes_successfully` | "processes successfully" |

**Grammar (Rule 19):**

- Active voice, present simple
- No modal verbs (should, can, must)
- `NOT` in caps for negation

### Side Effects

Side effects are operations that happen BEFORE the final return value. Each side effect generates a separate `it` block in tests.

**`methods[].side_effects[]`** — array of side effect objects:

```yaml
methods:
  - name: process
    side_effects:
      - type: webhook
        behavior_id: sends_payment_notification
      - type: email
        behavior_id: sends_confirmation_email
      - type: cache
        behavior_id: caches_result

behaviors:
  - id: sends_payment_notification
    description: "sends payment notification"
    type: side_effect
    subtype: webhook
    enabled: true
    used_by: 1
  - id: sends_confirmation_email
    description: "sends confirmation email"
    type: side_effect
    subtype: email
    enabled: true
    used_by: 1
```

**Side Effect Types:**

| Type           | Detection Pattern                                  | Example Description          |
| -------------- | -------------------------------------------------- | ---------------------------- |
| `webhook`      | `WebhooksSender.call`, `HTTP.post` to webhook URL  | "sends payment notification" |
| `email`        | `Mailer.deliver`, `ActionMailer` calls             | "sends confirmation email"   |
| `cache`        | `Redis.set`, `Rails.cache.write`                   | "caches result"              |
| `event`        | `EventBus.publish`, `ActiveSupport::Notifications` | "publishes payment event"    |
| `external_api` | `HTTP.post/get` to external service                | "calls billing API"          |

**Detection by code-analyzer:**

| Code pattern                    | type         | description                       |
| ------------------------------- | ------------ | --------------------------------- |
| `WebhooksSender.call(...)`      | webhook      | "sends {event_type} notification" |
| `SomeMailer.some_email.deliver` | email        | "sends {email_name} email"        |
| `Red.set(key, value)`           | cache        | "caches {key_description}"        |
| `EventBus.publish(:event)`      | event        | "publishes {event_name} event"    |
| `HTTP.post(external_url)`       | external_api | "calls {service_name}"            |

**Test generation:** Each side effect becomes a separate `it` block:

```ruby
context 'when authenticated' do
  it 'sends payment notification' do
    expect(WebhooksSender).to receive(:call).with(...)
    subject
  end

  it 'sends confirmation email' do
    expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
  end

  it 'processes the payment' do  # success flow (from leaf value's behavior_id)
    expect(result).to be_success
  end
end
```

---

## Behavior Bank

Centralized storage for all behavior descriptions. Behaviors are referenced by semantic ID instead of being stored inline.

### Benefits

1. **Deduplication**: Same behavior text stored once (e.g., multiple "returns nil" cases)
2. **User visibility**: See all behaviors before generation
3. **Easy editing**: Change one place, affects all usages
4. **Enable/disable**: Skip unwanted behaviors
5. **Audit trail**: Clear what behaviors exist

### Schema

```yaml
behaviors:
  - id: returns_nil # SEMANTIC ID (snake_case)
    description: "returns nil" # it block text
    type: terminal # terminal | success | side_effect
    enabled: true # user can toggle
    used_by: 3 # count of usages (for display)

  - id: process_payment
    description: "processes the payment"
    type: success # success flow (leaf with terminal: false)
    enabled: true
    used_by: 1

  - id: send_notification
    description: "sends payment notification"
    type: side_effect
    subtype: webhook # for side_effects only
    enabled: true
    used_by: 1

  # Behaviors from external source characteristics use standard types
  - id: billing_charge_succeeds
    description: "billing charge succeeds"
    type: success # external source, but same type semantics
    enabled: true
    used_by: 1

  - id: billing_charge_fails
    description: "billing charge fails"
    type: terminal
    enabled: true
    used_by: 1
```

**Note:** Behaviors from characteristics with `source.kind: external` use the same types as internal ones (terminal, success, side_effect). The source is tracked in the characteristic, not the behavior.

### ID Naming Convention

Semantic IDs use snake_case and describe the behavior:

| Pattern                    | ID Example               |
| -------------------------- | ------------------------ |
| `raise SomeError`          | `raises_some_error`      |
| `return nil`               | `returns_nil`            |
| `return false`             | `returns_false`          |
| `Model.create!(...)`       | `creates_model`          |
| `WebhooksSender.call(...)` | `sends_webhook`          |
| successful completion      | `processes_successfully` |

### Reference Usage

Instead of inline text, use `behavior_id`:

```yaml
# Avoid inline (legacy):
values:
  - value: false
    terminal: true
    behavior: "returns unauthorized error"

# Prefer reference:
values:
  - value: false
    terminal: true
    behavior_id: returns_unauthorized

behaviors:
  - id: returns_unauthorized
    description: "returns unauthorized error"
    type: terminal
    enabled: true
    used_by: 1
```

### Disabled Behaviors

When user disables a behavior, it remains in metadata with `enabled: false`:

```yaml
behaviors:
  - id: returns_nil
    description: "returns nil"
    type: terminal
    enabled: false # user disabled — test-architect skips
    used_by: 2
```

**test-architect/generator**: Skip behaviors where `enabled: false`.

### User Approval Flow

Behaviors are shown to user in code-analyzer Phase 5 alongside characteristics:

```
[BEHAVIORS]
Terminal:
  [x] returns_nil: "returns nil" (used 2 times)
  [x] raises_unauthorized: "raises UnauthorizedError" (used 1 time)

Happy path:
  [x] process_payment: "processes the payment" (#process)

Side effects:
  [x] send_notification: "sends payment notification" (webhook)
  [x] send_email: "sends confirmation email" (email)
```

User options:

- "Approve all" — proceed with everything
- "Modify behaviors" — enable/disable/edit text
- "Other" — custom instruction

---

## Setup Types

| Type     | Meaning (code-analyzer)                                     |
| -------- | ----------------------------------------------------------- |
| `model`  | ORM model (ActiveRecord/Sequel)                             |
| `data`   | PORO, Hash, Array, primitives                               |
| `action` | Runtime mutation (bang methods, session, state transitions) |

### Setup Type Coordination

**code-analyzer** outputs setup types describing the source code:

- `model` — characteristic involves an ORM model
- `data` — characteristic involves plain data
- `action` — characteristic requires runtime mutation

**test-architect** interprets these types for test generation (details in test-architect spec).

**Isolation:** code-analyzer describes source code structure only. Test-specific decisions (factories, let/before) belong to downstream agents.

---

## Test Levels (Under Review)

**Note**: test_level is currently under review. See `open-questions.md` for details on how `build_stubbed` vs `create` will be determined in the wave-based pipeline.

| Level         | Factory Method  | Database          | Use When                  |
| ------------- | --------------- | ----------------- | ------------------------- |
| `unit`        | `build_stubbed` | No                | Single class in isolation |
| `integration` | `create`        | Yes (transaction) | Multiple classes together |
| `request`     | `create`        | Yes               | HTTP endpoint testing     |

---

## Automation Section

Tracks pipeline progress:

```yaml
automation:
  discovery_agent_completed: true
  discovery_agent_version: "1.0"
  code_analyzer_completed: true
  code_analyzer_version: "1.0"
  test_architect_completed: true
  test_implementer_completed: false

  errors: []
  warnings:
    - "test_implementer: Factory trait :premium not found"
```

### Completion Markers

| Marker                       | Set By           | Checked By       |
| ---------------------------- | ---------------- | ---------------- |
| `discovery_agent_completed`  | discovery-agent  | code-analyzer    |
| `code_analyzer_completed`    | code-analyzer    | test-architect   |
| `test_architect_completed`   | test-architect   | test-implementer |
| `test_implementer_completed` | test-implementer | test-reviewer    |
| `test_reviewer_completed`    | test-reviewer    | (final)          |

---

## Complete Example

```yaml
# Written by discovery-agent
complexity:
  zone: yellow
  loc: 180
  methods: 8
dependencies:
  - PaymentGateway
  - NotificationService
spec_path: spec/services/payment_service_spec.rb

methods_to_analyze:
  - name: process
    method_mode: modified
    wave: 0
    line_range: [15, 80]
    selected: true
    cross_class_deps: [PaymentGateway]
  - name: refund
    method_mode: new
    wave: 0
    line_range: [85, 120]
    selected: true
    cross_class_deps: []

# Written by code-analyzer
slug: app_services_payment
source_file: app/services/payment_service.rb
source_mtime: 1699351530
class_name: PaymentService

# Behavior Bank (centralized)
behaviors:
  # Terminal behaviors
  - id: returns_unauthorized
    description: "returns unauthorized error"
    type: terminal
    enabled: true
    used_by: 1
  - id: returns_insufficient_funds
    description: "returns insufficient funds error"
    type: terminal
    enabled: true
    used_by: 1
  - id: returns_ineligible_refund
    description: "returns ineligible for refund error"
    type: terminal
    enabled: true
    used_by: 1

  # Success behaviors (leaf values with terminal: false)
  - id: processes_payment
    description: "processes the payment"
    type: success
    enabled: true
    used_by: 1
  - id: refunds_transaction
    description: "refunds the transaction"
    type: success
    enabled: true
    used_by: 1

  # Side effect behaviors
  - id: sends_payment_notification
    description: "sends payment notification"
    type: side_effect
    subtype: webhook
    enabled: true
    used_by: 1
  - id: sends_confirmation_email
    description: "sends confirmation email"
    type: side_effect
    subtype: email
    enabled: true
    used_by: 1

methods:
  - name: process
    type: instance
    analyzed: true
    side_effects:
      - type: webhook
        behavior_id: sends_payment_notification
      - type: email
        behavior_id: sends_confirmation_email
    characteristics:
      - name: authenticated
        description: "user is authenticated"
        type: boolean
        values:
          - value: true
            description: "authenticated"
            terminal: false
            # no behavior_id: continues to payment_method
          - value: false
            description: "not authenticated"
            terminal: true
            behavior_id: returns_unauthorized # terminal edge case
        setup:
          type: action
          class: null
        level: 1
        depends_on: null
        when_parent: null

      - name: payment_method
        description: "payment method type"
        type: enum
        values:
          - value: card
            description: "paying by card"
            terminal: false
            # no behavior_id: continues to balance
          - value: paypal
            description: "paying via PayPal"
            terminal: false
            behavior_id: processes_payment # leaf success flow
          - value: bank_transfer
            description: "bank transfer"
            terminal: false
            behavior_id: processes_payment # leaf success flow
        setup:
          type: model
          class: Payment
        level: 2
        depends_on: authenticated
        when_parent: [true]

      - name: balance
        description: "balance sufficiency"
        type: range
        values:
          - value: sufficient
            description: "enough balance"
            terminal: false
            behavior_id: processes_payment # leaf success flow
          - value: insufficient
            description: "not enough balance"
            terminal: true
            behavior_id: returns_insufficient_funds # terminal edge case
        threshold_value: 1000
        threshold_operator: ">="
        setup:
          type: model
          class: Account
        level: 3
        depends_on: payment_method
        when_parent: [card]
    dependencies:
      - PaymentGateway
      - User

  - name: refund
    type: instance
    analyzed: true
    characteristics:
      - name: refund_eligible
        description: "refund eligibility"
        type: boolean
        values:
          - value: true
            description: "eligible for refund"
            terminal: false
            behavior_id: refunds_transaction # leaf success flow
          - value: false
            description: "not eligible"
            terminal: true
            behavior_id: returns_ineligible_refund # reference to behaviors[]
        setup:
          type: model
          class: Transaction
        level: 1
        depends_on: null
        when_parent: null
    dependencies:
      - Transaction

automation:
  discovery_agent_completed: true
  discovery_agent_version: "1.0"
  code_analyzer_completed: true
  code_analyzer_version: "3.0"
  errors: []
  warnings: []
```

---

## Validation Rules

1. **Required fields**: slug, source_file, class_name
2. **Characteristics**: Must have at least 1 value in values[]
3. **Values**: Each value object must have: value, description, terminal
4. **Setup type**: Must be one of: model, data, action
5. **Automation markers**: Boolean only
6. **Method mode**: `methods_to_analyze[].method_mode` must be one of: `new`, `modified`, `unchanged`
7. **Behaviors bank** (optional but recommended):
   - `behaviors[]`: centralized array of behavior objects
   - Each object must have: `id` (unique snake_case), `description`, `type`, `enabled`
   - Valid types: `terminal`, `success`, `side_effect`
   - For `side_effect` type: `subtype` required (webhook|email|cache|event|external_api)
   - Behaviors are typed only as `terminal | success | side_effect`
   - Grammar: active voice, present simple, no modal verbs
8. **Behavior references** (optional):
   - `values[].behavior_id`: reference to behaviors[] for all leaf values (terminal and success)
   - `methods[].side_effects[].behavior_id`: reference to behaviors[] for side effects
   - All IDs must exist in `behaviors[]`
   - **Leaf value**: Presence of `behavior_id` marks a leaf. Analyzer attaches `behavior_id` to `terminal: true` values (terminal behaviors) and to non-terminal values that end branching (success behaviors).
9. **Side effects** (optional):
   - `methods[].side_effects[]`: array of side effect objects
   - Each object must have: `type` (webhook|email|cache|event|external_api), `behavior_id`
10. **Characteristic source** (required):

- `characteristics[].source.kind`: `internal` or `external`
- For `external`: `source.class` and `source.method` required
