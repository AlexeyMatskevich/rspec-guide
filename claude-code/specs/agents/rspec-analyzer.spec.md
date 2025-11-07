# rspec-analyzer Agent Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Subagent
**Location:** `.claude/agents/rspec-analyzer.md`

## ⚠️ IMPORTANT: This is a Claude AI Subagent

**What this means:**
- ✅ You are a Claude AI agent analyzing Ruby code directly
- ✅ You read source files using the Read tool
- ✅ You understand Ruby syntax and conditional logic natively
- ✅ You apply decision tree logic from algorithm specifications
- ❌ You do NOT need to write/execute Ruby AST parser scripts
- ❌ You do NOT use grep/sed/awk for code analysis (only for file checks)

**Bash/grep usage is ONLY for:**
- File existence checks (prerequisites)
- Running helper Ruby scripts (factory_detector.rb, metadata_validator.rb)
- Cache validation (metadata_helper.rb)

**Code analysis is done by:**
- Reading source file with Read tool
- Understanding Ruby code semantics
- Applying characteristic-extraction algorithm logic mentally

---

## Philosophy / Why This Agent Exists

**Problem:** Writing good RSpec tests requires understanding code structure, identifying characteristics, and determining test levels - tasks that are tedious and error-prone when done manually.

**Solution:** rspec-analyzer automates the analysis phase by examining source code to extract:
- Characteristics (what varies in method behavior)
- Dependencies between characteristics
- Test level (unit/integration/request)
- Factory information (what exists)

**Key Principle:** Characteristics come ONLY from code analysis, NOT from factory structure. Factories are informational only.

**Value:**
- Saves 5-10 minutes of manual analysis
- Ensures no characteristics missed
- Provides structured data for next agents
- Enables caching (skip re-analysis if source unchanged)

## Prerequisites Check

Before starting work, agent MUST verify:

### 🔴 MUST Check

```bash
# 1. Source file exists
if [ ! -f "$source_file" ]; then
  echo "Error: Source file not found: $source_file" >&2
  exit 1
fi

# 2. Source file contains specified class
if ! grep -q "class $class_name" "$source_file"; then
  echo "Error: Class $class_name not found in $source_file" >&2
  echo "Check class name spelling or file path" >&2
  exit 1
fi

# 3. Source file contains specified method
if ! grep -q "def $method_name" "$source_file"; then
  echo "Error: Method $method_name not found in $class_name" >&2
  echo "Available methods: $(grep 'def ' $source_file | sed 's/.*def //' | sed 's/(.*$//')" >&2
  exit 1
fi

# 4. Required Ruby scripts available
for script in metadata_helper.rb factory_detector.rb metadata_validator.rb; do
  if [ ! -f "lib/rspec_automation/$script" ]; then
    echo "Error: Required script not found: $script" >&2
    echo "Run: ruby claude-code/install.rb" >&2
    exit 1
  fi
done
```

### 🟡 SHOULD Check

- Git repository exists (for metadata path resolution)
- FactoryBot gem available (for factory detection)

## Input Contract

**From user (via skill invocation):**
```
Source file path: app/services/payment_service.rb
Method name: process_payment
```

**Expected format:**
- Source file: Relative or absolute path to Ruby file
- Method name: String without # or . prefix

## Output Contract

**Writes:**
1. **metadata.yml** at path determined by metadata_helper.rb
2. **Updates metadata.yml** with validation results

**metadata.yml structure:**
```yaml
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
  class: PaymentService
  method: process_payment
  method_type: instance
  file: app/services/payment_service.rb
  uses_models: true

characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    default: null
    depends_on: null
    level: 1

  - name: payment_method
    type: enum
    states: [card, paypal, bank_transfer]
    default: null
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2

factories_detected:
  user:
    file: spec/factories/users.rb
    traits: [authenticated, blocked]

automation:
  analyzer_completed: true
  analyzer_version: '1.0'
  factories_detected: true
  validation_passed: true
```

**Success markers:**
- ✅ `analyzer.completed = true`
- ✅ `validation.completed = true`
- ✅ `validation.errors = []`

## Decision Trees

### Decision Tree 1: Should I Run Analysis?

```
Source file provided?
  NO → Error: "Source file required"
  YES → Continue

Check cache validity (metadata_helper.metadata_valid?)
  VALID → ✅ Use cached metadata, SKIP analysis, exit 0
  INVALID → Continue to full analysis

Full analysis required
  → Run extraction algorithm
  → Write metadata
  → Validate
  → Exit 0 or 1
```

### Decision Tree 2: What Test Level?

```
Does method interact with database? (ActiveRecord queries, save, create, etc.)
  YES → Continue
  NO → test_level = 'unit'

Does method interact with ONLY ONE model class?
  YES → test_level = 'unit'
  NO → Continue

Does method coordinate multiple models/services?
  YES → test_level = 'integration'
  NO → test_level = 'unit'

Special cases:
  - Controller actions → test_level = 'request'
  - System features → test_level = 'e2e'
```

### Decision Tree 3: What is Characteristic Type?

```
First, check if condition uses comparison operators:

Condition contains >=, >, <=, < operators?
  YES → type = 'range'
    States: 2 business groups (sufficient/insufficient, below/above, etc.)
    Example: balance >= amount → ['sufficient', 'insufficient']
  NO → Continue to count states

Count distinct states for this characteristic:

states.length == 2:
  States look like true/false, present/absent, yes/no?
    YES → type = 'binary'
    NO → type = 'range' (business value groups)

states.length >= 3:
  States have inherent order (low→medium→high, pending→completed)?
    YES → type = 'sequential'
    NO → type = 'enum'

states.length < 2:
  ERROR: "Characteristic must have at least 2 states"
```

### Decision Tree 4: Are Characteristics Dependent?

```
Analyze code flow:

Does characteristic B only matter when characteristic A is in specific state?
  YES → B depends_on A, when_parent = specific_state
  NO → Continue

Does characteristic B appear in code block that's only executed when A is true?
  YES → B depends_on A
  NO → B is independent (depends_on = null)

Example:
if user.authenticated?          # ← Characteristic A
  case payment_method           # ← Characteristic B only matters when A=true
    when :card
      validate_card             # ← Characteristic C only matters when B=card
  end
end

Result:
  A: user_authenticated (level 1, depends_on null)
  B: payment_method (level 2, depends_on A, when_parent 'authenticated')
  C: card_valid (level 3, depends_on B, when_parent 'card')
```

### Decision Tree 5: Level Assignment Order (for Independent Characteristics)

**Problem:** When multiple characteristics are independent (not dependent on each other), they need unique consecutive levels ordered by "strength".

**Strength Hierarchy (strongest first):**
1. **Authentication layer** - user presence, session state
2. **Authorization layer** - roles, permissions, access rights
3. **Business layer** - domain-specific characteristics

**Algorithm:**
```
For each characteristic:
  1. If has depends_on → level = parent.level + 1
  2. If no depends_on (independent):
     - Assign to strength layer (auth/authz/business)
     - Within same layer: assign consecutive levels
     - Across layers: maintain hierarchy order

Result: unique levels, no gaps, ordered by strength
```

**Example 1: Independent characteristics in different layers**
```ruby
# Two characteristics both independent (no dependency between them):
# - user_authenticated: no depends_on (authentication layer)
# - feature_enabled: no depends_on (business layer)

Result:
  user_authenticated: level 1 (authentication is stronger)
  feature_enabled: level 2 (business follows authentication)
```

**Example 2: Independent characteristics in same layer**
```ruby
# Three characteristics:
# - user_authenticated: no depends_on (authentication layer) → level 1
# - user_role: depends_on user_authenticated (authorization layer) → level 2
# - feature_enabled: no depends_on, independent of user_role (business layer)
# - payment_method: depends_on feature_enabled (business layer) → level 4

# Note: user_role and feature_enabled are independent (no dependency between them)
# But user_role is authorization (stronger), feature_enabled is business (weaker)

Result:
  user_authenticated: level 1 (auth layer)
  user_role: level 2 (authz layer, depends on auth)
  feature_enabled: level 3 (business layer, independent but weaker than authz)
  payment_method: level 4 (business layer, depends on feature)
```

**Important:** If characteristics are truly in the same layer and equally strong, assign consecutive levels in any reasonable order.

## State Machine

```
[START]
  ↓
[Check Cache]
  ├─ Valid? → [Output cached path] → [END: exit 0]
  └─ Invalid? → Continue
      ↓
[Check Prerequisites]
  ├─ Fail? → [Error Message] → [END: exit 1]
  └─ Pass? → Continue
      ↓
[Read Source File]
  ↓
[Identify Method Definition]
  ↓
[Determine Test Level]
  ↓
[Extract Characteristics]
  ↓
[Determine Characteristic Types]
  ↓
[Identify Dependencies]
  ↓
[Assign Levels]
  ↓
[Run factory_detector.rb] (optional, can fail)
  ↓
[Build metadata.yml]
  ↓
[Write metadata.yml]
  ↓
[Run metadata_validator.rb]
  ├─ Validation fails? → [Error] → [END: exit 1]
  └─ Validation passes? → Continue
      ↓
[Mark analyzer.completed = true]
  ↓
[Output metadata path]
  ↓
[END: exit 0]
```

## Algorithm

### Step-by-Step Process

**Step 1: Cache Check**

```bash
source_file="app/services/payment_service.rb"

# Use metadata_helper to check cache
if ruby -r lib/rspec_automation/metadata_helper -e "
  exit 0 if RSpecAutomation::MetadataHelper.metadata_valid?('$source_file')
  exit 1
"; then
  metadata_path=$(ruby -r lib/rspec_automation/metadata_helper -e "
    puts RSpecAutomation::MetadataHelper.metadata_path_for('$source_file')
  ")

  echo "✅ Using cached metadata: $metadata_path"
  echo "$metadata_path"
  exit 0
fi

echo "⚙️ Running analysis (cache invalid or missing)"
```

**Step 2: Prerequisites Check**

(See "Prerequisites Check" section above)

**Step 3: Read and Parse Source Code**

**As a Claude AI agent, you will:**

1. **Use Read tool** to read the entire source file

2. **Locate target class:**
   - Scan for class definition line(s)
   - Identify the class name (e.g., `class PaymentService`)
   - Understand class hierarchy if present (`class Child < Parent`)

3. **Locate target method:**
   - Find the method definition within the class
   - Identify method type: instance method (`def method_name`) vs class method (`def self.method_name`)
   - Extract method parameters

4. **Understand method body:**
   - Read the entire method implementation
   - Identify all conditional logic (if/unless/case/when)
   - Note method calls, variable assignments, return values

**You understand Ruby syntax natively** - you don't need to write parser code, just read and comprehend the structure.

**Step 4: Determine Test Level**

**As a Claude AI agent, analyze method behavior and determine test level:**

**Request level** if method:
- Contains controller action patterns: `render`, `redirect_to`, `head`
- Accesses request data: `params[...]`, `session[...]`, `cookies[...]`
- Class name ends with "Controller"

**Integration level** if method:
- Interacts with 2+ ActiveRecord models (`.create`, `.save`, `.find`, `.where`)
- Coordinates multiple services (multiple `SomeService.new` or `.call`)
- Uses database transactions

**Unit level** (default) if method:
- Single class in isolation
- Pure logic without external dependencies
- Simple calculations or transformations

**Decision tree** (from spec):
```
Contains render/redirect/params? → request
Contains multiple .create/.save or 2+ models? → integration
Otherwise → unit
```

You understand Ruby semantics - apply this logic to the method you're analyzing.

**Step 5: Extract Characteristics**

**This is the CORE analysis step.** As a Claude AI agent, you will analyze the method code and extract characteristics.

**Read** `algorithms/characteristic-extraction.md` for full detailed logic.

**Your task:**

1. **Identify all conditional branches** in the method:
   - `if`/`elsif`/`unless`/`else` statements
   - `case`/`when` statements
   - Ternary operators (`condition ? true_value : false_value`)
   - Boolean operators in conditions (`&&`, `||`)

2. **For each condition, extract the characteristic:**
   - **Name**: What varies? (e.g., `user_authenticated`, `payment_method`)
   - **Type**: binary/enum/range/sequential (see algorithm spec for rules)
   - **States**: What are the possible values? (domain-meaningful names)
   - **Source**: Code location reference (e.g., `"app/services/payment_service.rb:45"` or `"app/services/payment_service.rb:52-58"`)
   - **Dependencies**: Is this nested inside another condition?

3. **Example thinking process:**

   **Code you see (Read tool output with line numbers):**
   ```ruby
   45→  if user.authenticated?
   46→    # ... do something
   47→  else
   48→    # ... do something else
   49→  end
   ```

   **Your analysis:**
   - Condition: `user.authenticated?`
   - Characteristic name: `user_authenticated`
   - Type: `binary` (true/false nature)
   - States: `[authenticated, not_authenticated]`
   - Source: `"app/services/payment_service.rb:45"` (single line for simple if)
   - Level: 1 (not nested)

   **Code you see:**
   ```ruby
   52→  case payment_method
   53→  when :card
   54→  when :paypal
   55→  when :bank_transfer
   56→  end
   ```

   **Your analysis:**
   - Condition: `case payment_method`
   - Characteristic name: `payment_method`
   - Type: `enum` (3+ discrete options)
   - States: `[card, paypal, bank_transfer]`
   - Source: `"app/services/payment_service.rb:52-56"` (multi-line case block)
   - Level: depends on nesting

   **Code you see:**
   ```ruby
   78→  if balance >= amount
   ```

   **Your analysis:**
   - Condition: `balance >= amount`
   - Characteristic name: `balance`
   - Type: `range` (comparison operator)
   - States: `[sufficient, insufficient]` (business-meaningful names, not numbers)
   - Source: `"app/services/payment_service.rb:78"` (single line)
   - Level: depends on nesting

**You understand Ruby code structure natively** - apply the algorithm logic from the spec to extract all characteristics systematically.

**Step 6: Determine Characteristic Types**

(See Decision Tree 3 above)

**Step 7: Identify Dependencies**

```
Analyze code structure:

1. Build AST of conditional nesting
2. Identify parent-child relationships
3. Record when_parent states

Example:

if user.authenticated?              # Level 1
  case payment_method               # Level 2, parent = user_authenticated
    when :card
      if card.valid?                # Level 3, parent = payment_method, when :card
        # ...
      end
  end
end

Result:
characteristics:
  - name: user_authenticated
    source: "app/services/payment_service.rb:517"
    depends_on: null
    level: 1

  - name: payment_method
    source: "app/services/payment_service.rb:518-522"
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2

  - name: card_valid
    source: "app/services/payment_service.rb:520"
    depends_on: payment_method
    when_parent: card
    level: 3
```

**Level Assignment Algorithm:**

When assigning levels to characteristics:

1. **For dependent characteristics:** `level = parent.level + 1`
   - Direct nesting in code → direct dependency in levels
   - Example: if `payment_method` depends on `user_authenticated` (level 1), then `payment_method` gets level 2

2. **For independent characteristics** (no `depends_on`):
   - **Identify strength layer:**
     - Authentication (user presence, session) → strongest
     - Authorization (roles, permissions) → middle
     - Business logic (domain characteristics) → weakest
   - **Assign consecutive levels** ordered by strength
   - Example: if `user_authenticated` (auth) and `feature_enabled` (business) are both independent, assign levels 1 and 2 (auth first)

3. **Result validation:**
   - Each characteristic has unique level (no duplicates)
   - Levels are sequential without gaps (1,2,3 not 1,3,5)
   - Independent characteristics at consecutive levels, ordered by strength

**Example with mixed dependencies:**
```ruby
# Characteristics:
# - user_authenticated: no depends_on (authentication layer)
# - user_role: depends_on user_authenticated (authorization layer)
# - feature_enabled: no depends_on (business layer, independent of role)
# - payment_method: depends_on feature_enabled (business layer)

# Assignment:
user_authenticated: level 1 (auth, root)
user_role: level 2 (depends on user_authenticated → parent.level + 1)
feature_enabled: level 3 (business, independent but comes after authz layer)
payment_method: level 4 (depends on feature_enabled → parent.level + 1)

# Note: user_role and feature_enabled are independent of each other,
# but user_role is stronger (authorization), so it gets lower level
```

**Step 7b: Identify Terminal States**

For each characteristic, determine which states are **terminal** (should not have child contexts).

**Detection heuristics:**

1. **Early return/raise in code:**
   ```ruby
   return unauthorized_error unless user.authenticated?
   # → user_authenticated: terminal_states: [not_authenticated]

   raise InsufficientFunds if balance < amount
   # → balance: terminal_states: [insufficient]
   ```

2. **Negative prefixes:**
   - `not_`, `no_`, `invalid_`, `missing_`, `without_` → likely terminal
   - Example: `not_authenticated`, `invalid_input`, `missing_card`

3. **Blocking keywords:**
   - `guest`, `none`, `disabled`, `blocked`, `denied`, `rejected` → likely terminal
   - Example: enum [admin, customer, guest] → terminal: guest

4. **Final states (sequential):**
   - `completed`, `finished`, `cancelled`, `failed`, `closed` → terminal
   - Example: [pending, processing, completed] → terminal: completed

5. **Insufficient/exceeds (range):**
   - `insufficient`, `exceeds_`, `below_`, `above_` → likely terminal
   - Example: [sufficient, insufficient] → terminal: insufficient

**Algorithm:**

```ruby
def identify_terminal_states(characteristic)
  terminals = []

  characteristic.states.each do |state|
    # Check code flow for this state
    state_code = find_code_for_state(characteristic, state)

    # Pattern 1: Early return/raise
    if state_code.match?(/\b(return|raise)\b.*error/i)
      terminals << state
      next
    end

    # Pattern 2: Heuristics by name
    terminal_keywords = %w[
      not_ no_ invalid_ missing_ without_
      guest none disabled blocked denied rejected
      completed finished cancelled failed closed
      insufficient exceeds_ below_ above_
    ]

    if terminal_keywords.any? { |kw| state.include?(kw) }
      terminals << state
    end
  end

  characteristic.terminal_states = terminals
end
```

**Output in metadata:**
```yaml
characteristics:
  - name: user_authenticated
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]  # ← Auto-detected

  - name: payment_method
    depends_on: user_authenticated
    when_parent: [authenticated]  # Array format
```

**Note:** These are suggestions for human review. Agent should mark likely terminals, user confirms during metadata review.

**Step 8: Run Factory Detector**

```bash
# Optional step - failure is OK
factory_data=$(ruby lib/rspec_automation/extractors/factory_detector.rb 2>/tmp/factory_err)
exit_code=$?

case $exit_code in
  0|2)
    echo "✅ Factories detected (or warnings)"
    # Add to metadata
    ;;
  1)
    echo "⚠️ Factory detection failed, continuing without factory data"
    factory_data="{}"
    ;;
esac
```

**Step 9: Build metadata.yml**

```yaml
# Construct YAML structure
analyzer:
  completed: true
  timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
  source_file_mtime: $(stat -c %Y "$source_file")
  version: '1.0'

test_level: #{determined_level}

target:
  class: #{class_name}
  method: #{method_name}
  method_type: #{instance_or_class}
  file: #{source_file}
  uses_models: #{true if integration/request}

characteristics: #{extracted_characteristics}

factories_detected: #{factory_data}

automation:
  analyzer_completed: true
  analyzer_version: '1.0'
  factories_detected: #{true if factory_data not empty}
  validation_passed: false  # Will be set by validator
```

**Step 10: Write and Validate**

```bash
# Get metadata path
metadata_path=$(ruby -r lib/rspec_automation/metadata_helper -e "
  puts RSpecAutomation::MetadataHelper.metadata_path_for('$source_file')
")

# Write metadata
echo "$metadata_yaml" > "$metadata_path"

# Validate
if ! ruby lib/rspec_automation/validators/metadata_validator.rb "$metadata_path" 2>&1; then
  echo "❌ Generated metadata is invalid (this is a bug in analyzer)" >&2
  exit 1
fi

# Update validation section
# ... (mark validation.completed = true, validation.errors = [])

echo "✅ Analysis complete: $metadata_path"
echo "$metadata_path"
exit 0
```

## Error Handling (Fail Fast)

### Error 1: Source File Not Found

```bash
echo "Error: Source file not found: $source_file" >&2
echo "" >&2
echo "Check that file path is correct:" >&2
echo "  ls -la $(dirname $source_file)" >&2
exit 1
```

### Error 2: Method Not Found in Class

```bash
echo "Error: Method $method_name not found in class $class_name" >&2
echo "" >&2
echo "Available methods in $class_name:" >&2
grep "def " "$source_file" | sed 's/^[[:space:]]*/  /' >&2
exit 1
```

### Error 3: Cannot Determine Characteristics

```bash
echo "Error: Cannot extract characteristics from method $method_name" >&2
echo "" >&2
echo "Method appears to have no conditional logic (no if/case statements)" >&2
echo "This usually means:" >&2
echo "  1. Method is too simple (returns constant or single calculation)" >&2
echo "  2. Method delegates to other methods (test those instead)" >&2
echo "  3. Analyzer needs improvement (report issue)" >&2
exit 1
```

### Error 4: Generated Metadata Invalid

```bash
echo "❌ Generated metadata failed validation" >&2
echo "" >&2
echo "This is a bug in rspec-analyzer. Validation errors:" >&2
cat /tmp/validation_errors >&2
echo "" >&2
echo "Please report this issue with the source file and method name" >&2
exit 1
```

### Error 5: Too Complex (7+ Nesting Levels)

```bash
echo "Error: Method $method_name has 7+ nesting levels" >&2
echo "" >&2
echo "This indicates a code smell: method does too many things" >&2
echo "Consider refactoring using 'Do One Thing' principle:" >&2
echo "  - Extract nested conditions to separate methods" >&2
echo "  - Use polymorphism instead of case statements" >&2
echo "  - Split into multiple single-purpose methods" >&2
echo "" >&2
echo "Analyzer cannot generate good tests for overly complex methods" >&2
exit 1
```

## Dependencies

**Must run before:**
- (nothing - first in pipeline)

**Must run after:**
- (nothing - first in pipeline)

**Ruby scripts used:**
- metadata_helper.rb (cache check, path resolution)
- factory_detector.rb (optional factory information)
- metadata_validator.rb (validation)

**External dependencies:**
- Ruby (for script execution)
- Source code file (to analyze)

## Examples

### Example 1: Simple Unit Test

**Input:**
```
Source: app/services/discount_calculator.rb
Method: calculate
```

**Source code:**
```ruby
class DiscountCalculator
  def calculate(customer_type)
    case customer_type
    when :regular
      0.0
    when :premium
      0.1
    when :vip
      0.2
    end
  end
end
```

**Process:**
1. Cache check: no cache → run analysis
2. Test level: no database operations → unit
3. Extract characteristics:
   - Found case statement on `customer_type`
   - States: [regular, premium, vip]
   - Type: enum (3+ discrete states)
4. No dependencies (single characteristic)
5. Factory detection: no models → empty
6. Write metadata
7. Validate → pass

**Output:** `tmp/rspec_claude_metadata/metadata_app_services_discount_calculator.yml`

**Exit code:** 0

---

### Example 2: Integration Test with Dependencies

**Input:**
```
Source: app/services/payment_service.rb
Method: process_payment
```

**Source code:**
```ruby
class PaymentService
  def process_payment(user, amount)
    unless user.authenticated?
      raise AuthenticationError
    end

    case user.payment_method
    when :card
      if user.balance >= amount
        charge_card(user, amount)
      else
        raise InsufficientFundsError
      end
    when :paypal
      charge_paypal(user, amount)
    end
  end
end
```

**Process:**
1. Cache check: cached but source modified → run analysis
2. Test level: calls `charge_card` (likely database) → integration
3. Extract characteristics:
   - Characteristic 1: user_authenticated (from `unless user.authenticated?`)
     - Type: binary
     - States: [authenticated, not_authenticated]
     - Level: 1
   - Characteristic 2: payment_method (from `case user.payment_method`)
     - Type: enum
     - States: [card, paypal]
     - Depends on: user_authenticated (only when authenticated)
     - Level: 2
   - Characteristic 3: balance_sufficient (from `if user.balance >= amount`)
     - Type: binary
     - States: [sufficient, insufficient]
     - Depends on: payment_method (only when card)
     - Level: 3
4. Factory detection: User model → find factories
5. Write metadata
6. Validate → pass

**Output:** metadata with 3 characteristics, 3 levels

**Exit code:** 0

---

### Example 3: Method Too Simple

**Input:**
```
Source: app/models/user.rb
Method: full_name
```

**Source code:**
```ruby
class User < ApplicationRecord
  def full_name
    "#{first_name} #{last_name}"
  end
end
```

**Process:**
1. Cache check: no cache
2. Test level: no conditionals → unit
3. Extract characteristics:
   - No if/case statements found
   - Cannot extract characteristics

**Output:** (none)

**stderr:**
```
Error: Cannot extract characteristics from method full_name

Method appears to have no conditional logic
This usually means method is too simple (returns calculation)

Consider:
  1. Test method is not worth testing (trivial calculation)
  2. Test at integration level if behavior important
```

**Exit code:** 1

---

### Example 4: Using Cached Metadata

**Input:**
```
Source: app/services/payment_service.rb (unchanged)
Method: process_payment
```

**Process:**
1. Cache check:
   - metadata.yml exists
   - analyzer.completed = true
   - validation.completed = true
   - source_file_mtime matches
   - → Cache VALID
2. Output cached path, exit 0

**Output:**
```
✅ Using cached metadata: tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml
```

**Exit code:** 0

**Time saved:** ~10 seconds (no analysis needed)

## Integration with Skills

### From rspec-write-new skill

```markdown
1. Invoke rspec-analyzer with source file and method
2. Wait for completion
3. Check exit code:
   - 0: Success, metadata written, continue to architect
   - 1: Error, show user error message, STOP
4. If success, invoke spec_skeleton_generator
5. Continue to rspec-architect
```

### From rspec-update-diff skill

```markdown
1. Get list of changed files from git diff
2. For each changed file:
   a. Determine which methods changed
   b. Invoke rspec-analyzer for each method
   c. If cached and valid, skip analysis
3. Continue with architect for changed methods
```

### From rspec-refactor-legacy skill

```markdown
1. User provides existing spec file
2. Extract source file and method from spec
3. Invoke rspec-analyzer (audit mode)
4. Compare extracted characteristics vs existing test structure
5. Identify gaps or issues
6. Continue with restructuring
```

## Testing Criteria

**Agent is correct if:**
- ✅ Generates valid metadata (passes validation)
- ✅ Extracts all characteristics (no false negatives)
- ✅ Correctly identifies dependencies
- ✅ Assigns correct levels
- ✅ Determines appropriate test level
- ✅ Uses cache when valid
- ✅ Fails fast with clear errors

**Common issues to test:**
- Source file doesn't exist
- Method not found in file
- Method has no characteristics (too simple)
- Method has circular conditions (unusual but possible)
- Very deep nesting (7+ levels)
- Factory detection fails (should continue)

## Related Specifications

- **contracts/metadata-format.spec.md** - Output format
- **contracts/agent-communication.spec.md** - How metadata passed to next agent
- **ruby-scripts/metadata-helper.spec.md** - Cache checking
- **ruby-scripts/factory-detector.spec.md** - Factory information
- **ruby-scripts/metadata-validator.spec.md** - Validation
- **algorithms/characteristic-extraction.md** - Detailed extraction algorithm
- **agents/rspec-architect.spec.md** - Next agent in pipeline

---

**Key Takeaway:** Analyzer is foundation. Must be thorough (find all characteristics) and accurate (correct dependencies). Cache validation saves time.
