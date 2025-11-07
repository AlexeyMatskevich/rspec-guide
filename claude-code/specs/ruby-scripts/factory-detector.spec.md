# factory_detector.rb Script Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Ruby Script (Scanner)
**Location:** `lib/rspec_automation/factory_detector.rb`

## Purpose

Scans FactoryBot factory files and extracts factory names and traits.

**Why this matters:**
- Provides inventory of existing factories for test generation
- Identifies available traits for characteristic mapping
- Helps factory-optimizer reuse existing traits
- Informational only - does NOT influence characteristic extraction

**Key Responsibilities:**
1. Find all factory files in `spec/factories/` directory
2. Extract factory names from `factory :name` declarations
3. Extract trait names from `trait :name` blocks
4. Return structured JSON/YAML with factory inventory

**Important:** This is a **discovery tool**, not an analyzer. It only reports what exists, doesn't make decisions.

## Exit Code Contract

| Exit Code | Meaning | stdout | stderr |
|-----------|---------|--------|--------|
| `0` | Success | JSON with factories | Empty |
| `1` | Critical Error | Empty | Error message |
| `2` | Warning | JSON with factories | Warning message |

**Exit 0 scenarios:**
- Factories found and scanned successfully
- No factories found (returns empty `{}`) - this is normal for new projects

**Exit 1 scenarios:**
- `spec/factories/` directory doesn't exist AND no factories found
- Cannot read factory files (permission denied)
- Invalid Ruby syntax in factory files (cannot parse)

**Exit 2 scenarios:**
- Factory file found but no traits defined (valid but unusual)
- Factory file has suspicious patterns (e.g., empty factory block)
- Some factory files unreadable (partial results returned)

## Command-Line Interface

### Basic Usage

**Usage:**
```bash
ruby lib/rspec_automation/factory_detector.rb [factories_dir]
```

**Arguments:**
- `[factories_dir]` (optional): Path to factories directory. Default: `spec/factories`

**Output (stdout):**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": ["admin", "blocked", "premium"]
  },
  "product": {
    "file": "spec/factories/products.rb",
    "traits": ["with_image", "with_reviews", "reindex"]
  }
}
```

**Output format:** JSON (for easy parsing by agents)

## Detection Algorithm

### Step 1: Find Factory Files

**Search paths (in order):**
1. Provided directory argument (if given)
2. `spec/factories/` (default)
3. `test/factories/` (alternative)

**Pattern:** `*.rb` files recursively

**Example:**
```bash
# Default search
ruby factory_detector.rb
# -> Scans spec/factories/**/*.rb

# Custom directory
ruby factory_detector.rb test/factories
# -> Scans test/factories/**/*.rb
```

---

### Step 2: Extract Factory Names

**Pattern matching:**
```ruby
# Match factory declarations
/^\s*factory\s+:(\w+)/

# Also match with do blocks
/^\s*factory\s+:(\w+)\s+do/
/^\s*factory\s+:(\w+),/  # with options
```

**Supported syntaxes:**

```ruby
# Basic factory
factory :user do
  # ...
end
# -> Extracts: "user"

# Factory with parent
factory :admin, parent: :user do
  # ...
end
# -> Extracts: "admin" (not "user")

# Factory with class
factory :user, class: 'Person' do
  # ...
end
# -> Extracts: "user"

# Factory with aliases
factory :user, aliases: [:author, :commenter] do
  # ...
end
# -> Extracts: "user" (aliases ignored for now)
```

**Edge cases:**

```ruby
# Nested factories (child factories)
factory :user do
  factory :admin do  # Child factory
    # ...
  end
end
# -> Extracts: "user" and "admin" (both as separate factories)

# Multiple FactoryBot.define blocks
FactoryBot.define do
  factory :user do
    # ...
  end
end

FactoryBot.define do
  factory :post do
    # ...
  end
end
# -> Extracts: "user" and "post"
```

---

### Step 3: Extract Trait Names

**Pattern matching:**
```ruby
# Match trait declarations
/^\s*trait\s+:(\w+)/
```

**Supported syntaxes:**

```ruby
# Basic trait
trait :admin do
  role { 'admin' }
end
# -> Extracts: "admin"

# Trait with block
trait :with_posts do
  after(:create) do |user|
    create_list(:post, 3, user: user)
  end
end
# -> Extracts: "with_posts"

# Multiple traits in same factory
factory :user do
  trait :admin do
    # ...
  end

  trait :blocked do
    # ...
  end

  trait :premium do
    # ...
  end
end
# -> Extracts: ["admin", "blocked", "premium"]
```

**Edge cases:**

```ruby
# Transient attributes (not traits, ignore)
transient do
  posts_count { 5 }
end
# -> NOT extracted (not a trait)

# Callbacks (not traits, ignore)
after(:create) do |user|
  # ...
end
# -> NOT extracted (not a trait)

# Sequences (not traits, ignore)
sequence(:email) { |n| "user#{n}@example.com" }
# -> NOT extracted (not a trait)
```

---

### Step 4: Associate Traits with Factories

**Algorithm:**
1. Parse file line by line
2. Track current factory context (inside which `factory` block we are)
3. When `trait` found, associate it with current factory
4. Handle nested factories correctly

**Example:**

```ruby
# Input file: spec/factories/users.rb
FactoryBot.define do
  factory :user do
    name { "John" }

    trait :admin do
      role { 'admin' }
    end

    trait :blocked do
      blocked_at { Time.current }
    end
  end

  factory :guest do
    name { "Guest" }

    trait :temporary do
      expires_at { 1.day.from_now }
    end
  end
end

# Output:
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": ["admin", "blocked"]
  },
  "guest": {
    "file": "spec/factories/users.rb",
    "traits": ["temporary"]
  }
}
```

---

### Step 5: Handle Edge Cases

**Case 1: Factory with no traits**
```ruby
factory :simple_user do
  name { "John" }
end

# Output:
{
  "simple_user": {
    "file": "spec/factories/users.rb",
    "traits": []
  }
}
```

**Case 2: Multiple files for same factory (should not happen, but handle)**
```ruby
# spec/factories/users.rb
factory :user do
  trait :admin
end

# spec/factories/user_extras.rb (bad practice!)
factory :user do
  trait :premium
end

# Output: Keep last occurrence, warn
{
  "user": {
    "file": "spec/factories/user_extras.rb",
    "traits": ["premium"]
  }
}
# stderr: "Warning: Duplicate factory :user found in user_extras.rb (previous: users.rb)"
```

**Case 3: Empty factories directory**
```ruby
# spec/factories/ directory exists but empty

# Output:
{}
```

**Case 4: No factories directory**
```ruby
# spec/factories/ doesn't exist

# Output:
{}
# stderr: "Warning: Factories directory not found: spec/factories"
```

## Complete Examples

### Example 1: Standard Rails Project (Exit 0)

**Directory structure:**
```
spec/factories/
  users.rb
  posts.rb
  comments.rb
```

**File: spec/factories/users.rb**
```ruby
FactoryBot.define do
  factory :user do
    name { "John Doe" }
    email { "john@example.com" }

    trait :admin do
      role { 'admin' }
    end

    trait :blocked do
      blocked_at { Time.current }
    end

    trait :premium do
      subscription_tier { 'premium' }
    end
  end
end
```

**File: spec/factories/posts.rb**
```ruby
FactoryBot.define do
  factory :post do
    title { "Sample Post" }
    user

    trait :published do
      published_at { Time.current }
    end

    trait :with_comments do
      after(:create) do |post|
        create_list(:comment, 3, post: post)
      end
    end
  end
end
```

**File: spec/factories/comments.rb**
```ruby
FactoryBot.define do
  factory :comment do
    body { "Nice post!" }
    post
    user
  end
end
```

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": ["admin", "blocked", "premium"]
  },
  "post": {
    "file": "spec/factories/posts.rb",
    "traits": ["published", "with_comments"]
  },
  "comment": {
    "file": "spec/factories/comments.rb",
    "traits": []
  }
}
```

**Exit code:** `0`

---

### Example 2: Nested Factories (Exit 0)

**File: spec/factories/users.rb**
```ruby
FactoryBot.define do
  factory :user do
    name { "John Doe" }

    factory :admin do
      role { 'admin' }

      trait :super_admin do
        permissions { 'all' }
      end
    end

    factory :guest do
      role { 'guest' }
    end
  end
end
```

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": []
  },
  "admin": {
    "file": "spec/factories/users.rb",
    "traits": ["super_admin"]
  },
  "guest": {
    "file": "spec/factories/users.rb",
    "traits": []
  }
}
```

**Exit code:** `0`

**Note:** Nested factories are treated as separate factories.

---

### Example 3: No Factories Found (Exit 0)

**Scenario:** New project, no factories yet

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{}
```

**Output (stderr):**
```
Warning: Factories directory not found: spec/factories
This is normal for new projects without FactoryBot setup.
```

**Exit code:** `2` (warning)

---

### Example 4: Complex Traits (Exit 0)

**File: spec/factories/products.rb**
```ruby
FactoryBot.define do
  factory :product do
    name { "Product Name" }
    price { 100 }

    trait :with_image do
      after(:create) do |product|
        product.image.attach(
          io: File.open('spec/fixtures/image.png'),
          filename: 'image.png'
        )
      end
    end

    trait :with_reviews do
      transient do
        review_count { 3 }
      end

      after(:create) do |product, evaluator|
        create_list(:review, evaluator.review_count, product: product)
      end
    end

    trait :discounted do
      discount_percent { 20 }
    end

    trait :out_of_stock do
      stock_quantity { 0 }
    end
  end
end
```

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{
  "product": {
    "file": "spec/factories/products.rb",
    "traits": ["with_image", "with_reviews", "discounted", "out_of_stock"]
  }
}
```

**Exit code:** `0`

---

### Example 5: Factory with Aliases (Exit 0)

**File: spec/factories/users.rb**
```ruby
FactoryBot.define do
  factory :user, aliases: [:author, :commenter] do
    name { "John Doe" }

    trait :verified do
      verified_at { Time.current }
    end
  end
end
```

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": ["verified"]
  }
}
```

**Exit code:** `0`

**Note:** Aliases are ignored - only primary factory name extracted.

---

### Example 6: Custom Factories Directory (Exit 0)

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb test/factories
```

**Output (stdout):**
```json
{
  "user": {
    "file": "test/factories/users.rb",
    "traits": ["admin"]
  }
}
```

**Exit code:** `0`

---

### Example 7: Unreadable Factory File (Exit 2)

**Scenario:** Permission denied on one factory file

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": ["admin"]
  }
}
```

**Output (stderr):**
```
Warning: Cannot read factory file: spec/factories/protected.rb
Permission denied. Skipping this file.
```

**Exit code:** `2` (partial results)

---

### Example 8: Syntax Error in Factory File (Exit 1)

**File: spec/factories/broken.rb**
```ruby
FactoryBot.define do
  factory :broken do
    name { "Test"
    # Missing closing brace!
  end
end
```

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stderr):**
```
Error: Cannot parse factory file: spec/factories/broken.rb
Syntax error at line 3: unexpected end-of-input, expecting '}'

This may indicate invalid Ruby syntax in factory definition.
Run: ruby -c spec/factories/broken.rb
```

**Exit code:** `1`

---

### Example 9: Duplicate Factory Names (Exit 2)

**File: spec/factories/users.rb**
```ruby
FactoryBot.define do
  factory :user do
    trait :admin
  end
end
```

**File: spec/factories/user_extras.rb**
```ruby
FactoryBot.define do
  factory :user do
    trait :premium
  end
end
```

**Command:**
```bash
ruby lib/rspec_automation/factory_detector.rb
```

**Output (stdout):**
```json
{
  "user": {
    "file": "spec/factories/user_extras.rb",
    "traits": ["premium"]
  }
}
```

**Output (stderr):**
```
Warning: Duplicate factory :user found in spec/factories/user_extras.rb
Previous definition: spec/factories/users.rb
Using latest definition. Consider consolidating factories.
```

**Exit code:** `2`

## Usage in Agents

### rspec-analyzer (Primary User)

**Pattern:**
```bash
# Detect factories
factories_json=$(ruby lib/rspec_automation/factory_detector.rb 2>/tmp/factory_warnings)
exit_code=$?

if [ $exit_code -eq 1 ]; then
  echo "L Factory detection failed:" >&2
  cat /tmp/factory_warnings >&2
  echo "Continuing without factory information..." >&2
  factories_json="{}"
fi

if [ $exit_code -eq 2 ]; then
  echo " Factory detection warnings:" >&2
  cat /tmp/factory_warnings >&2
fi

# Add to metadata
echo "factories_detected:" >> metadata.yml
echo "$factories_json" | yq -P >> metadata.yml
```

---

### rspec-factory-optimizer (Consumer)

**Pattern:**
```bash
# Read factories from metadata
factories=$(yq '.factories_detected' metadata.yml)

# Check if specific factory exists
if echo "$factories" | jq -e '.user' > /dev/null; then
  echo "Factory :user exists"

  # Check if trait exists
  if echo "$factories" | jq -e '.user.traits[] | select(. == "admin")' > /dev/null; then
    echo "Trait :admin exists, can use: build_stubbed(:user, :admin)"
  else
    echo "Trait :admin missing, will use attributes: build_stubbed(:user, role: 'admin')"
  fi
fi
```

## Implementation Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# factory_detector.rb - Scan FactoryBot factories and extract traits
#
# Exit 0: Success (factories found or none exist)
# Exit 1: Critical error (cannot read files, syntax errors)
# Exit 2: Warning (partial results, unusual patterns)

require 'json'

def main
  factories_dir = ARGV[0] || 'spec/factories'

  unless Dir.exist?(factories_dir)
    # Try alternative location
    factories_dir = 'test/factories' unless Dir.exist?('test/factories')
  end

  unless Dir.exist?(factories_dir)
    $stderr.puts "Warning: Factories directory not found: #{factories_dir}"
    $stderr.puts "This is normal for new projects without FactoryBot setup."
    puts({}.to_json)
    exit 2
  end

  factory_files = Dir.glob(File.join(factories_dir, '**', '*.rb'))

  if factory_files.empty?
    $stderr.puts "Warning: No factory files found in: #{factories_dir}"
    puts({}.to_json)
    exit 2
  end

  warnings = []
  factories = {}

  factory_files.each do |file|
    begin
      detected = scan_factory_file(file)

      detected.each do |factory_name, factory_data|
        if factories.key?(factory_name)
          warnings << "Duplicate factory :#{factory_name} found in #{file}"
          warnings << "Previous definition: #{factories[factory_name]['file']}"
          warnings << "Using latest definition. Consider consolidating factories."
        end

        factories[factory_name] = factory_data
      end
    rescue StandardError => e
      $stderr.puts "Error: Cannot parse factory file: #{file}"
      $stderr.puts e.message
      exit 1
    end
  end

  # Output results
  puts factories.to_json

  # Print warnings if any
  if warnings.any?
    warnings.each { |w| $stderr.puts "Warning: #{w}" }
    exit 2
  end

  exit 0
rescue StandardError => e
  $stderr.puts "Error: Unexpected error during factory detection"
  $stderr.puts e.message
  $stderr.puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
  exit 1
end

def scan_factory_file(file)
  content = File.read(file)
  factories = {}
  current_factory = nil
  factory_stack = []

  content.each_line.with_index do |line, _idx|
    # Match factory declaration
    if line =~ /^\s*factory\s+:(\w+)/
      factory_name = Regexp.last_match(1)
      factory_stack << current_factory if current_factory
      current_factory = factory_name
      factories[factory_name] = {
        'file' => file,
        'traits' => []
      }
    end

    # Match trait declaration
    if line =~ /^\s*trait\s+:(\w+)/ && current_factory
      trait_name = Regexp.last_match(1)
      factories[current_factory]['traits'] << trait_name
    end

    # Detect end of factory block (simplified heuristic)
    if line =~ /^\s*end\s*$/ && current_factory
      current_factory = factory_stack.pop
    end
  end

  factories
end

main if __FILE__ == $PROGRAM_NAME
```

## Testing Checklist

Before committing this script, verify:

### Factory Detection
- [ ] Detects basic factories (`factory :user`)
- [ ] Detects factories with options (`factory :admin, parent: :user`)
- [ ] Detects nested factories (child factories)
- [ ] Handles multiple `FactoryBot.define` blocks

### Trait Detection
- [ ] Detects basic traits (`trait :admin`)
- [ ] Detects multiple traits in same factory
- [ ] Associates traits with correct factory
- [ ] Ignores transient attributes
- [ ] Ignores callbacks (after, before)

### Edge Cases
- [ ] Empty factories directory -> `{}` with warning
- [ ] No factories directory -> `{}` with warning
- [ ] Factory with no traits -> empty array `[]`
- [ ] Duplicate factory names -> warning, use latest
- [ ] Unreadable files -> partial results, warning

### Exit Codes
- [ ] Exits 0 on success (factories found or none)
- [ ] Exits 1 on syntax errors
- [ ] Exits 2 on warnings (partial results)

### Output Format
- [ ] Valid JSON
- [ ] Correct structure (file + traits per factory)
- [ ] Parseable by jq
- [ ] Works with yq for YAML conversion

### Integration
- [ ] Works with rspec-analyzer
- [ ] Output matches metadata-format.spec.md
- [ ] Validates with metadata_validator.rb

## Related Specifications

- **contracts/metadata-format.spec.md** - `factories_detected` section schema
- **contracts/exit-codes.spec.md** - Exit code contract
- **agents/rspec-analyzer.spec.md** - Invokes this script
- **agents/rspec-factory-optimizer.spec.md** - Consumes factory data

---

**Key Takeaway:** factory_detector.rb is a discovery tool. It reports what exists, doesn't make decisions. Purely informational for other agents.
