# Output Schema

Full YAML schema for code-analyzer output.

**Location:** `{metadata_path}/rspec_metadata/{slug}.yml`
- metadata_path from config (default: tmp)
- slug: `app/services/payment.rb` → `app_services_payment`

---

## Complete Schema

```yaml
status: success

slug: app_services_payment
source_file: app/services/payment_processor.rb
source_mtime: 1699351530
class_name: PaymentProcessor

methods:
  - name: process
    method_mode: modified   # passthrough from methods_to_analyze
    type: instance
    analyzed: true
    characteristics:
      - name: authenticated
        description: "user is authenticated"
        type: boolean
        source:
          kind: internal
        values:
          - value: true
            description: "user is authenticated"
            terminal: false
            # no behavior_id: continues to next characteristic
          - value: false
            description: "user is not authenticated"
            terminal: true
            behavior_id: raises_unauthorized  # terminal edge case
        source_line: "8"
        setup:
          type: data
          class: null
        level: 1
        depends_on: null
        when_parent: null

      - name: subscription
        description: "user has subscription"
        type: presence
        source:
          kind: internal
        values:
          - value: present
            description: "subscription"
            terminal: false
            # no behavior_id: continues to payment_method
          - value: nil
            description: "subscription"
            terminal: true
            behavior_id: returns_subscription_required  # terminal edge case
        source_line: "12"
        setup:
          type: model
          class: Subscription
        level: 2
        depends_on: authenticated
        when_parent: [true]

      - name: payment_method
        description: "payment method type"
        type: enum
        source:
          kind: internal
        values:
          - value: card
            description: "card"
            terminal: false
            behavior_id: processes_card_payment  # leaf success
          - value: paypal
            description: "PayPal"
            terminal: false
            behavior_id: processes_paypal_payment  # leaf success
          - value: bank_transfer
            description: "bank transfer"
            terminal: false
            behavior_id: processes_bank_transfer  # leaf success
        source_line: "15-22"
        setup:
          type: model
          class: Payment
        level: 3
        depends_on: subscription
        when_parent: [present]
    dependencies: [Payment, User, Subscription]

  - name: refund
    method_mode: unchanged
    type: instance
    analyzed: true
    characteristics: [...]
    dependencies: [...]

automation:
  code_analyzer_completed: true
  errors: []
  warnings: []
```

---

## Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `status` | Yes | `success`, `error`, `skipped` |
| `slug` | Yes | File identifier (path with `_`) |
| `source_file` | Yes | Original Ruby file path |
| `source_mtime` | Yes | Unix timestamp for cache |
| `class_name` | Yes | Class under test |
| `methods[]` | Yes | Array of analyzed methods |
| `automation.*` | Yes | Pipeline state markers |

### Method Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Method name |
| `method_mode` | Yes | `new` / `modified` / `unchanged` (pass-through from discovery) |
| `type` | Yes | `instance` or `class` |
| `analyzed` | Yes | `true` if fully analyzed |

### Characteristic Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Semantic name for let block |
| `description` | Yes | Human-readable description |
| `type` | Yes | boolean/presence/enum/range/sequential |
| `source` | Yes | Source object (see below) |
| `values[]` | Yes | Array of value objects |
| `source_line` | Yes | Line number(s) in source |
| `setup.type` | Yes | model/data/action |
| `setup.class` | No | ORM class name or null |
| `level` | Yes | Nesting depth (1 = root) |
| `depends_on` | No | Parent characteristic name |
| `when_parent` | No | Parent values that enable this |

### Value Object Fields

| Field | Required | Description |
|-------|----------|-------------|
| `value` | Yes | The value (true/false, :symbol, "string") |
| `description` | Yes | Human-readable description |
| `terminal` | Yes | Whether this value ends the flow |
| `behavior_id` | Leaf only | Reference to behaviors[] (required for all leaf values) |

**Leaf value:** Analyzer marks leaves by attaching `behavior_id`:
- `terminal: true` → `behavior_id` pointing to `type: terminal`
- `terminal: false` with no further branching → `behavior_id` pointing to `type: success`
Intermediate values have no `behavior_id`.

### Source Object

| Field | Required | Description |
|-------|----------|-------------|
| `source.kind` | Yes | `internal` or `external` |
| `source.class` | External only | Class being called |
| `source.method` | External only | Method being called |

### External Source Example

When code calls another service, characteristic uses `source.kind: external`. The type is determined by OUR branching pattern (boolean, enum, etc.):

```yaml
# Source: result = BillingService.charge(amount)
# Our code branches: if result.success? ... else ... (2 branches = boolean)
- name: billing_result
  description: "billing operation result"
  type: boolean  # 2 branches = boolean
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
  level: 1
  depends_on: null
  when_parent: null
```

The number of values is determined by how OUR code branches on the external result. Dependency's edge cases are tested in its own spec.
