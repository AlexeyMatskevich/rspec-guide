# spec_skeleton_generator.rb Script Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Ruby Script (Generator)
**Location:** `lib/rspec_automation/generators/spec_skeleton_generator.rb`

## Purpose

Transforms metadata.yml (containing characteristics) into RSpec test file skeleton with proper context hierarchy and placeholders.

**Why this matters:**
- Generates consistent test structure from characteristics
- Creates proper nesting based on dependencies
- Inserts placeholders for later agents to fill
- Mechanical transformation (no semantic analysis needed)

**Key Responsibilities:**
1. Read metadata.yml and extract characteristics
2. Build context hierarchy based on levels and dependencies
3. Determine context words (when/with/but/and)
4. Generate describe/context/it structure
5. Insert placeholders for architect and implementer agents
6. Write complete RSpec skeleton to file

**Important:** This is a **mechanical generator**. It transforms data structure to code structure without understanding semantics.

## Exit Code Contract

| Exit Code | Meaning | stdout | stderr |
|-----------|---------|--------|--------|
| `0` | Success | Path to generated file | Empty |
| `1` | Critical Error | Empty | Error message |
| `2` | Warning | Path to generated file | Warning message |

**Exit 0 scenarios:**
- Skeleton successfully generated
- All characteristics converted to contexts

**Exit 1 scenarios:**
- metadata.yml not found or unreadable
- Invalid YAML syntax
- Missing required fields (target, characteristics)
- Circular dependencies detected (shouldn't happen if validated)
- Cannot write output file (permission denied)

**Exit 2 scenarios:**
- Empty characteristics array (minimal skeleton generated)
- Suspicious patterns (4+ nesting levels, complexity warning)
- Some context words ambiguous (used {CONTEXT_WORD} placeholder)

## Command-Line Interface

### Basic Usage

**Usage:**
```bash
ruby lib/rspec_automation/generators/spec_skeleton_generator.rb <metadata_path> [output_file]
```

**Arguments:**
- `<metadata_path>`: Path to metadata YAML file (required)
- `[output_file]`: Path to output RSpec file (optional, auto-determined from target.file)

**Output (stdout):**
```
spec/services/payment_service_spec.rb
```

**Auto-determination of output file:**
```ruby
# From metadata target.file: app/services/payment_service.rb
# Generate spec path: spec/services/payment_service_spec.rb

# Algorithm:
# 1. Remove "app/" prefix -> services/payment_service.rb
# 2. Remove ".rb" suffix -> services/payment_service
# 3. Add "_spec.rb" suffix -> services/payment_service_spec.rb
# 4. Prepend "spec/" -> spec/services/payment_service_spec.rb
```

**Example:**
```bash
$ ruby spec_skeleton_generator.rb tmp/rspec_claude_metadata/metadata_app_services_payment.yml
spec/services/payment_service_spec.rb
$ echo $?
0
```

## Algorithm: Building Context Hierarchy

### Step 1: Read and Parse Metadata

```ruby
metadata = YAML.load_file(metadata_path)

# Extract required sections
target = metadata['target']
test_level = metadata['test_level']
characteristics = metadata['characteristics']

# Validate presence
raise "Missing target section" unless target
raise "Missing characteristics" unless characteristics
```

---

### Step 2: Order States (Happy Path First)

**Goal:** Ensure positive/successful states come before negative/failure states

**Binary characteristics:**
```ruby
def order_binary_states(states)
  # If first state has negative prefix, swap
  negative_prefixes = ['not_', 'no_', 'invalid_', 'missing_', 'without_']

  first_state = states[0]
  if negative_prefixes.any? { |prefix| first_state.start_with?(prefix) }
    states.reverse
  else
    states
  end
end

# Examples:
# [not_authenticated, authenticated] -> [authenticated, not_authenticated]
# [authenticated, not_authenticated] -> [authenticated, not_authenticated] (no change)
# [invalid, valid] -> [valid, invalid]
```

**Enum/Range/Sequential:**
```ruby
def order_other_states(states, type)
  # Keep original order (assume first is happy path)
  # Analyzer should have put them in correct order
  states
end
```

---

### Step 3: Determine Context Word

**Decision tree:**

```ruby
def determine_context_word(characteristic, state, state_index, level)
  # Level 1 always uses 'when'
  return 'when' if level == 1

  type = characteristic['type']
  states = characteristic['states']

  case type
  when 'enum', 'sequential'
    # Always 'and' for all states
    'and'

  when 'binary'
    # First state: 'with', second: 'but'
    state_index == 0 ? 'with' : 'but'

  when 'range'
    if states.length == 2
      # 2 states: 'with' / 'but' (like binary)
      state_index == 0 ? 'with' : 'but'
    else
      # 3+ states: 'and' (like enum)
      'and'
    end

  else
    # Unknown type: use placeholder
    '{CONTEXT_WORD}'
  end
end
```

**Examples:**

| Type | Level | States | Context Words |
|------|-------|--------|---------------|
| binary | 1 | [authenticated, not_authenticated] | when, when |
| binary | 2 | [authenticated, not_authenticated] | with, but |
| enum | 2 | [card, paypal, bank] | and, and, and |
| range (2) | 2 | [sufficient, insufficient] | with, but |
| range (3+) | 2 | [child, adult, senior] | and, and, and |
| sequential | 2 | [pending, approved, rejected] | and, and, and |

---

### Step 4: Format Context Descriptions

**Convert characteristic name + state to readable text:**

```ruby
def format_description(characteristic, state)
  name = characteristic['name']
  type = characteristic['type']

  # Convert snake_case to space-separated
  readable_name = name.gsub('_', ' ')
  readable_state = state.gsub('_', ' ')

  case type
  when 'binary'
    # Binary: use state directly
    # user_authenticated + authenticated -> "user authenticated"
    readable_state

  when 'enum', 'sequential', 'range'
    # Others: "name is state"
    # payment_method + card -> "payment method is card"
    "#{readable_name} is #{readable_state}"
  end
end
```

**Examples:**

| Characteristic | State | Type | Description |
|----------------|-------|------|-------------|
| user_authenticated | authenticated | binary | "user authenticated" |
| user_authenticated | not_authenticated | binary | "user not authenticated" |
| payment_method | card | enum | "payment method is card" |
| balance | sufficient | range | "balance is sufficient" |
| order_status | pending | sequential | "order status is pending" |

---

### Step 5: Build Context Tree Recursively

**Algorithm:**

```ruby
def build_context_tree(characteristics, current_level = 1, parent_context = nil)
  # Filter characteristics for current level
  level_chars = characteristics.select { |c| c['level'] == current_level }

  # Filter by dependency
  if parent_context
    level_chars = level_chars.select do |c|
      c['depends_on'] == parent_context[:char_name] &&
      c['when_parent'] == parent_context[:state]
    end
  else
    # Root level: no dependencies
    level_chars = level_chars.select { |c| c['depends_on'].nil? }
  end

  contexts = []

  level_chars.each do |char|
    # Order states (happy path first)
    states = order_states(char)

    states.each_with_index do |state, index|
      context_word = determine_context_word(char, state, index, current_level)
      description = format_description(char, state)

      context = {
        word: context_word,
        description: description,
        level: current_level,
        characteristic: char['name'],
        state: state,
        children: []
      }

      # Recurse for nested characteristics
      child_parent = { char_name: char['name'], state: state }
      context[:children] = build_context_tree(
        characteristics,
        current_level + 1,
        child_parent
      )

      # Leaf context: add placeholder it block
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

**Example tree structure:**

```ruby
[
  {
    word: 'when',
    description: 'user authenticated',
    level: 1,
    children: [
      {
        word: 'and',
        description: 'payment method is card',
        level: 2,
        children: [
          {
            word: 'with',
            description: 'balance is sufficient',
            level: 3,
            children: [],
            it_blocks: [{ description: '{BEHAVIOR_DESCRIPTION}' }]
          },
          {
            word: 'but',
            description: 'balance is insufficient',
            level: 3,
            children: [],
            it_blocks: [{ description: '{BEHAVIOR_DESCRIPTION}' }]
          }
        ]
      }
    ]
  },
  {
    word: 'when',
    description: 'user not authenticated',
    level: 1,
    children: [],
    it_blocks: [{ description: '{BEHAVIOR_DESCRIPTION}' }]
  }
]
```

---

### Step 6: Generate RSpec Code from Tree

```ruby
def generate_context_code(context_tree, indent_level = 2)
  code = []
  indent = '  ' * indent_level

  context_tree.each do |context|
    # Generate context line
    code << "#{indent}context '#{context[:word]} #{context[:description]}' do"
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
      child_code = generate_context_code(context[:children], indent_level + 1)
      code << ""
      code << child_code
    end

    code << "#{indent}end"
    code << "" unless context == context_tree.last
  end

  code.join("\n")
end
```

---

### Step 7: Add Placeholders

**Placeholders inserted:**

1. **{COMMON_SETUP}** - Top of describe block
   - Purpose: Shared let blocks used by all contexts
   - Replaced by: rspec-implementer

2. **{SETUP_CODE}** - Inside each context
   - Purpose: Context-specific let/let!/before blocks
   - Replaced by: rspec-implementer

3. **{BEHAVIOR_DESCRIPTION}** - it block descriptions
   - Purpose: Actual test description
   - Replaced by: rspec-architect

4. **{EXPECTATION}** - Inside it blocks
   - Purpose: expect statements
   - Replaced by: rspec-implementer

5. **{CONTEXT_WORD}** - (rare) Ambiguous context word
   - Purpose: When algorithm cannot determine word
   - Replaced by: rspec-architect

---

### Step 8: Wrap in RSpec Structure

```ruby
def generate_full_spec(metadata, context_tree)
  target = metadata['target']
  class_name = target['class']
  method_name = target['method']
  method_type = target['method_type']

  # Method descriptor
  method_descriptor = method_type == 'class' ? ".#{method_name}" : "##{method_name}"

  # Build full spec
  spec = []
  spec << "# frozen_string_literal: true"
  spec << ""
  spec << "RSpec.describe #{class_name} do"
  spec << "  describe '#{method_descriptor}' do"
  spec << "    subject(:result) { service.#{method_name} }  # TODO: Add parameters"
  spec << ""

  if method_type == 'instance'
    spec << "    let(:service) { described_class.new }"
    spec << ""
  end

  spec << "    {COMMON_SETUP}"
  spec << ""

  # Add context tree
  context_code = generate_context_code(context_tree, 2)
  spec << context_code

  spec << "  end"
  spec << "end"

  spec.join("\n")
end
```

---

### Step 9: Write to File

```ruby
def write_spec_file(output_path, content)
  # Ensure directory exists
  FileUtils.mkdir_p(File.dirname(output_path))

  # Write file
  File.write(output_path, content)

  # Output path to stdout
  puts output_path
end
```

## Complete Examples

### Example 1: Simple Binary Characteristic (Exit 0)

**Input metadata:**
```yaml
target:
  class: UserService
  method: activate
  method_type: instance
  file: app/services/user_service.rb

test_level: unit

characteristics:
  - name: user_active
    type: binary
    states: [active, inactive]
    default: null
    depends_on: null
    when_parent: null
    level: 1
```

**Command:**
```bash
ruby spec_skeleton_generator.rb metadata.yml
```

**Output (stdout):**
```
spec/services/user_service_spec.rb
```

**Generated file:**
```ruby
# frozen_string_literal: true

RSpec.describe UserService do
  describe '#activate' do
    subject(:result) { service.activate }  # TODO: Add parameters

    let(:service) { described_class.new }

    {COMMON_SETUP}

    context 'when user active' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end

    context 'when user inactive' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end
  end
end
```

**Exit code:** `0`

---

### Example 2: Enum with Three States (Exit 0)

**Input metadata:**
```yaml
target:
  class: PaymentService
  method: process
  method_type: instance

characteristics:
  - name: payment_method
    type: enum
    states: [card, paypal, bank_transfer]
    default: null
    depends_on: null
    level: 1
```

**Generated file:**
```ruby
# frozen_string_literal: true

RSpec.describe PaymentService do
  describe '#process' do
    subject(:result) { service.process }  # TODO: Add parameters

    let(:service) { described_class.new }

    {COMMON_SETUP}

    context 'when payment method is card' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end

    context 'when payment method is paypal' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end

    context 'when payment method is bank_transfer' do
      {SETUP_CODE}

      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end
  end
end
```

**Exit code:** `0`

---

### Example 3: Two-Level Dependency (Exit 0)

**Input metadata:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    depends_on: null
    level: 1

  - name: payment_method
    type: enum
    states: [card, paypal]
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2
```

**Generated file:**
```ruby
# frozen_string_literal: true

RSpec.describe PaymentService do
  describe '#process_payment' do
    subject(:result) { service.process_payment }  # TODO: Add parameters

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

**Exit code:** `0`

**Note:** payment_method contexts only appear inside "when user authenticated"

---

### Example 4: Three-Level Nesting (Exit 0)

**Input metadata:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    level: 1

  - name: payment_method
    type: enum
    states: [card, paypal]
    depends_on: user_authenticated
    when_parent: authenticated
    level: 2

  - name: balance_sufficient
    type: binary
    states: [sufficient, insufficient]
    depends_on: payment_method
    when_parent: card
    level: 3
```

**Generated file:**
```ruby
# frozen_string_literal: true

RSpec.describe PaymentService do
  describe '#process_payment' do
    subject(:result) { service.process_payment }  # TODO: Add parameters

    let(:service) { described_class.new }

    {COMMON_SETUP}

    context 'when user authenticated' do
      {SETUP_CODE}

      context 'and payment method is card' do
        {SETUP_CODE}

        context 'with balance is sufficient' do
          {SETUP_CODE}

          it '{BEHAVIOR_DESCRIPTION}' do
            {EXPECTATION}
          end
        end

        context 'but balance is insufficient' do
          {SETUP_CODE}

          it '{BEHAVIOR_DESCRIPTION}' do
            {EXPECTATION}
          end
        end
      end

      context 'and payment method is paypal' do
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

**Exit code:** `0`

**Note:** balance contexts only appear inside "and payment method is card"

---

### Example 5: Binary with Swapped States (Exit 0)

**Input metadata:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [not_authenticated, authenticated]  # Wrong order!
    level: 1
```

**Algorithm detects "not_" prefix, swaps to: [authenticated, not_authenticated]**

**Generated file:**
```ruby
context 'when user authenticated' do
  # ... (authenticated first, happy path)
end

context 'when user not authenticated' do
  # ... (not_authenticated second)
end
```

**Exit code:** `0`

---

### Example 6: Range with 3+ States (Exit 0)

**Input metadata:**
```yaml
characteristics:
  - name: age_group
    type: range
    states: [child, adult, senior]
    level: 1
```

**Generated file:**
```ruby
context 'when age group is child' do
  # ...
end

context 'when age group is adult' do
  # ...
end

context 'when age group is senior' do
  # ...
end
```

**Note:** All use "when" (level 1), and if nested would use "and" (3+ states)

**Exit code:** `0`

---

### Example 7: Multiple Root Characteristics (Exit 0)

**Input metadata:**
```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    depends_on: null
    level: 1

  - name: account_active
    type: binary
    states: [active, inactive]
    depends_on: null
    level: 1
```

**Generated file:**
```ruby
context 'when user authenticated' do
  # ...
end

context 'when user not authenticated' do
  # ...
end

context 'when account active' do
  # ...
end

context 'when account inactive' do
  # ...
end
```

**Note:** Both at level 1, no dependency -> separate parallel contexts (not nested)

**Exit code:** `0`

---

### Example 8: Empty Characteristics (Exit 2)

**Input metadata:**
```yaml
target:
  class: SimpleService
  method: call
  method_type: instance

characteristics: []
```

**Command:**
```bash
ruby spec_skeleton_generator.rb metadata.yml
```

**Output (stdout):**
```
spec/services/simple_service_spec.rb
```

**Output (stderr):**
```
Warning: No characteristics found in metadata
Generated minimal skeleton with single it block
```

**Generated file:**
```ruby
# frozen_string_literal: true

RSpec.describe SimpleService do
  describe '#call' do
    subject(:result) { service.call }  # TODO: Add parameters

    let(:service) { described_class.new }

    {COMMON_SETUP}

    it '{BEHAVIOR_DESCRIPTION}' do
      {EXPECTATION}
    end
  end
end
```

**Exit code:** `2` (warning)

---

### Example 9: Class Method (Exit 0)

**Input metadata:**
```yaml
target:
  class: Calculator
  method: add
  method_type: class
  file: app/services/calculator.rb
```

**Generated file:**
```ruby
# frozen_string_literal: true

RSpec.describe Calculator do
  describe '.add' do  # Note: . not #
    subject(:result) { described_class.add }  # TODO: Add parameters

    {COMMON_SETUP}

    # ... contexts
  end
end
```

**Note:** No `let(:service)` for class methods

**Exit code:** `0`

---

### Example 10: Error - Missing Metadata File (Exit 1)

**Command:**
```bash
ruby spec_skeleton_generator.rb missing.yml
```

**Output (stderr):**
```
Error: Metadata file not found: missing.yml

Run rspec-analyzer first to generate metadata:
  Use the rspec-write-new skill
```

**Exit code:** `1`

---

### Example 11: Error - Invalid YAML (Exit 1)

**Input file:** (corrupted YAML)
```yaml
target:
  class: Test
characteristics:
  - name: test
    states: [a, b
    # Missing closing bracket
```

**Command:**
```bash
ruby spec_skeleton_generator.rb metadata.yml
```

**Output (stderr):**
```
Error: Cannot parse metadata YAML: metadata.yml
Syntax error: did not find expected ',' or ']'

Check YAML syntax or re-run rspec-analyzer
```

**Exit code:** `1`

## Usage in Pipeline

### After rspec-analyzer

**Pattern:**
```bash
# Analyzer just wrote metadata
metadata_path="tmp/rspec_claude_metadata/metadata_app_services_payment.yml"

# Generate skeleton
spec_file=$(ruby lib/rspec_automation/generators/spec_skeleton_generator.rb "$metadata_path")
exit_code=$?

if [ $exit_code -eq 1 ]; then
  echo "L Skeleton generation failed" >&2
  exit 1
fi

if [ $exit_code -eq 2 ]; then
  echo " Skeleton generated with warnings" >&2
  # Continue anyway
fi

echo " Skeleton generated: $spec_file"

# Update metadata
yq -i ".automation.skeleton_generated = true" "$metadata_path"
yq -i ".automation.skeleton_file = \"$spec_file\"" "$metadata_path"
```

---

### Before rspec-architect

**Pattern:**
```bash
# Architect needs skeleton file path
spec_file=$(yq '.automation.skeleton_file' metadata.yml)

if [ ! -f "$spec_file" ]; then
  echo "L Skeleton file not found: $spec_file" >&2
  echo "Run spec_skeleton_generator.rb first" >&2
  exit 1
fi

echo " Skeleton exists, invoking architect..."
# invoke rspec-architect
```

## Implementation Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# spec_skeleton_generator.rb - Generate RSpec skeleton from metadata
#
# Exit 0: Skeleton successfully generated
# Exit 1: Critical error (invalid metadata, file errors)
# Exit 2: Warning (suspicious patterns, but skeleton created)

require 'yaml'
require 'fileutils'

def main
  if ARGV.empty?
    $stderr.puts "Error: Missing metadata file argument"
    $stderr.puts "Usage: #{$PROGRAM_NAME} <metadata_file> [output_file]"
    exit 1
  end

  metadata_path = ARGV[0]
  output_path = ARGV[1]

  unless File.exist?(metadata_path)
    $stderr.puts "Error: Metadata file not found: #{metadata_path}"
    $stderr.puts ""
    $stderr.puts "Run rspec-analyzer first to generate metadata:"
    $stderr.puts "  Use the rspec-write-new skill"
    exit 1
  end

  # Parse metadata
  begin
    metadata = YAML.load_file(metadata_path)
  rescue Psych::SyntaxError => e
    $stderr.puts "Error: Cannot parse metadata YAML: #{metadata_path}"
    $stderr.puts "Syntax error: #{e.message}"
    $stderr.puts ""
    $stderr.puts "Check YAML syntax or re-run rspec-analyzer"
    exit 1
  end

  # Validate required sections
  validate_metadata(metadata)

  # Determine output path if not provided
  output_path ||= determine_spec_path(metadata['target']['file'])

  # Generate skeleton
  warnings = []
  context_tree = build_context_tree(metadata['characteristics'], warnings)

  # Generate RSpec code
  spec_content = generate_full_spec(metadata, context_tree)

  # Write to file
  write_spec_file(output_path, spec_content)

  # Output path
  puts output_path

  # Handle warnings
  if warnings.any?
    warnings.each { |w| $stderr.puts "Warning: #{w}" }
    exit 2
  end

  exit 0
rescue StandardError => e
  $stderr.puts "Error: Unexpected error during skeleton generation"
  $stderr.puts e.message
  $stderr.puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
  exit 1
end

def validate_metadata(metadata)
  raise "Missing target section" unless metadata['target']
  raise "Missing characteristics section" unless metadata['characteristics']
  raise "Missing target.class" unless metadata['target']['class']
  raise "Missing target.method" unless metadata['target']['method']
end

def determine_spec_path(source_file)
  # app/services/payment_service.rb -> spec/services/payment_service_spec.rb

  # Remove app/ prefix
  spec_path = source_file.sub(/^app\//, '')

  # Remove .rb extension
  spec_path = spec_path.sub(/\.rb$/, '')

  # Add _spec.rb suffix
  spec_path = "#{spec_path}_spec.rb"

  # Prepend spec/
  "spec/#{spec_path}"
end

def build_context_tree(characteristics, warnings, current_level = 1, parent_context = nil)
  return [] if characteristics.empty?

  if characteristics.empty? && current_level == 1
    warnings << "No characteristics found in metadata"
    warnings << "Generated minimal skeleton with single it block"
  end

  # Filter characteristics for current level
  level_chars = characteristics.select { |c| c['level'] == current_level }

  # Filter by dependency
  if parent_context
    level_chars = level_chars.select do |c|
      c['depends_on'] == parent_context[:char_name] &&
      c['when_parent'] == parent_context[:state]
    end
  else
    level_chars = level_chars.select { |c| c['depends_on'].nil? }
  end

  contexts = []

  level_chars.each do |char|
    states = order_states(char)

    states.each_with_index do |state, index|
      context_word = determine_context_word(char, state, index, current_level)
      description = format_description(char, state)

      context = {
        word: context_word,
        description: description,
        level: current_level,
        characteristic: char['name'],
        state: state,
        children: []
      }

      # Recurse for nested characteristics
      child_parent = { char_name: char['name'], state: state }
      context[:children] = build_context_tree(
        characteristics,
        warnings,
        current_level + 1,
        child_parent
      )

      # Leaf context: add placeholder it block
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

def order_states(characteristic)
  states = characteristic['states']
  type = characteristic['type']

  if type == 'binary'
    # Detect negative prefix, swap if found
    negative_prefixes = ['not_', 'no_', 'invalid_', 'missing_', 'without_']
    first_state = states[0]

    if negative_prefixes.any? { |prefix| first_state.start_with?(prefix) }
      states.reverse
    else
      states
    end
  else
    # Keep original order for enum/range/sequential
    states
  end
end

def determine_context_word(characteristic, state, state_index, level)
  return 'when' if level == 1

  type = characteristic['type']
  states = characteristic['states']

  case type
  when 'enum', 'sequential'
    'and'
  when 'binary'
    state_index == 0 ? 'with' : 'but'
  when 'range'
    states.length == 2 ? (state_index == 0 ? 'with' : 'but') : 'and'
  else
    '{CONTEXT_WORD}'
  end
end

def format_description(characteristic, state)
  name = characteristic['name']
  type = characteristic['type']

  readable_name = name.gsub('_', ' ')
  readable_state = state.gsub('_', ' ')

  case type
  when 'binary'
    readable_state
  when 'enum', 'sequential', 'range'
    "#{readable_name} is #{readable_state}"
  end
end

def generate_context_code(context_tree, indent_level = 2)
  return "" if context_tree.empty?

  code = []
  indent = '  ' * indent_level

  context_tree.each do |context|
    code << "#{indent}context '#{context[:word]} #{context[:description]}' do"
    code << "#{indent}  {SETUP_CODE}"
    code << ""

    if context[:it_blocks]
      context[:it_blocks].each do |it_block|
        code << "#{indent}  it '#{it_block[:description]}' do"
        code << "#{indent}    {EXPECTATION}"
        code << "#{indent}  end"
      end
    end

    if context[:children].any?
      child_code = generate_context_code(context[:children], indent_level + 1)
      code << ""
      code << child_code
    end

    code << "#{indent}end"
    code << "" unless context == context_tree.last
  end

  code.join("\n")
end

def generate_full_spec(metadata, context_tree)
  target = metadata['target']
  class_name = target['class']
  method_name = target['method']
  method_type = target['method_type']

  method_descriptor = method_type == 'class' ? ".#{method_name}" : "##{method_name}"

  spec = []
  spec << "# frozen_string_literal: true"
  spec << ""
  spec << "RSpec.describe #{class_name} do"
  spec << "  describe '#{method_descriptor}' do"
  spec << "    subject(:result) { service.#{method_name} }  # TODO: Add parameters"
  spec << ""

  if method_type == 'instance'
    spec << "    let(:service) { described_class.new }"
    spec << ""
  end

  spec << "    {COMMON_SETUP}"
  spec << ""

  if context_tree.empty?
    # Minimal skeleton for empty characteristics
    spec << "    it '{BEHAVIOR_DESCRIPTION}' do"
    spec << "      {EXPECTATION}"
    spec << "    end"
  else
    context_code = generate_context_code(context_tree, 2)
    spec << context_code
  end

  spec << "  end"
  spec << "end"

  spec.join("\n")
end

def write_spec_file(output_path, content)
  FileUtils.mkdir_p(File.dirname(output_path))
  File.write(output_path, content)
end

main if __FILE__ == $PROGRAM_NAME
```

## Testing Checklist

Before committing this script, verify:

### Structure Generation
- [ ] describe/context/it hierarchy correct
- [ ] Proper indentation (2 spaces per level)
- [ ] context blocks properly nested
- [ ] it blocks only in leaf contexts

### Context Words
- [ ] Level 1 always "when"
- [ ] Enum always "and"
- [ ] Binary uses "with" / "but"
- [ ] Range (2 states) uses "with" / "but"
- [ ] Range (3+ states) uses "and"

### State Ordering
- [ ] Binary with "not_" prefix swapped
- [ ] Happy path states come first
- [ ] Enum/sequential keep original order

### Placeholders
- [ ] {COMMON_SETUP} at top
- [ ] {SETUP_CODE} in each context
- [ ] {BEHAVIOR_DESCRIPTION} in each it
- [ ] {EXPECTATION} inside it blocks
- [ ] {CONTEXT_WORD} only when ambiguous

### Dependencies
- [ ] Nested contexts only appear in correct parent state
- [ ] when_parent filtering works correctly
- [ ] Multiple root characteristics generate parallel contexts

### Output
- [ ] Valid Ruby syntax
- [ ] Correct file path generated
- [ ] File written successfully
- [ ] Stdout shows path only

### Exit Codes
- [ ] Exits 0 on success
- [ ] Exits 1 on missing file or invalid YAML
- [ ] Exits 2 on warnings (empty characteristics)

## Related Specifications

- **contracts/metadata-format.spec.md** - Input format
- **contracts/exit-codes.spec.md** - Exit code contract
- **contracts/agent-communication.spec.md** - Pipeline integration
- **agents/rspec-architect.spec.md** - Next agent (consumes skeleton)
- **agents/rspec-implementer.spec.md** - Fills expectations
- **algorithms/context-hierarchy.md** - Context building algorithm

---

**Key Takeaway:** spec_skeleton_generator.rb is a mechanical transformer. It converts metadata structure to RSpec structure without semantic understanding. Placeholders allow later agents to add meaning.
