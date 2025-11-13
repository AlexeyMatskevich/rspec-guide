# metadata_validator.rb Script Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Ruby Script (Validator)
**Location:** `lib/rspec_automation/metadata_validator.rb`

## Purpose

Validates metadata YAML files against the schema defined in `contracts/metadata-format.spec.md`.

**Why this matters:**
- Catches errors early before agents consume invalid metadata
- Prevents cascading failures in the pipeline
- Provides clear error messages for debugging
- Ensures metadata completeness and consistency

**Key Responsibilities:**
1. Validate YAML syntax and structure
2. Check all required fields present
3. Validate field types and values
4. Check characteristics dependencies (no circular deps)
5. Verify level consistency with dependency depth
6. Write validation results back to metadata file

## Exit Code Contract

| Exit Code | Meaning | stdout | stderr |
|-----------|---------|--------|--------|
| `0` | Valid metadata | Summary JSON | Empty |
| `1` | Invalid metadata | Empty | Detailed error messages |
| `2` | Valid with warnings | Summary JSON | Warning messages |

**Exit 0 scenarios:**
- All validation rules passed
- No errors, no warnings

**Exit 1 scenarios:**
- YAML syntax error (cannot parse)
- Missing required fields
- Invalid field types
- Circular dependencies detected
- Level inconsistent with dependency depth
- Referenced dependency doesn't exist

**Exit 2 scenarios:**
- `target.file` path doesn't exist on filesystem
- Empty `characteristics` array (valid but no tests will be generated)
- Binary characteristic has != 2 states (expected exactly 2)

## Command-Line Interface

### Basic Usage

**Usage:**
```bash
ruby lib/rspec_automation/metadata_validator.rb <metadata_file>
```

**Arguments:**
- `<metadata_file>`: Path to metadata YAML file

**Output (stdout on success):**
```json
{
  "valid": true,
  "errors": [],
  "warnings": [],
  "metadata_path": "tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml"
}
```

**Output (stderr on error):**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata.yml

Missing required fields:
  - target.class
  - target.method

Circular dependency detected:
  - char_a depends_on char_b
  - char_b depends_on char_a

Please re-run rspec-analyzer to regenerate metadata.
```

## Validation Rules

### Section: `analyzer`

**Required fields:**
- =4 `completed` (boolean): MUST be boolean `true`
- =4 `timestamp` (string): MUST be valid ISO 8601 format
- =4 `source_file_mtime` (integer): MUST be positive integer
- =4 `version` (string): MUST be present

**Validation checks:**
```ruby
# Check 1: Section exists
errors << "Missing section: analyzer" unless metadata['analyzer']

# Check 2: completed is boolean true
unless metadata.dig('analyzer', 'completed') == true
  errors << "analyzer.completed must be boolean true, got: #{metadata.dig('analyzer', 'completed').inspect}"
end

# Check 3: timestamp is valid ISO 8601
timestamp = metadata.dig('analyzer', 'timestamp')
begin
  Time.iso8601(timestamp) if timestamp
rescue ArgumentError
  errors << "analyzer.timestamp must be valid ISO 8601 format, got: #{timestamp}"
end

# Check 4: source_file_mtime is positive integer
mtime = metadata.dig('analyzer', 'source_file_mtime')
unless mtime.is_a?(Integer) && mtime > 0
  errors << "analyzer.source_file_mtime must be positive integer, got: #{mtime.inspect}"
end

# Check 5: version present
errors << "Missing analyzer.version" unless metadata.dig('analyzer', 'version')
```

---

### Section: `validation`

**Note:** This section is written BY this script, so it may not exist when validating.

**If present:**
- `completed` (boolean)
- `errors` (array of strings)
- `warnings` (array of strings)

**Behavior:**
- Script OVERWRITES this section with validation results
- If section missing: creates it
- If section present: replaces it

---

### Section: `test_level`

**Required field:**
- =4 `test_level` (string): MUST be one of: `unit`, `integration`, `request`, `e2e`

**Validation checks:**
```ruby
test_level = metadata['test_level']

unless %w[unit integration request e2e].include?(test_level)
  errors << "test_level must be one of: unit, integration, request, e2e (got: #{test_level.inspect})"
end
```

---

### Section: `target`

**Required fields:**
- =4 `class` (string): Ruby class name (valid constant)
- =4 `method` (string): Ruby method name (valid identifier)
- =4 `method_type` (string): `instance` or `class`
- =4 `file` (string): File path

**Optional fields:**
- =á `uses_models` (boolean)

**Validation checks:**
```ruby
target = metadata['target']
errors << "Missing section: target" unless target

# Check required fields present
%w[class method method_type file].each do |field|
  errors << "Missing target.#{field}" unless target&.key?(field)
end

# Validate class name (Ruby constant)
class_name = target&.dig('class')
unless class_name =~ /^[A-Z][a-zA-Z0-9_]*(::[A-Z][a-zA-Z0-9_]*)*$/
  errors << "target.class must be valid Ruby constant name, got: #{class_name.inspect}"
end

# Validate method name (Ruby identifier)
method_name = target&.dig('method')
unless method_name =~ /^[a-z_][a-zA-Z0-9_]*[?!=]?$/
  errors << "target.method must be valid Ruby method name, got: #{method_name.inspect}"
end

# Validate method_type
method_type = target&.dig('method_type')
unless %w[instance class].include?(method_type)
  errors << "target.method_type must be 'instance' or 'class', got: #{method_type.inspect}"
end

# Validate file exists (optional - may not exist during test)
file_path = target&.dig('file')
if file_path && !File.exist?(file_path)
  warnings << "target.file does not exist: #{file_path}"
end
```

---

### Section: `characteristics`

**Required field:**
- =4 `characteristics` (array): Array of characteristic hashes

**Per characteristic, required fields:**
- =4 `name` (string): Unique within characteristics
- =4 `type` (string): `binary`, `enum`, `range`, `sequential`
- =4 `setup` (string): `data` or `action`
- =4 `states` (array): 2+ string elements
- =4 `default` (string or null): If not null, must be in `states`
- =4 `depends_on` (string or null): If not null, must reference existing characteristic
- =4 `when_parent` (string or null): Required if `depends_on` not null
- =4 `level` (integer): >= 1
- =á `threshold_value` (integer/float or null): Optional, for range type
- =á `threshold_operator` (string or null): Optional, for range type

**Validation checks:**

#### Check 1: Array structure
```ruby
chars = metadata['characteristics']

unless chars.is_a?(Array)
  errors << "characteristics must be an array, got: #{chars.class}"
  return # Cannot continue validation
end

if chars.empty?
  warnings << "characteristics array is empty - no test structure will be generated"
end
```

#### Check 2: Required fields per characteristic
```ruby
chars.each_with_index do |char, idx|
  %w[name type setup states default depends_on level].each do |field|
    unless char.key?(field)
      errors << "characteristics[#{idx}] missing required field: #{field}"
    end
  end
end
```

#### Check 3: Unique names
```ruby
names = chars.map { |c| c['name'] }
duplicates = names.select { |n| names.count(n) > 1 }.uniq

duplicates.each do |dup|
  errors << "Duplicate characteristic name: #{dup}"
end
```

#### Check 4: Valid types
```ruby
chars.each_with_index do |char, idx|
  type = char['type']
  unless %w[binary enum range sequential].include?(type)
    errors << "characteristics[#{idx}].type must be one of: binary, enum, range, sequential (got: #{type.inspect})"
  end
end
```

#### Check 5: States validation
```ruby
chars.each_with_index do |char, idx|
  states = char['states']

  # Must be array
  unless states.is_a?(Array)
    errors << "characteristics[#{idx}].states must be an array, got: #{states.class}"
    next
  end

  # Must have 2+ elements
  if states.length < 2
    errors << "characteristics[#{idx}].states must have at least 2 elements, got: #{states.length}"
  end

  # Must be strings
  states.each_with_index do |state, state_idx|
    unless state.is_a?(String)
      errors << "characteristics[#{idx}].states[#{state_idx}] must be string, got: #{state.class}"
    end
  end

  # Warning: binary should have exactly 2 states
  if char['type'] == 'binary' && states.length != 2
    warnings << "characteristics[#{idx}] has type 'binary' but #{states.length} states (expected 2)"
  end
end
```

#### Check 6: Source validation (optional)
```ruby
chars.each_with_index do |char, idx|
  source = char['source']

  # Source is optional, skip if not present
  next if source.nil?

  # Must be string
  unless source.is_a?(String)
    errors << "characteristics[#{idx}].source must be string, got: #{source.class}"
    next
  end

  # Must match format "path:N" or "path:N-M"
  # Pattern: any_path.rb:123 or any_path.rb:123-456
  unless source.match?(/^.+:\d+(-\d+)?$/)
    errors << "characteristics[#{idx}].source must match format 'path:line' or 'path:line-line', got: #{source.inspect}"
  end

  # If range format, validate start < end
  if source.match(/^.+:(\d+)-(\d+)$/)
    start_line = $1.to_i
    end_line = $2.to_i
    if start_line >= end_line
      errors << "characteristics[#{idx}].source range invalid: start line #{start_line} >= end line #{end_line}"
    end
  end
end
```

#### Check 7: Default validation
```ruby
chars.each_with_index do |char, idx|
  default = char['default']
  states = char['states']

  next if default.nil?

  unless states.include?(default)
    errors << "characteristics[#{idx}].default '#{default}' not in states: #{states.inspect}"
  end
end
```

#### Check 8: Dependency validation
```ruby
char_names = chars.map { |c| c['name'] }

chars.each_with_index do |char, idx|
  depends_on = char['depends_on']
  when_parent = char['when_parent']

  # If depends_on is null, when_parent must be null
  if depends_on.nil? && !when_parent.nil?
    errors << "characteristics[#{idx}].when_parent must be null when depends_on is null"
  end

  # If depends_on is not null
  if depends_on
    # Must reference existing characteristic
    unless char_names.include?(depends_on)
      errors << "characteristics[#{idx}].depends_on references unknown characteristic: #{depends_on}"
    end

    # when_parent must be present and must be array
    if when_parent.nil?
      errors << "characteristics[#{idx}].when_parent required when depends_on is not null"
    elsif !when_parent.is_a?(Array)
      errors << "characteristics[#{idx}].when_parent must be array, got: #{when_parent.class}"
    elsif when_parent.empty?
      errors << "characteristics[#{idx}].when_parent array cannot be empty"
    else
      # All when_parent values must be in parent's states
      parent_char = chars.find { |c| c['name'] == depends_on }
      if parent_char
        parent_states = parent_char['states'] || []
        invalid_states = when_parent - parent_states
        unless invalid_states.empty?
          errors << "characteristics[#{idx}].when_parent contains invalid states: #{invalid_states.inspect} (parent states: #{parent_states.inspect})"
        end
      end
    end
  end
end
```

#### Check 9: No circular dependencies
```ruby
def detect_circular_dependency(chars)
  visited = Set.new
  path = []

  chars.each do |char|
    next if visited.include?(char['name'])

    if has_cycle?(char, chars, visited, path)
      return path.join(' -> ')
    end
  end

  nil
end

def has_cycle?(char, all_chars, visited, path)
  return true if path.include?(char['name'])  # Cycle detected

  path << char['name']
  visited << char['name']

  if char['depends_on']
    parent = all_chars.find { |c| c['name'] == char['depends_on'] }
    return has_cycle?(parent, all_chars, visited, path) if parent
  end

  path.pop
  false
end

# Usage
if cycle = detect_circular_dependency(chars)
  errors << "Circular dependency detected: #{cycle}"
end
```

#### Check 10: Level consistency
```ruby
chars.each_with_index do |char, idx|
  level = char['level']

  # Level must be integer >= 1
  unless level.is_a?(Integer) && level >= 1
    errors << "characteristics[#{idx}].level must be integer >= 1, got: #{level.inspect}"
    next
  end

  # If has dependency, level must be parent.level + 1
  if char['depends_on']
    parent = chars.find { |c| c['name'] == char['depends_on'] }
    if parent
      expected_level = parent['level'] + 1
      if level != expected_level
        errors << "characteristics[#{idx}].level=#{level} but parent.level=#{parent['level']} (expected #{expected_level})"
      end
    end
  end
end

# Collect all levels for global validation
levels = chars.map { |c| c['level'] }.compact

# Check: all levels must be unique
if levels.uniq.length != levels.length
  duplicates = levels.group_by { |l| l }.select { |_, v| v.size > 1 }.keys
  errors << "characteristics: duplicate levels found: #{duplicates.inspect}"
end

# Check: levels must be sequential without gaps (1,2,3... not 1,3,5)
sorted_levels = levels.sort
expected_sequence = (sorted_levels.first..sorted_levels.last).to_a
if sorted_levels != expected_sequence
  missing = expected_sequence - sorted_levels
  errors << "characteristics: levels must be sequential, missing levels: #{missing.inspect}"
end
```

#### Check 11: terminal_states validation
```ruby
chars.each_with_index do |char, idx|
  terminal_states = char['terminal_states']

  # Optional field - skip if not present
  next if terminal_states.nil?

  # Must be array
  unless terminal_states.is_a?(Array)
    errors << "characteristics[#{idx}].terminal_states must be array, got: #{terminal_states.class}"
    next
  end

  # All values must be in char's own states
  states = char['states'] || []
  invalid = terminal_states - states
  unless invalid.empty?
    errors << "characteristics[#{idx}].terminal_states contains invalid states: #{invalid.inspect} (valid states: #{states.inspect})"
  end
end

# Warning: child depends on terminal parent state
chars.each_with_index do |char, idx|
  next unless char['depends_on']

  parent = chars.find { |c| c['name'] == char['depends_on'] }
  next unless parent

  parent_terminals = parent['terminal_states'] || []
  when_parent = char['when_parent'] || []

  conflicts = when_parent & parent_terminals
  unless conflicts.empty?
    warnings << "characteristics[#{idx}] depends on terminal states: #{conflicts.inspect} (parent '#{parent['name']}' marks these as terminal - child contexts won't be generated)"
  end
end
```

#### Check 12: setup field validation
```ruby
chars.each_with_index do |char, idx|
  setup = char['setup']

  # Required field
  if setup.nil?
    errors << "characteristics[#{idx}] missing required field: setup"
    next
  end

  # Must be string
  unless setup.is_a?(String)
    errors << "characteristics[#{idx}].setup must be string, got: #{setup.class}"
    next
  end

  # Must be valid value
  unless %w[data action].include?(setup)
    errors << "characteristics[#{idx}].setup must be 'data' or 'action', got: #{setup.inspect}"
  end
end
```

#### Check 13: threshold fields validation (for range type)
```ruby
chars.each_with_index do |char, idx|
  type = char['type']
  threshold_value = char['threshold_value']
  threshold_operator = char['threshold_operator']

  if type == 'range'
    # For range characteristics, threshold fields are optional but must be valid if present

    # Validate threshold_value if present
    if threshold_value && !threshold_value.nil?
      unless threshold_value.is_a?(Integer) || threshold_value.is_a?(Float)
        errors << "characteristics[#{idx}].threshold_value must be integer or float, got: #{threshold_value.class}"
      end

      # Warning for float threshold
      if threshold_value.is_a?(Float)
        warnings << "characteristics[#{idx}].threshold_value is float - skeleton-generator will use placeholder (manual value required)"
      end
    end

    # Validate threshold_operator if present
    if threshold_operator && !threshold_operator.nil?
      unless %w[>= > <= <].include?(threshold_operator)
        errors << "characteristics[#{idx}].threshold_operator must be one of: >=, >, <=, <, got: #{threshold_operator.inspect}"
      end
    end

    # Consistency check: value without operator
    if threshold_value && !threshold_value.nil? && (threshold_operator.nil? || threshold_operator.empty?)
      warnings << "characteristics[#{idx}].threshold_value present but threshold_operator missing"
    end

    # Consistency check: operator without value
    if (threshold_value.nil? || threshold_value.empty?) && threshold_operator && !threshold_operator.empty?
      warnings << "characteristics[#{idx}].threshold_operator present but threshold_value missing"
    end
  else
    # For non-range types, threshold fields should not be present
    if threshold_value && !threshold_value.nil?
      warnings << "characteristics[#{idx}].threshold_value should only be used with range type (current type: #{type})"
    end

    if threshold_operator && !threshold_operator.empty?
      warnings << "characteristics[#{idx}].threshold_operator should only be used with range type (current type: #{type})"
    end
  end
end
```

---

### Section: `factories_detected`

**Optional section** - may be empty object `{}`

**If present, per factory:**
- =4 `file` (string): Path to factory file
- =4 `traits` (array): Array of trait names (may be empty)

**Validation checks:**
```ruby
factories = metadata['factories_detected']

if factories && !factories.is_a?(Hash)
  errors << "factories_detected must be a hash, got: #{factories.class}"
end

factories&.each do |factory_name, factory_data|
  unless factory_data.is_a?(Hash)
    errors << "factories_detected.#{factory_name} must be a hash"
    next
  end

  unless factory_data.key?('file')
    errors << "factories_detected.#{factory_name} missing 'file' key"
  end

  unless factory_data.key?('traits')
    errors << "factories_detected.#{factory_name} missing 'traits' key"
  end

  traits = factory_data['traits']
  unless traits.is_a?(Array)
    errors << "factories_detected.#{factory_name}.traits must be an array"
  end
end
```

---

### Section: `automation`

**Optional section** - flexible structure

**Common fields (all optional):**
- `analyzer_completed` (boolean)
- `architect_completed` (boolean)
- `implementer_completed` (boolean)
- `polisher_completed` (boolean)
- `errors` (array)
- `warnings` (array)

**Validation:** Permissive - agents can add custom fields

---

## Validation Output Format

### Success (Exit 0)

**stdout:**
```json
{
  "valid": true,
  "errors": [],
  "warnings": [],
  "metadata_path": "tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml"
}
```

**stderr:** (empty)

**Metadata file updated:**
```yaml
# ... (existing content unchanged)

validation:
  completed: true
  errors: []
  warnings: []
```

---

### Invalid (Exit 1)

**stdout:** (empty)

**stderr:**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata.yml

Missing required fields:
  - target.class
  - target.method

Field validation errors:
  - characteristics[0].states must have at least 2 elements, got: 1
  - characteristics[1].depends_on references unknown characteristic: user_auth

Circular dependency detected:
  - payment_method -> card_valid -> payment_method

Please re-run rspec-analyzer to regenerate metadata.
```

**Metadata file updated:**
```yaml
# ... (existing content unchanged)

validation:
  completed: false
  errors:
    - "Missing target.class"
    - "Missing target.method"
    - "characteristics[0].states must have at least 2 elements"
    - "Circular dependency detected: payment_method -> card_valid -> payment_method"
  warnings: []
```

---

### Valid with Warnings (Exit 2)

**stdout:**
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    "characteristics[0] has only 1 state (should have 2+)",
    "target.file does not exist: app/services/missing.rb"
  ],
  "metadata_path": "tmp/rspec_claude_metadata/metadata.yml"
}
```

**stderr:**
```
Warning: characteristics[0] has only 1 state (should have 2+)
Warning: target.file does not exist: app/services/missing.rb
```

**Metadata file updated:**
```yaml
# ... (existing content unchanged)

validation:
  completed: true
  errors: []
  warnings:
    - "characteristics[0] has only 1 state (should have 2+)"
    - "target.file does not exist: app/services/missing.rb"
```

## Complete Examples

### Example 1: Valid Metadata (Exit 0)

**Input file:** `tmp/rspec_claude_metadata/metadata_app_services_discount.yml`

```yaml
analyzer:
  completed: true
  timestamp: '2025-11-07T10:30:45Z'
  source_file_mtime: 1699351530
  version: '1.0'

test_level: unit

target:
  class: DiscountCalculator
  method: calculate
  method_type: instance
  file: app/services/discount_calculator.rb

characteristics:
  - name: customer_type
    type: enum
    states: [regular, premium, vip]
    default: null
    depends_on: null
    when_parent: null
    level: 1

factories_detected: {}
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_app_services_discount.yml
```

**Output (stdout):**
```json
{"valid":true,"errors":[],"warnings":[],"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_discount.yml"}
```

**Exit code:** `0`

**Metadata file after validation:**
```yaml
# ... (all existing content)

validation:
  completed: true
  errors: []
  warnings: []
```

---

### Example 2: Missing Required Fields (Exit 1)

**Input file:** `tmp/rspec_claude_metadata/metadata_broken.yml`

```yaml
analyzer:
  completed: true
  timestamp: '2025-11-07T10:30:45Z'
  source_file_mtime: 1699351530
  version: '1.0'

test_level: unit

target:
  # Missing 'class' field!
  method: process_payment
  method_type: instance
  file: app/services/payment_service.rb

characteristics:
  - name: payment_method
    type: enum
    states: [card, paypal]
    default: null
    depends_on: null
    when_parent: null
    level: 1
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_broken.yml
echo "Exit code: $?"
```

**Output (stderr):**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata_broken.yml

Missing required fields:
  - target.class

Please re-run rspec-analyzer to regenerate metadata.
```

**Exit code:** `1`

**Metadata file after validation:**
```yaml
# ... (all existing content)

validation:
  completed: false
  errors:
    - "Missing target.class"
  warnings: []
```

---

### Example 3: Circular Dependency (Exit 1)

**Input file:** `tmp/rspec_claude_metadata/metadata_circular.yml`

```yaml
analyzer:
  completed: true
  timestamp: '2025-11-07T10:30:45Z'
  source_file_mtime: 1699351530
  version: '1.0'

test_level: unit

target:
  class: PaymentService
  method: process
  method_type: instance
  file: app/services/payment_service.rb

characteristics:
  - name: char_a
    type: binary
    states: [yes, no]
    default: null
    depends_on: char_b
    when_parent: yes
    level: 2

  - name: char_b
    type: binary
    states: [yes, no]
    default: null
    depends_on: char_a
    when_parent: yes
    level: 2
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_circular.yml
```

**Output (stderr):**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata_circular.yml

Circular dependency detected:
  - char_a -> char_b -> char_a

Please re-run rspec-analyzer to fix dependency structure.
```

**Exit code:** `1`

---

### Example 4a: Level Gap (Exit 1)

**Input file:** `tmp/rspec_claude_metadata/metadata_level_gap.yml`

```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: payment_method
    type: enum
    states: [card, paypal]
    default: null
    depends_on: user_authenticated
    when_parent: authenticated
    level: 5  # L Should be 2, not 5! (level gap: 1 -> 5)
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_level_gap.yml
```

**Output (stderr):**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata_level_gap.yml

Field validation errors:
  - characteristics[1].level=5 but parent.level=1 (expected 2)
  - characteristics: levels must be sequential, missing levels: [2, 3, 4]
```

**Exit code:** `1`

---

### Example 4b: Duplicate Levels (Exit 1)

**Input file:** `tmp/rspec_claude_metadata/metadata_duplicate_levels.yml`

```yaml
characteristics:
  - name: user_authenticated
    type: binary
    states: [authenticated, not_authenticated]
    default: null
    depends_on: null
    when_parent: null
    level: 1

  - name: user_role
    type: enum
    states: [admin, user]
    default: null
    depends_on: null
    when_parent: null
    level: 1  # L ERROR: duplicate level! Each characteristic must have unique level
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_duplicate_levels.yml
```

**Output (stderr):**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata_duplicate_levels.yml

Field validation errors:
  - characteristics: duplicate levels found: [1]
```

**Exit code:** `1`

---

### Example 5: Invalid Dependency Reference (Exit 1)

**Input file:** `tmp/rspec_claude_metadata/metadata_invalid_dep.yml`

```yaml
characteristics:
  - name: payment_method
    type: enum
    states: [card, paypal]
    default: null
    depends_on: user_authenticated  # L This characteristic doesn't exist!
    when_parent: authenticated
    level: 2
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_invalid_dep.yml
```

**Output (stderr):**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata_invalid_dep.yml

Field validation errors:
  - characteristics[0].depends_on references unknown characteristic: user_authenticated
```

**Exit code:** `1`

---

### Example 6: Valid with Warnings (Exit 2)

**Input file:** `tmp/rspec_claude_metadata/metadata_warnings.yml`

```yaml
analyzer:
  completed: true
  timestamp: '2025-11-07T10:30:45Z'
  source_file_mtime: 1699351530
  version: '1.0'

test_level: unit

target:
  class: Calculator
  method: calculate
  method_type: instance
  file: app/services/missing.rb  #   File doesn't exist

characteristics:
  - name: input_type
    type: binary
    states: [valid, invalid]
    default: null
    depends_on: null
    when_parent: null
    level: 1

factories_detected: {}
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_warnings.yml
```

**Output (stdout):**
```json
{"valid":true,"errors":[],"warnings":["target.file does not exist: app/services/missing.rb"],"metadata_path":"tmp/rspec_claude_metadata/metadata_warnings.yml"}
```

**Output (stderr):**
```
Warning: target.file does not exist: app/services/missing.rb
```

**Exit code:** `2`

---

### Example 7: YAML Syntax Error (Exit 1)

**Input file:** `tmp/rspec_claude_metadata/metadata_corrupt.yml`

```yaml
analyzer:
  completed: true
  timestamp: '2025-11-07T10:30:45Z'
  source_file_mtime: 1699351530
characteristics:
  - name: test
    type: enum
    states: [a, b
    # L Missing closing bracket!
```

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/metadata_corrupt.yml
```

**Output (stderr):**
```
Error: Cannot parse YAML file: tmp/rspec_claude_metadata/metadata_corrupt.yml
Syntax error: (<unknown>): did not find expected ',' or ']' while parsing a flow sequence at line 7 column 5

Please check YAML syntax or re-run rspec-analyzer.
```

**Exit code:** `1`

---

### Example 8: File Not Found (Exit 1)

**Command:**
```bash
ruby metadata_validator.rb tmp/rspec_claude_metadata/missing.yml
```

**Output (stderr):**
```
Error: Metadata file not found: tmp/rspec_claude_metadata/missing.yml

If you're creating a new test, run rspec-analyzer first:
  Use the rspec-write-new skill
```

**Exit code:** `1`

## Usage in Agents

### rspec-analyzer (After Writing Metadata)

**Pattern:**
```bash
# Write metadata file
metadata_path=$(ruby lib/rspec_automation/metadata_helper.rb path "$source_file")
cat > "$metadata_path" <<EOF
analyzer:
  completed: true
  # ... rest of metadata
EOF

# Validate what we just wrote
if ! ruby lib/rspec_automation/metadata_validator.rb "$metadata_path"; then
  echo "L Generated invalid metadata (bug in analyzer)" >&2
  exit 1
fi

echo " Metadata validated successfully"
```

---

### Other Agents (Before Reading Metadata)

**Pattern:**
```bash
metadata_path=$(ruby lib/rspec_automation/metadata_helper.rb path "$source_file")

# Validate before using
validation=$(ruby lib/rspec_automation/metadata_validator.rb "$metadata_path" 2>&1)
exit_code=$?

if [ $exit_code -eq 1 ]; then
  echo "L Invalid metadata:" >&2
  echo "$validation" >&2
  echo "Run rspec-analyzer to regenerate" >&2
  exit 1
fi

if [ $exit_code -eq 2 ]; then
  echo "  Metadata has warnings:" >&2
  echo "$validation" >&2
  echo "Continuing anyway..." >&2
fi

# Metadata valid, proceed
```

## Implementation Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# metadata_validator.rb - Validate metadata YAML against schema
#
# Exit 0: Valid metadata
# Exit 1: Invalid metadata (errors present)
# Exit 2: Valid metadata with warnings

require 'yaml'
require 'json'
require 'set'
require 'time'

def main
  if ARGV.empty?
    $stderr.puts "Error: Missing metadata file argument"
    $stderr.puts "Usage: #{$PROGRAM_NAME} <metadata_file>"
    exit 1
  end

  metadata_file = ARGV[0]

  unless File.exist?(metadata_file)
    $stderr.puts "Error: Metadata file not found: #{metadata_file}"
    $stderr.puts ""
    $stderr.puts "If you're creating a new test, run rspec-analyzer first:"
    $stderr.puts "  Use the rspec-write-new skill"
    exit 1
  end

  # Parse YAML
  begin
    metadata = YAML.load_file(metadata_file)
  rescue Psych::SyntaxError => e
    $stderr.puts "Error: Cannot parse YAML file: #{metadata_file}"
    $stderr.puts "Syntax error: #{e.message}"
    $stderr.puts ""
    $stderr.puts "Please check YAML syntax or re-run rspec-analyzer."
    exit 1
  end

  # Validate
  errors = []
  warnings = []

  validate_analyzer_section(metadata, errors, warnings)
  validate_test_level(metadata, errors, warnings)
  validate_target_section(metadata, errors, warnings)
  validate_characteristics_section(metadata, errors, warnings)
  validate_factories_detected(metadata, errors, warnings)

  # Write validation results back to metadata
  write_validation_results(metadata_file, metadata, errors, warnings)

  # Output and exit
  if errors.any?
    print_errors(metadata_file, errors)
    exit 1
  elsif warnings.any?
    print_warnings(warnings)
    puts({ valid: true, errors: [], warnings: warnings, metadata_path: metadata_file }.to_json)
    exit 2
  else
    puts({ valid: true, errors: [], warnings: [], metadata_path: metadata_file }.to_json)
    exit 0
  end
rescue StandardError => e
  $stderr.puts "Error: Unexpected validation error: #{e.message}"
  $stderr.puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
  exit 1
end

def validate_analyzer_section(metadata, errors, warnings)
  unless metadata['analyzer']
    errors << "Missing section: analyzer"
    return
  end

  analyzer = metadata['analyzer']

  # completed must be boolean true
  unless analyzer['completed'] == true
    errors << "analyzer.completed must be boolean true, got: #{analyzer['completed'].inspect}"
  end

  # timestamp must be valid ISO 8601
  timestamp = analyzer['timestamp']
  if timestamp
    begin
      Time.iso8601(timestamp)
    rescue ArgumentError
      errors << "analyzer.timestamp must be valid ISO 8601 format, got: #{timestamp}"
    end
  else
    errors << "Missing analyzer.timestamp"
  end

  # source_file_mtime must be positive integer
  mtime = analyzer['source_file_mtime']
  unless mtime.is_a?(Integer) && mtime > 0
    errors << "analyzer.source_file_mtime must be positive integer, got: #{mtime.inspect}"
  end

  # version must be present
  errors << "Missing analyzer.version" unless analyzer['version']
end

def validate_test_level(metadata, errors, warnings)
  test_level = metadata['test_level']

  unless %w[unit integration request e2e].include?(test_level)
    errors << "test_level must be one of: unit, integration, request, e2e (got: #{test_level.inspect})"
  end
end

def validate_target_section(metadata, errors, warnings)
  target = metadata['target']

  unless target
    errors << "Missing section: target"
    return
  end

  # Required fields
  %w[class method method_type file].each do |field|
    errors << "Missing target.#{field}" unless target.key?(field)
  end

  # Validate class name
  class_name = target['class']
  if class_name && class_name !~ /^[A-Z][a-zA-Z0-9_]*(::[A-Z][a-zA-Z0-9_]*)*$/
    errors << "target.class must be valid Ruby constant name, got: #{class_name.inspect}"
  end

  # Validate method name
  method_name = target['method']
  if method_name && method_name !~ /^[a-z_][a-zA-Z0-9_]*[?!=]?$/
    errors << "target.method must be valid Ruby method name, got: #{method_name.inspect}"
  end

  # Validate method_type
  method_type = target['method_type']
  unless %w[instance class].include?(method_type)
    errors << "target.method_type must be 'instance' or 'class', got: #{method_type.inspect}"
  end

  # Check file exists (warning only)
  file_path = target['file']
  if file_path && !File.exist?(file_path)
    warnings << "target.file does not exist: #{file_path}"
  end
end

def validate_characteristics_section(metadata, errors, warnings)
  chars = metadata['characteristics']

  unless chars.is_a?(Array)
    errors << "characteristics must be an array, got: #{chars.class}"
    return
  end

  warnings << "characteristics array is empty - no test structure will be generated" if chars.empty?

  validate_characteristic_fields(chars, errors, warnings)
  validate_unique_names(chars, errors)
  validate_types(chars, errors)
  validate_states(chars, errors, warnings)
  validate_defaults(chars, errors)
  validate_dependencies(chars, errors)
  validate_circular_dependencies(chars, errors)
  validate_levels(chars, errors)
  validate_terminal_states(chars, errors, warnings)
end

def validate_characteristic_fields(chars, errors, warnings)
  chars.each_with_index do |char, idx|
    %w[name type states default depends_on level].each do |field|
      errors << "characteristics[#{idx}] missing required field: #{field}" unless char.key?(field)
    end
  end
end

def validate_unique_names(chars, errors)
  names = chars.map { |c| c['name'] }
  duplicates = names.select { |n| names.count(n) > 1 }.uniq

  duplicates.each do |dup|
    errors << "Duplicate characteristic name: #{dup}"
  end
end

def validate_types(chars, errors)
  chars.each_with_index do |char, idx|
    type = char['type']
    unless %w[binary enum range sequential].include?(type)
      errors << "characteristics[#{idx}].type must be one of: binary, enum, range, sequential (got: #{type.inspect})"
    end
  end
end

def validate_states(chars, errors, warnings)
  chars.each_with_index do |char, idx|
    states = char['states']

    unless states.is_a?(Array)
      errors << "characteristics[#{idx}].states must be an array, got: #{states.class}"
      next
    end

    if states.length < 2
      errors << "characteristics[#{idx}].states must have at least 2 elements, got: #{states.length}"
    end

    states.each_with_index do |state, state_idx|
      unless state.is_a?(String)
        errors << "characteristics[#{idx}].states[#{state_idx}] must be string, got: #{state.class}"
      end
    end

    if char['type'] == 'binary' && states.length != 2
      warnings << "characteristics[#{idx}] has type 'binary' but #{states.length} states (expected 2)"
    end
  end
end

def validate_defaults(chars, errors)
  chars.each_with_index do |char, idx|
    default = char['default']
    states = char['states']

    next if default.nil?

    unless states&.include?(default)
      errors << "characteristics[#{idx}].default '#{default}' not in states: #{states.inspect}"
    end
  end
end

def validate_dependencies(chars, errors)
  char_names = chars.map { |c| c['name'] }

  chars.each_with_index do |char, idx|
    depends_on = char['depends_on']
    when_parent = char['when_parent']

    if depends_on.nil? && !when_parent.nil?
      errors << "characteristics[#{idx}].when_parent must be null when depends_on is null"
    end

    if depends_on
      unless char_names.include?(depends_on)
        errors << "characteristics[#{idx}].depends_on references unknown characteristic: #{depends_on}"
      end

      if when_parent.nil?
        errors << "characteristics[#{idx}].when_parent required when depends_on is not null"
      elsif !when_parent.is_a?(Array)
        errors << "characteristics[#{idx}].when_parent must be array, got: #{when_parent.class}"
      elsif when_parent.empty?
        errors << "characteristics[#{idx}].when_parent array cannot be empty"
      else
        parent_char = chars.find { |c| c['name'] == depends_on }
        if parent_char
          parent_states = parent_char['states'] || []
          invalid_states = when_parent - parent_states
          unless invalid_states.empty?
            errors << "characteristics[#{idx}].when_parent contains invalid states: #{invalid_states.inspect} (parent states: #{parent_states.inspect})"
          end
        end
      end
    end
  end
end

def validate_circular_dependencies(chars, errors)
  cycle = detect_circular_dependency(chars)
  errors << "Circular dependency detected: #{cycle}" if cycle
end

def detect_circular_dependency(chars)
  chars.each do |char|
    visited = Set.new
    path = []

    if has_cycle?(char, chars, visited, path)
      return path.join(' -> ')
    end
  end

  nil
end

def has_cycle?(char, all_chars, visited, path)
  return true if path.include?(char['name'])

  path << char['name']
  visited << char['name']

  if char['depends_on']
    parent = all_chars.find { |c| c['name'] == char['depends_on'] }
    if parent && has_cycle?(parent, all_chars, visited, path.dup)
      return true
    end
  end

  false
end

def validate_levels(chars, errors)
  chars.each_with_index do |char, idx|
    level = char['level']

    unless level.is_a?(Integer) && level >= 1
      errors << "characteristics[#{idx}].level must be integer >= 1, got: #{level.inspect}"
      next
    end

    if char['depends_on']
      parent = chars.find { |c| c['name'] == char['depends_on'] }
      if parent
        expected_level = parent['level'] + 1
        if level != expected_level
          errors << "characteristics[#{idx}].level=#{level} but parent.level=#{parent['level']} (expected #{expected_level})"
        end
      end
    end
  end

  # Collect all levels for global validation
  levels = chars.map { |c| c['level'] }.compact

  # Check: all levels must be unique
  if levels.uniq.length != levels.length
    duplicates = levels.group_by { |l| l }.select { |_, v| v.size > 1 }.keys
    errors << "characteristics: duplicate levels found: #{duplicates.inspect}"
  end

  # Check: levels must be sequential without gaps (1,2,3... not 1,3,5)
  sorted_levels = levels.sort
  expected_sequence = (sorted_levels.first..sorted_levels.last).to_a
  if sorted_levels != expected_sequence
    missing = expected_sequence - sorted_levels
    errors << "characteristics: levels must be sequential, missing levels: #{missing.inspect}"
  end
end

def validate_terminal_states(chars, errors, warnings)
  chars.each_with_index do |char, idx|
    terminal_states = char['terminal_states']

    # Optional field - skip if not present
    next if terminal_states.nil?

    # Must be array
    unless terminal_states.is_a?(Array)
      errors << "characteristics[#{idx}].terminal_states must be array, got: #{terminal_states.class}"
      next
    end

    # All values must be in char's own states
    states = char['states'] || []
    invalid = terminal_states - states
    unless invalid.empty?
      errors << "characteristics[#{idx}].terminal_states contains invalid states: #{invalid.inspect} (valid states: #{states.inspect})"
    end
  end

  # Warning: child depends on terminal parent state
  chars.each_with_index do |char, idx|
    next unless char['depends_on']

    parent = chars.find { |c| c['name'] == char['depends_on'] }
    next unless parent

    parent_terminals = parent['terminal_states'] || []
    when_parent = char['when_parent'] || []

    conflicts = when_parent & parent_terminals
    unless conflicts.empty?
      warnings << "characteristics[#{idx}] depends on terminal states: #{conflicts.inspect} (parent '#{parent['name']}' marks these as terminal - child contexts won't be generated)"
    end
  end
end

def validate_factories_detected(metadata, errors, warnings)
  factories = metadata['factories_detected']
  return unless factories

  unless factories.is_a?(Hash)
    errors << "factories_detected must be a hash, got: #{factories.class}"
    return
  end

  factories.each do |factory_name, factory_data|
    unless factory_data.is_a?(Hash)
      errors << "factories_detected.#{factory_name} must be a hash"
      next
    end

    errors << "factories_detected.#{factory_name} missing 'file' key" unless factory_data.key?('file')
    errors << "factories_detected.#{factory_name} missing 'traits' key" unless factory_data.key?('traits')

    traits = factory_data['traits']
    unless traits.is_a?(Array)
      errors << "factories_detected.#{factory_name}.traits must be an array"
    end
  end
end

def write_validation_results(metadata_file, metadata, errors, warnings)
  metadata['validation'] = {
    'completed' => errors.empty?,
    'errors' => errors,
    'warnings' => warnings
  }

  File.write(metadata_file, metadata.to_yaml)
end

def print_errors(metadata_file, errors)
  $stderr.puts "Error: Invalid metadata format in #{metadata_file}"
  $stderr.puts ""

  $stderr.puts "Validation errors:"
  errors.each do |error|
    $stderr.puts "  - #{error}"
  end

  $stderr.puts ""
  $stderr.puts "Please re-run rspec-analyzer to regenerate metadata."
end

def print_warnings(warnings)
  warnings.each do |warning|
    $stderr.puts "Warning: #{warning}"
  end
end

main if __FILE__ == $PROGRAM_NAME
```

## Testing Checklist

Before committing this script, verify:

### YAML Parsing
- [ ] Valid YAML parses correctly
- [ ] Syntax errors detected with clear message
- [ ] Empty file handled gracefully

### Required Fields
- [ ] Missing `analyzer.completed`  error
- [ ] Missing `target.class`  error
- [ ] Missing `characteristics[].name`  error
- [ ] All required fields checked

### Field Validation
- [ ] `test_level` must be unit/integration/request/e2e
- [ ] `target.class` must be valid Ruby constant
- [ ] `target.method` must be valid Ruby identifier
- [ ] `characteristics[].type` must be binary/enum/range/sequential

### Characteristics Validation
- [ ] Duplicate names detected
- [ ] States must have 2+ elements
- [ ] Default must be in states
- [ ] Circular dependencies detected
- [ ] Level consistency validated

### Exit Codes
- [ ] Exits 0 on valid metadata
- [ ] Exits 1 on errors
- [ ] Exits 2 on warnings only

### Metadata Update
- [ ] Validation section written on success
- [ ] Validation section written on failure (with errors)
- [ ] Original metadata preserved

### Integration
- [ ] Works with rspec-analyzer output
- [ ] Agents can parse JSON output
- [ ] Error messages are actionable

## Related Specifications

- **contracts/metadata-format.spec.md** - Schema being validated
- **contracts/exit-codes.spec.md** - Exit code contract
- **agents/rspec-analyzer.spec.md** - Writes metadata that gets validated
- **ruby-scripts/metadata-helper.spec.md** - Provides metadata paths

---

**Key Takeaway:** metadata_validator.rb is the gatekeeper. Invalid metadata MUST NOT pass. Clear errors guide users to fix issues.
