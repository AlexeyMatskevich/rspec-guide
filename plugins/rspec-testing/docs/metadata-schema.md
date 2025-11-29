# Metadata Schema

Complete schema for metadata files used in agent communication.

**Location**: `{metadata_path}/rspec_metadata/{slug}.yml`
- `metadata_path` from `.claude/rspec-testing-config.yml` (default: `tmp`)
- Slug: `app/services/payment.rb` → `app_services_payment`

---

## Field Reference

| Field | Writer | Reader | Purpose |
|-------|--------|--------|---------|
| **Discovery-agent fields** ||||
| `mode` | discovery-agent | code-analyzer, implementer | `new_code` or `legacy_code` |
| `selected` | discovery-agent | orchestrator, all | `true` if user selected for processing |
| `skip_reason` | discovery-agent | orchestrator | `null`, `"User deselected"`, or `"Custom: {reason}"` |
| `complexity.zone` | discovery-agent | code-analyzer | STOP decision for red+new |
| `complexity.loc` | discovery-agent | debug | Lines of code |
| `complexity.methods` | discovery-agent | debug | Method count |
| `dependencies` | discovery-agent | architect | Classes to stub (within changed files) |
| `spec_path` | discovery-agent | implementer | Where to write spec |
| **Code-analyzer fields** ||||
| `slug` | code-analyzer | all | Unique file identifier |
| `source_file` | code-analyzer | cache | Original Ruby file path |
| `source_mtime` | code-analyzer | cache | Unix timestamp for cache validation |
| `class_name` | code-analyzer | all | Class under test |
| `methods[]` | code-analyzer | architect, implementer | Array of analyzed methods |
| `methods[].name` | code-analyzer | all | Method name |
| `methods[].type` | code-analyzer | implementer | `instance` or `class` |
| `methods[].analyzed` | code-analyzer | all | `true` if fully analyzed |
| `methods[].characteristics[]` | code-analyzer | architect, implementer | Characteristics for this method |
| `methods[].dependencies[]` | code-analyzer | architect | Classes used in method |
| `characteristics[].name` | code-analyzer | architect, implementer | Variable naming in let blocks |
| `characteristics[].description` | code-analyzer | architect | Human-readable description of characteristic |
| `characteristics[].type` | code-analyzer | architect | Determines context structure |
| `characteristics[].values[]` | code-analyzer | architect, implementer | Array of value objects |
| `characteristics[].values[].value` | code-analyzer | implementer | The actual value |
| `characteristics[].values[].description` | code-analyzer | architect | Human-readable description for this value |
| `characteristics[].values[].terminal` | code-analyzer | architect | `true` if terminal state |
| `characteristics[].threshold_value` | code-analyzer | implementer | For range: numeric threshold (e.g., 1000) |
| `characteristics[].threshold_operator` | code-analyzer | implementer | For range: comparison operator (>=, <, etc) |
| `characteristics[].setup.type` | code-analyzer | implementer | `model`, `data`, or `action` |
| `characteristics[].setup.class` | code-analyzer | implementer | ORM class name or null |
| `characteristics[].level` | code-analyzer | architect | Nesting depth (1 = root) |
| `characteristics[].depends_on` | code-analyzer | architect | Parent characteristic name |
| `characteristics[].when_parent` | code-analyzer | architect | Parent values that enable this |
| `characteristics[].external_domain` | code-analyzer | architect, implementer | `true` if collapsed from service call |
| `characteristics[].domain_class` | code-analyzer | implementer | Source class for stubbing (when external) |
| **Automation fields** ||||
| `automation.*_completed` | each agent | next agent | Prerequisite check |
| `automation.*_version` | each agent | debug | Version tracking |
| `automation.errors` | any agent | user | Error list |
| `automation.warnings` | any agent | user | Non-critical issues |

---

## Characteristic Types

| Type | Description | Values | Terminal? |
|------|-------------|--------|-----------|
| `boolean` | Predicate method (ends with ?) | `[true, false]` | Often yes |
| `presence` | Object presence check | `[present, nil]` | Often yes |
| `enum` | 3+ discrete values | `[:admin, :manager, :user]` | Optional |
| `range` | Numeric threshold from comparison | semantic groups | Often yes |
| `sequential` | Ordered states (state machine) | `[:pending, :active, :completed]` | Final states yes |

### Range Type Fields

For `range` type, additional fields capture the threshold:

| Field | Type | Description |
|-------|------|-------------|
| `threshold_value` | number or null | Concrete numeric value (e.g., `1000` from `>= 1000`) |
| `threshold_operator` | string or null | Comparison operator: `>=`, `>`, `<=`, `<` |

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
  threshold_operator: '>='
  setup:
    type: model
    class: Account
```

**Usage in tests:**
- `threshold_value: 1000` + `threshold_operator: '>='`
- Sufficient: `balance: 1000` (boundary)
- Insufficient: `balance: 999` (boundary - 1)

### Terminal States

Terminal states are values where no further context nesting makes sense. The `terminal` flag is set per-value in the `values[]` array.

**Examples of terminal values:**
- `false` for boolean checks → no point testing inner logic
- `nil` for presence checks → object doesn't exist
- `cancelled`, `failed` → final states in enum/sequential

**Usage by architect**: When building context hierarchy, values with `terminal: true` generate leaf contexts only.

---

## Setup Types

| Type | Meaning (code-analyzer) |
|------|-------------------------|
| `model` | ORM model (ActiveRecord/Sequel) |
| `data` | PORO, Hash, Array, primitives |
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

| Level | Factory Method | Database | Use When |
|-------|---------------|----------|----------|
| `unit` | `build_stubbed` | No | Single class in isolation |
| `integration` | `create` | Yes (transaction) | Multiple classes together |
| `request` | `create` | Yes | HTTP endpoint testing |

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

| Marker | Set By | Checked By |
|--------|--------|------------|
| `discovery_agent_completed` | discovery-agent | code-analyzer |
| `code_analyzer_completed` | code-analyzer | test-architect |
| `test_architect_completed` | test-architect | test-implementer |
| `test_implementer_completed` | test-implementer | test-reviewer |
| `test_reviewer_completed` | test-reviewer | (final) |

---

## Complete Example

```yaml
# Written by discovery-agent
mode: new_code
selected: true
skip_reason: null
complexity:
  zone: yellow
  loc: 180
  methods: 8
dependencies:
  - PaymentGateway
  - NotificationService
spec_path: spec/services/payment_service_spec.rb

# Written by code-analyzer
slug: app_services_payment
source_file: app/services/payment_service.rb
source_mtime: 1699351530
class_name: PaymentService

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
          - value: paypal
            description: "paying via PayPal"
            terminal: false
          - value: bank_transfer
            description: "bank transfer"
            terminal: false
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
          - value: insufficient
            description: "not enough balance"
            terminal: true
        threshold_value: 1000
        threshold_operator: '>='
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
          - value: false
            description: "not eligible"
            terminal: true
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
  code_analyzer_version: "2.2"
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
