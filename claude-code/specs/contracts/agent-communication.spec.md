# Agent Communication Specification

**Version:** 1.0
**Created:** 2025-11-07

## Purpose

Defines how subagents communicate and coordinate through metadata files and conventions.

**Why this matters:**
- Agents run sequentially, must pass state correctly
- Fail-fast principle requires clear handoffs
- Cache validation requires consistent markers
- Debugging requires inspectable state

## Communication Channels

### 1. Metadata Files (Primary Channel)

**Location:** Determined by `metadata_helper.rb`
- Primary: `{project_root}/tmp/rspec_claude_metadata/metadata_*.yml`
- Fallback: `/tmp/{project_name}_rspec_claude_metadata/metadata_*.yml`

**Content:** YAML format (see `metadata-format.spec.md`)

**Lifecycle:**
```
[rspec-analyzer]
    ↓ writes metadata.yml
[validation]
    ↓ updates metadata.yml (validation section)
[skeleton generator]
    ↓ reads metadata.yml, generates spec file
[rspec-architect]
    ↓ reads metadata.yml + spec file, updates spec file
[rspec-implementer]
    ↓ reads metadata.yml + spec file, updates spec file
[rspec-factory-optimizer]
    ↓ reads metadata.yml + spec file, updates spec file
[rspec-polisher]
    ↓ reads spec file, runs tests
[rspec-reviewer]
    ↓ reads metadata.yml + spec file, writes report.md
```

### 2. Generated Test Files (Secondary Channel)

**Location:** Standard RSpec locations
- Models: `spec/models/{name}_spec.rb`
- Services: `spec/services/{name}_spec.rb`
- Controllers: `spec/controllers/{name}_spec.rb`
- etc.

**Content:** Ruby RSpec test code

**Lifecycle:**
- Created by: skeleton generator (Ruby script)
- Modified by: architect, implementer, factory-optimizer, polisher
- Read by: reviewer

### 3. Review Reports (Output Channel)

**Location:** `tmp/rspec_claude_metadata/review_report_{name}.md`

**Content:** Markdown formatted review report

**Lifecycle:**
- Created by: rspec-reviewer
- Read by: user (human)

## Sequential Pipeline Protocol

### Rule 1: Strict Sequential Execution

🔴 **MUST:** Agents MUST run one at a time, in order

```
✅ CORRECT:
analyzer completes → architect starts → architect completes → implementer starts

❌ WRONG:
analyzer + architect run in parallel
```

**Why:** Each agent depends on previous agent's output

### Rule 2: Completion Markers

🔴 **MUST:** Each agent MUST mark completion in metadata

```yaml
automation:
  analyzer_completed: true      # Set by analyzer before exit
  architect_completed: true     # Set by architect before exit
  implementer_completed: true   # Set by implementer before exit
  # etc.
```

**Purpose:** Next agent can verify previous agent completed successfully

### Rule 3: Prerequisite Checking

🔴 **MUST:** Each agent MUST check prerequisites before starting

**Example (architect):**
```bash
# Check that analyzer completed
if ! grep -q "analyzer_completed: true" metadata.yml; then
  echo "Error: rspec-analyzer has not completed successfully"
  echo "Run rspec-analyzer first"
  exit 1
fi

# Check that metadata is valid
if ! ruby metadata_validator.rb metadata.yml; then
  echo "Error: Invalid metadata format"
  echo "Re-run rspec-analyzer"
  exit 1
fi

# OK to proceed
echo "✅ Prerequisites met, starting architect..."
```

### Rule 4: Fail-Fast on Error

🔴 **MUST:** If any agent fails, entire pipeline stops

```
analyzer → SUCCESS
    ↓
architect → FAILURE (exit 1)
    ↓
(pipeline stops here, implementer does NOT run)
```

**No retry logic:** If agent fails, user must fix issue and re-run

## Agent Responsibilities

### rspec-analyzer

**Inputs:**
- Source code file (Ruby)
- Method name (string)

**Outputs:**
- `metadata.yml` with:
  - `analyzer.completed = true`
  - `analyzer.timestamp`
  - `analyzer.source_file_mtime`
  - `test_level`
  - `target.*`
  - `characteristics[]`
  - `factories_detected` (via factory_detector.rb)

**Completion criteria:**
- ✅ metadata.yml written
- ✅ metadata.yml passes validation
- ✅ `analyzer.completed = true` set

**Next agent:** rspec-architect (via skeleton generator first)

---

### spec_skeleton_generator.rb (Ruby Script)

**Inputs:**
- `metadata.yml`

**Outputs:**
- `spec/path/to/file_spec.rb` with:
  - describe/context structure
  - `{CONTEXT_WORD}` placeholders for leaf contexts
  - TODO comments for architect and implementer

**Completion criteria:**
- ✅ Spec file created
- ✅ Structure matches characteristics hierarchy
- ✅ Placeholders in correct positions

**Next agent:** rspec-architect

---

### rspec-architect

**Inputs:**
- `metadata.yml` (reads characteristics, target)
- `spec/path/to/file_spec.rb` (reads structure)
- Source code file (analyzes for semantics)

**Outputs:**
- Updated `spec/path/to/file_spec.rb` with:
  - `{CONTEXT_WORD}` replaced with when/with/and/but/without
  - it block descriptions added
  - Sorted (happy path first)
- Updated `metadata.yml`:
  - `automation.architect_completed = true`

**Completion criteria:**
- ✅ No `{CONTEXT_WORD}` placeholders remain
- ✅ Every context has at least one it block
- ✅ Language rules (17-20) applied
- ✅ `architect.completed = true` set

**Next agent:** rspec-implementer

---

### rspec-implementer

**Inputs:**
- `metadata.yml` (reads test_level, characteristics, factories_detected)
- `spec/path/to/file_spec.rb` (reads structure and it descriptions)
- Source code file (analyzes method signature, dependencies, behavior)

**Outputs:**
- Updated `spec/path/to/file_spec.rb` with:
  - let/let!/before blocks
  - subject definition
  - expect statements in it blocks
- Updated `metadata.yml`:
  - `automation.implementer_completed = true`

**Completion criteria:**
- ✅ All it blocks have expectations
- ✅ All contexts have necessary setup (let/before)
- ✅ subject defined appropriately
- ✅ Tests follow behavior testing (Rule 1)
- ✅ `implementer.completed = true` set

**Next agent:** rspec-factory-optimizer

---

### rspec-factory-optimizer

**Inputs:**
- `metadata.yml` (reads characteristics, factories_detected)
- `spec/path/to/file_spec.rb` (reads current factory usage)

**Outputs:**
- Updated `spec/path/to/file_spec.rb` with:
  - Optimized factory methods (build_stubbed vs create)
  - Trait usage instead of manual attributes
- Updated `metadata.yml`:
  - `automation.factory_optimizer_completed = true`
  - `automation.warnings[]` if traits missing

**Completion criteria:**
- ✅ Unit tests use build_stubbed where possible
- ✅ Traits used instead of attribute overrides
- ✅ Warnings logged for missing traits
- ✅ `factory_optimizer.completed = true` set

**Next agent:** rspec-polisher

---

### rspec-polisher

**Inputs:**
- `spec/path/to/file_spec.rb`

**Outputs:**
- Updated `spec/path/to/file_spec.rb` (cleaned up)
- Updated `metadata.yml`:
  - `automation.polisher_completed = true`

**Completion criteria:**
- ✅ RuboCop violations fixed
- ✅ Tests run and pass
- ✅ No syntax errors
- ✅ `polisher.completed = true` set

**Next agent:** rspec-reviewer (automatic)

---

### rspec-reviewer (READ-ONLY)

**Inputs:**
- `metadata.yml` (for context)
- `spec/path/to/file_spec.rb` (for review)

**Outputs:**
- `tmp/rspec_claude_metadata/review_report_{name}.md`
- Does NOT modify metadata or spec file

**Completion criteria:**
- ✅ All 28 rules checked
- ✅ Time handling checked
- ✅ Report generated
- ✅ User informed of results

**Next agent:** None (end of pipeline)

## Cache Validation Protocol

### Purpose

Avoid re-analyzing unchanged source files.

### Algorithm

```
User requests test for: app/services/payment_service.rb

1. metadata_helper.rb determines metadata file path:
   → tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml

2. Check if metadata file exists:
   NO → Run full analysis (no cache)
   YES → Continue to step 3

3. Check analyzer.completed == true:
   NO → Run full analysis (incomplete cache)
   YES → Continue to step 4

4. Check validation.completed == true && validation.errors == []:
   NO → Run full analysis (invalid cache)
   YES → Continue to step 5

5. Compare source_file_mtime:
   cached_mtime = metadata['analyzer']['source_file_mtime']
   current_mtime = File.mtime('app/services/payment_service.rb').to_i

   cached_mtime == current_mtime?
   YES → ✅ Cache valid, SKIP analysis, use cached metadata
   NO → Run full analysis (stale cache)
```

### Implementation

**In rspec-analyzer:**

```bash
#!/usr/bin/env bash

source_file="app/services/payment_service.rb"
method_name="process_payment"

# Get metadata path
metadata_path=$(ruby -r lib/rspec_automation/metadata_helper -e "
  require 'yaml'
  puts RSpecAutomation::MetadataHelper.metadata_path_for('$source_file')
")

# Check cache validity
if ruby -r lib/rspec_automation/metadata_helper -e "
  exit 0 if RSpecAutomation::MetadataHelper.metadata_valid?('$source_file')
  exit 1
"; then
  echo "✅ Using cached metadata: $metadata_path"
  exit 0
else
  echo "⚙️ Running analysis (cache invalid or missing)"
  # ... perform analysis ...
fi
```

## Error Communication Protocol

### Fail-Fast Error Reporting

When agent encounters error:

1. **Write error to stderr**
   ```bash
   echo "Error: Source file not found: $source_file" >&2
   ```

2. **Update metadata with error** (if metadata accessible)
   ```yaml
   automation:
     errors:
       - "analyzer: Source file not found: app/services/missing.rb"
   ```

3. **Exit with code 1**
   ```bash
   exit 1
   ```

4. **Pipeline stops** - next agent does NOT run

### Warning Communication

When agent encounters non-critical issue:

1. **Write warning to stderr**
   ```bash
   echo "Warning: Factory trait :premium not found" >&2
   ```

2. **Update metadata with warning**
   ```yaml
   automation:
     warnings:
       - "factory-optimizer: Factory trait :premium not found, using attributes"
   ```

3. **Continue execution**
   ```bash
   # Keep working, mark completion
   ```

## Multi-Repo Scenario

### Problem

User runs Claude Code from parent directory containing multiple projects:

```
/home/user/multi-repo/
├── project1/
│   ├── app/
│   └── spec/
└── project2/
    ├── app/
    └── spec/
```

User analyzes: `/home/user/multi-repo/project1/app/models/user.rb`

### Solution

**metadata_helper.rb finds git root:**

```ruby
def self.find_git_root(file_path)
  dir = File.dirname(File.expand_path(file_path))

  loop do
    return dir if File.directory?(File.join(dir, '.git'))
    parent = File.dirname(dir)
    break if parent == dir  # reached filesystem root
    dir = parent
  end

  nil  # No git root found
end

def self.metadata_dir_for(source_file)
  git_root = find_git_root(source_file)

  if git_root && Dir.exist?(File.join(git_root, 'tmp'))
    # Use project's tmp/
    "#{git_root}/tmp/rspec_claude_metadata"
  elsif git_root
    # Ask user to create tmp/ or use system /tmp
    # (implementation detail in metadata_helper.rb spec)
    "/tmp/#{File.basename(git_root)}_rspec_claude_metadata"
  else
    # Fallback: system tmp
    "/tmp/rspec_claude_metadata"
  end
end
```

**Result:**
- Metadata goes to: `/home/user/multi-repo/project1/tmp/rspec_claude_metadata/`
- NOT to: `/home/user/multi-repo/tmp/` (wrong!)

## State Inspection for Debugging

### Check Pipeline State

```bash
# Which agents completed?
grep "completed:" tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml

# Output:
# analyzer_completed: true
# architect_completed: true
# implementer_completed: false  ← stuck here
```

### Check Errors

```bash
# Any errors recorded?
grep -A 5 "errors:" tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml

# Output:
# errors:
#   - "implementer: Cannot determine method signature for process_payment"
```

### Check Characteristics

```bash
# What characteristics were extracted?
grep -A 20 "characteristics:" tmp/rspec_claude_metadata/metadata_app_services_payment_service.yml
```

### Verify Cache

```bash
# Is cache still valid?
ruby -r lib/rspec_automation/metadata_helper -e "
  valid = RSpecAutomation::MetadataHelper.metadata_valid?('app/services/payment_service.rb')
  puts valid ? 'VALID' : 'INVALID'
"
```

## Common Communication Issues

### Issue 1: Agent starts before previous completes

**Symptom:**
```
architect: Error: metadata.yml missing 'analyzer.completed: true'
```

**Cause:** Skill invoked agents in parallel or didn't wait for completion

**Fix:** Ensure skill waits for each agent:
```ruby
# In skill SKILL.md:
# 1. Invoke analyzer, WAIT for completion
# 2. Verify analyzer completed successfully
# 3. THEN invoke architect
```

---

### Issue 2: Metadata corrupted mid-pipeline

**Symptom:**
```
implementer: Error: Cannot parse metadata.yml - invalid YAML
```

**Cause:**
- Previous agent wrote invalid YAML
- File system issue
- Concurrent modification

**Fix:**
- metadata_validator.rb MUST run after analyzer
- Agents MUST NOT run in parallel
- Use atomic writes (write to temp file, then rename)

---

### Issue 3: Cache invalidation not working

**Symptom:**
- Source file changed
- But analyzer still skips analysis

**Cause:** `source_file_mtime` not updated correctly

**Fix:**
- Ensure analyzer always writes current mtime:
  ```ruby
  metadata['analyzer']['source_file_mtime'] = File.mtime(source_file).to_i
  ```

---

### Issue 4: Stale metadata from old pipeline

**Symptom:**
- metadata.yml has `implementer_completed: true`
- But implementer never ran in current session

**Cause:** Re-using old metadata file

**Fix:**
- When analyzer runs, clear all `automation.*_completed` flags except `analyzer_completed`
- Or delete metadata file and start fresh

## Testing Communication

### Test 1: Sequential Execution

```bash
# Run each agent manually, verify order
ruby analyzer.rb app/services/payment.rb process
# → Creates metadata.yml

grep "analyzer_completed: true" metadata.yml || echo "FAIL: analyzer didn't complete"

ruby architect.rb spec/services/payment_spec.rb
# → Updates spec file

grep "architect_completed: true" metadata.yml || echo "FAIL: architect didn't complete"

# etc.
```

### Test 2: Fail-Fast

```bash
# Corrupt metadata
echo "invalid yaml [[[" > metadata.yml

# Try to run architect
ruby architect.rb spec/services/payment_spec.rb
exit_code=$?

[ $exit_code -eq 1 ] || echo "FAIL: Should have exited 1"
```

### Test 3: Cache Validation

```bash
# Analyze file
ruby analyzer.rb app/services/payment.rb process

# Touch source file (change mtime)
touch app/services/payment.rb

# Re-run analyzer
ruby analyzer.rb app/services/payment.rb process
# Should run full analysis, not use cache

# Don't touch source file
ruby analyzer.rb app/services/payment.rb process
# Should use cache this time
```

## Related Specifications

- **metadata-format.spec.md** - Complete metadata schema
- **exit-codes.spec.md** - Error communication via exit codes
- **agents/*.spec.md** - Each agent's specific communication behavior
- **ruby-scripts/metadata-helper.spec.md** - Path resolution and cache checking

---

**Key Takeaway:** Communication is sequential, explicit, and fail-fast. No magic, no parallelism, no silent failures.
