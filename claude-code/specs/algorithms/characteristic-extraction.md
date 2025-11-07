# Characteristic Extraction Algorithm

**Version:** 1.0
**Created:** 2025-11-07
**Used by:** rspec-analyzer agent

## ⚠️ IMPORTANT: Audience is Claude AI Agents

**How to use this document:**

This algorithm describes the **LOGIC** for analyzing Ruby code to extract characteristics.

**As a Claude AI agent:**
- ✅ You read Ruby source code directly (using Read tool)
- ✅ You understand Ruby syntax and semantics natively
- ✅ You apply this logic mentally to identify characteristics
- ❌ You do NOT execute the Ruby code shown in examples
- ❌ You do NOT create Ruby scripts from this algorithm
- ❌ You do NOT use `parser` gem or AST libraries

**The Ruby code examples in this document show:**
- The LOGIC you should apply
- How to think about different code patterns
- Decision trees for determining types
- NOT literal code you must execute

**Think of this as:** A detailed guide explaining how to think about Ruby code when extracting characteristics. The Ruby syntax is used for clarity, but you apply the logic directly without running code.

---

## Purpose

This algorithm defines how to extract **characteristics** (conditional branches) from Ruby source code to build a characteristic-based test hierarchy.

**Core Principle:** A characteristic is any conditional logic that changes method behavior. Tests must cover all combinations of characteristic states.

## Definitions

**Characteristic:** A conditional expression that determines method behavior
- Examples: `if user.admin?`, `case status`, `balance >= amount`
- Each characteristic has multiple **states** (e.g., true/false, or enum values)

**Characteristic Types:**
1. **binary:** Two states (if/unless conditions)
2. **enum:** Multiple named states (case/when, multiple elsif)
3. **range:** Continuous values with boundary conditions

**Dependency:** When one characteristic only matters if another is in a specific state
- Example: "payment method" only matters when "user authenticated" is true

**Level:** Nesting depth in characteristic hierarchy (1 = root, 2+ = dependent)

## Algorithm Overview

**High-level process (what you do as Claude agent):**

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

## Step-by-Step Process

### Step 1: Read Source Code

**What you do:**
- Use Read tool to read the source file
- Understand the overall structure
- Identify the target class and method

**Conceptual thinking (shown as Ruby for clarity):**
```ruby
# You're reading the file and understanding its structure
source_code = File.read(source_file)  # ← You do this via Read tool
# You understand the code structure natively, no AST parser needed
```

### Step 2: Locate Target Method

**What you do:**
- Scan the source code for the method definition
- Look for `def method_name` or `def self.method_name`
- Identify the method body (code between `def` and matching `end`)

**Conceptual logic (shown as pseudocode):**
```ruby
# You're scanning the file looking for the method
# Example: looking for "def process_payment"
# You identify where it starts and where it ends (matching `end` keyword)
# Error if method not found → report to user
```

**What to extract:**
- Method name
- Method type (instance vs class method)
- Method parameters
- Method body (all code inside)

### Step 3: Identify Conditional Statements

**What you do:**
- Scan the method body for conditional logic
- Identify all `if`, `unless`, `elsif`, `case/when` statements
- Note boolean combinations (`&&`, `||`)
- Track nesting levels

**Types of conditionals to find:**
- **if/unless/elsif** - binary or multi-way branches
- **case/when** - enum-style switches
- **Ternary** - `condition ? value1 : value2`
- **Boolean operators** - `a && b`, `a || b`

**Conceptual thinking:**
```ruby
# As you read the method body, you identify patterns like:
# "if user.authenticated?" ← This is a conditional!
# "case payment_method" ← This is a conditional!
# "balance >= amount" ← This is a conditional (comparison)!
```
- `:case` - case/when
- `:and`, `:or` - boolean combinations
- **Skip:** ternary operators (too simple, part of data flow)

### Step 4: Extract Characteristics

**For each conditional you identified, extract:**

#### 4a. Extract Condition Expression and Source Location

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

#### 4b. Determine Characteristic Type

**Decision logic (apply in this order):**

1. **Check for comparison operators** (`>=`, `>`, `<=`, `<`):
   - If present → type is `'range'`
   - Example: `balance >= amount` → `'range'`

2. **Check if it's a case statement**:
   - Always → type is `'enum'`
   - Example: `case status` → `'enum'`

3. **Check if it's an if-elsif chain**:
   - Multiple elsif → type is `'enum'`
   - Example: `if ... elsif ... elsif` → `'enum'`

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
4. **Case statement**: `case ... when ... when` → `'enum'` (multiple states)

**Why check range first:**
- Per `algoritm/test.en.md:162-185`, range characteristics are identified by comparison operators
- Range typically has 2 states (sufficient/insufficient, below/above threshold)
- Without this check, `if balance >= amount` would incorrectly be classified as `'binary'`

#### 4c. Extract States

**For binary characteristics:**
```ruby
def extract_binary_states(condition_expr)
  # Condition: "user.authenticated?"
  # States: ['authenticated', 'not_authenticated']

  positive = condition_expr.gsub(/\?$/, '').split('.').last
  negative = "not_#{positive}"

  [positive, negative]
end
```

**For enum characteristics:**
```ruby
def extract_enum_states(case_node)
  # case status
  #   when :pending
  #   when :approved
  #   when :rejected
  # end

  states = []
  case_node.children[1..].each do |when_node|
    next unless when_node.type == :when
    condition = when_node.children[0]
    states << extract_symbol_or_string(condition)
  end

  states
  # → ['pending', 'approved', 'rejected']
end
```

**For range characteristics:**
```ruby
def extract_range_states(condition_expr)
  # Condition: "balance >= amount"
  # States: ['sufficient', 'insufficient']

  if condition_expr =~ />=|>/
    ['sufficient', 'insufficient']
  elsif condition_expr =~ /<=|</
    ['below_threshold', 'above_threshold']
  else
    ['boundary_condition', 'normal_case']
  end
end
```

#### 4d. Detect Dependencies

**Dependency exists when:**
- Characteristic is nested inside another conditional
- Characteristic only matters when parent condition is true

**Algorithm:**
```ruby
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

#### 4e. Calculate Level

```ruby
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

### Step 5: Generate YAML Output

```ruby
characteristics_data = {
  'source_file' => source_file,
  'method_name' => method_name,
  'characteristics' => characteristics.map do |char|
    {
      'name' => char[:name],
      'type' => char[:type],
      'states' => char[:states],
      'source' => char[:source],  # NEW: "path:line" or "path:line-line"
      'depends_on' => char[:depends_on],
      'level' => char[:level],
      'condition_expression' => char[:condition_expression],
      'line_number' => char[:line_number]  # Kept for backward compat (deprecated)
    }
  end
}

YAML.dump(characteristics_data)
```

**Note:** The `source` field combines file path and line information in a single string format suitable for IDE navigation and comments.

## Complete Example

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
source_file: app/services/payment_service.rb
method_name: process_payment
characteristics:
  - name: user_authenticated
    type: binary
    states:
      - authenticated
      - not_authenticated
    source: "app/services/payment_service.rb:4-6"  # unless block spans 3 lines
    depends_on: null
    level: 1
    condition_expression: user.authenticated?
    line_number: 4

  - name: payment_method
    type: enum
    states:
      - card
      - paypal
      - bank_transfer
    source: "app/services/payment_service.rb:9-15"  # case statement block
    depends_on: user_authenticated
    level: 2
    condition_expression: payment_method
    line_number: 9
```

## Edge Cases

### Edge Case 1: No Conditionals Found

```ruby
def simple_method(x, y)
  x + y  # No conditionals
end
```

**Action:** Warn user, generate minimal metadata with empty characteristics array
**Exit code:** 2 (warning)

### Edge Case 2: Guard Clauses

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

### Edge Case 3: Boolean Combinations

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
  level: 1
```

**Recommendation:** Use Approach 2 (expanded) for better test coverage.

**Implementation:**
```ruby
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

### Edge Case 4: Nested Case Statements

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
  depends_on: user_role  # Only matters when admin
  level: 2
```

### Edge Case 5: Else Clause Without Explicit Condition

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

### Edge Case 6: Range with 3+ States (Age Groups)

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
  default: null
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
- Context word: 'and' for all states (like enum, because 3+ states)

## Characteristic Naming Rules

### Rule 1: Use Domain Language

```ruby
# Source: if user.authenticated?
# ✅ Good: user_authenticated
# ❌ Bad: condition1, auth_check
```

### Rule 2: Avoid Verb Forms

```ruby
# Source: if can_process?
# ✅ Good: processable
# ❌ Bad: can_process
```

### Rule 3: Handle Negations

```ruby
# Source: unless user.blocked?
# ✅ Good: user_blocked (with states: [blocked, not_blocked])
# ❌ Bad: user_not_blocked
```

### Rule 4: Simplify Complex Expressions

```ruby
# Source: if order.total >= 100 && order.total < 1000
# ✅ Good: order_total_range
# ❌ Bad: order_total_gte_100_and_lt_1000
```

### Rule 5: Boolean Combinations

```ruby
# Source: if user.authenticated? && user.premium?
# ✅ Good: Extract as two characteristics
#   - user_authenticated
#   - user_premium
# ❌ Bad: user_authenticated_and_premium
```

## State Naming Rules

### Rule 1: Use Affirmative Terms

```ruby
# Characteristic: user_authenticated
# ✅ Good: [authenticated, not_authenticated]
# ❌ Bad: [true, false]
```

### Rule 2: Enum States Use Original Values

```ruby
# Source: case status
#          when :pending
#          when :approved
# ✅ Good: [pending, approved]
# ❌ Bad: [status_pending, status_approved]
```

### Rule 3: Range States Use Business Terms

```ruby
# Source: if balance >= amount
# ✅ Good: [sufficient, insufficient]
# ❌ Bad: [true, false]
# ❌ Bad: [gte_amount, lt_amount]
```

## Testing Criteria

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

## Related Specifications

- **agents/rspec-analyzer.spec.md** - Uses this algorithm
- **contracts/metadata-format.spec.md** - Output format
- **algorithms/context-hierarchy.md** - How characteristics become contexts

---

**Key Takeaway:** Extract conditional logic as domain-meaningful characteristics. Dependencies = nesting. Guard clauses = independent roots. Expand boolean combinations.
