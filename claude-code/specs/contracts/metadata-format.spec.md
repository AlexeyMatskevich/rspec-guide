# Metadata Format Specification

**Version:** 1.3
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
  uses_models: true                         # Hint for factory-optimizer (optional)
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
    default: null                           # Default state (null = no default)
    depends_on: null                        # Parent characteristic name (null = independent)
    when_parent: null                       # Required parent state for dependency
    level: 1                                # Nesting level (1 = root)
```

**Characteristic types:**

1. **`binary`**: Two states (present/absent, true/false, authenticated/not_authenticated)
   ```yaml
   - name: user_authenticated
     type: binary
     states: [authenticated, not_authenticated]
     default: null
     depends_on: null
     level: 1
   ```

2. **`enum`**: Multiple discrete states (3+)
   ```yaml
   - name: payment_method
     type: enum
     states: [card, paypal, bank_transfer, crypto]
     default: card
     depends_on: null
     level: 1
   ```

3. **`range`**: Business value groups from comparison operators (2+ states)
   ```yaml
   # Range with 2 states (most common):
   - name: balance
     type: range
     states: [sufficient, insufficient]  # balance >= amount
     default: null
     depends_on: null
     level: 1

   # Range with 3+ states (age groups, price tiers):
   - name: age
     type: range
     states: [child, adult, senior]  # age < 18 / age < 65
     default: null
     depends_on: null
     level: 1
   ```

4. **`sequential`**: States that must be in specific order
   ```yaml
   - name: order_status
     type: sequential
     states: [pending, processing, shipped, delivered]
     default: pending
     depends_on: null
     level: 1
   ```

**Required fields per characteristic:**
- 🔴 `name` (string): Unique identifier within this metadata
- 🔴 `type` (string): One of: `binary`, `enum`, `range`, `sequential`
- 🔴 `states` (array): Array of state names (2+ elements)
- 🔴 `default` (string or null): Default state or null
- 🔴 `depends_on` (string or null): Parent characteristic name or null
- 🟡 `when_parent` (string or null): Required if `depends_on` is not null
- 🔴 `level` (integer): Nesting level (1 = root, 2+ = nested)

**Validation rules:**
- `name` MUST be unique within `characteristics` array
- `type` MUST be one of: `binary`, `enum`, `range`, `sequential`
- `states` MUST have at least 2 elements
- `states` elements MUST be strings
- `default` if not null MUST be in `states`
- `depends_on` if not null MUST reference existing characteristic name
- `when_parent` MUST be null if `depends_on` is null
- `when_parent` MUST be in parent's `states` if `depends_on` is not null
- `level` MUST be integer >= 1
- No circular dependencies allowed
- `level` MUST match dependency depth (root = 1, child of root = 2, etc.)

**Dependency example:**
```yaml
characteristics:
  - name: user_authenticated           # Level 1 (root)
    type: binary
    states: [authenticated, not_authenticated]
    default: null
    depends_on: null
    level: 1

  - name: payment_method                # Level 2 (depends on authenticated)
    type: enum
    states: [card, paypal]
    default: null
    depends_on: user_authenticated      # Only relevant when user authenticated
    when_parent: authenticated          # Only when parent is in this state
    level: 2

  - name: card_valid                    # Level 3 (depends on payment_method)
    type: binary
    states: [valid, expired]
    default: null
    depends_on: payment_method
    when_parent: card                   # Only when using card payment
    level: 3
```

---

### Section: `factories_detected`

**Written by:** factory_detector.rb (invoked by rspec-analyzer)
**Purpose:** Information about existing FactoryBot factories and traits

**IMPORTANT:** This section does NOT influence characteristic extraction. It's purely informational for implementer and factory-optimizer agents.

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

  # Written by implementer
  implementer_completed: false             # Still in progress

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

**Common fields:**
- `{agent}_completed` (boolean): Marks agent completion
- `{agent}_version` (string): Agent version for compatibility
- `linter` (string or null): Detected linter tool (written by polisher)
- `errors` (array): Critical errors encountered
- `warnings` (array): Non-critical issues

**Validation rules:**
- 🟡 This section is flexible and can contain agent-specific fields
- `errors` and `warnings` SHOULD be arrays if present

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
    states: [regular, premium, vip]
    default: null
    depends_on: null
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
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    default: null
    depends_on: null
    level: 1

  # Level 2 - payment method (only when authenticated)
  - name: payment_method
    type: enum
    states: [card, paypal, bank_transfer]
    default: null
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2

  # Level 3 - card validity (only when card payment)
  - name: card_valid
    type: binary
    states: [valid, expired]
    default: null
    depends_on: payment_method
    when_parent: card
    level: 3

  # Level 3 - balance (when card payment)
  - name: balance_sufficient
    type: binary
    states: [sufficient, insufficient]
    default: null
    depends_on: payment_method
    when_parent: card
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
  errors: []
  warnings:
    - "Factory trait :with_card found but :with_bank_transfer missing"
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
    states: [present, absent]
    default: absent
    depends_on: null
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
    states: [card, paypal]
    default: null
    depends_on: user_auth          # ERROR: 'user_auth' not defined!
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

**Reads:**
- `characteristics[]` (to understand structure)
- `target.*` (to analyze source code)
- `factories_detected` (informational)

**Uses metadata to:**
- Understand characteristic hierarchy
- Determine happy path vs corner cases
- Apply language rules (when/with/and/but)

---

### rspec-implementer (Reader + Updater)

**Writes:**
- `automation.implementer_completed`

**Reads:**
- `test_level` (determines build_stubbed vs create)
- `target.*` (to analyze source code)
- `characteristics[]` (to understand required setup)
- `factories_detected` (to use existing traits)

**Uses metadata to:**
- Generate appropriate let blocks
- Choose factory methods
- Determine what to expect (behavior)

---

### rspec-factory-optimizer (Reader + Updater)

**Writes:**
- `automation.factory_optimizer_completed`
- `automation.warnings[]` (if traits missing)

**Reads:**
- `characteristics[]` (what traits should exist)
- `factories_detected` (what traits do exist)
- `test_level` (optimization strategy)

**Uses metadata to:**
- Compare characteristics vs traits
- Suggest missing traits
- Optimize build_stubbed vs create

---

### rspec-reviewer (Reader ONLY)

**Writes:**
- NOTHING (read-only agent)

**Reads:**
- Entire metadata (for context in review report)

**Uses metadata to:**
- Include context in review report
- Check if characteristics properly tested

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

**Current version:** 1.3

**Version history:**
- 1.0: Initial format
- 1.1: Added `factories_detected` section
- 1.2: Added `automation` section
- 1.3: Added `validation` section and `source_file_mtime`

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
