# Metadata Schema

Complete schema for metadata files used in agent communication.

**Location**: `tmp/rspec_metadata/{slug}.yml`

---

## Field Reference

| Field | Writer | Reader | Purpose |
|-------|--------|--------|---------|
| **Discovery-agent fields** ||||
| `mode` | discovery-agent | code-analyzer, implementer | `new_code` or `legacy_code` |
| `complexity.zone` | discovery-agent | code-analyzer | STOP decision for red+new |
| `complexity.loc` | discovery-agent | debug | Lines of code |
| `complexity.methods` | discovery-agent | debug | Method count |
| `dependencies` | discovery-agent | architect | Classes to stub (within changed files) |
| `spec_path` | discovery-agent | implementer | Where to write spec |
| `waves` | discovery-agent | orchestrator | Execution order (topological sort) |
| **Code-analyzer fields** ||||
| `slug` | code-analyzer | all | Unique file identifier |
| `source_file` | code-analyzer | cache | Original Ruby file path |
| `source_mtime` | code-analyzer | cache | Unix timestamp for cache validation |
| `test_level` | code-analyzer | factory, implementer | Determines `build_stubbed` vs `create` |
| `target.class` | code-analyzer | all | Class under test |
| `target.method` | code-analyzer | architect | Method being tested |
| `target.method_type` | code-analyzer | implementer | `instance` or `class` |
| `characteristics[].name` | code-analyzer | architect, implementer | Variable naming in let blocks |
| `characteristics[].type` | code-analyzer | architect | Determines context structure |
| `characteristics[].values` | code-analyzer | architect, implementer | Possible states |
| `characteristics[].terminal_values` | code-analyzer | architect | States that prevent child nesting |
| `characteristics[].threshold_value` | code-analyzer | implementer | For range: numeric threshold (e.g., 1000) |
| `characteristics[].threshold_operator` | code-analyzer | implementer | For range: comparison operator (>=, <, etc) |
| `characteristics[].setup.type` | code-analyzer | factory, implementer | Responsibility split |
| `characteristics[].setup.class` | code-analyzer | factory | Factory/class to use |
| `factories_detected` | code-analyzer | factory, implementer | Existing traits |
| **Automation fields** ||||
| `automation.*_completed` | each agent | next agent | Prerequisite check |
| `automation.*_version` | each agent | debug | Version tracking |
| `automation.errors` | any agent | user | Error list |
| `automation.warnings` | any agent | user | Non-critical issues |

---

## Characteristic Types

| Type | Description | States | Terminal? |
|------|-------------|--------|-----------|
| `binary` | Two states | `[present, absent]` or similar | Often yes |
| `enum` | 3+ discrete values | `[admin, manager, user]` | Optional |
| `range` | Numeric threshold from comparison | `[sufficient, insufficient]` | Often yes |
| `sequential` | Ordered states | `[pending, active, completed]` | Final states yes |

### Range Type Fields

For `range` type, additional fields capture the threshold:

| Field | Type | Description |
|-------|------|-------------|
| `threshold_value` | number or null | Concrete numeric value (e.g., `1000` from `>= 1000`) |
| `threshold_operator` | string or null | Comparison operator: `>=`, `>`, `<=`, `<` |

**Example:**
```yaml
- name: balance
  type: range
  values: [sufficient, insufficient]
  threshold_value: 1000
  threshold_operator: '>='
  setup:
    type: factory
    class: Account
```

**Usage in tests:**
- `threshold_value: 1000` + `threshold_operator: '>='`
- Sufficient: `balance: 1000` (boundary)
- Insufficient: `balance: 999` (boundary - 1)

### Terminal Values

Terminal values are states where no further context nesting makes sense.

**Examples**:
- `not_authenticated` → no point testing business logic
- `insufficient_balance` → transaction rejected
- `completed`, `cancelled` → final states

**Usage by architect**: When building context hierarchy, terminal values generate leaf contexts only.

---

## Setup Types

| Type | Processor | Generates | Use When |
|------|-----------|-----------|----------|
| `factory` | Factory Agent | `let(:x) { build_stubbed(:x, trait) }` | ActiveRecord models |
| `data` | Implementer | `let(:x) { { key: value } }` | PORO, hashes, primitives |
| `action` | Implementer | `before { x.action! }` | State changes, sessions |

### Setup Type Coordination

**Factory Agent** processes characteristics with `setup.type = "factory"`:
- Creates factory calls
- Applies trait selection heuristics
- Fills `{SETUP_CODE}` for AR models

**Implementer** processes remaining:
- `setup.type = "data"` → let blocks with plain objects
- `setup.type = "action"` → before hooks

**No overlap**: Each characteristic processed by exactly one agent.

---

## Test Levels

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

test_level: unit

target:
  class: PaymentService
  method: process
  method_type: instance

characteristics:
  - name: authenticated
    type: binary
    values: [authenticated, not_authenticated]
    terminal_values: [not_authenticated]
    setup:
      type: action
      class: null

  - name: payment_method
    type: enum
    values: [card, paypal, bank_transfer]
    terminal_values: []
    setup:
      type: factory
      class: Payment

  - name: balance
    type: range
    values: [sufficient, insufficient]
    terminal_values: [insufficient]
    threshold_value: 1000
    threshold_operator: '>='
    setup:
      type: factory
      class: Account

factories_detected:
  payment:
    file: spec/factories/payments.rb
    traits: [with_card, with_paypal]
  account:
    file: spec/factories/accounts.rb
    traits: [with_balance]

automation:
  discovery_agent_completed: true
  discovery_agent_version: "1.0"
  code_analyzer_completed: true
  code_analyzer_version: "1.0"
  errors: []
  warnings: []
```

---

## Validation Rules

1. **Required fields**: slug, source_file, test_level, target.class
2. **Characteristics**: Must have at least 2 values
3. **Terminal values**: Must be subset of values
4. **Setup type**: Must be one of: factory, data, action
5. **Automation markers**: Boolean only
