# Metadata Format Specification

**Version:** 2.0
**Created:** 2025-11-07
**File Format:** YAML
**Location:** `tmp/rspec_claude_metadata/metadata_*.yml` or `/tmp/{project}_rspec_claude_metadata/metadata_*.yml`

## Purpose

Defines the YAML metadata format for passing test architecture data between agents.

**Why this matters:**
- Central communication protocol for all agents
- Persistent state (survives crashes, enables caching)
- Human-readable and inspectable for debugging
- Versioned schema for backward compatibility

## File Naming Convention

Metadata files are named based on the source file path:

```
Source file: app/services/payment_service.rb
Metadata:    metadata_app_services_payment_service.yml

Source file: app/models/user.rb
Metadata:    metadata_app_models_user.yml

Source file: app/controllers/api/v1/orders_controller.rb
Metadata:    metadata_app_controllers_api_v1_orders_controller.yml
```

**Algorithm:**
1. Remove leading `./` if present
2. Remove `.rb` extension
3. Replace `/` with `_`
4. Prepend `metadata_`
5. Append `.yml`

See `ruby-scripts/metadata-helper.spec.md` for implementation details.

## Schema Overview

```yaml
# Top-level sections (order matters for readability):
analyzer:          # ← Written by rspec-analyzer
validation:        # ← Written by metadata_validator.rb
test_level:        # ← Written by rspec-analyzer
target:            # ← Written by rspec-analyzer
characteristics:   # ← Written by rspec-analyzer (core data!)
factories_detected:# ← Written by factory_detector.rb (via analyzer)
automation:        # ← Updated by each agent in pipeline
```

## Complete Schema Definition

### Section: `analyzer`

**Written by:** rspec-analyzer
**Purpose:** Track analysis completion and source file state

```yaml
analyzer:
  completed: true                          # MUST be true after successful analysis
  timestamp: '2025-11-07T10:30:45Z'       # ISO 8601 format
  source_file_mtime: 1699351530           # Unix timestamp of source file modification time
  version: '1.0'                           # Analyzer version (for future compatibility)
```

**Required fields:**
- 🔴 `completed` (boolean): MUST be `true` for valid metadata
- 🔴 `timestamp` (string): ISO 8601 UTC timestamp
- 🔴 `source_file_mtime` (integer): Unix timestamp for cache validation
- 🔴 `version` (string): Schema version

**Validation rules:**
- `completed` MUST be boolean `true` (not string "true")
- `timestamp` MUST be valid ISO 8601
- `source_file_mtime` MUST match current file mtime for cache to be valid

---

### Section: `validation`

**Written by:** metadata_validator.rb
**Purpose:** Track validation results

```yaml
validation:
  completed: true                          # MUST be true after validation
  errors: []                               # Empty array = no errors
  warnings: []                             # May contain warning strings
```

**Required fields:**
- 🔴 `completed` (boolean)
- 🔴 `errors` (array of strings): MUST be empty for valid metadata
- 🔴 `warnings` (array of strings): MAY contain warnings

**Validation rules:**
- If `errors` is not empty, metadata is INVALID
- If `warnings` is not empty, metadata is valid but has issues
- Example error: `"Missing required field: target.class"`
- Example warning: `"Characteristic 'status' has only one state (should have 2+)"`

---

### Section: `test_level`

**Written by:** rspec-analyzer
**Purpose:** Determines testing level (affects what to check in tests)

```yaml
test_level: unit  # or: integration, request, e2e
```

**Allowed values:**
- `unit`: Testing single class/module in isolation (use build_stubbed, stub external dependencies)
- `integration`: Testing multiple classes together (use create, may hit database)
- `request`: Testing HTTP endpoints (use request specs, full stack)
- `e2e`: End-to-end testing (rare, use system specs)

**Validation rules:**
- 🔴 MUST be one of: `unit`, `integration`, `request`, `e2e`

---

### Section: `target`

**Written by:** rspec-analyzer
**Purpose:** Identifies what is being tested

```yaml
target:
  class: PaymentService                    # Class name (required)
  method: process_payment                   # Method name (required)
  method_type: instance                     # or: class
  file: app/services/payment_service.rb    # Relative path from project root (required)
  uses_models: true                         # Hint for factory agent (optional)
```

**Required fields:**
- 🔴 `class` (string): Ruby class name
- 🔴 `method` (string): Method name (without # or .)
- 🔴 `method_type` (string): `instance` or `class`
- 🔴 `file` (string): Relative path to source file

**Optional fields:**
- 🟡 `uses_models` (boolean): Hint that method works with ActiveRecord models

**Validation rules:**
- `class` MUST be valid Ruby constant name
- `method` MUST be valid Ruby method name
- `method_type` MUST be `instance` or `class`
- `file` MUST exist and contain the specified class and method

---

### Section: `characteristics`

**Written by:** rspec-analyzer
**Purpose:** Core data! Characteristics extracted from source code analysis

**This is the MOST IMPORTANT section** - characteristics define test structure.

```yaml
characteristics:
  - name: customer_type                    # Characteristic name (unique within this metadata)
    type: enum                              # Type: binary, enum, range, sequential
    states: [regular, premium, vip]        # All possible states for this characteristic
    terminal_states: []                     # States that don't generate child contexts (optional)
    source: "app/services/calculator.rb:45-52"  # Code location (optional)
    default: null                           # Default state (null = no default)
    depends_on: null                        # Parent characteristic name (null = independent)
    when_parent: null                       # Required parent state for dependency (array or null)
    level: 1                                # Nesting level (1 = root)
```

**Characteristic types:**

1. **`binary`**: Two states (present/absent, true/false, authenticated/not_authenticated)
   ```yaml
   - name: user_authenticated
     type: binary
     setup: action
     states: [authenticated, not_authenticated]
     terminal_states: [not_authenticated]
     source: "app/services/auth_service.rb:23"
     default: null
     depends_on: null
     when_parent: null
     level: 1
   ```

2. **`enum`**: Multiple discrete states (3+)
   ```yaml
   - name: payment_method
     type: enum
     setup: data
     states: [card, paypal, bank_transfer, crypto]
     terminal_states: []
     source: "app/services/payment_service.rb:45-58"
     default: card
     depends_on: null
     when_parent: null
     level: 1
   ```

3. **`range`**: Business value groups from comparison operators (2+ states)
   ```yaml
   # Range with 2 states (most common):
   - name: balance
     type: range
     setup: data
     states: [sufficient, insufficient]  # balance >= amount
     terminal_states: [insufficient]
     threshold_value: 1000
     threshold_operator: '>='
     source: "app/services/payment_service.rb:78"
     default: null
     depends_on: null
     when_parent: null
     level: 1

   # Range with 3+ states (age groups, price tiers):
   - name: age
     type: range
     setup: data
     states: [child, adult, senior]  # age < 18 / age < 65
     terminal_states: []
     threshold_value: null  # Multiple thresholds, cannot be represented as single value
     threshold_operator: '<'
     source: "app/services/discount_service.rb:34-40"
     default: null
     depends_on: null
     when_parent: null
     level: 1
   ```

4. **`sequential`**: States that must be in specific order
   ```yaml
   - name: order_status
     type: sequential
     setup: action
     states: [pending, processing, shipped, delivered]
     terminal_states: [delivered]
     source: "app/models/order.rb:89-102"
     default: pending
     depends_on: null
     when_parent: null
     level: 1
   ```

**Setup methods:**

The `setup` field is **an object** that specifies how test data should be prepared for this characteristic.

**Structure:**
```yaml
setup:
  type: factory    # One of: factory, data, action
  class: User      # Class name (always specified, may be null for action-based setup)
  source: "app/services/payment.rb:45"  # Code location where this setup is derived from
```

**Fields:**
- **`type`** (required): How to prepare test data
  - **`factory`**: Use FactoryBot factories (ActiveRecord models)
    - Creates `let` blocks with `build_stubbed`/`create` calls
    - Example: `let(:user) { build_stubbed(:user, authenticated: authenticated) }`

  - **`data`**: Create data structures directly (PORO, hashes, primitives)
    - Creates `let` blocks with plain Ruby objects
    - Examples: `let(:params) { { amount: 100 } }` or `let(:calculator) { Calculator.new }`

  - **`action`**: Execute method calls to achieve state
    - Creates `before` blocks with method calls
    - Session state, cookies, state machine transitions
    - Examples: `before { session[:user_id] = user.id }` or `before { order.ship! }`

- **`class`** (required): Class name associated with this characteristic
  - For `factory` type: ActiveRecord model name (e.g., `User`, `Order`)
  - For `data` type: PORO class name (e.g., `Calculator`, `Validator`) or `null` for hashes/primitives
  - For `action` type: May be `null` if setup doesn't involve a specific class

- **`source`** (required): Code location reference
  - Format: `"path:line"` or `"path:line-line"`
  - Example: `"app/services/payment.rb:45"` or `"app/models/user.rb:23-30"`

**Setup examples by type:**
```yaml
# Binary + factory (ActiveRecord model):
- name: enabled
  type: binary
  setup:
    type: factory
    class: User
    source: "app/models/user.rb:34"
  states: [enabled, disabled]

# Binary + action (session):
- name: authenticated
  type: binary
  setup:
    type: action
    class: null
    source: "app/services/auth_service.rb:23"
  states: [authenticated, not_authenticated]

# Enum + factory (ActiveRecord model):
- name: payment_method
  type: enum
  setup:
    type: factory
    class: Payment
    source: "app/models/payment.rb:45-52"
  states: [card, paypal, bank_transfer]

# Enum + data (PORO):
- name: calculator_type
  type: enum
  setup:
    type: data
    class: Calculator
    source: "app/services/discount.rb:12"
  states: [percentage, fixed]

# Sequential + data (no guards/callbacks):
- name: status
  type: sequential
  setup:
    type: factory
    class: Article
    source: "app/models/article.rb:23"
  states: [draft, published]

# Sequential + action (with guards/callbacks):
- name: status
  type: sequential
  setup:
    type: action
    class: Order
    source: "app/models/order.rb:89-102"
  states: [pending, processing, shipped]

# Range + factory (database column):
- name: balance_sufficient
  type: range
  setup:
    type: factory
    class: Account
    source: "app/services/payment.rb:78"
  states: [sufficient, insufficient]
  threshold_value: 1000
  threshold_operator: '>='

# Range + action (time comparison):
- name: deadline_passed
  type: range
  setup:
    type: action
    class: null
    source: "app/services/scheduler.rb:45"
  states: [passed, not_passed]
  threshold_value: null
  threshold_operator: '>='
```

**Threshold fields (for range type):**

- **`threshold_value`**: Concrete numeric value from comparison (integer or float)
  - Example: `if balance >= 1000` → `threshold_value: 1000`
  - Set to `null` if value is variable or computed

- **`threshold_operator`**: Comparison operator used in code
  - Must be one of: `>=`, `>`, `<=`, `<`
  - Example: `if balance >= 1000` → `threshold_operator: '>=`'
  - Set to `null` if not applicable

**Threshold examples:**
```yaml
# Constant found:
- name: balance_sufficient
  type: range
  setup: data
  threshold_value: 1000
  threshold_operator: '>='
  states: [sufficient, insufficient]

# Variable (not constant):
- name: balance_sufficient
  type: range
  setup: data
  threshold_value: null
  threshold_operator: '>='
  states: [sufficient, insufficient]

# Float constant:
- name: percentage_high
  type: range
  setup: data
  threshold_value: 0.5
  threshold_operator: '>='
  states: [high, low]
```

**Required fields per characteristic:**
- 🔴 `name` (string): Unique identifier within this metadata
- 🔴 `type` (string): One of: `binary`, `enum`, `range`, `sequential`
- 🔴 `setup` (object): Object with `type`, `class`, `source` fields - how to prepare test data
  - 🔴 `setup.type` (string): One of: `factory`, `data`, `action`
  - 🔴 `setup.class` (string or null): Class name (null allowed for action type)
  - 🔴 `setup.source` (string): Code location in format "path:line" or "path:line-line"
- 🔴 `states` (array): Array of state names (2+ elements)
- 🟡 `terminal_states` (array): States that don't generate child contexts (optional)
- 🔴 `default` (string or null): Default state or null
- 🔴 `depends_on` (string or null): Parent characteristic name or null
- 🟡 `when_parent` (array or null): Parent states when this char applies (required if `depends_on` is not null)
- 🔴 `level` (integer): Nesting level (1 = root, 2+ = nested)
- 🟡 `threshold_value` (number or null): For range type, concrete threshold value (optional)
- 🟡 `threshold_operator` (string or null): For range type, comparison operator (optional)

**Validation rules:**
- `name` MUST be unique within `characteristics` array
- `type` MUST be one of: `binary`, `enum`, `range`, `sequential`
- `setup` MUST be an object with all three required fields
- `setup.type` MUST be one of: `factory`, `data`, `action`
- `setup.class` MUST be valid Ruby constant name or null
- `setup.source` MUST match format "path:N" or "path:N-M" where N,M are positive integers
- `states` MUST have at least 2 elements
- `states` elements MUST be strings
- `terminal_states` if present MUST be array with all values in `states`
- `default` if not null MUST be in `states`
- `depends_on` if not null MUST reference existing characteristic name
- `when_parent` MUST be null if `depends_on` is null
- `when_parent` if not null MUST be non-empty array
- `when_parent` array elements MUST all be in parent's `states`
- `level` MUST be integer >= 1
- No circular dependencies allowed
- `level` MUST match dependency depth (root = 1, child of root = 2, etc.)
- `threshold_value` if present MUST be number (integer or float) or null
- `threshold_operator` if present MUST be one of: `>=`, `>`, `<=`, `<`, or null
- `threshold_value` and `threshold_operator` are typically used together for `range` type
- WARNING: `when_parent` should not include parent's `terminal_states` (child won't generate)

**Example 1: Binary with terminal state:**
```yaml
characteristics:
  - name: authenticated
    type: binary
    setup:
      type: action
      class: null
      source: "app/services/payment_service.rb:45"
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]  # Terminal: no auth → no business logic
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: payment_method
    type: enum
    setup:
      type: factory
      class: Payment
      source: "app/services/payment_service.rb:52-58"
    states: [card, paypal]
    default: null
    depends_on: authenticated
    when_parent: [authenticated]          # Array with single element
    level: 2
```

**Example 2: Enum with multiple terminals:**
```yaml
characteristics:
  - name: role
    type: enum
    setup:
      type: factory
      class: User
      source: "app/services/order_service.rb:23-35"
    states: [admin, manager, customer, guest]
    terminal_states: [customer, guest]    # These roles have no edit permissions
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: can_edit_orders
    type: binary
    setup:
      type: data
      class: null
      source: "app/services/order_service.rb:40"
    states: [allowed, denied]
    default: null
    depends_on: role
    when_parent: [admin, manager]         # Array: applies to both admin AND manager
    level: 2
```

**Example 3: Sequential with final states:**
```yaml
characteristics:
  - name: status
    type: sequential
    setup:
      type: action
      class: Order
      source: "app/models/order.rb:89-102"
    states: [pending, processing, completed, cancelled]
    terminal_states: [completed, cancelled]  # Final states: no further transitions
    default: pending
    depends_on: null
    when_parent: null
    level: 1

  - name: can_modify
    type: binary
    setup:
      type: data
      class: null
      source: "app/models/order.rb:150"
    states: [allowed, denied]
    default: null
    depends_on: status
    when_parent: [pending, processing]    # Only active states allow modifications
    level: 2
```

---

### Section: `factories_detected`

**Written by:** factory_detector.rb (invoked by rspec-analyzer)
**Purpose:** Information about existing FactoryBot factories and traits

**IMPORTANT:** This section does NOT influence characteristic extraction. It's purely informational for implementer and factory agents.

```yaml
factories_detected:
  user:                                    # Factory name (symbol or string)
    file: spec/factories/users.rb
    traits: [admin, blocked, premium]     # Array of trait names
  order:
    file: spec/factories/orders.rb
    traits: [with_items, completed, cancelled]
```

**Structure:**
- Top-level keys are factory names
- Each factory has:
  - `file` (string): Path to factory file
  - `traits` (array): List of trait names found in factory

**Validation rules:**
- 🟡 MAY be empty object `{}` if no factories found
- Each factory MUST have `file` and `traits` keys
- `traits` MAY be empty array `[]`

---

### Section: `automation`

**Written by:** Multiple agents throughout pipeline
**Purpose:** Track pipeline progress and store agent-specific data

```yaml
automation:
  # Written by analyzer
  analyzer_completed: true
  analyzer_version: '1.0'

  # Written by skeleton generator (Ruby script)
  skeleton_generated: true
  skeleton_file: spec/services/payment_service_spec.rb

  # Written by architect
  architect_completed: true
  architect_version: '1.0'

  # Written by factory agent
  factory_completed: true
  factory_version: '1.0'
  factory_skipped: false

  # Written by implementer
  implementer_completed: true
  implementer_version: '1.0'

  # Written by polisher
  polisher_completed: true
  polisher_version: '1.0'
  linter: 'rubocop'                        # or 'standardrb' or null if none detected

  # Errors and warnings from any step
  errors: []
  warnings:
    - "Factory trait :premium not found, using attributes instead"
    - "rubocop: 2 offenses auto-corrected"
```

**Field documentation:**

**Analyzer fields:**
- `analyzer_completed` (boolean): MUST be true after analyzer runs
- `analyzer_version` (string): Analyzer version (e.g., '1.0')
- `factories_detected` (boolean): True if factories found
- `validation_passed` (boolean): True if metadata validated successfully

**Skeleton generator fields (Ruby script):**
- `skeleton_generated` (boolean): True if spec skeleton created
- `skeleton_file` (string): Path to generated spec file

**Architect fields:**
- `architect_completed` (boolean): True after architect completes
- `architect_version` (string): Architect version (e.g., '1.0')

**Factory agent fields:**
- `factory_completed` (boolean): True after factory agent completes
- `factory_version` (string): Factory agent version (e.g., '1.0')
- `factory_skipped` (boolean): True if factory agent skipped (no ActiveRecord models)
- `factory_skip_reason` (string): Reason when skipped=true (e.g., "No factory setup types found")

**Implementer fields:**
- `implementer_completed` (boolean): True after implementer completes
- `implementer_version` (string): Implementer version (e.g., '1.0')

**Polisher fields:**
- `polisher_completed` (boolean): True after polisher completes
- `polisher_version` (string): Polisher version (e.g., '1.0')
- `linter` (string or null): Detected linter tool ('rubocop', 'standardrb', or null)

**Common fields (written by any agent):**
- `errors` (array of strings): Critical errors encountered during pipeline
- `warnings` (array of strings): Non-critical issues (linter warnings, missing traits, etc.)

**Validation rules:**
- 🟡 This section is flexible and can contain agent-specific fields
- 🔴 All `*_completed` fields MUST be boolean
- 🔴 All `*_version` fields SHOULD be strings in semver format
- 🔴 `errors` and `warnings` MUST be arrays if present

## Complete Examples

### Example 1: Simple Unit Test (No Dependencies)

```yaml
# metadata_app_services_discount_calculator.yml

analyzer:
  completed: true
  timestamp: '2025-11-07T10:30:45Z'
  source_file_mtime: 1699351530
  version: '1.0'

validation:
  completed: true
  errors: []
  warnings: []

test_level: unit

target:
  class: DiscountCalculator
  method: calculate
  method_type: instance
  file: app/services/discount_calculator.rb
  uses_models: false

characteristics:
  - name: customer_type
    type: enum
    setup:
      type: data
      class: null
      source: "app/services/discount_calculator.rb:12-20"
    states: [regular, premium, vip]
    terminal_states: []
    default: null
    depends_on: null
    when_parent: null
    level: 1

factories_detected: {}

automation:
  analyzer_completed: true
  analyzer_version: '1.0'
  skeleton_generated: false
  factories_detected: false
  validation_passed: true
```

---

### Example 2: Complex Integration Test (With Dependencies)

```yaml
# metadata_app_services_payment_service.yml

analyzer:
  completed: true
  timestamp: '2025-11-07T10:35:20Z'
  source_file_mtime: 1699352120
  version: '1.0'

validation:
  completed: true
  errors: []
  warnings:
    - "Characteristic 'card_valid' depends on 'payment_method' with when_parent='card'"

test_level: integration

target:
  class: PaymentService
  method: process_payment
  method_type: instance
  file: app/services/payment_service.rb
  uses_models: true

characteristics:
  # Root level - user authentication
  - name: authenticated
    type: binary
    setup:
      type: action
      class: null
      source: "app/services/payment_service.rb:23"
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]
    default: null
    depends_on: null
    when_parent: null
    level: 1

  # Level 2 - payment method (only when authenticated)
  - name: payment_method
    type: enum
    setup:
      type: factory
      class: Payment
      source: "app/services/payment_service.rb:30-38"
    states: [card, paypal, bank_transfer]
    terminal_states: []
    default: null
    depends_on: authenticated
    when_parent: [authenticated]
    level: 2

  # Level 3 - card validity (only when card payment)
  - name: card_valid
    type: binary
    setup:
      type: factory
      class: Card
      source: "app/services/payment_service.rb:42"
    states: [valid, expired]
    terminal_states: [expired]
    default: null
    depends_on: payment_method
    when_parent: [card]
    level: 3

  # Level 3 - balance (when card payment)
  - name: balance_sufficient
    type: binary
    setup:
      type: factory
      class: Account
      source: "app/services/payment_service.rb:45"
    states: [sufficient, insufficient]
    terminal_states: [insufficient]
    default: null
    depends_on: payment_method
    when_parent: [card]
    level: 3

factories_detected:
  user:
    file: spec/factories/users.rb
    traits: [authenticated, blocked, premium]
  payment:
    file: spec/factories/payments.rb
    traits: [with_card, with_paypal]
  card:
    file: spec/factories/cards.rb
    traits: [expired, valid]

automation:
  analyzer_completed: true
  analyzer_version: '1.0'
  factories_detected: true
  validation_passed: true
  architect_completed: true
  architect_version: '1.0'
  factory_completed: true
  factory_version: '1.0'
  factory_skipped: false
  implementer_completed: true
  implementer_version: '1.0'
  polisher_completed: true
  polisher_version: '1.0'
  linter: 'rubocop'
  errors: []
  warnings:
    - "Factory trait :with_bank_transfer missing, consider adding"
    - "rubocop: 1 offense auto-corrected"
```

---

### Example 3: Edge Case - Single Characteristic

```yaml
# metadata_app_models_user.yml

analyzer:
  completed: true
  timestamp: '2025-11-07T10:40:15Z'
  source_file_mtime: 1699352415
  version: '1.0'

validation:
  completed: true
  errors: []
  warnings:
    - "Only one characteristic found. Consider if method has more edge cases."

test_level: unit

target:
  class: User
  method: full_name
  method_type: instance
  file: app/models/user.rb
  uses_models: true

characteristics:
  - name: middle_name_present
    type: binary
    setup:
      type: factory
      class: User
      source: "app/models/user.rb:45"
    states: [present, absent]
    terminal_states: []
    default: absent
    depends_on: null
    when_parent: null
    level: 1

factories_detected:
  user:
    file: spec/factories/users.rb
    traits: [with_middle_name]

automation:
  analyzer_completed: true
  analyzer_version: '1.0'
  factories_detected: true
  validation_passed: true
```

---

### Example 4: Invalid Metadata (Validation Errors)

```yaml
# metadata_app_services_broken.yml

analyzer:
  completed: true
  timestamp: '2025-11-07T10:45:00Z'
  source_file_mtime: 1699352700
  version: '1.0'

validation:
  completed: false
  errors:
    - "Missing required field: target.class"
    - "Characteristic 'payment_method' depends_on 'user_auth' but 'user_auth' not found"
    - "Circular dependency detected: A → B → A"
  warnings: []

test_level: unit

target:
  # Missing 'class' field!
  method: calculate
  method_type: instance
  file: app/services/calculator.rb

characteristics:
  - name: payment_method
    type: enum
    setup:
      type: factory
      class: Payment
      source: "app/services/calculator.rb:34-40"
    states: [card, paypal]
    terminal_states: []
    default: null
    depends_on: user_auth          # ERROR: 'user_auth' not defined!
    when_parent: [authenticated]   # ERROR: parent doesn't exist!
    level: 2

factories_detected: {}

automation:
  analyzer_completed: true
  validation_passed: false
```

**This metadata is INVALID and MUST NOT be used by subsequent agents.**

## Usage by Agents

### rspec-analyzer (Writer)

**Writes:**
- `analyzer.*`
- `test_level`
- `target.*`
- `characteristics[]`
- `factories_detected` (via factory_detector.rb)
- `automation.analyzer_completed`

**Reads:**
- Nothing (first in pipeline)

**Cache check:**
```ruby
# Check if metadata exists and source hasn't changed
if metadata_exists? && metadata['analyzer']['source_file_mtime'] == File.mtime(source_file).to_i
  # Use cached metadata, skip analysis
else
  # Run analysis, write new metadata
end
```

---

### metadata_validator.rb (Validator)

**Writes:**
- `validation.*`

**Reads:**
- Entire metadata structure

**Validates:**
- All required fields present
- Field types correct
- No circular dependencies
- level values match dependency depth

---

### rspec-architect (Reader + Updater)

**Writes:**
- `automation.architect_completed`
- `automation.architect_version`

**Reads:**
- `characteristics[]` (to understand structure)
- `target.*` (to analyze source code)
- `factories_detected` (informational)

**Uses metadata to:**
- Understand characteristic hierarchy
- Determine happy path vs corner cases
- Apply language rules (when/with/and/but)

---

### rspec-factory (Reader + Updater + Writer)

**Writes:**
- `automation.factory_completed`
- `automation.factory_version`
- `automation.factory_skipped` (boolean: true if no factory setup types)
- `automation.factory_skip_reason` (string: reason when skipped=true)
- Factory files (`spec/factories/*.rb`)

**Reads:**
- `characteristics[]` (identifies setup.type = factory)
- `target.*` (to analyze source code)
- `test_level` (determines build_stubbed vs create)
- `factories_detected` (to use existing traits)

**Uses metadata to:**
- Create FactoryBot factories for ActiveRecord models (setup.type = factory)
- Fill {SETUP_CODE} placeholders for factory-based characteristics
- Apply Decision Trees (Semantic → Bundling → 5-File Rule → Simplicity Default)
- Optimize factory calls (create → build_stubbed for unit tests)

**Skip conditions:**
- No characteristics with `setup.type = factory`
- Project doesn't use FactoryBot

---

### rspec-implementer (Reader + Updater)

**Writes:**
- `automation.implementer_completed`
- `automation.implementer_version`

**Reads:**
- `test_level` (determines build_stubbed vs create)
- `target.*` (to analyze source code)
- `characteristics[]` (to understand required setup, processes setup.type = data|action)
- `factories_detected` (to use existing traits)
- `automation.factory_completed` (warning if false and factory setup types present)

**Uses metadata to:**
- Fill {SETUP_CODE} placeholders for PORO/hashes/service objects (setup.type = data)
- Fill {SETUP_CODE} placeholders for action-based setup (setup.type = action)
- Handle composite characteristics
- Fill {EXPECTATION} placeholders
- Coordinate with factory agent via setup.type

---

### rspec-reviewer (Reader ONLY)

**Writes:**
- NOTHING (read-only agent)

**Reads:**
- Entire metadata (for context in review report)

**Uses metadata to:**
- Include context in review report
- Check if characteristics properly tested

---

### rspec-polisher (Updater)

**Writes:**
- `automation.polisher_completed`
- `automation.polisher_version`
- `automation.linter` (string or null: 'rubocop', 'standardrb', or null)
- `automation.warnings[]` (if linter issues found)

**Reads:**
- Nothing from metadata (works purely on spec file)

**Uses metadata to:**
- Mark polishing completion
- Document which linter was used
- Record auto-correction warnings

**Note:** Polisher runs external tools (ruby -c, rubocop/standardrb, rspec) and doesn't need to read metadata. It operates directly on the spec file.

## Common Mistakes to Avoid

### ❌ Mixing characteristics with factory information

```yaml
# BAD - don't add factory info to characteristics
characteristics:
  - name: user_type
    type: enum
    states: [regular, premium]
    existing_trait: :premium         # NO! Wrong place
```

**Fix:** Use `factories_detected` section

---

### ❌ Forgetting to update source_file_mtime

```yaml
# BAD - stale mtime means cache always invalid
analyzer:
  completed: true
  source_file_mtime: 0               # NO! Must be actual mtime
```

**Fix:** Always set to `File.mtime(source_file).to_i`

---

### ❌ Invalid dependency without when_parent

```yaml
# BAD - depends_on without when_parent
characteristics:
  - name: card_valid
    depends_on: payment_method       # Has dependency
    when_parent: null                # NO! Must specify when_parent
```

**Fix:** Always set `when_parent` when `depends_on` is not null

---

### ❌ Level doesn't match dependency depth

```yaml
# BAD - level inconsistent with dependency
characteristics:
  - name: root_char
    depends_on: null
    level: 1                         # OK

  - name: child_char
    depends_on: root_char
    level: 5                         # NO! Should be 2
```

**Fix:** Level = dependency depth (root=1, child of root=2, etc.)

## Versioning

**Current version:** 2.0

**Version history:**
- 1.0: Initial format
- 1.1: Added `factories_detected` section
- 1.2: Added `automation` section
- 1.3: Added `validation` section and `source_file_mtime`
- 2.0: **BREAKING CHANGE** - Changed `setup` from string to object with `type`, `class`, `source` fields; added `automation.factory_completed` flag; smart characteristic naming (removed model prefix for single-domain cases)

**Future compatibility:**
- `analyzer.version` field allows format evolution
- Validators should check version and handle accordingly

## Related Specifications

- **exit-codes.spec.md** - How validators report errors
- **agent-communication.spec.md** - How agents coordinate using metadata
- **ruby-scripts/metadata-helper.spec.md** - Path management for metadata files
- **ruby-scripts/metadata-validator.spec.md** - Validation rules implementation

---

**Key Takeaway:** Metadata is the communication backbone. Keep it valid, keep it consistent.
