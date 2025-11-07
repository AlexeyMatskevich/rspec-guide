# Exit Codes Contract Specification

**Version:** 1.0
**Created:** 2025-11-07
**Applies To:** All Ruby scripts in `lib/rspec_automation/`

## Purpose

Defines standard exit code contract for communication between Ruby scripts and subagents.

**Why this matters:**
- Subagents must know if script succeeded, failed, or warns
- Consistent contract across all Ruby scripts
- Enables fail-fast behavior

## Exit Code Contract

### 🔴 MUST Follow

All Ruby scripts MUST use exactly these exit codes:

| Exit Code | Meaning | stdout | stderr | Subagent Action |
|-----------|---------|--------|--------|-----------------|
| `0` | Success | Data output (JSON/YAML/path) | Empty or informational logs | ✅ Continue, use stdout data |
| `1` | Critical Error | Empty or partial | Error message (human-readable) | ❌ ABORT entire pipeline, show stderr to user |
| `2` | Warning | Data output (may be partial) | Warning message (human-readable) | ⚠️ Continue, log warning, use stdout data |

### Stream Usage Rules

**stdout (standard output):**
- 🔴 MUST contain ONLY structured data or file paths
- 🔴 MUST NOT contain debug messages, progress indicators, or casual text
- 🔴 MUST be parseable (JSON, YAML, or plain path string)
- Example: `{"user": {"file": "spec/factories/users.rb", "traits": ["admin"]}}`
- Example: `tmp/rspec_claude_metadata/metadata_app_models_user.yml`

**stderr (standard error):**
- 🔴 MUST contain ONLY error messages or warnings
- 🔴 MUST be human-readable (plain English text)
- 🔴 MUST start with "Error:" for exit 1, "Warning:" for exit 2
- 🟡 SHOULD include context (file name, line number, what failed)
- Example: `Error: Source file not found: app/services/missing.rb`
- Example: `Warning: No traits found in factory file: spec/factories/users.rb`

### Exit Code Decision Tree

```
Script execution completes
    │
    ├─ All operations successful?
    │   └─ YES → exit 0, data to stdout, nothing to stderr
    │
    ├─ Recoverable issue found?
    │   └─ YES (can continue with partial/alternative data)
    │       └─ exit 2, partial data to stdout, warning to stderr
    │
    └─ Unrecoverable error?
        └─ YES (cannot produce valid output)
            └─ exit 1, nothing to stdout, error to stderr
```

## Examples

### Example 1: Success (Exit 0)

**Script:** `factory_detector.rb`

**Command:**
```bash
ruby lib/rspec_automation/extractors/factory_detector.rb
```

**Exit Code:** `0`

**stdout:**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": ["admin", "blocked", "premium"]
  },
  "order": {
    "file": "spec/factories/orders.rb",
    "traits": ["with_items", "completed"]
  }
}
```

**stderr:** (empty)

**Subagent Action:**
```bash
output=$(ruby factory_detector.rb 2>/tmp/err)
exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "✅ Factories detected successfully"
  # Parse JSON from $output
  # Continue with next step
fi
```

---

### Example 2: Warning (Exit 2)

**Script:** `factory_detector.rb`

**Scenario:** Factories found but no traits defined

**Command:**
```bash
ruby lib/rspec_automation/extractors/factory_detector.rb
```

**Exit Code:** `2`

**stdout:**
```json
{
  "user": {
    "file": "spec/factories/users.rb",
    "traits": []
  }
}
```

**stderr:**
```
Warning: No traits found in factory file: spec/factories/users.rb
This may indicate factory needs traits for characteristics, or factory is too simple.
```

**Subagent Action:**
```bash
output=$(ruby factory_detector.rb 2>/tmp/err)
exit_code=$?

if [ $exit_code -eq 2 ]; then
  echo "⚠️ Factory detection completed with warnings"
  cat /tmp/err  # Show warning to user
  # Still parse JSON from $output
  # Continue with next step (factory-optimizer will handle missing traits)
fi
```

---

### Example 3: Critical Error (Exit 1)

**Script:** `metadata_validator.rb`

**Scenario:** metadata.yml missing required field

**Command:**
```bash
ruby lib/rspec_automation/validators/metadata_validator.rb tmp/rspec_claude_metadata/metadata.yml
```

**Exit Code:** `1`

**stdout:** (empty)

**stderr:**
```
Error: Invalid metadata format in tmp/rspec_claude_metadata/metadata.yml
Missing required field: target.class

Expected structure:
target:
  class: ClassName
  method: method_name
  file: path/to/file.rb

Please check the metadata file or re-run rspec-analyzer.
```

**Subagent Action:**
```bash
output=$(ruby metadata_validator.rb metadata.yml 2>/tmp/err)
exit_code=$?

if [ $exit_code -eq 1 ]; then
  echo "❌ Validation failed"
  cat /tmp/err  # Show error to user
  exit 1  # ABORT entire pipeline, DO NOT CONTINUE
fi
```

---

### Example 4: Edge Case - File Not Found (Exit 1)

**Script:** `spec_structure_extractor.rb`

**Scenario:** Spec file doesn't exist

**Command:**
```bash
ruby lib/rspec_automation/extractors/spec_structure_extractor.rb spec/models/missing_spec.rb
```

**Exit Code:** `1`

**stdout:** (empty)

**stderr:**
```
Error: Spec file not found: spec/models/missing_spec.rb

If you're creating a new test, this is expected.
If you're refactoring existing test, check the file path.
```

**Subagent Action:**
```bash
if ! ruby spec_structure_extractor.rb "$spec_file" 2>&1; then
  echo "❌ Cannot extract spec structure"
  echo "File may not exist or is not a valid Ruby file"
  exit 1
fi
```

---

### Example 5: Edge Case - Parsing Error (Exit 1)

**Script:** `spec_structure_extractor.rb`

**Scenario:** Spec file has syntax errors

**Command:**
```bash
ruby lib/rspec_automation/extractors/spec_structure_extractor.rb spec/models/user_spec.rb
```

**Exit Code:** `1`

**stdout:** (empty)

**stderr:**
```
Error: Cannot parse spec file: spec/models/user_spec.rb
Syntax error at line 15: unexpected end-of-input, expecting keyword_end

This may be a Ruby syntax error in the spec file.
Run: ruby -c spec/models/user_spec.rb
```

**Subagent Action:**
```bash
# Same as Example 4 - abort on exit 1
```

## Implementation Template

### Ruby Script Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Script purpose: [describe what this does]
# Exit 0: [when this happens]
# Exit 1: [when this happens]
# Exit 2: [when this happens]

require 'json'
require 'yaml'

def main
  # Validate input arguments
  if ARGV.empty?
    $stderr.puts "Error: Missing required argument"
    $stderr.puts "Usage: #{$PROGRAM_NAME} <argument>"
    exit 1
  end

  input_file = ARGV[0]

  # Check prerequisites
  unless File.exist?(input_file)
    $stderr.puts "Error: File not found: #{input_file}"
    exit 1
  end

  # Main logic
  result = perform_analysis(input_file)

  # Handle warnings
  if result[:warnings].any?
    result[:warnings].each do |warning|
      $stderr.puts "Warning: #{warning}"
    end
    puts result[:data].to_json
    exit 2
  end

  # Success
  puts result[:data].to_json
  exit 0

rescue ArgumentError => e
  $stderr.puts "Error: Invalid argument - #{e.message}"
  exit 1
rescue JSON::ParserError, Psych::SyntaxError => e
  $stderr.puts "Error: Cannot parse file - #{e.message}"
  exit 1
rescue StandardError => e
  $stderr.puts "Error: Unexpected error - #{e.message}"
  $stderr.puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
  exit 1
end

def perform_analysis(file)
  # Implementation
  { data: {}, warnings: [] }
end

# Run main function
main if __FILE__ == $PROGRAM_NAME
```

### Subagent Handling Template

```bash
#!/usr/bin/env bash

# Invoke Ruby script and capture output/error
script_output=$(ruby lib/rspec_automation/script.rb "$input_file" 2>/tmp/script_err_$$)
exit_code=$?

case $exit_code in
  0)
    echo "✅ Script completed successfully"
    # Use $script_output (contains data)
    ;;

  2)
    echo "⚠️ Script completed with warnings:"
    cat /tmp/script_err_$$
    # Still use $script_output (may be partial but usable)
    ;;

  1)
    echo "❌ Script failed:"
    cat /tmp/script_err_$$
    # ABORT - do not continue
    rm -f /tmp/script_err_$$
    exit 1
    ;;

  *)
    echo "❌ Unexpected exit code: $exit_code"
    cat /tmp/script_err_$$
    rm -f /tmp/script_err_$$
    exit 1
    ;;
esac

# Cleanup
rm -f /tmp/script_err_$$
```

## Common Mistakes to Avoid

### ❌ BAD: Mixed output in stdout

```ruby
puts "Analyzing file..."  # NO! This is not data
result = analyze
puts result.to_json      # OK
```

**Why bad:** Subagent cannot parse "Analyzing file..." as JSON

**Fix:**
```ruby
$stderr.puts "Analyzing file..." if ENV['VERBOSE']  # Debug to stderr
puts result.to_json                                  # Data to stdout
```

---

### ❌ BAD: Silent failure

```ruby
return {} if file_missing  # NO! Returns empty data with exit 0
```

**Why bad:** Subagent thinks success but got no data

**Fix:**
```ruby
unless File.exist?(file)
  $stderr.puts "Error: File not found: #{file}"
  exit 1
end
```

---

### ❌ BAD: Wrong exit code

```ruby
if warnings.any?
  $stderr.puts "Warning: #{warnings.join(', ')}"
  exit 1  # NO! This is exit 2 scenario
end
```

**Why bad:** Exit 1 aborts pipeline, but warnings are recoverable

**Fix:**
```ruby
if warnings.any?
  warnings.each { |w| $stderr.puts "Warning: #{w}" }
  puts result.to_json  # Still output data
  exit 2               # Warning, can continue
end
```

---

### ❌ BAD: Generic error message

```ruby
$stderr.puts "Error: Something went wrong"  # NO! Not helpful
exit 1
```

**Why bad:** User doesn't know what to fix

**Fix:**
```ruby
$stderr.puts "Error: Cannot parse YAML file: #{file}"
$stderr.puts "Syntax error at line #{line_num}: #{error_message}"
$stderr.puts "Expected valid YAML format. Check for indentation issues."
exit 1
```

## Testing Checklist

Before committing any Ruby script, verify:

### Exit Code Testing

- [ ] Test success scenario: exits 0, data in stdout, stderr empty
- [ ] Test warning scenario: exits 2, data in stdout, warning in stderr
- [ ] Test error scenario: exits 1, stdout empty, error in stderr

### Stream Testing

- [ ] stdout contains ONLY data (no debug messages)
- [ ] stderr contains ONLY error/warning messages
- [ ] stdout is parseable (valid JSON/YAML/path)
- [ ] stderr starts with "Error:" or "Warning:"

### Edge Case Testing

- [ ] Missing input file: exit 1, helpful error
- [ ] Invalid input format: exit 1, specific error
- [ ] Empty input: exit 2 or 0 depending on context
- [ ] Partial success: exit 2, partial data + warning

### Integration Testing

- [ ] Subagent can invoke script and get output
- [ ] Subagent correctly handles all 3 exit codes
- [ ] Error messages are clear and actionable

## Validation Script

```bash
#!/usr/bin/env bash
# validate_exit_codes.sh - Test exit code contract for a Ruby script

script="$1"

echo "Testing: $script"

# Test 1: Does it exit?
if ! timeout 5 ruby "$script" > /dev/null 2>&1; then
  echo "❌ Script doesn't exit cleanly or hangs"
  exit 1
fi

# Test 2: Does it use valid exit codes (0, 1, or 2)?
ruby "$script" > /dev/null 2>&1
exit_code=$?
if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ] && [ $exit_code -ne 2 ]; then
  echo "❌ Invalid exit code: $exit_code (expected 0, 1, or 2)"
  exit 1
fi

# Test 3: stderr empty on success (exit 0)?
output=$(ruby "$script" 2>&1 > /dev/null)
if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
  echo "⚠️ Exit 0 but stderr not empty"
fi

echo "✅ Exit code contract looks good"
```

## Related Specifications

- **metadata-format.spec.md** - What scripts output in JSON/YAML
- **ruby-scripts/*.spec.md** - Individual script specifications
- **agent-communication.spec.md** - How agents use script outputs

---

**Key Takeaway:** Exit codes are a contract. Follow them exactly. Fail fast with clear messages.
