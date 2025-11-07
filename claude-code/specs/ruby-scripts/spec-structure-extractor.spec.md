# spec_structure_extractor.rb Script Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Ruby Script (Parser/Extractor)
**Location:** `lib/rspec_automation/extractors/spec_structure_extractor.rb`

## Purpose

Parses existing RSpec test files using RuboCop AST parser and extracts structure information (describe/context/it hierarchy).

**Why this matters:**
- Enables auditing existing tests structure
- Provides data for refactoring decisions (compare existing vs ideal)
- Extracts patterns for analysis (what contexts exist, how nested)
- Non-destructive inspection tool for legacy tests

**Key Responsibilities:**
1. Parse RSpec file using RuboCop AST parser
2. Extract describe/context/it hierarchy
3. Capture context descriptions and nesting levels
4. Identify setup blocks (let, let!, before, subject)
5. Count examples and contexts
6. Return structured JSON with complete test anatomy

**Important:** This is an **extraction tool**, not a validator. It reports what exists without judging quality.

## Exit Code Contract

| Exit Code | Meaning | stdout | stderr |
|-----------|---------|--------|--------|
| `0` | Success | JSON with structure | Empty |
| `1` | Critical Error | Empty | Error message |
| `2` | Warning | JSON with partial structure | Warning message |

**Exit 0 scenarios:**
- File successfully parsed
- Complete structure extracted

**Exit 1 scenarios:**
- Spec file not found
- Invalid Ruby syntax (cannot parse)
- Not an RSpec file (no describe blocks found)
- RuboCop parser gem not available

**Exit 2 scenarios:**
- File parsed but has suspicious patterns (very deep nesting, empty contexts)
- Some blocks could not be fully analyzed
- Malformed RSpec DSL (still parseable but unusual)

## Command-Line Interface

### Basic Usage

**Usage:**
```bash
ruby lib/rspec_automation/extractors/spec_structure_extractor.rb <spec_file>
```

**Arguments:**
- `<spec_file>`: Path to RSpec test file (required)

**Output (stdout) - JSON:**
```json
{
  "file": "spec/services/payment_service_spec.rb",
  "describe_blocks": [
    {
      "type": "describe",
      "description": "PaymentService",
      "line": 3,
      "children": [
        {
          "type": "describe",
          "description": "#process_payment",
          "line": 4,
          "setup": {
            "subject": ["result"],
            "let": ["service", "user", "amount"],
            "let!": [],
            "before": ["setup payment gateway"]
          },
          "children": [
            {
              "type": "context",
              "description": "when user authenticated",
              "line": 10,
              "children": [
                {
                  "type": "it",
                  "description": "processes payment successfully",
                  "line": 13
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  "stats": {
    "total_contexts": 5,
    "total_examples": 12,
    "max_nesting_depth": 4,
    "has_subject": true,
    "has_let": true
  }
}
```

## Extraction Algorithm

### Step 1: Parse File with RuboCop AST

```ruby
require 'rubocop'
require 'rubocop-rspec'

def parse_spec_file(file_path)
  source = File.read(file_path)

  # Parse with RuboCop AST
  processed_source = RuboCop::ProcessedSource.new(
    source,
    RUBY_VERSION.to_f,
    file_path
  )

  unless processed_source.valid_syntax?
    raise "Invalid Ruby syntax in #{file_path}"
  end

  processed_source.ast
end
```

---

### Step 2: Find RSpec Blocks

**RSpec DSL methods to detect:**
- `describe` / `RSpec.describe` - Top-level or nested describe blocks
- `context` - Context blocks (subdivisions within describe)
- `it` / `specify` / `example` - Example blocks (actual tests)
- `let` / `let!` - Lazy/eager variable definitions
- `subject` - Subject definition
- `before` / `after` - Setup/teardown hooks

**AST Node Types:**
- RSpec blocks: `(block (send nil :describe ...) ...)`
- Context: `(block (send nil :context ...) ...)`
- It blocks: `(block (send nil :it ...) ...)`

```ruby
def rspec_block?(node)
  return false unless node.is_a?(RuboCop::AST::Node)
  return false unless node.type == :block

  send_node = node.children[0]
  return false unless send_node.type == :send

  method_name = send_node.method_name
  [:describe, :context, :it, :specify, :example].include?(method_name)
end
```

---

### Step 3: Extract Block Hierarchy

**Recursive traversal:**

```ruby
def extract_block_structure(node, parent_type = nil, depth = 0)
  return nil unless rspec_block?(node)

  send_node = node.children[0]
  method_name = send_node.method_name
  args = send_node.arguments

  # Extract description
  description = extract_description(args)

  block_info = {
    type: method_name.to_s,
    description: description,
    line: node.loc.line,
    depth: depth,
    children: []
  }

  # Extract setup blocks (let, subject, before) if describe/context
  if [:describe, :context].include?(method_name)
    block_info[:setup] = extract_setup_blocks(node)
  end

  # Recurse into children
  body_node = node.children[2]
  if body_node
    body_node.each_child_node do |child|
      if rspec_block?(child)
        child_structure = extract_block_structure(child, method_name, depth + 1)
        block_info[:children] << child_structure if child_structure
      end
    end
  end

  block_info
end
```

---

### Step 4: Extract Descriptions

**Description extraction from various formats:**

```ruby
def extract_description(args)
  return "unknown" if args.empty?

  first_arg = args[0]

  case first_arg.type
  when :str
    # Simple string: describe 'PaymentService'
    first_arg.str_content

  when :const
    # Constant: describe PaymentService
    const_name(first_arg)

  when :send
    # Method call: describe described_class
    if first_arg.method_name == :described_class
      "described_class"
    else
      first_arg.source
    end

  when :dstr
    # Interpolated string: describe "User #{user.id}"
    first_arg.source

  else
    # Fallback
    first_arg.source
  end
end

def const_name(node)
  # Handle nested constants: Foo::Bar::Baz
  if node.type == :const
    if node.children[0].nil?
      node.children[1].to_s
    else
      "#{const_name(node.children[0])}::#{node.children[1]}"
    end
  else
    node.source
  end
end
```

---

### Step 5: Extract Setup Blocks

**Find let, subject, before inside describe/context:**

```ruby
def extract_setup_blocks(node)
  setup = {
    subject: [],
    let: [],
    let!: [],
    before: [],
    after: []
  }

  body_node = node.children[2]
  return setup unless body_node

  body_node.each_child_node do |child|
    next unless child.type == :block

    send_node = child.children[0]
    next unless send_node.type == :send

    method_name = send_node.method_name

    case method_name
    when :subject
      # subject(:result) { ... }
      args = send_node.arguments
      name = args.empty? ? "subject" : extract_symbol_name(args[0])
      setup[:subject] << name

    when :let
      # let(:user) { ... }
      args = send_node.arguments
      name = extract_symbol_name(args[0]) if args.any?
      setup[:let] << name if name

    when :let!
      # let!(:user) { ... }
      args = send_node.arguments
      name = extract_symbol_name(args[0]) if args.any?
      setup[:let!] << name if name

    when :before, :after
      # before { ... } or before(:each) { ... }
      setup[method_name] << "hook"
    end
  end

  setup
end

def extract_symbol_name(node)
  return nil unless node

  case node.type
  when :sym
    node.children[0].to_s
  when :str
    node.str_content
  else
    node.source
  end
end
```

---

### Step 6: Calculate Statistics

```ruby
def calculate_stats(structure)
  stats = {
    total_contexts: 0,
    total_examples: 0,
    max_nesting_depth: 0,
    has_subject: false,
    has_let: false,
    has_let!: false,
    has_before: false
  }

  count_recursive(structure, stats, 0)

  stats
end

def count_recursive(block_info, stats, depth)
  stats[:max_nesting_depth] = [stats[:max_nesting_depth], depth].max

  case block_info[:type]
  when 'context', 'describe'
    stats[:total_contexts] += 1

    # Check setup
    if block_info[:setup]
      stats[:has_subject] ||= block_info[:setup][:subject].any?
      stats[:has_let] ||= block_info[:setup][:let].any?
      stats[:has_let!] ||= block_info[:setup][:let!].any?
      stats[:has_before] ||= block_info[:setup][:before].any?
    end

  when 'it', 'specify', 'example'
    stats[:total_examples] += 1
  end

  block_info[:children].each do |child|
    count_recursive(child, stats, depth + 1)
  end
end
```

---

### Step 7: Generate JSON Output

```ruby
def generate_output(file_path, structure, stats)
  {
    file: file_path,
    describe_blocks: [structure],
    stats: stats
  }.to_json
end
```

## Output Format

### Complete JSON Schema

```json
{
  "file": "string",
  "describe_blocks": [
    {
      "type": "describe|context|it",
      "description": "string",
      "line": "number",
      "depth": "number",
      "setup": {
        "subject": ["string"],
        "let": ["string"],
        "let!": ["string"],
        "before": ["string"],
        "after": ["string"]
      },
      "children": [
        {
          "type": "...",
          "description": "...",
          "children": []
        }
      ]
    }
  ],
  "stats": {
    "total_contexts": "number",
    "total_examples": "number",
    "max_nesting_depth": "number",
    "has_subject": "boolean",
    "has_let": "boolean",
    "has_let!": "boolean",
    "has_before": "boolean"
  }
}
```

**Field descriptions:**

- `file` - Path to analyzed spec file
- `describe_blocks` - Array of top-level describe blocks
- `type` - Block type: "describe", "context", "it", "specify", "example"
- `description` - Block description text
- `line` - Line number in source file
- `depth` - Nesting level (0 = top-level describe)
- `setup` - Setup blocks found in this describe/context (not in it blocks)
- `children` - Nested blocks (contexts, examples)
- `stats` - Summary statistics

## Complete Examples

### Example 1: Simple Flat Structure (Exit 0)

**Input file: spec/models/user_spec.rb**
```ruby
RSpec.describe User do
  describe '#full_name' do
    subject(:full_name) { user.full_name }

    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns concatenated name' do
      expect(full_name).to eq('John Doe')
    end
  end
end
```

**Command:**
```bash
ruby spec_structure_extractor.rb spec/models/user_spec.rb
```

**Output (stdout):**
```json
{
  "file": "spec/models/user_spec.rb",
  "describe_blocks": [
    {
      "type": "describe",
      "description": "User",
      "line": 1,
      "depth": 0,
      "setup": {
        "subject": [],
        "let": [],
        "let!": [],
        "before": [],
        "after": []
      },
      "children": [
        {
          "type": "describe",
          "description": "#full_name",
          "line": 2,
          "depth": 1,
          "setup": {
            "subject": ["full_name"],
            "let": ["user"],
            "let!": [],
            "before": [],
            "after": []
          },
          "children": [
            {
              "type": "it",
              "description": "returns concatenated name",
              "line": 7,
              "depth": 2
            }
          ]
        }
      ]
    }
  ],
  "stats": {
    "total_contexts": 2,
    "total_examples": 1,
    "max_nesting_depth": 2,
    "has_subject": true,
    "has_let": true,
    "has_let!": false,
    "has_before": false
  }
}
```

**Exit code:** `0`

---

### Example 2: Nested Contexts (Exit 0)

**Input file: spec/services/payment_service_spec.rb**
```ruby
RSpec.describe PaymentService do
  describe '#process_payment' do
    subject(:result) { service.process_payment(user, amount) }

    let(:service) { described_class.new }
    let(:amount) { 100 }

    context 'when user authenticated' do
      let(:user) { create(:user, :authenticated) }

      context 'and payment method is card' do
        let(:payment_method) { :card }

        it 'processes payment' do
          expect(result).to be_success
        end
      end

      context 'and payment method is paypal' do
        let(:payment_method) { :paypal }

        it 'processes via paypal' do
          expect(result).to be_success
        end
      end
    end

    context 'when user not authenticated' do
      let(:user) { build(:user) }

      it 'returns authentication error' do
        expect(result).to be_error
      end
    end
  end
end
```

**Command:**
```bash
ruby spec_structure_extractor.rb spec/services/payment_service_spec.rb
```

**Output (stdout):**
```json
{
  "file": "spec/services/payment_service_spec.rb",
  "describe_blocks": [
    {
      "type": "describe",
      "description": "PaymentService",
      "line": 1,
      "depth": 0,
      "setup": {
        "subject": [],
        "let": [],
        "let!": [],
        "before": [],
        "after": []
      },
      "children": [
        {
          "type": "describe",
          "description": "#process_payment",
          "line": 2,
          "depth": 1,
          "setup": {
            "subject": ["result"],
            "let": ["service", "amount"],
            "let!": [],
            "before": [],
            "after": []
          },
          "children": [
            {
              "type": "context",
              "description": "when user authenticated",
              "line": 8,
              "depth": 2,
              "setup": {
                "subject": [],
                "let": ["user"],
                "let!": [],
                "before": [],
                "after": []
              },
              "children": [
                {
                  "type": "context",
                  "description": "and payment method is card",
                  "line": 11,
                  "depth": 3,
                  "setup": {
                    "subject": [],
                    "let": ["payment_method"],
                    "let!": [],
                    "before": [],
                    "after": []
                  },
                  "children": [
                    {
                      "type": "it",
                      "description": "processes payment",
                      "line": 14,
                      "depth": 4
                    }
                  ]
                },
                {
                  "type": "context",
                  "description": "and payment method is paypal",
                  "line": 19,
                  "depth": 3,
                  "setup": {
                    "subject": [],
                    "let": ["payment_method"],
                    "let!": [],
                    "before": [],
                    "after": []
                  },
                  "children": [
                    {
                      "type": "it",
                      "description": "processes via paypal",
                      "line": 22,
                      "depth": 4
                    }
                  ]
                }
              ]
            },
            {
              "type": "context",
              "description": "when user not authenticated",
              "line": 27,
              "depth": 2,
              "setup": {
                "subject": [],
                "let": ["user"],
                "let!": [],
                "before": [],
                "after": []
              },
              "children": [
                {
                  "type": "it",
                  "description": "returns authentication error",
                  "line": 30,
                  "depth": 3
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  "stats": {
    "total_contexts": 5,
    "total_examples": 3,
    "max_nesting_depth": 4,
    "has_subject": true,
    "has_let": true,
    "has_let!": false,
    "has_before": false
  }
}
```

**Exit code:** `0`

---

### Example 3: With Before Hooks (Exit 0)

**Input file:**
```ruby
RSpec.describe OrderProcessor do
  describe '#process' do
    subject(:process) { processor.process(order) }

    let(:processor) { described_class.new }
    let!(:order) { create(:order) }

    before do
      setup_payment_gateway
    end

    it 'processes order' do
      expect(process).to be_success
    end
  end
end
```

**Output (key parts):**
```json
{
  "setup": {
    "subject": ["process"],
    "let": ["processor"],
    "let!": ["order"],
    "before": ["hook"],
    "after": []
  },
  "stats": {
    "has_let": true,
    "has_let!": true,
    "has_before": true
  }
}
```

**Exit code:** `0`

---

### Example 4: Multiple Top-Level Describes (Exit 0)

**Input file:**
```ruby
RSpec.describe User do
  describe '#activate' do
    it 'activates user' do
      # ...
    end
  end

  describe '#deactivate' do
    it 'deactivates user' do
      # ...
    end
  end
end
```

**Output:**
```json
{
  "describe_blocks": [
    {
      "type": "describe",
      "description": "User",
      "children": [
        {
          "type": "describe",
          "description": "#activate",
          "children": [
            { "type": "it", "description": "activates user" }
          ]
        },
        {
          "type": "describe",
          "description": "#deactivate",
          "children": [
            { "type": "it", "description": "deactivates user" }
          ]
        }
      ]
    }
  ]
}
```

**Exit code:** `0`

---

### Example 5: File Not Found (Exit 1)

**Command:**
```bash
ruby spec_structure_extractor.rb spec/missing_spec.rb
```

**Output (stderr):**
```
Error: Spec file not found: spec/missing_spec.rb

Check file path or create the file first.
```

**Exit code:** `1`

---

### Example 6: Invalid Ruby Syntax (Exit 1)

**Input file:**
```ruby
RSpec.describe User do
  describe '#test' do
    it 'does something' do
      expect(result).to eq(value
      # Missing closing parenthesis
    end
  end
end
```

**Command:**
```bash
ruby spec_structure_extractor.rb spec/broken_spec.rb
```

**Output (stderr):**
```
Error: Invalid Ruby syntax in spec/broken_spec.rb
Syntax error at line 4: unexpected end-of-input, expecting ')'

Fix syntax errors before extraction:
  ruby -c spec/broken_spec.rb
```

**Exit code:** `1`

---

### Example 7: Not an RSpec File (Exit 1)

**Input file: lib/calculator.rb** (not a spec)
```ruby
class Calculator
  def add(a, b)
    a + b
  end
end
```

**Command:**
```bash
ruby spec_structure_extractor.rb lib/calculator.rb
```

**Output (stderr):**
```
Error: No RSpec blocks found in lib/calculator.rb

This does not appear to be an RSpec test file.
Expected: describe, context, or it blocks
```

**Exit code:** `1`

---

### Example 8: Deep Nesting Warning (Exit 2)

**Input file:** (5+ levels deep)
```ruby
RSpec.describe DeepService do
  describe '#method' do
    context 'level 2' do
      context 'level 3' do
        context 'level 4' do
          context 'level 5' do
            context 'level 6' do
              it 'works' do
                # ...
              end
            end
          end
        end
      end
    end
  end
end
```

**Output (stdout):**
```json
{
  "stats": {
    "max_nesting_depth": 7
  }
}
```

**Output (stderr):**
```
Warning: Very deep nesting detected (7 levels)
Consider refactoring to reduce complexity (max recommended: 4 levels)
```

**Exit code:** `2`

---

### Example 9: Empty Contexts (Exit 2)

**Input file:**
```ruby
RSpec.describe EmptyService do
  describe '#method' do
    context 'some condition' do
      # Empty context, no examples
    end

    it 'works' do
      # ...
    end
  end
end
```

**Output (stderr):**
```
Warning: Empty context found at line 3: "some condition"
Context has no examples or nested contexts
```

**Exit code:** `2`

## Usage in Pipeline

### rspec-refactor-legacy (Primary User)

**Pattern:**
```bash
# Extract existing test structure
existing=$(ruby lib/rspec_automation/extractors/spec_structure_extractor.rb "$spec_file")
exit_code=$?

if [ $exit_code -eq 1 ]; then
  echo "L Cannot extract structure from $spec_file" >&2
  exit 1
fi

if [ $exit_code -eq 2 ]; then
  echo "  Structure extracted with warnings" >&2
  # Continue anyway
fi

# Save for comparison
echo "$existing" > /tmp/existing_structure.json

# Extract characteristics from existing structure
existing_contexts=$(echo "$existing" | jq -r '.describe_blocks[].children[].description')

# Compare with ideal (from analyzer)
# ...
```

---

### Analysis and Comparison

**Example comparison workflow:**
```bash
# Extract existing
existing=$(ruby spec_structure_extractor.rb "$spec_file")

# Get ideal from metadata
ideal=$(yq '.characteristics[].name' metadata.yml)

# Find gaps
comm -23 <(echo "$ideal" | sort) <(echo "$existing" | jq -r '... | .description?' | sort)

# Output: characteristics in ideal but missing in existing tests
```

## Implementation Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# spec_structure_extractor.rb - Extract RSpec structure using AST
#
# Exit 0: Structure successfully extracted
# Exit 1: Critical error (file not found, syntax error, not RSpec)
# Exit 2: Warning (deep nesting, empty contexts)

require 'rubocop'
require 'json'

def main
  if ARGV.empty?
    $stderr.puts "Error: Missing spec file argument"
    $stderr.puts "Usage: #{$PROGRAM_NAME} <spec_file>"
    exit 1
  end

  spec_file = ARGV[0]

  unless File.exist?(spec_file)
    $stderr.puts "Error: Spec file not found: #{spec_file}"
    $stderr.puts ""
    $stderr.puts "Check file path or create the file first."
    exit 1
  end

  # Parse file
  ast = parse_spec_file(spec_file)

  # Extract structure
  warnings = []
  structure = extract_top_level_describes(ast, warnings)

  if structure.empty?
    $stderr.puts "Error: No RSpec blocks found in #{spec_file}"
    $stderr.puts ""
    $stderr.puts "This does not appear to be an RSpec test file."
    $stderr.puts "Expected: describe, context, or it blocks"
    exit 1
  end

  # Calculate stats
  stats = calculate_stats(structure)

  # Check for warnings
  check_deep_nesting(stats, warnings)
  check_empty_contexts(structure, warnings)

  # Generate output
  output = {
    file: spec_file,
    describe_blocks: structure,
    stats: stats
  }

  puts output.to_json

  # Handle warnings
  if warnings.any?
    warnings.each { |w| $stderr.puts "Warning: #{w}" }
    exit 2
  end

  exit 0
rescue StandardError => e
  $stderr.puts "Error: #{e.message}"
  $stderr.puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
  exit 1
end

def parse_spec_file(file_path)
  source = File.read(file_path)

  processed_source = RuboCop::ProcessedSource.new(
    source,
    RUBY_VERSION.to_f,
    file_path
  )

  unless processed_source.valid_syntax?
    raise "Invalid Ruby syntax in #{file_path}\n" \
          "Syntax error: #{processed_source.diagnostics.first.message}\n\n" \
          "Fix syntax errors before extraction:\n" \
          "  ruby -c #{file_path}"
  end

  processed_source.ast
end

def extract_top_level_describes(ast, warnings)
  structures = []

  ast.each_node(:block) do |node|
    next unless top_level_describe?(node)

    structure = extract_block_structure(node, 0)
    structures << structure if structure
  end

  structures
end

def top_level_describe?(node)
  send_node = node.children[0]
  return false unless send_node.type == :send
  return false unless send_node.method_name == :describe

  # Check if it's truly top-level (not nested inside another describe)
  parent = node.parent
  while parent
    return false if parent.type == :block && rspec_block?(parent)
    parent = parent.parent
  end

  true
end

def rspec_block?(node)
  return false unless node.type == :block

  send_node = node.children[0]
  return false unless send_node.type == :send

  [:describe, :context, :it, :specify, :example].include?(send_node.method_name)
end

def extract_block_structure(node, depth)
  send_node = node.children[0]
  method_name = send_node.method_name
  args = send_node.arguments

  description = extract_description(args)

  block_info = {
    type: method_name.to_s,
    description: description,
    line: node.loc.line,
    depth: depth,
    children: []
  }

  if [:describe, :context].include?(method_name)
    block_info[:setup] = extract_setup_blocks(node)
  end

  body_node = node.children[2]
  if body_node
    body_node.each_node(:block) do |child|
      next unless rspec_block?(child)

      child_structure = extract_block_structure(child, depth + 1)
      block_info[:children] << child_structure if child_structure
    end
  end

  block_info
end

def extract_description(args)
  return "unknown" if args.empty?

  first_arg = args[0]

  case first_arg.type
  when :str
    first_arg.str_content
  when :const
    const_name(first_arg)
  when :send
    first_arg.method_name == :described_class ? "described_class" : first_arg.source
  else
    first_arg.source
  end
end

def const_name(node)
  if node.type == :const
    if node.children[0].nil?
      node.children[1].to_s
    else
      "#{const_name(node.children[0])}::#{node.children[1]}"
    end
  else
    node.source
  end
end

def extract_setup_blocks(node)
  setup = {
    subject: [],
    let: [],
    let!: [],
    before: [],
    after: []
  }

  body_node = node.children[2]
  return setup unless body_node

  body_node.each_node(:block) do |child|
    send_node = child.children[0]
    next unless send_node.type == :send

    method_name = send_node.method_name

    case method_name
    when :subject
      args = send_node.arguments
      name = args.empty? ? "subject" : extract_symbol_name(args[0])
      setup[:subject] << name if name

    when :let
      args = send_node.arguments
      name = extract_symbol_name(args[0]) if args.any?
      setup[:let] << name if name

    when :let!
      args = send_node.arguments
      name = extract_symbol_name(args[0]) if args.any?
      setup[:let!] << name if name

    when :before, :after
      setup[method_name] << "hook"
    end
  end

  setup
end

def extract_symbol_name(node)
  return nil unless node

  case node.type
  when :sym
    node.children[0].to_s
  when :str
    node.str_content
  else
    node.source
  end
end

def calculate_stats(structures)
  stats = {
    total_contexts: 0,
    total_examples: 0,
    max_nesting_depth: 0,
    has_subject: false,
    has_let: false,
    has_let!: false,
    has_before: false
  }

  structures.each do |structure|
    count_recursive(structure, stats)
  end

  stats
end

def count_recursive(block_info, stats)
  stats[:max_nesting_depth] = [stats[:max_nesting_depth], block_info[:depth]].max

  case block_info[:type]
  when 'context', 'describe'
    stats[:total_contexts] += 1

    if block_info[:setup]
      stats[:has_subject] ||= block_info[:setup][:subject].any?
      stats[:has_let] ||= block_info[:setup][:let].any?
      stats[:has_let!] ||= block_info[:setup][:let!].any?
      stats[:has_before] ||= block_info[:setup][:before].any?
    end

  when 'it', 'specify', 'example'
    stats[:total_examples] += 1
  end

  block_info[:children].each do |child|
    count_recursive(child, stats)
  end
end

def check_deep_nesting(stats, warnings)
  if stats[:max_nesting_depth] > 4
    warnings << "Very deep nesting detected (#{stats[:max_nesting_depth]} levels)"
    warnings << "Consider refactoring to reduce complexity (max recommended: 4 levels)"
  end
end

def check_empty_contexts(structures, warnings)
  structures.each do |structure|
    check_empty_recursive(structure, warnings)
  end
end

def check_empty_recursive(block_info, warnings)
  if [:describe, :context].include?(block_info[:type].to_sym)
    if block_info[:children].empty?
      warnings << "Empty context found at line #{block_info[:line]}: \"#{block_info[:description]}\""
      warnings << "Context has no examples or nested contexts"
    end
  end

  block_info[:children].each do |child|
    check_empty_recursive(child, warnings)
  end
end

main if __FILE__ == $PROGRAM_NAME
```

## Testing Checklist

Before committing this script, verify:

### Parsing
- [ ] Valid RSpec files parse correctly
- [ ] Syntax errors detected and reported
- [ ] Non-RSpec files rejected
- [ ] RuboCop parser gem required

### Structure Extraction
- [ ] describe blocks extracted
- [ ] context blocks extracted
- [ ] it/specify/example blocks extracted
- [ ] Nesting preserved correctly

### Setup Extraction
- [ ] subject blocks detected
- [ ] let blocks detected
- [ ] let! blocks detected
- [ ] before/after hooks detected

### Statistics
- [ ] Total contexts counted correctly
- [ ] Total examples counted correctly
- [ ] Max depth calculated correctly
- [ ] Boolean flags set correctly

### Edge Cases
- [ ] Multiple top-level describes handled
- [ ] Deeply nested contexts (5+ levels) warned
- [ ] Empty contexts detected
- [ ] Nested constants (Foo::Bar::Baz) parsed

### Output
- [ ] Valid JSON produced
- [ ] All fields present
- [ ] Parseable by jq
- [ ] Line numbers accurate

### Exit Codes
- [ ] Exits 0 on success
- [ ] Exits 1 on file not found
- [ ] Exits 1 on syntax error
- [ ] Exits 1 on non-RSpec file
- [ ] Exits 2 on warnings

## Related Specifications

- **contracts/exit-codes.spec.md** - Exit code contract
- **skills/rspec-refactor-legacy.spec.md** - Primary user
- **ruby-scripts/spec-skeleton-generator.spec.md** - Inverse operation (generates structure)

---

**Key Takeaway:** spec_structure_extractor.rb is an audit tool. It reads existing tests and reports structure without judgment. Useful for comparison with ideal structure from analyzer.
