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
    setup: action
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]
    source: "app/services/payment_service.rb:23"
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: payment_method
    type: enum
    setup: data
    states: [card, paypal, bank_transfer]
    terminal_states: []
    source: "app/services/payment_service.rb:30-38"
    default: null
    depends_on: user_authenticated
    when_parent: [authenticated]
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
  Is this a state machine with transitions (AASM, state_machines)?
    YES → type = 'sequential'
    NO → Continue checking

  Do states have clear order and dependent transitions?
    Sequential indicators:
    - Has initial/terminal states
    - Transitions follow order (cannot skip states)
    - Has transition methods (process!, ship!, deliver!)
    - Usually workflow or order status

    YES → type = 'sequential'

  Are states independent and mutually exclusive?
    Enum indicators:
    - Any transition between states is valid
    - No inherent order (roles: admin/user/guest)
    - No transition methods, just assignment
    - Usually types, categories, payment methods

    YES → type = 'enum'

  If uncertain → type = 'enum' (conservative choice)

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
  ├─ 7+ nesting levels? → [Error: Too Complex] → [END: exit 1]
  └─ OK? → Continue
      ↓
[Determine Characteristic Types]
  ↓
[Identify Dependencies]
  ↓
[Assign Levels]
  ├─ More than 6 levels assigned? → [Error: Too Complex] → [END: exit 1]
  └─ OK (≤6 levels)? → Continue
  ↓
[Check FactoryBot in Gemfile]
  ├─ Not found? → Set factories_detected: {} → Continue
  └─ Found? → [Run factory_detector.rb]
      ├─ Exit 0 (success)? → Continue
      └─ Exit 1 (error)? → [Error: Factory Detection Failed] → [END: exit 1]
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

### Characteristic Extraction Algorithm (Inlined)

**Core Principle:** A characteristic is any conditional logic that changes method behavior. Tests must cover all combinations of characteristic states.

#### Definitions

**Characteristic:** A conditional expression that determines method behavior
- Examples: `if user.admin?`, `case status`, `balance >= amount`
- Each characteristic has multiple **states** (e.g., true/false, or enum values)

**Characteristic Types:**
1. **binary:** Two states (if/unless conditions)
2. **enum:** Multiple named states (case/when, multiple elsif)
3. **range:** Continuous values with boundary conditions
4. **sequential:** Ordered progression (pending→processing→completed)

**Dependency:** When one characteristic only matters if another is in a specific state
- Example: "payment method" only matters when "user authenticated" is true

**Level:** Nesting depth in characteristic hierarchy (1 = root, 2+ = dependent)

#### High-Level Extraction Process

```
1. Read source code (using Read tool)
2. Locate target method
3. Scan method body for conditional statements
4. For each conditional:
   a. Identify what varies (characteristic name)
   b. Determine characteristic type (binary/enum/range/sequential)
   c. Extract possible states
   d. Detect dependencies (is it nested?)
   e. Calculate level (depth in hierarchy)
5. Output characteristics in YAML format
```

#### Detailed Step-by-Step Process

##### 5a. Identify Conditional Statements

**What you do:**
- Scan the method body for conditional logic
- Identify all `if`, `unless`, `elsif`, `case/when` statements
- Note boolean combinations (`&&`, `||`)
- Track nesting levels

**Types of conditionals to find:**
- **if/unless/elsif** - binary or multi-way branches
- **case/when** - enum-style switches
- **Ternary** - `condition ? value1 : value2` (usually skip - too simple)
- **Boolean operators** - `a && b`, `a || b`

**Conceptual thinking:**
```ruby
# As you read the method body, you identify patterns like:
# "if user.authenticated?" ← This is a conditional!
# "case payment_method" ← This is a conditional!
# "balance >= amount" ← This is a conditional (comparison)!
```

##### 5b. Extract Condition Expression and Source Location

**What you do:**
- Identify what's being checked in the condition
- Extract the expression as a string
- Capture line number(s) where the condition appears

**Examples of what you see and extract:**
```ruby
# Code: if user.authenticated?
# Extract expression: "user.authenticated?"
# Extract source: "app/services/payment_service.rb:45"

# Code: case status
#        when :pending
#        when :approved
#      end
# Extract expression: "status"
# Extract source: "app/services/payment_service.rb:52-55" (case line to end line)

# Code: if balance >= amount
# Extract expression: "balance >= amount"
# Extract source: "app/services/payment_service.rb:78"
```

**Source location formats:**
- **Single line:** Simple if/unless statements: `"path:N"`
- **Range:** Multi-line blocks (case, if-elsif chains): `"path:N-M"`

**How to capture line numbers:**
When using the Read tool, line numbers are shown in the output:
```
337→  unless user.authenticated?
338→    raise AuthenticationError
339→  end
```

Extract:
- Start line: 337 (where condition begins)
- End line: 339 (where block ends) - only for multi-line blocks
- Format: `"app/services/payment_service.rb:337-339"`

##### 5c. Determine Characteristic Type

**Decision logic (apply in this order):**

1. **Check for comparison operators** (`>=`, `>`, `<=`, `<`):
   - If present → type is `'range'`
   - Example: `balance >= amount` → `'range'`

2. **Check if it's a case statement**:
   - Always → type is `'enum'` or `'sequential'` (see 3a)
   - Example: `case status` → check for state machine

3. **Check if it's an if-elsif chain**:
   - Multiple elsif → type is `'enum'` or `'sequential'` (see 3a)
   - Example: `if ... elsif ... elsif` → check for ordering

3a. **Check for state machine** (for case/elsif):
   - If found `aasm` or `state_machines` block → type might be `'sequential'`
   - Check for transitions with clear order
   - If yes → type is `'sequential'`

3b. **Distinguish enum vs sequential** (for case/elsif):
   - Check for transition methods (process!, ship!, etc.)
   - If yes → type is `'sequential'`
   - Check for initial/terminal states
   - If yes → type is `'sequential'`
   - If states are independent → type is `'enum'`

4. **Simple if/unless**:
   - Just if-else → type is `'binary'`
   - Example: `if user.authenticated?` → `'binary'`

**Conceptual thinking (NOT code to execute):**
```ruby
# This shows the LOGIC you apply mentally:
if condition_contains_comparison_operator?
  type = 'range'
elsif case_statement?
  type = 'enum'
elsif has_multiple_elsif?
  type = 'enum'
else
  type = 'binary'
end
```

**Why check range first:**
- Range characteristics are identified by comparison operators
- Range typically has 2 states (sufficient/insufficient, below/above threshold)
- Without this check, `if balance >= amount` would incorrectly be classified as `'binary'`

##### 5d. Extract States

**For binary characteristics:**

```ruby
# Example logic (you apply this mentally):
# Condition: "user.authenticated?"
# States: ['authenticated', 'not_authenticated']

positive = condition_expr.gsub(/\?$/, '').split('.').last
negative = "not_#{positive}"

[positive, negative]
```

**For enum characteristics:**

```ruby
# Example: case status
#          when :pending
#          when :approved
#          when :rejected
#        end
#
# Extract states from each when clause:
# states → ['pending', 'approved', 'rejected']
```

**For range characteristics:**

```ruby
# Example logic:
# Condition: "balance >= amount"
# States: ['sufficient', 'insufficient']

if condition_expr =~ />=|>/
  ['sufficient', 'insufficient']
elsif condition_expr =~ /<=|</
  ['below_threshold', 'above_threshold']
else
  ['boundary_condition', 'normal_case']
end
```

**Extracting threshold value (for range characteristics):**

After extracting states, attempt to extract the concrete threshold value from the comparison.

**Your task (as Claude AI agent):**

Find the comparison in the code and determine:
1. Which operator is used: `>=`, `>`, `<=`, `<`
2. What is being compared to: a constant (number) or a variable

**Examples:**

Example 1: Constant found
```ruby
# Code:
if balance >= 1000
  # ...
end

# Extract:
threshold_value: 1000
threshold_operator: '>='
```

Example 2: Variable (not constant)
```ruby
# Code:
if balance >= required_amount
  # ...
end

# Extract:
threshold_value: null
threshold_operator: '>='
```

Example 3: Complex expression
```ruby
# Code:
if balance >= (minimum_balance * 1.5)
  # ...
end

# Extract:
threshold_value: null
threshold_operator: '>='
```

Example 4: Float constant
```ruby
# Code:
if percentage >= 0.5
  # ...
end

# Extract:
threshold_value: 0.5
threshold_operator: '>='
```

**IMPORTANT:** Threshold extraction is optional:
- If you found a **numeric constant** → save `threshold_value` and `threshold_operator` in metadata
- If variable, method call, or complex expression → `threshold_value: null, threshold_operator: operator`
- This allows skeleton-generator to use concrete values when possible

**What NOT to do:**
- Don't try to evaluate expressions
- Don't search for variable values elsewhere in the code
- If uncertain → `threshold_value: null`

**For sequential characteristics:**

States have inherent ordering (low→medium→high, pending→processing→completed).

##### 5e. Detect Dependencies

**What you do as Claude AI agent:**

For each characteristic you extracted, determine if it depends on another characteristic. A dependency exists when a characteristic is nested inside another conditional and only matters when the parent condition is in a specific state.

**Your task:** Analyze code structure to identify parent-child relationships between characteristics.

**Dependency exists when:**
- Characteristic is nested inside another conditional
- Characteristic only matters when parent condition is true

**How to detect:**
1. For each characteristic, look at where it appears in the code
2. Check if it's inside another conditional block (parent)
3. If yes, record the parent characteristic name and the parent state that enables this child
4. If no, mark `depends_on: null` (root level characteristic)

**Example logic (shows the thinking process - NOT code to execute):**

```ruby
# Conceptual logic:
def detect_dependency(node, all_conditionals)
  parent = find_parent_conditional(node, all_conditionals)

  if parent
    parent_condition = extract_condition(parent)
    parent_characteristic_name = condition_to_name(parent_condition)
    return parent_characteristic_name
  end

  nil  # No dependency (root characteristic)
end

# Example:
# if user.authenticated?          ← root (depends_on: nil)
#   if payment_method == :card    ← depends on 'user_authenticated'
#     ...
#   end
# end
```

**Special case - guard clauses:**
```ruby
# Guard clauses are NOT dependencies, they're separate characteristics
def process_payment(user, amount)
  raise AuthError unless user.authenticated?  # ← binary characteristic
  raise InsufficientFunds if balance < amount # ← binary characteristic

  # Main logic here
end

# Result: Two independent characteristics, NOT nested dependency
```

##### 5f. Calculate Level

**What you do as Claude AI agent:**

Assign a numeric level to each characteristic based on its position in the dependency hierarchy. Levels determine context nesting depth in the generated test file.

**Your task:** Calculate level numbers ensuring they are unique, sequential, and reflect the dependency structure.

**Calculation rules:**
1. **Root characteristics** (no `depends_on`) → level = 1
2. **Dependent characteristics** → level = parent's level + 1
3. **Independent characteristics** (multiple roots) → assign consecutive levels ordered by strength layer (auth → authz → business)
4. **Result validation:** No gaps, no duplicates, sequential ordering

**Example logic (shows the thinking process - NOT code to execute):**

```ruby
# Conceptual algorithm:
def calculate_level(characteristic_name, all_characteristics)
  char = all_characteristics.find { |c| c[:name] == characteristic_name }

  if char[:depends_on].nil?
    return 1  # Root level
  end

  parent_level = calculate_level(char[:depends_on], all_characteristics)
  parent_level + 1
end

# Example:
# user_authenticated (depends_on: nil) → level 1
# payment_method (depends_on: user_authenticated) → level 2
# currency (depends_on: payment_method) → level 3
```

##### 5g. Generate YAML Output Structure

```yaml
characteristics:
  - name: user_authenticated
    type: binary
    setup: action
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]
    source: "app/services/payment_service.rb:45"
    default: null
    depends_on: null
    when_parent: null
    level: 1
    condition_expression: user.authenticated?

  - name: payment_method
    type: enum
    setup: data
    states: [card, paypal, bank_transfer]
    terminal_states: []
    source: "app/services/payment_service.rb:52-56"
    default: null
    depends_on: user_authenticated
    when_parent: [authenticated]
    level: 2
    condition_expression: payment_method
```

#### Edge Cases in Characteristic Extraction

##### Edge Case 1: No Conditionals Found

```ruby
def simple_method(x, y)
  x + y  # No conditionals
end
```

**Action:** Warn user, generate minimal metadata with empty characteristics array
**Exit code:** 2 (warning)

##### Edge Case 2: Guard Clauses

```ruby
def process
  return if invalid?  # ← Guard clause
  return if unauthorized?  # ← Guard clause

  do_work
end
```

**Extraction:**
- Each guard clause = separate binary characteristic
- Dependencies: null (all root level)
- Level: 1 for all

**Rationale:** Guard clauses are independent preconditions, not nested conditions

##### Edge Case 3: Boolean Combinations

```ruby
if user.authenticated? && user.premium?
  # ...
end
```

**Two approaches:**

**Approach 1 (Simple):** Treat as single characteristic
```yaml
- name: user_authenticated_and_premium
  type: binary
  states: [true, false]
```

**Approach 2 (Expanded):** Split into two characteristics
```yaml
- name: user_authenticated
  type: binary
  states: [authenticated, not_authenticated]
  depends_on: null
  level: 1

- name: user_premium
  type: binary
  states: [premium, not_premium]
  depends_on: null
  level: 2
```

**Recommendation:** Use Approach 2 (expanded) for better test coverage.

**Implementation:**
```ruby
# Conceptual logic:
def expand_logical_and(node)
  # Extract both conditions as separate characteristics
  left_condition = node.children[0]
  right_condition = node.children[1]

  [
    extract_characteristic(left_condition),
    extract_characteristic(right_condition)
  ]
end
```

##### Edge Case 4: Nested Case Statements

```ruby
case user.role
when :admin
  case action
  when :read
    # ...
  when :write
    # ...
  end
when :user
  # ...
end
```

**Extraction:**
```yaml
- name: user_role
  type: enum
  states: [admin, user]
  depends_on: null
  level: 1

- name: action
  type: enum
  states: [read, write]
  depends_on: user_role
  when_parent: [admin]
  level: 2
```

##### Edge Case 5: Else Clause Without Explicit Condition

```ruby
if balance >= amount
  process
else
  reject  # ← implicit "balance < amount"
end
```

**Extraction:**
```yaml
- name: balance
  type: range
  states: [sufficient, insufficient]
  condition_expression: balance >= amount
```

**State mapping:**
- `sufficient` → if branch
- `insufficient` → else branch

##### Edge Case 6: Range with 3+ States (Age Groups)

```ruby
if age < 18
  apply_child_discount
elsif age < 65
  apply_adult_price
else
  apply_senior_discount
end
```

**Extraction:**
```yaml
- name: age
  type: range
  states: [child, adult, senior]
  condition_expression: age < 18 / age < 65
  depends_on: null
  level: 1
```

**State mapping:**
- `child` → age < 18
- `adult` → 18 <= age < 65
- `senior` → age >= 65

**Why range and not enum:**
- Source: comparison operators (`<`, not `case` statement)
- States represent **business value groups** from numeric ranges
- Formatting: "age is child" (not just "child")

#### Characteristic Naming Rules

##### Rule 1: Use Domain Language

```ruby
# Source: if user.authenticated?
# ✅ Good: user_authenticated
# ❌ Bad: condition1, auth_check
```

##### Rule 2: Avoid Verb Forms

```ruby
# Source: if can_process?
# ✅ Good: processable
# ❌ Bad: can_process
```

##### Rule 3: Handle Negations

```ruby
# Source: unless user.blocked?
# ✅ Good: user_blocked (with states: [blocked, not_blocked])
# ❌ Bad: user_not_blocked
```

##### Rule 4: Simplify Complex Expressions

```ruby
# Source: if order.total >= 100 && order.total < 1000
# ✅ Good: order_total_range
# ❌ Bad: order_total_gte_100_and_lt_1000
```

##### Rule 5: Boolean Combinations

```ruby
# Source: if user.authenticated? && user.premium?
# ✅ Good: Extract as two characteristics
#   - user_authenticated
#   - user_premium
# ❌ Bad: user_authenticated_and_premium
```

#### State Naming Rules

##### Rule 1: Use Affirmative Terms

```ruby
# Characteristic: user_authenticated
# ✅ Good: [authenticated, not_authenticated]
# ❌ Bad: [true, false]
```

##### Rule 2: Enum States Use Original Values

```ruby
# Source: case status
#          when :pending
#          when :approved
# ✅ Good: [pending, approved]
# ❌ Bad: [status_pending, status_approved]
```

##### Rule 3: Range States Use Business Terms

```ruby
# Source: if balance >= amount
# ✅ Good: [sufficient, insufficient]
# ❌ Bad: [true, false]
# ❌ Bad: [gte_amount, lt_amount]
```

#### Complete Extraction Example

**Input source code:**
```ruby
class PaymentService
  def process_payment(user, amount, payment_method)
    # Characteristic 1: user authentication (binary, root)
    unless user.authenticated?
      raise AuthenticationError
    end

    # Characteristic 2: payment method (enum, depends on authenticated)
    case payment_method
    when :card
      process_card_payment(user, amount)
    when :paypal
      process_paypal_payment(user, amount)
    when :bank_transfer
      process_bank_payment(user, amount)
    end
  end
end
```

**Output YAML:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    setup: action
    states:
      - authenticated
      - not_authenticated
    terminal_states: [not_authenticated]
    source: "app/services/payment_service.rb:4-6"
    default: null
    depends_on: null
    when_parent: null
    level: 1
    condition_expression: user.authenticated?

  - name: payment_method
    type: enum
    setup: data
    states:
      - card
      - paypal
      - bank_transfer
    terminal_states: []
    source: "app/services/payment_service.rb:9-15"
    default: null
    depends_on: user_authenticated
    when_parent: [authenticated]
    level: 2
    condition_expression: payment_method
```

#### Algorithm Correctness Criteria

**Algorithm is correct if:**
- ✅ Extracts all conditional branches
- ✅ Determines correct characteristic types
- ✅ Generates human-readable names
- ✅ Detects dependencies accurately
- ✅ Handles guard clauses as independent characteristics
- ✅ Expands boolean combinations

**Common mistakes to avoid:**
- Treating guard clauses as nested dependencies
- Ignoring elsif branches (multi-state enums)
- Using technical names instead of domain language
- Not expanding `&&` / `||` conditions

**You understand Ruby code structure natively** - apply this algorithm logic to extract all characteristics systematically.

**Step 6: Determine Characteristic Types**

(See Decision Tree 3 above)

**Step 7: Identify Dependencies**

**What you do as Claude AI agent:**

Now that you've extracted all characteristics from the method, determine which characteristics depend on others based on code nesting structure.

**Your task:**
1. Analyze the code structure you read earlier
2. Identify parent-child relationships between characteristics
3. Record `depends_on` and `when_parent` fields for each characteristic

**How to identify dependencies:**
- Look at the code nesting: if characteristic B appears inside characteristic A's conditional block, then B depends on A
- Identify which state of A enables B (e.g., B only matters when A is "authenticated")
- Record this as: `depends_on: A`, `when_parent: [state]` (always array format)

**You understand Ruby code structure natively** - just read the indentation and conditional nesting, no need to build AST programmatically.

**Example analysis:**

```ruby
if user.authenticated?              # Characteristic: user_authenticated, Level 1
  case payment_method               # Characteristic: payment_method, Level 2
    when :card                      #   (only matters when authenticated)
      if card.valid?                # Characteristic: card_valid, Level 3
        # ...                       #   (only matters when payment_method is :card)
      end
  end
end
```

**Result:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    setup: action
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]
    source: "app/services/payment_service.rb:517"
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: payment_method
    type: enum
    setup: data
    states: [card, paypal]
    terminal_states: []
    source: "app/services/payment_service.rb:518-522"
    default: null
    depends_on: user_authenticated
    when_parent: [authenticated]  # Array format
    level: 2

  - name: card_valid
    type: binary
    setup: data
    states: [valid, invalid]
    terminal_states: [invalid]
    source: "app/services/payment_service.rb:520"
    default: null
    depends_on: payment_method
    when_parent: [card]  # Array format
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

**What you do as Claude AI agent:**

For each characteristic you extracted, determine which states are **terminal** - states that should not have child contexts in the test hierarchy. Terminal states typically represent error conditions, edge cases, or final outcomes where no further branching is needed.

**Why this matters:**
- Terminal states help architect know when to stop nesting contexts
- Prevents creating meaningless test hierarchies (e.g., testing what happens after "unauthorized" error)
- Improves test readability by avoiding over-specification

**Your task:** Apply detection heuristics to identify terminal states automatically.

#### Detection Heuristics (Apply in Order)

**Heuristic 1: Code Flow Analysis (Most Reliable)**

**What you do:**
1. For each state, find the code block that executes when that state is true
2. Look for early termination patterns in that code block
3. If code raises exception or returns early, mark state as terminal

**Patterns to detect:**
```ruby
# Pattern: Early return with error
return unauthorized_error unless user.authenticated?
# → State "not_authenticated" is TERMINAL

# Pattern: Raise exception
raise InsufficientFunds if balance < amount
# → State "insufficient" is TERMINAL

# Pattern: Render error in controller
render json: { error: 'Forbidden' }, status: 403 and return
# → State that triggers this is TERMINAL

# Pattern: Guard clause (same as early return)
return unless valid?
# → State "not_valid" is TERMINAL
```

**How to apply:**
- Read the code branch for each state
- Check if it contains: `raise`, `return`, `render ... and return`
- If yes → mark state as terminal
- This is the MOST RELIABLE indicator

**Heuristic 2: State Name Analysis (Semantic Patterns)**

When code flow analysis is insufficient (e.g., complex logic), use semantic patterns in state names.

**2a. Negative prefixes indicate terminal states:**
```
not_* → terminal (not_authenticated, not_authorized, not_valid)
no_* → terminal (no_permission, no_balance, no_access)
invalid_* → terminal (invalid_input, invalid_format, invalid_token)
missing_* → terminal (missing_data, missing_field, missing_permission)
without_* → terminal (without_access, without_subscription)
```

**Example:**
```yaml
# Characteristic: user_authenticated
# States: [authenticated, not_authenticated]
# Analysis: "not_authenticated" has prefix "not_"
# Decision: terminal_states: [not_authenticated]
```

**2b. Blocking keywords indicate terminal states:**
```
guest → terminal (typically lowest permission level)
none → terminal (absence of something required)
disabled → terminal (feature turned off, no logic needed)
blocked → terminal (user/action prevented)
denied → terminal (access/permission refused)
rejected → terminal (request/action not accepted)
forbidden → terminal (permission error)
```

**Example:**
```yaml
# Characteristic: user_role
# States: [admin, customer, guest]
# Analysis: "guest" is blocking keyword (lowest privilege)
# Decision: terminal_states: [guest]
```

**2c. Final states in sequential characteristics:**
```
completed → terminal (workflow finished)
finished → terminal (process done)
cancelled → terminal (workflow stopped)
failed → terminal (error state, no recovery)
closed → terminal (no further actions)
archived → terminal (inactive state)
```

**Example:**
```yaml
# Characteristic: order_status (sequential)
# States: [pending, processing, completed]
# Analysis: "completed" is final state keyword
# Decision: terminal_states: [completed]
```

**2d. Boundary conditions in range characteristics:**
```
insufficient → terminal (not enough resources)
exceeds_* → terminal (over limit, typically error)
below_* → terminal (under threshold, typically error)
above_* → terminal (over threshold, may be error)
empty → terminal (no data to process)
```

**Example:**
```yaml
# Characteristic: balance
# States: [sufficient, insufficient]
# Analysis: "insufficient" is boundary error keyword
# Decision: terminal_states: [insufficient]
```

**Heuristic 3: Characteristic Type Patterns**

**For binary characteristics:**
- If one state is negative prefix → that state is terminal
- If both states are neutral → likely NO terminal states
- Example: [authenticated, not_authenticated] → terminal: [not_authenticated]

**For enum characteristics:**
- Check each state individually against keywords
- Multiple states can be terminal
- Example: [approved, rejected, cancelled] → terminal: [rejected, cancelled]

**For range characteristics:**
- Boundary error states are usually terminal
- Normal operating range is NOT terminal
- Example: [below_minimum, normal, above_maximum] → terminal: [below_minimum, above_maximum]

**For sequential characteristics:**
- Final states in progression are usually terminal
- Intermediate states are NOT terminal
- Example: [draft, submitted, approved, closed] → terminal: [closed]

#### Decision Tree: Is State Terminal?

```
For each state in characteristic:

1. Code Flow Check (PRIMARY):
   Does code for this state contain early return/raise?
     YES → State is TERMINAL ✓
     NO → Continue to heuristics

2. Negative Prefix Check:
   Does state name start with not_/no_/invalid_/missing_/without_?
     YES → State is TERMINAL ✓
     NO → Continue

3. Blocking Keyword Check:
   Does state name contain guest/none/disabled/blocked/denied/rejected?
     YES → State is TERMINAL ✓
     NO → Continue

4. Final State Check (if sequential):
   Does state name contain completed/finished/cancelled/failed/closed?
     YES → State is TERMINAL ✓
     NO → Continue

5. Boundary Error Check (if range):
   Does state name contain insufficient/exceeds_/below_/above_/empty?
     YES → State is TERMINAL ✓
     NO → State is NOT terminal

Result: terminal_states = [list of states marked ✓]
```

#### Example Logic (Illustrative - NOT literal code to execute)

This shows the LOGIC you should apply mentally when analyzing each characteristic:

```ruby
# Example thinking process (you apply this logic as Claude agent):

def identify_terminal_states(characteristic, source_code)
  terminals = []

  characteristic.states.each do |state|
    # Heuristic 1: Check code flow for this state
    state_code = find_code_for_state(characteristic, state, source_code)

    if state_code.match?(/\b(return|raise)\b/)
      terminals << state
      next  # Most reliable indicator, skip other checks
    end

    # Heuristic 2: Check state name patterns
    terminal_patterns = [
      /^not_/, /^no_/, /^invalid_/, /^missing_/, /^without_/,  # Negative prefixes
      /guest/, /none/, /disabled/, /blocked/, /denied/, /rejected/, /forbidden/,  # Blocking
      /completed/, /finished/, /cancelled/, /failed/, /closed/, /archived/,  # Final states
      /insufficient/, /exceeds_/, /below_/, /above_/, /empty/  # Boundary errors
    ]

    if terminal_patterns.any? { |pattern| state.match?(pattern) }
      terminals << state
    end
  end

  terminals
end
```

#### Output Format

Terminal states are written to metadata.yml as an array:

```yaml
characteristics:
  - name: user_authenticated
    type: binary
    setup: action
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]  # ← Array format
    source: "app/services/payment_service.rb:23"
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: order_status
    type: sequential
    setup: data
    states: [pending, processing, completed, cancelled]
    terminal_states: [completed, cancelled]  # ← Multiple terminals OK
    source: "app/models/order.rb:89-102"
    default: pending
    depends_on: null
    when_parent: null
    level: 1

  - name: payment_method
    type: enum
    setup: data
    states: [card, paypal, bank_transfer]
    terminal_states: []  # ← Empty array if no terminals (or omit field)
    source: "app/services/payment_service.rb:30-38"
    default: null
    depends_on: user_authenticated
    when_parent: [authenticated]
    level: 2
```

#### Important Notes

**1. Terminal states are SUGGESTIONS, not requirements:**
- Agent auto-detects based on heuristics
- User can override during metadata review
- False positives are acceptable (user will correct)
- False negatives are worse (missing terminals leads to over-nesting)

**2. When uncertain, mark as terminal:**
- Better to suggest terminal and let user remove it
- Prevents creating meaningless nested contexts
- User has final decision

**3. Array format is MANDATORY:**
- Always write `terminal_states: [state1, state2]`
- Empty terminals: use `[]` or omit field entirely
- Never write `terminal_states: state1` (not an array)

**Step 7c: Determine Setup Method**

**What you do as Claude AI agent:**

For each characteristic you extracted, determine how it should be set up in tests: through data creation (`data`) or through action/method calls (`action`).

**Why this matters:**
- `setup: data` → generates `let` blocks with factory/data structures
- `setup: action` → generates `before` blocks with method calls
- Different characteristics require different test preparation approaches

**Your task:** Analyze the code and characteristic type to determine the appropriate setup method.

### Detection Algorithm (Apply in Order)

**1. Database column check:**
- Read `db/schema.rb` (if exists)
- Find table definition for the model
- Check if column with characteristic name exists
- Example: `t.boolean "enabled"` → `setup: 'data'`
- If column found → `setup: 'data'`

**2. Session/cookie check:**
- Check if code uses `session` or `cookies`
- Examples: `session[:user_id]`, `cookies[:auth_token]`
- If yes → `setup: 'action'`

**3. State machine guards/callbacks check:**
- For `sequential` type: find AASM/state_machines block
- Check transitions for:
  - guards (transition conditions)
  - callbacks (after/before hooks)
- If guards or callbacks exist → `setup: 'action'`
- If no guards/callbacks → `setup: 'data'`

**4. Bang method check:**
- Check for method with `!` suffix
- Example: `def authenticate!` for characteristic "authenticated"
- If bang method exists → `setup: 'action'`

**5. Range computation check:**
- For `range` type: examine what's being compared
- `Time.current`, `Time.now`, external API calls → `setup: 'action'`
- Stored columns (`balance`, `age`) → `setup: 'data'`

**6. Default:**
- If not determined above → `setup: 'data'` (conservative choice)
- Data setup is safer default (easier to implement)

### Decision Tree: Setup Method

```
For each characteristic:

1. Is this a database column? (check schema.rb)
   YES → setup = 'data'
   NO → Continue

2. Does code use session/cookies?
   YES → setup = 'action'
   NO → Continue

3. Type is sequential + has AASM/state_machines?
   YES → Check transitions:
     Has guards/callbacks?
       YES → setup = 'action'
       NO → setup = 'data'
   NO → Continue

4. Bang method exists (authenticate!, process!, etc.)?
   YES → setup = 'action'
   NO → Continue

5. Type is range + compares with Time.current/external data?
   YES → setup = 'action'
   NO → Continue

6. Default:
   setup = 'data'
```

### Examples

**Example 1: Binary + Database Column**
```ruby
# schema.rb:
t.boolean "enabled"

# Source code:
if user.enabled?
  # ...
end

# Result:
- name: user_enabled
  type: binary
  setup: data  # ← Column in database
  states: [enabled, not_enabled]
```

**Example 2: Binary + Session**
```ruby
# Source code:
if session[:user_id].present?
  # authenticated user
end

# Result:
- name: user_authenticated
  type: binary
  setup: action  # ← Session state, not in database
  states: [authenticated, not_authenticated]
```

**Example 3: Sequential + No Guards**
```ruby
# Model:
aasm column: :status do
  state :draft, initial: true
  state :published

  event :publish do
    transitions from: :draft, to: :published
    # No guards, no callbacks
  end
end

# Result:
- name: article_status
  type: sequential
  setup: data  # ← Can set status directly via column
  states: [draft, published]
```

**Example 4: Sequential + Guards**
```ruby
# Model:
aasm column: :status do
  state :pending, initial: true
  state :processing

  event :process do
    transitions from: :pending, to: :processing, guard: :payment_confirmed?
    # Has guard → need to call event method
  end
end

# Result:
- name: order_status
  type: sequential
  setup: action  # ← Guard requires event method call
  states: [pending, processing]
```

**Example 5: Range + Database Column**
```ruby
# schema.rb:
t.decimal "balance"

# Source code:
if balance >= 1000
  # ...
end

# Result:
- name: balance_sufficient
  type: range
  setup: data  # ← Balance is database column
  states: [sufficient, insufficient]
  threshold_value: 1000
  threshold_operator: '>='
```

**Example 6: Range + Time Comparison**
```ruby
# Source code:
if Time.current >= deadline
  # ...
end

# Result:
- name: deadline_passed
  type: range
  setup: action  # ← Time.current is runtime value
  states: [passed, not_passed]
  threshold_value: null
  threshold_operator: '>='
```

### Output Format

Add to characteristic metadata:
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    setup: data  # ← NEW FIELD
    states: [authenticated, not_authenticated]
    terminal_states: [not_authenticated]
    source: "app/services/payment_service.rb:23"
    default: null
    depends_on: null
    when_parent: null
    level: 1
```

### Important Notes

**1. Setup is a suggestion:**
- Agent auto-detects based on heuristics
- User can override during metadata review or implementation
- Goal is to provide reasonable default

**2. When uncertain, use 'data':**
- Data setup is more common
- Easier to implement (just pass attributes)
- Can always be changed to action during implementation

**3. Required field:**
- Every characteristic MUST have `setup` field
- Validator will check for presence
- No default value (must be explicitly determined)

**Step 8: Run Factory Detector**

**What you do as Claude AI agent:**

Detect available FactoryBot factories and traits if FactoryBot is used in the project.

**Your task:**
1. Check if FactoryBot gem is in Gemfile
2. If present, run factory_detector.rb script
3. Handle success or failure appropriately
4. Add factory data to metadata

**Factory Detection Logic:**

```
Step 1: Check if FactoryBot is in Gemfile
  ├─ NO FactoryBot gem? → Skip detection, factories_detected: {}
  └─ YES FactoryBot gem? → Continue to Step 2

Step 2: Run factory_detector.rb
  ├─ Exit 0 (success)? → Use factory data
  └─ Exit 1 (error)? → FAIL FAST (do not continue)
```

**Implementation:**

```bash
# Step 1: Check if FactoryBot is in Gemfile
if ! grep -q "factory_bot" Gemfile 2>/dev/null; then
  echo "ℹ️ FactoryBot not in Gemfile, skipping factory detection"
  factory_data="{}"
else
  echo "ℹ️ FactoryBot found in Gemfile, detecting factories..."

  # Step 2: Run factory detector
  factory_data=$(ruby lib/rspec_automation/extractors/factory_detector.rb 2>/tmp/factory_err)
  exit_code=$?

  case $exit_code in
    0)
      echo "✅ Factories detected successfully"
      # factory_data contains JSON with factory information
      # Add to metadata YAML
      ;;
    1)
      # FAIL FAST: Parse errors indicate bugs or syntax errors
      echo "❌ Factory detection failed with errors" >&2
      cat /tmp/factory_err >&2
      echo "" >&2
      echo "Factory detection errors indicate:" >&2
      echo "  1. Bug in factory_detector.rb script (needs fixing)" >&2
      echo "  2. Syntax errors in factory definitions (needs fixing)" >&2
      echo "" >&2
      echo "Fix the issue and re-run analyzer." >&2
      exit 1
      ;;
  esac
fi
```

**Handling Specific Scenarios:**

**Scenario 1: FactoryBot not in Gemfile**
```
Check: grep -q "factory_bot" Gemfile
Result: Not found
Action: Skip detection, set factories_detected: {}
Rationale: Project doesn't use FactoryBot, nothing to detect
Continue: YES (this is normal case)
```

**Scenario 2: FactoryBot in Gemfile, factories detected successfully**
```
Exit code: 0
Output: JSON with factory information
Action: Add factory data to metadata
Continue: YES
```

**Scenario 3: FactoryBot in Gemfile, spec/factories directory missing**
```
Exit code: 1
Error: Factories directory not found: spec/factories
Action: FAIL FAST - Exit analyzer with error
Rationale: FactoryBot is declared but no factories exist - project setup issue
Continue: NO (user must fix)
```

**Scenario 4: FactoryBot in Gemfile, factory files have syntax errors**
```
Exit code: 1
Error: SyntaxError in spec/factories/users.rb:23
Action: FAIL FAST - Exit analyzer with error
Rationale: Factory definitions are broken, must be fixed before generating tests
Continue: NO (user must fix syntax errors)
```

**Scenario 5: FactoryBot in Gemfile, factory_detector.rb has bugs**
```
Exit code: 1
Error: NoMethodError in factory_detector.rb:45
Action: FAIL FAST - Exit analyzer with error
Rationale: Script needs debugging/fixing
Continue: NO (developer must fix script)
```

**Important Distinction:**

❌ **OLD logic (wrong):** "Factory detection is optional, always continue"
✅ **NEW logic (correct):**
- If FactoryBot not used → skip detection (normal)
- If FactoryBot IS used → detection MUST succeed or FAIL FAST
- Parse errors = bugs that must be fixed, not warnings to ignore

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
echo "Error: Generated metadata failed validation" >&2
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

### Error 6: Factory Detection Failed

```bash
echo "❌ Factory detection failed with errors" >&2
cat /tmp/factory_err >&2
echo "" >&2
echo "Factory detection errors indicate:" >&2
echo "  1. Bug in factory_detector.rb script (needs fixing)" >&2
echo "  2. Syntax errors in factory definitions (needs fixing)" >&2
echo "" >&2
echo "Possible causes:" >&2
echo "  - FactoryBot is in Gemfile but spec/factories/ directory missing" >&2
echo "  - Factory files have syntax errors (SyntaxError)" >&2
echo "  - factory_detector.rb script has bugs (NoMethodError, etc)" >&2
echo "" >&2
echo "Fix the issue and re-run analyzer." >&2
exit 1
```

## Dependencies

**Must run before:**
- (nothing - first in pipeline)

**Must run after:**
- (nothing - first in pipeline)

**Ruby scripts used:**
- metadata_helper.rb (cache check, path resolution)
- factory_detector.rb (factory detection - FAIL FAST on errors if FactoryBot present)
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
- Factory detection fails when FactoryBot present (should FAIL FAST, not continue)
- FactoryBot not in Gemfile (should skip detection gracefully)

## Related Specifications

- **contracts/metadata-format.spec.md** - Output format
- **contracts/agent-communication.spec.md** - How metadata passed to next agent
- **ruby-scripts/metadata-helper.spec.md** - Cache checking
- **ruby-scripts/factory-detector.spec.md** - Factory information
- **ruby-scripts/metadata-validator.spec.md** - Validation
- **agents/rspec-architect.spec.md** - Next agent in pipeline

---

**Key Takeaway:** Analyzer is foundation. Must be thorough (find all characteristics) and accurate (correct dependencies). Cache validation saves time.
