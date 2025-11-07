# metadata_helper.rb Script Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Ruby Script (Utility)
**Location:** `lib/rspec_automation/metadata_helper.rb`

## Purpose

Provides path management and cache validation for metadata files in the RSpec automation system.

**Why this matters:**
- Central source of truth for metadata file paths
- Enables multi-repo support (isolated metadata per project)
- Cache validation prevents unnecessary re-analysis
- Consistent naming across all agents

**Key Responsibilities:**
1. Convert source file path  metadata file path
2. Determine correct metadata directory (project-local or /tmp fallback)
3. Validate cache (check if metadata is fresh and complete)
4. Create metadata directories when needed

## Exit Code Contract

| Exit Code | Meaning | stdout | stderr |
|-----------|---------|--------|--------|
| `0` | Success | Path or validation result (JSON/text) | Empty |
| `1` | Critical Error | Empty | Error message |
| `2` | Warning | Partial data | Warning message |

**Exit 0 scenarios:**
- Metadata path successfully generated
- Cache is valid (metadata fresh, completed=true)
- Cache is invalid (metadata missing or stale) - returns status, NOT error

**Exit 1 scenarios:**
- Invalid source file path format
- Cannot determine project root
- Permission denied to create/access directories

**Exit 2 scenarios:**
- Metadata directory doesn't exist (created automatically, warns)
- Project root detection ambiguous (uses fallback /tmp)

## Command-Line Interface

### Mode 1: Generate Metadata Path

**Usage:**
```bash
ruby lib/rspec_automation/metadata_helper.rb path <source_file>
```

**Arguments:**
- `<source_file>`: Relative or absolute path to Ruby source file

**Output (stdout):**
```
/home/user/project/tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml
```

**Example:**
```bash
$ ruby metadata_helper.rb path app/services/payment_service.rb
/home/user/project/tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml
$ echo $?
0
```

---

### Mode 2: Validate Cache

**Usage:**
```bash
ruby lib/rspec_automation/metadata_helper.rb validate <source_file>
```

**Arguments:**
- `<source_file>`: Relative or absolute path to Ruby source file

**Output (stdout) - JSON:**
```json
{
  "valid": true,
  "metadata_path": "/path/to/metadata.yml",
  "reason": "metadata is fresh and completed"
}
```

**OR (cache invalid):**
```json
{
  "valid": false,
  "metadata_path": "/path/to/metadata.yml",
  "reason": "metadata not found"
}
```

**Possible reasons for invalid cache:**
- `"metadata not found"` - File doesn't exist
- `"source file modified"` - mtime mismatch
- `"analysis incomplete"` - `analyzer.completed != true`
- `"metadata corrupted"` - Cannot parse YAML

**Example:**
```bash
$ ruby metadata_helper.rb validate app/services/payment_service.rb
{"valid":true,"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml","reason":"metadata is fresh and completed"}
$ echo $?
0

$ ruby metadata_helper.rb validate app/services/newly_changed.rb
{"valid":false,"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_newly_changed.yml","reason":"source file modified"}
$ echo $?
0
```

**Note:** Invalid cache is NOT an error (exit 0), it just means re-analysis needed.

---

### Mode 3: Get Metadata Directory

**Usage:**
```bash
ruby lib/rspec_automation/metadata_helper.rb dir
```

**Output (stdout):**
```
/home/user/project/tmp/rspec_claude_metadata
```

**Example:**
```bash
$ ruby metadata_helper.rb dir
/home/user/project/tmp/rspec_claude_metadata
$ echo $?
0
```

## Path Resolution Algorithm

### Step 1: Convert Source Path to Metadata Filename

**Algorithm:**
1. Normalize path (remove leading `./`)
2. Convert to relative path (from project root)
3. Remove `.rb` extension
4. Replace `/` with `_`
5. Prepend `metadata_`
6. Append `.yml`

**Examples:**

```ruby
# Input  Output
"app/services/payment_service.rb"
   "metadata_app_services_payment_service.yml"

"./app/models/user.rb"
   "metadata_app_models_user.yml"

"app/controllers/api/v1/orders_controller.rb"
   "metadata_app_controllers_api_v1_orders_controller.yml"

"/home/user/project/lib/calculator.rb" (absolute)
   "metadata_lib_calculator.yml"
```

**Edge cases:**

```ruby
# Nested directories - flatten all
"app/services/billing/stripe/payment_processor.rb"
   "metadata_app_services_billing_stripe_payment_processor.yml"

# Single file in root
"calculator.rb"
   "metadata_calculator.yml"

# File without .rb extension (should error)
"README.md"
   Error: "Expected .rb file, got: README.md"
```

### Step 2: Determine Metadata Directory

**Priority order:**

1. **Project-local directory (preferred):**
   - `{project_root}/tmp/rspec_claude_metadata/`
   - Project root = nearest parent directory with `.git/` OR `Gemfile`

2. **System temp directory (fallback):**
   - `/tmp/{project_name}_rspec_claude_metadata/`
   - Project name = basename of project root directory

**Detection algorithm:**

```ruby
def find_project_root(source_file_path)
  current = File.dirname(File.expand_path(source_file_path))

  loop do
    # Check for .git directory
    return current if Dir.exist?(File.join(current, '.git'))

    # Check for Gemfile
    return current if File.exist?(File.join(current, 'Gemfile'))

    # Move up one level
    parent = File.dirname(current)
    break if parent == current  # Reached filesystem root
    current = parent
  end

  # No project root found, use fallback
  nil
end

def metadata_directory(source_file_path)
  project_root = find_project_root(source_file_path)

  if project_root
    # Preferred: project-local directory
    File.join(project_root, 'tmp', 'rspec_claude_metadata')
  else
    # Fallback: system temp directory
    project_name = File.basename(Dir.pwd)
    "/tmp/#{project_name}_rspec_claude_metadata"
  end
end
```

**Examples:**

```bash
# Scenario 1: Standard Rails project
/home/user/project/.git         #  Project root detected here
/home/user/project/app/services/payment_service.rb

Metadata dir: /home/user/project/tmp/rspec_claude_metadata/
Full path:    /home/user/project/tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml
```

```bash
# Scenario 2: Multi-repo structure
/home/user/multi-repo/project1/.git        #  Project root for project1
/home/user/multi-repo/project1/app/models/user.rb

Metadata dir: /home/user/multi-repo/project1/tmp/rspec_claude_metadata/
Full path:    /home/user/multi-repo/project1/tmp/rspec_claude_metadata/metadata_app_models_user.yml

# NOT: /home/user/multi-repo/tmp/ (wrong! would mix projects)
```

```bash
# Scenario 3: No git/Gemfile found (fallback)
/home/user/standalone-script/calculator.rb

Project name: standalone-script
Metadata dir: /tmp/standalone-script_rspec_claude_metadata/
Full path:    /tmp/standalone-script_rspec_claude_metadata/metadata_calculator.yml
```

### Step 3: Ensure Directory Exists

**Behavior:**
- If metadata directory doesn't exist, create it (with parents)
- Permissions: `0755` (rwxr-xr-x)
- If creation fails  exit 1 with error

**Example:**
```ruby
metadata_dir = metadata_directory(source_file)
unless Dir.exist?(metadata_dir)
  FileUtils.mkdir_p(metadata_dir, mode: 0755)
  $stderr.puts "Warning: Created metadata directory: #{metadata_dir}" if ENV['VERBOSE']
end
```

## Cache Validation Algorithm

**Validates metadata freshness and completeness.**

### Validation Steps

**Step 1: Check metadata file exists**
```ruby
return { valid: false, reason: "metadata not found" } unless File.exist?(metadata_path)
```

**Step 2: Parse metadata YAML**
```ruby
begin
  metadata = YAML.load_file(metadata_path)
rescue Psych::SyntaxError, StandardError
  return { valid: false, reason: "metadata corrupted" }
end
```

**Step 3: Check analyzer completion flag**
```ruby
unless metadata.dig('analyzer', 'completed') == true
  return { valid: false, reason: "analysis incomplete" }
end
```

**Note:** MUST be boolean `true`, not string `"true"`

**Step 4: Compare source file modification time**
```ruby
source_mtime = File.mtime(source_file).to_i
metadata_mtime = metadata.dig('analyzer', 'source_file_mtime')

if metadata_mtime.nil?
  return { valid: false, reason: "missing source_file_mtime in metadata" }
end

if source_mtime != metadata_mtime
  return { valid: false, reason: "source file modified" }
end
```

**Step 5: Cache is valid**
```ruby
{ valid: true, reason: "metadata is fresh and completed" }
```

### Validation Decision Tree

```
Cache validation requested
    
      Metadata file exists?
         NO  invalid: "metadata not found"
    
      Can parse YAML?
         NO  invalid: "metadata corrupted"
    
      analyzer.completed == true?
         NO  invalid: "analysis incomplete"
    
      analyzer.source_file_mtime present?
         NO  invalid: "missing source_file_mtime in metadata"
    
      File.mtime(source) == metadata.source_file_mtime?
         NO  invalid: "source file modified"
    
      ALL CHECKS PASS
          valid: true
```

## Complete Examples

### Example 1: First Time Use (No Cache)

**Scenario:** Analyzing `app/services/payment_service.rb` for the first time

**Command:**
```bash
ruby metadata_helper.rb validate app/services/payment_service.rb
```

**Output (stdout):**
```json
{"valid":false,"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml","reason":"metadata not found"}
```

**Exit code:** `0` (not an error, just cache miss)

**Agent action:**
```bash
validation=$(ruby metadata_helper.rb validate "$source_file")
if [ "$(echo "$validation" | jq -r '.valid')" = "false" ]; then
  echo "Cache miss, running analyzer..."
  # Run rspec-analyzer
fi
```

---

### Example 2: Cache Hit (Metadata Fresh)

**Scenario:** Source file unchanged since last analysis

**Setup:**
- Source file: `app/services/payment_service.rb` (mtime: 1699351530)
- Metadata exists with `analyzer.completed: true` and `source_file_mtime: 1699351530`

**Command:**
```bash
ruby metadata_helper.rb validate app/services/payment_service.rb
```

**Output (stdout):**
```json
{"valid":true,"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml","reason":"metadata is fresh and completed"}
```

**Exit code:** `0`

**Agent action:**
```bash
validation=$(ruby metadata_helper.rb validate "$source_file")
if [ "$(echo "$validation" | jq -r '.valid')" = "true" ]; then
  echo " Using cached metadata, skipping analysis"
  metadata_path=$(echo "$validation" | jq -r '.metadata_path')
  # Skip analyzer, proceed to next step
fi
```

---

### Example 3: Cache Miss (Source Modified)

**Scenario:** Source file changed after analysis

**Setup:**
- Source file: `app/services/payment_service.rb` (mtime: 1699355000 - NEW)
- Metadata exists with `source_file_mtime: 1699351530` (OLD)

**Command:**
```bash
ruby metadata_helper.rb validate app/services/payment_service.rb
```

**Output (stdout):**
```json
{"valid":false,"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml","reason":"source file modified"}
```

**Exit code:** `0`

**Agent action:**
```bash
validation=$(ruby metadata_helper.rb validate "$source_file")
reason=$(echo "$validation" | jq -r '.reason')
if [ "$(echo "$validation" | jq -r '.valid')" = "false" ]; then
  echo "Cache invalid: $reason"
  echo "Re-running analyzer..."
  # Run rspec-analyzer (will overwrite metadata)
fi
```

---

### Example 4: Incomplete Analysis

**Scenario:** Previous analyzer run failed/interrupted

**Setup:**
- Metadata exists but has `analyzer.completed: false`

**Command:**
```bash
ruby metadata_helper.rb validate app/services/payment_service.rb
```

**Output (stdout):**
```json
{"valid":false,"metadata_path":"tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml","reason":"analysis incomplete"}
```

**Exit code:** `0`

**Agent action:**
```bash
# Same as Example 3 - re-run analyzer
```

---

### Example 5: Generate Path Only

**Scenario:** Just need the metadata path, not validation

**Command:**
```bash
ruby metadata_helper.rb path app/controllers/api/v1/orders_controller.rb
```

**Output (stdout):**
```
tmp/rspec_claude_metadata/metadata_app_controllers_api_v1_orders_controller.yml
```

**Exit code:** `0`

**Agent action:**
```bash
metadata_path=$(ruby metadata_helper.rb path "$source_file")
echo "Metadata will be written to: $metadata_path"
# Use path for writing metadata
```

---

### Example 6: Multi-Repo Isolation

**Scenario:** Working in multi-repo structure

**Directory structure:**
```
/home/user/multi-repo/
     project1/.git
        app/models/user.rb
        tmp/rspec_claude_metadata/   Project 1 metadata here
     project2/.git
         app/models/order.rb
         tmp/rspec_claude_metadata/   Project 2 metadata here
```

**Command (in project1):**
```bash
cd /home/user/multi-repo/project1
ruby lib/rspec_automation/metadata_helper.rb path app/models/user.rb
```

**Output:**
```
/home/user/multi-repo/project1/tmp/rspec_claude_metadata/metadata_app_models_user.yml
```

**NOT:**
```
/home/user/multi-repo/tmp/... L WRONG - would mix projects
```

---

### Example 7: Error - Invalid File Path

**Scenario:** Source file path is not a .rb file

**Command:**
```bash
ruby metadata_helper.rb path README.md
```

**Output (stderr):**
```
Error: Invalid source file: README.md
Expected Ruby source file with .rb extension
```

**Exit code:** `1`

**Agent action:**
```bash
if ! metadata_path=$(ruby metadata_helper.rb path "$source_file" 2>&1); then
  echo "L Cannot generate metadata path"
  exit 1
fi
```

---

### Example 8: Error - Source File Not Found

**Scenario:** Source file doesn't exist

**Command:**
```bash
ruby metadata_helper.rb validate app/services/missing.rb
```

**Output (stderr):**
```
Error: Source file not found: app/services/missing.rb
Cannot validate cache for non-existent file
```

**Exit code:** `1`

**Agent action:**
```bash
# Script exits 1, agent aborts
```

---

### Example 9: Warning - Fallback to /tmp

**Scenario:** No .git or Gemfile found in parent directories

**Command:**
```bash
cd /home/user/standalone
ruby lib/rspec_automation/metadata_helper.rb path calculator.rb
```

**Output (stdout):**
```
/tmp/standalone_rspec_claude_metadata/metadata_calculator.yml
```

**Output (stderr):**
```
Warning: No project root detected (no .git or Gemfile found)
Using fallback directory: /tmp/standalone_rspec_claude_metadata/
```

**Exit code:** `2` (warning)

**Agent action:**
```bash
metadata_path=$(ruby metadata_helper.rb path "$source_file" 2>/tmp/warn)
exit_code=$?

if [ $exit_code -eq 2 ]; then
  echo "  Warning:"
  cat /tmp/warn
  # Still use the path (works, just in /tmp)
fi
```

## Usage in Agents

### rspec-analyzer (Primary User)

**Before analysis:**
```bash
# Check if we can skip analysis
validation=$(ruby lib/rspec_automation/metadata_helper.rb validate "$source_file")

if [ "$(echo "$validation" | jq -r '.valid')" = "true" ]; then
  metadata_path=$(echo "$validation" | jq -r '.metadata_path')
  echo " Using cached metadata: $metadata_path"
  echo "Source file unchanged, skipping analysis"
  exit 0
fi

# Cache invalid, proceed with analysis
echo "Cache miss: $(echo "$validation" | jq -r '.reason')"
metadata_path=$(ruby lib/rspec_automation/metadata_helper.rb path "$source_file")
```

**After analysis:**
```bash
# Write metadata to correct path
metadata_path=$(ruby lib/rspec_automation/metadata_helper.rb path "$source_file")

cat > "$metadata_path" <<EOF
analyzer:
  completed: true
  timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
  source_file_mtime: $(stat -c %Y "$source_file")
  version: '1.0'
# ... rest of metadata
EOF
```

### Other Agents (Read Metadata)

**Pattern:**
```bash
# Get metadata path for source file
metadata_path=$(ruby lib/rspec_automation/metadata_helper.rb path "$source_file")

# Verify metadata exists and is valid
if [ ! -f "$metadata_path" ]; then
  echo "Error: Metadata not found: $metadata_path" >&2
  echo "Run rspec-analyzer first" >&2
  exit 1
fi

# Load metadata
# ... (use yq/jq to read YAML)
```

## Implementation Template

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# metadata_helper.rb - Path management and cache validation for RSpec automation
#
# Exit 0: Success (path generated or validation result returned)
# Exit 1: Critical error (invalid input, file not found)
# Exit 2: Warning (fallback to /tmp, directory created)

require 'yaml'
require 'json'
require 'fileutils'

def main
  command = ARGV[0]

  unless %w[path validate dir].include?(command)
    $stderr.puts "Error: Invalid command: #{command}"
    $stderr.puts "Usage: #{$PROGRAM_NAME} {path|validate|dir} [source_file]"
    exit 1
  end

  case command
  when 'path'
    handle_path_command
  when 'validate'
    handle_validate_command
  when 'dir'
    handle_dir_command
  end
end

def handle_path_command
  source_file = ARGV[1]

  if source_file.nil? || source_file.empty?
    $stderr.puts "Error: Missing source file argument"
    $stderr.puts "Usage: #{$PROGRAM_NAME} path <source_file>"
    exit 1
  end

  validate_source_file(source_file)

  metadata_path = generate_metadata_path(source_file)
  puts metadata_path
  exit 0
rescue StandardError => e
  $stderr.puts "Error: #{e.message}"
  exit 1
end

def handle_validate_command
  source_file = ARGV[1]

  if source_file.nil? || source_file.empty?
    $stderr.puts "Error: Missing source file argument"
    exit 1
  end

  validate_source_file(source_file)

  result = validate_cache(source_file)
  puts result.to_json
  exit 0
rescue StandardError => e
  $stderr.puts "Error: #{e.message}"
  exit 1
end

def handle_dir_command
  metadata_dir = determine_metadata_directory
  puts metadata_dir
  exit 0
rescue StandardError => e
  $stderr.puts "Error: #{e.message}"
  exit 1
end

def validate_source_file(source_file)
  unless source_file.end_with?('.rb')
    raise "Invalid source file: #{source_file}\nExpected Ruby source file with .rb extension"
  end

  expanded_path = File.expand_path(source_file)
  unless File.exist?(expanded_path)
    raise "Source file not found: #{source_file}"
  end
end

def generate_metadata_path(source_file)
  metadata_dir = determine_metadata_directory
  ensure_directory_exists(metadata_dir)

  filename = convert_path_to_metadata_filename(source_file)
  File.join(metadata_dir, filename)
end

def convert_path_to_metadata_filename(source_file)
  # Normalize path
  path = source_file.sub(%r{^\./}, '')

  # Make relative to project root if absolute
  project_root = find_project_root(source_file)
  if project_root && source_file.start_with?('/')
    path = source_file.sub("#{project_root}/", '')
  end

  # Remove .rb extension
  path = path.sub(/\.rb$/, '')

  # Replace / with _
  path = path.tr('/', '_')

  # Add prefix and suffix
  "metadata_#{path}.yml"
end

def determine_metadata_directory
  project_root = find_project_root(Dir.pwd)

  if project_root
    File.join(project_root, 'tmp', 'rspec_claude_metadata')
  else
    project_name = File.basename(Dir.pwd)
    $stderr.puts "Warning: No project root detected (no .git or Gemfile found)"
    $stderr.puts "Using fallback directory: /tmp/#{project_name}_rspec_claude_metadata/"
    "/tmp/#{project_name}_rspec_claude_metadata"
  end
end

def find_project_root(start_path)
  current = File.expand_path(start_path)
  current = File.dirname(current) if File.file?(current)

  loop do
    return current if Dir.exist?(File.join(current, '.git'))
    return current if File.exist?(File.join(current, 'Gemfile'))

    parent = File.dirname(current)
    break if parent == current
    current = parent
  end

  nil
end

def ensure_directory_exists(directory)
  return if Dir.exist?(directory)

  FileUtils.mkdir_p(directory, mode: 0755)
  $stderr.puts "Warning: Created metadata directory: #{directory}" if ENV['VERBOSE']
end

def validate_cache(source_file)
  metadata_path = generate_metadata_path(source_file)

  # Check 1: Metadata file exists
  return invalid_cache(metadata_path, "metadata not found") unless File.exist?(metadata_path)

  # Check 2: Can parse YAML
  begin
    metadata = YAML.load_file(metadata_path)
  rescue Psych::SyntaxError, StandardError
    return invalid_cache(metadata_path, "metadata corrupted")
  end

  # Check 3: Analyzer completed
  unless metadata.dig('analyzer', 'completed') == true
    return invalid_cache(metadata_path, "analysis incomplete")
  end

  # Check 4: source_file_mtime present
  metadata_mtime = metadata.dig('analyzer', 'source_file_mtime')
  if metadata_mtime.nil?
    return invalid_cache(metadata_path, "missing source_file_mtime in metadata")
  end

  # Check 5: Source file mtime matches
  source_mtime = File.mtime(File.expand_path(source_file)).to_i
  if source_mtime != metadata_mtime
    return invalid_cache(metadata_path, "source file modified")
  end

  # All checks passed
  {
    valid: true,
    metadata_path: metadata_path,
    reason: "metadata is fresh and completed"
  }
end

def invalid_cache(metadata_path, reason)
  {
    valid: false,
    metadata_path: metadata_path,
    reason: reason
  }
end

main if __FILE__ == $PROGRAM_NAME
```

## Testing Checklist

Before committing this script, verify:

### Path Generation
- [ ] Converts simple paths correctly (`app/models/user.rb`)
- [ ] Handles nested paths (`app/controllers/api/v1/orders_controller.rb`)
- [ ] Removes leading `./` from relative paths
- [ ] Works with absolute paths
- [ ] Errors on non-.rb files

### Directory Detection
- [ ] Finds project root with `.git`
- [ ] Finds project root with `Gemfile`
- [ ] Prefers `.git` over `Gemfile` if both present
- [ ] Falls back to `/tmp` when no project root
- [ ] Warns (exit 2) when using /tmp fallback

### Multi-Repo Support
- [ ] Isolated metadata per project in multi-repo structure
- [ ] Doesn't mix metadata from different projects

### Cache Validation
- [ ] Returns `valid: true` when all checks pass
- [ ] Returns `valid: false, reason: "metadata not found"` when file missing
- [ ] Returns `valid: false, reason: "source file modified"` when mtime differs
- [ ] Returns `valid: false, reason: "analysis incomplete"` when completed != true
- [ ] Returns `valid: false, reason: "metadata corrupted"` when YAML invalid

### Exit Codes
- [ ] Exits 0 on success (path generated, validation completed)
- [ ] Exits 1 on critical error (invalid input, file not found)
- [ ] Exits 2 with warning when using /tmp fallback

### Integration
- [ ] Can be required as library: `ruby -r lib/rspec_automation/metadata_helper -e "..."`
- [ ] Works from any working directory
- [ ] Output parseable by jq (JSON) or as plain text (paths)

## Related Specifications

- **contracts/exit-codes.spec.md** - Exit code contract (0/1/2)
- **contracts/metadata-format.spec.md** - Metadata YAML schema
- **contracts/agent-communication.spec.md** - How agents use this script
- **agents/rspec-analyzer.spec.md** - Primary user of cache validation

---

**Key Takeaway:** metadata_helper.rb is the single source of truth for metadata paths. All agents MUST use it for consistency and multi-repo support.
