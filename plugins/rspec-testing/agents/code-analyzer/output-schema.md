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
    type: instance
    analyzed: true
    characteristics:
      - name: authenticated
        description: "user is authenticated"
        type: boolean
        values:
          - value: true
            description: "authenticated"
            terminal: false
          - value: false
            description: "not authenticated"
            terminal: true
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
        values:
          - value: present
            description: "with subscription"
            terminal: false
          - value: nil
            description: "without subscription"
            terminal: true
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
        values:
          - value: card
            description: "paying by card"
            terminal: false
          - value: paypal
            description: "paying via PayPal"
            terminal: false
          - value: bank_transfer
            description: "bank transfer"
            terminal: false
        source_line: "15-22"
        setup:
          type: model
          class: Payment
        level: 3
        depends_on: subscription
        when_parent: [present]
    dependencies: [Payment, User, Subscription]

  - name: refund
    type: instance
    analyzed: true
    characteristics: [...]
    dependencies: [...]

automation:
  code_analyzer_completed: true
  code_analyzer_version: "2.2"
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

### Characteristic Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Semantic name for let block |
| `description` | Yes | Human-readable description |
| `type` | Yes | boolean/presence/enum/range/sequential |
| `values[]` | Yes | Array of {value, description, terminal} |
| `source_line` | Yes | Line number(s) in source |
| `setup.type` | Yes | model/data/action |
| `setup.class` | No | ORM class name or null |
| `level` | Yes | Nesting depth (1 = root) |
| `depends_on` | No | Parent characteristic name |
| `when_parent` | No | Parent values that enable this |
| `external_domain` | No | `true` if collapsed from service call (see 4.2) |
| `domain_class` | No | Source class name for stubbing (when external_domain: true) |

### External Domain Example

When code calls another service (external domain), characteristic is collapsed to binary:

```yaml
# Source: result = BillingService.call(amount); if result.success?
- name: billing_result
  description: "billing operation result"
  type: boolean
  values:
    - value: true
      description: "billing succeeded"
      terminal: false
    - value: false
      description: "billing failed"
      terminal: true
  source_line: "15"
  setup:
    type: action
    class: BillingService
  level: 1
  depends_on: null
  when_parent: null
  external_domain: true
  domain_class: BillingService
```

Edge cases (no_card, no_money) are tested in BillingService spec, not here.
