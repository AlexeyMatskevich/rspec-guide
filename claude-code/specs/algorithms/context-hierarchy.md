# Context Hierarchy Algorithm

**Version:** 1.0
**Created:** 2025-11-07
**Used by:** spec_skeleton_generator.rb

## Purpose

This algorithm defines how to transform extracted **characteristics** (from rspec-analyzer) into a **context hierarchy** (nested RSpec `context` blocks).

**Core Principle:** Each characteristic becomes a context level. Happy path first, then edge cases. Characteristics with dependencies nest deeper.

## Definitions

**Context Hierarchy:** Nested `context` blocks organized by characteristic levels
- Level 1 characteristic → 1st level `context`
- Level 2 characteristic → 2nd level `context` (nested inside level 1)
- And so on...

**Happy Path:** The successful/normal scenario (comes first in hierarchy)

**Context Word:** The word that starts a context description
- `when` - Level 1 contexts (entry condition)
- `with` - First state at any level (positive case)
- `and` - Additional enum states (continuation)
- `but` - Contrast state (negative case after positive)
- `without` - Negation (absence of something)

**Leaf Context:** Deepest context level where `it` blocks live

## Algorithm Overview

```
1. Read characteristics from metadata.yml
2. Sort by level (1, 2, 3, ...)
3. For each level:
   a. Group characteristics by level
   b. Order states (happy path first)
   c. Generate context blocks with correct nesting
   d. Choose appropriate context word
4. Add placeholder it blocks to leaf contexts
5. Return RSpec structure
```

## Step-by-Step Process

### Step 1: Read and Organize Characteristics

```ruby
metadata = YAML.load_file(metadata_path)
characteristics = metadata['characteristics']

# Group by level
by_level = characteristics.group_by { |char| char['level'] }
# { 1 => [...], 2 => [...], 3 => [...] }
```

### Step 2: Determine State Order (Happy Path First)

**Rule 7 from guide.en.md:** Happy path contexts come before edge case contexts.

```ruby
def order_states(characteristic)
  type = characteristic['type']
  states = characteristic['states']

  case type
  when 'binary'
    # Positive state first, negative second
    positive, negative = states
    positive =~ /^not_/ ? [negative, positive] : [positive, negative]

  when 'enum'
    # First state = happy path (usually)
    # Keep original order from source code
    states

  when 'range'
    # Sufficient/valid state first
    states.partition { |s| s =~ /sufficient|valid|within/ }.flatten
  end
end

# Examples:
# [authenticated, not_authenticated] → keep order
# [not_authenticated, authenticated] → swap to [authenticated, not_authenticated]
# [pending, approved, rejected] → keep order (pending is entry state)
```

### Step 3: Build Context Tree

This is a recursive process that builds nested contexts level by level.

**Algorithm:**
```ruby
def build_context_tree(characteristics, current_level = 1, parent_state = nil)
  level_chars = characteristics.select { |c| c['level'] == current_level }

  # Filter by dependency
  if parent_state
    level_chars = level_chars.select do |c|
      c['depends_on'] == parent_state[:characteristic_name]
    end
  end

  contexts = []

  level_chars.each do |char|
    states = order_states(char)

    states.each_with_index do |state, index|
      # Determine context word
      context_word = determine_context_word(char, state, index, current_level)

      # Create context
      context = {
        word: context_word,
        description: format_description(char, state),
        level: current_level,
        children: []
      }

      # Recurse for nested characteristics
      child_state = { characteristic_name: char['name'], state: state }
      context[:children] = build_context_tree(
        characteristics,
        current_level + 1,
        child_state
      )

      # If no children (leaf context), add placeholder it block
      if context[:children].empty?
        context[:it_blocks] = [
          { description: '{BEHAVIOR_DESCRIPTION}' }
        ]
      end

      contexts << context
    end
  end

  contexts
end
```

### Step 4: Determine Context Word

**Rules from guide.en.md Rule 20:**
- Level 1: `when`
- Enum states: `and` (continuation)
- First state (positive): `with`
- Contrast state (negative): `but`
- Negation: `without`

```ruby
def determine_context_word(characteristic, state, state_index, level)
  type = characteristic['type']
  states_count = characteristic['states'].length

  # Level 1 always uses 'when'
  return 'when' if level == 1

  # Level 2+: context word depends on type and states count
  case type
  when 'enum', 'sequential'
    # Enum/sequential: ALWAYS 'and' for all states
    'and'

  when 'binary'
    # Binary (always 2 states): first state 'with', second 'but'
    state_index == 0 ? 'with' : 'but'

  when 'range'
    # Range: depends on number of states
    if states_count == 2
      # Range with 2 states (sufficient/insufficient): 'with'/'but'
      state_index == 0 ? 'with' : 'but'
    else
      # Range with 3+ states (child/adult/senior): 'and' (like enum)
      'and'
    end

  else
    # Fallback (should not reach here)
    '{CONTEXT_WORD}'
  end
end

# Examples:
# Level 1, any type → 'when'
# Level 2, enum (3 states), state 'pending' → 'and'
# Level 2, binary (2 states), first state 'authenticated' → 'with'
# Level 2, binary (2 states), second state 'not_authenticated' → 'but'
# Level 2, range (2 states), first state 'sufficient' → 'with'
# Level 2, range (2 states), second state 'insufficient' → 'but'
# Level 2, range (3 states), state 'child' → 'and'
# Level 2, range (3 states), state 'adult' → 'and'
# Level 2, range (3 states), state 'senior' → 'and'
```

### Step 5: Format Context Descriptions

```ruby
def format_description(characteristic, state)
  name = characteristic['name']
  type = characteristic['type']

  case type
  when 'binary'
    # Use state name directly
    # user_authenticated + authenticated → "user authenticated"
    # user_authenticated + not_authenticated → "user not authenticated"
    state.gsub('_', ' ')

  when 'enum'
    # characteristic_name is state_name
    # payment_method + card → "payment method is card"
    "#{name.gsub('_', ' ')} is #{state}"

  when 'range'
    # balance + sufficient → "balance is sufficient"
    "#{name.gsub('_', ' ')} is #{state.gsub('_', ' ')}"
  end
end

# Examples:
# user_authenticated + authenticated → "user authenticated"
# payment_method + card → "payment method is card"
# balance + sufficient → "balance is sufficient"
```

### Step 6: Generate RSpec Code

```ruby
def generate_rspec_code(context_tree, indent_level = 1)
  code = []
  indent = '  ' * indent_level

  context_tree.each do |context|
    # Generate context line
    code << "#{indent}context '#{context[:word]} #{context[:description]}' do"

    # Generate let blocks (placeholders)
    code << "#{indent}  {SETUP_CODE}"
    code << ""

    # Generate it blocks (if leaf context)
    if context[:it_blocks]
      context[:it_blocks].each do |it_block|
        code << "#{indent}  it '#{it_block[:description]}' do"
        code << "#{indent}    {EXPECTATION}"
        code << "#{indent}  end"
      end
    end

    # Recurse for children
    if context[:children].any?
      code << generate_rspec_code(context[:children], indent_level + 1)
    end

    code << "#{indent}end"
    code << "" unless context == context_tree.last
  end

  code.join("\n")
end
```

## Complete Example

**Input metadata.yml:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    depends_on: null
    level: 1

  - name: payment_method
    type: enum
    states: [card, paypal, bank_transfer]
    depends_on: user_authenticated
    level: 2
```

**Output RSpec structure:**
```ruby
RSpec.describe PaymentService do
  describe '#process_payment' do
    subject(:result) { service.process_payment(user, amount, payment_method) }

    let(:service) { described_class.new }
    {COMMON_SETUP}

    context 'when user authenticated' do
      {SETUP_CODE}

      context 'and payment method is card' do
        {SETUP_CODE}

        it '{BEHAVIOR_DESCRIPTION}' do
          {EXPECTATION}
        end
      end

      context 'and payment method is paypal' do
        {SETUP_CODE}

        it '{BEHAVIOR_DESCRIPTION}' do
          {EXPECTATION}
        end
      end

      context 'and payment method is bank_transfer' do
        {SETUP_CODE}

        it '{BEHAVIOR_DESCRIPTION}' do
          {EXPECTATION}
        end
      end
    end

    context 'when user not authenticated' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end
  end
end
```

### Complete Example 2: Range with 3+ States

**Input metadata.yml:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    depends_on: null
    level: 1

  - name: age
    type: range
    states: [child, adult, senior]  # age < 18 / age < 65
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2
```

**Output RSpec structure:**
```ruby
RSpec.describe TicketService do
  describe '#calculate_price' do
    context 'when user authenticated' do
      {SETUP_CODE}

      # Range with 3+ states uses 'and' for all (like enum)
      context 'and age is child' do
        {SETUP_CODE}

        it '{BEHAVIOR_DESCRIPTION}' do
          {EXPECTATION}
        end
      end

      context 'and age is adult' do
        {SETUP_CODE}

        it '{BEHAVIOR_DESCRIPTION}' do
          {EXPECTATION}
        end
      end

      context 'and age is senior' do
        {SETUP_CODE}

        it '{BEHAVIOR_DESCRIPTION}' do
          {EXPECTATION}
        end
      end
    end

    context 'when user not authenticated' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end
  end
end
```

**Note:** Range with 3+ states behaves like enum for context word selection (all use 'and'), but formatting differs: `"age is child"` (range) vs `"payment_method is card"` (enum).

## Context Word Decision Tree

```
Determine context word for characteristic state:

Is this level 1?
  YES → 'when'
  NO → Continue

Is characteristic type 'enum' or 'sequential'?
  YES → 'and'
  NO → Continue

Is characteristic type 'binary'?
  YES → First state? 'with' : 'but'
  NO → Continue

Is characteristic type 'range'?
  YES → Does it have 2 states?
    YES → First state? 'with' : 'but'
    NO → 'and' (like enum)

Examples:
  Level 1, any type → 'when'
  Level 2, enum (3 states), any state → 'and'
  Level 2, binary (2 states), first state → 'with'
  Level 2, binary (2 states), second state → 'but'
  Level 2, range (2 states), first state → 'with'
  Level 2, range (2 states), second state → 'but'
  Level 2, range (3+ states), any state → 'and'
```

## Leaf Context Rules

**Leaf context:** A context with no children (deepest nesting level)

**Rules:**
1. Only leaf contexts get `it` blocks
2. Each leaf context gets exactly 1 placeholder `it` block initially
3. Placeholder: `it '{BEHAVIOR_DESCRIPTION}' do`
4. Architect agent will replace placeholder with actual description
5. Implementer agent will add expectations

**Example:**
```ruby
context 'when user authenticated' do
  context 'and payment method is card' do  # ← Leaf context
    let(:user) { build_stubbed(:user, authenticated: true) }
    let(:payment_method) { :card }

    it '{BEHAVIOR_DESCRIPTION}' do  # ← Placeholder
      {EXPECTATION}
    end
  end
end
```

## Edge Cases

### Edge Case 1: No Dependencies (All Root Level)

**Input:**
```yaml
characteristics:
  - name: user_authenticated
    level: 1
    depends_on: null

  - name: balance_sufficient
    level: 1
    depends_on: null
```

**Output:**
```ruby
context 'when user authenticated' do
  # ...
end

context 'when user not authenticated' do
  # ...
end

context 'when balance sufficient' do
  # ...
end

context 'when balance insufficient' do
  # ...
end
```

**Note:** Each characteristic creates separate top-level contexts (no nesting).

### Edge Case 2: Three Levels Deep

**Input:**
```yaml
characteristics:
  - name: user_authenticated
    level: 1

  - name: payment_method
    level: 2
    depends_on: user_authenticated

  - name: currency
    level: 3
    depends_on: payment_method
```

**Output:**
```ruby
context 'when user authenticated' do
  context 'and payment method is card' do
    context 'with currency is usd' do
      it '{BEHAVIOR_DESCRIPTION}' do
        # ...
      end
    end

    context 'but currency is eur' do
      it '{BEHAVIOR_DESCRIPTION}' do
        # ...
      end
    end
  end
end
```

### Edge Case 3: Happy Path is Second State

Sometimes the positive case is listed second in source code:

**Input:**
```yaml
- name: user_authenticated
  type: binary
  states: [not_authenticated, authenticated]  # Negative first!
```

**Algorithm detects and reorders:**
```ruby
def order_states(characteristic)
  if characteristic['states'][0] =~ /^not_/
    # Swap: put positive first
    [characteristic['states'][1], characteristic['states'][0]]
  else
    characteristic['states']
  end
end
```

**Output:**
```ruby
# Correct order (positive first)
context 'when user authenticated' do
  # ...
end

context 'when user not authenticated' do
  # ...
end
```

### Edge Case 4: Multiple Enum States

**Input:**
```yaml
- name: order_status
  type: enum
  states: [pending, processing, shipped, delivered, cancelled]
```

**Output:**
```ruby
context 'when order status is pending' do
  # ...
end

context 'and order status is processing' do  # 'and' for continuation
  # ...
end

context 'and order status is shipped' do
  # ...
end

context 'and order status is delivered' do
  # ...
end

context 'and order status is cancelled' do
  # ...
end
```

**Note:** First enum state uses `when` (level 1), rest use `and`.

### Edge Case 5: Conditional Dependency

Some characteristics only exist when parent is in specific state:

**Source code:**
```ruby
if user.authenticated?
  case payment_method
  when :card
    # ...
  when :paypal
    # ...
  end
else
  raise AuthenticationError
end
```

**Extracted metadata:**
```yaml
- name: user_authenticated
  level: 1
  states: [authenticated, not_authenticated]

- name: payment_method
  level: 2
  depends_on: user_authenticated  # Only when authenticated
  states: [card, paypal]
```

**Generated structure:**
```ruby
context 'when user authenticated' do
  # payment_method contexts appear here

  context 'and payment method is card' do
    # ...
  end

  context 'and payment method is paypal' do
    # ...
  end
end

context 'when user not authenticated' do
  # No payment_method contexts (not applicable)

  it '{BEHAVIOR_DESCRIPTION}' do
    # Test authentication error
  end
end
```

## Placeholders

**The algorithm generates placeholders for agents to fill:**

### Placeholder 1: `{CONTEXT_WORD}`

**Where:** Context descriptions when word is ambiguous
**Replaced by:** rspec-architect (analyzes source code for semantic meaning)

```ruby
# Generated by skeleton generator:
context '{CONTEXT_WORD} balance is sufficient' do
  # ...
end

# Replaced by architect:
context 'with balance is sufficient' do  # 'with' chosen by semantic analysis
  # ...
end
```

**Note:** skeleton_generator uses decision tree to determine context word. Placeholder only used when ambiguous.

### Placeholder 2: `{SETUP_CODE}`

**Where:** Inside each context block
**Replaced by:** rspec-implementer

```ruby
# Generated:
context 'when user authenticated' do
  {SETUP_CODE}

  it '...' do
    # ...
  end
end

# Replaced:
context 'when user authenticated' do
  let(:user) { build_stubbed(:user, authenticated: true) }

  it '...' do
    # ...
  end
end
```

### Placeholder 3: `{BEHAVIOR_DESCRIPTION}`

**Where:** `it` block descriptions
**Replaced by:** rspec-architect

```ruby
# Generated:
it '{BEHAVIOR_DESCRIPTION}' do
  {EXPECTATION}
end

# Replaced:
it 'processes payment successfully' do
  {EXPECTATION}
end
```

### Placeholder 4: `{EXPECTATION}`

**Where:** Inside `it` blocks
**Replaced by:** rspec-implementer

```ruby
# Generated:
it 'processes payment successfully' do
  {EXPECTATION}
end

# Replaced:
it 'processes payment successfully' do
  expect(result).to be_a(Payment)
  expect(result.status).to eq(:completed)
end
```

### Placeholder 5: `{COMMON_SETUP}`

**Where:** Top of describe block (before contexts)
**Replaced by:** rspec-implementer

```ruby
# Generated:
describe '#process_payment' do
  subject(:result) { service.process_payment(user, amount) }

  let(:service) { described_class.new }
  {COMMON_SETUP}

  context '...' do
    # ...
  end
end

# Replaced:
describe '#process_payment' do
  subject(:result) { service.process_payment(user, amount) }

  let(:service) { described_class.new }
  let(:amount) { 100 }

  context '...' do
    # ...
  end
end
```

## Testing Criteria

**Algorithm is correct if:**
- ✅ Characteristics transform to correctly nested contexts
- ✅ Happy path contexts appear before edge cases
- ✅ Context words follow Rule 20 from guide.en.md
- ✅ Leaf contexts contain `it` blocks
- ✅ Non-leaf contexts contain child contexts
- ✅ Dependencies determine nesting structure
- ✅ Placeholders present for agents to replace

**Common mistakes to avoid:**
- `it` blocks in non-leaf contexts
- Wrong context word (e.g., 'with' at level 1)
- Edge case contexts before happy path
- Missing placeholders

---

## Terminal States in Context Hierarchies

### Concept

**Terminal state** = parent state that doesn't generate child contexts.

Represents scenarios where:
- Business logic cannot proceed (authentication failed, insufficient funds)
- Final state reached (order completed, process cancelled)
- Access denied (guest user, disabled feature)

### Metadata Representation

```yaml
- name: parent_char
  states: [positive, negative]
  terminal_states: [negative]  # ← Explicitly marked

- name: child_char
  depends_on: parent_char
  when_parent: [positive]  # ← Array: only for non-terminal states
```

### Generated Structure

```ruby
context 'when parent positive' do
  # Child contexts here (non-terminal)
  context 'and child_char is ...' do
    # ...
  end
end

context 'when parent negative' do
  # NO child contexts (terminal)
  it 'expects error/denial' do
    # ...
  end
end
```

### Decision Tree: Is This State Terminal?

```
1. Does code return early with error for this state?
   YES → Terminal
   NO → Continue

2. Is this a final state (completed/cancelled)?
   YES → Terminal
   NO → Continue

3. Does state block business logic (guest/disabled)?
   YES → Terminal
   NO → Continue

4. State has negative prefix (not_/invalid_/no_)?
   YES → Likely terminal (review)
   NO → Likely non-terminal

5. For range: Is this insufficient/exceeds state?
   YES → Likely terminal
   NO → Non-terminal
```

### Array `when_parent` Format

**Multiple positive parent states:**

```yaml
- name: user_role
  states: [admin, manager, customer, guest]
  terminal_states: [customer, guest]

- name: can_edit_orders
  depends_on: user_role
  when_parent: [admin, manager]  # ← Array: both states allow editing
```

**Generated:**
```ruby
context 'when user role is admin' do
  context 'with can edit orders allowed' do
    # ...
  end
end

context 'and user role is manager' do
  context 'with can edit orders allowed' do  # ← SAME child contexts
    # ...
  end
end

context 'and user role is customer' do
  it 'denies access'  # ← TERMINAL (no children)
end

context 'and user role is guest' do
  it 'denies access'  # ← TERMINAL (no children)
end
```

**Trade-off:** Duplicate child contexts for each positive parent state. This is correct - each scenario should be independently tested.

---

## Related Specifications

- **ruby-scripts/spec-skeleton-generator.spec.md** - Implements this algorithm
- **algorithms/characteristic-extraction.md** - Produces input for this algorithm
- **agents/rspec-architect.spec.md** - Replaces placeholders

---

**Key Takeaway:** Characteristics → nested contexts. Happy path first. Context words follow rules. Placeholders for agents to fill.
