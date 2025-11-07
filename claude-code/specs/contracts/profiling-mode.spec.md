# Profiling Mode Contract

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Contract
**Applies to:** All skills and agents

## Philosophy / Why Profiling Mode Exists

**Problem:** During real-world usage, Claude Code agents may:
- Try to "help" by working around errors instead of reporting them
- Hide underlying issues with creative solutions
- Make it hard to identify root causes in specifications
- Prevent iterative improvement based on real failures

**Solution:** Profiling mode enforces **strict fail-fast** with **detailed error reports**.

**Value:**
- Identify specification ambiguities quickly
- Capture real-world edge cases
- Iteratively improve agents based on production usage
- Clear debugging information for specification authors

## Scope: What Gets Profiled

🔴 **Profiling covers ALL aspects of agent/skill logic:**

**Infrastructure & Prerequisites:**
- ✅ File system permissions (read/write/execute)
- ✅ Directory creation failures
- ✅ Missing tools (RuboCop, StandardRB, git, bundler)
- ✅ Environment issues (Ruby version, missing gems)

**Script Execution:**
- ✅ Ruby script failures (exit codes)
- ✅ Script timeouts
- ✅ Parse errors (YAML, JSON, Ruby AST)

**Agent Logic:**
- ✅ LLM-generated code with errors
- ✅ Wrong decisions (test level, characteristic types)
- ✅ Context size exceeded
- ✅ Validation failures

**External Tools:**
- ✅ MCP server unavailable/errors
- ✅ Git operations failures
- ✅ Bundler/gem errors

**System State:**
- ✅ Unexpected file states
- ✅ Cache corruption
- ✅ Concurrent modifications

**EVERYTHING that can fail MUST generate a profiling report.**

Even "minor" issues like missing permissions are **critical information** for improving specifications.

## Enabling Profiling Mode

### Environment Variable

```bash
# Enable profiling mode
export RSPEC_AUTOMATION_PROFILE=1

# Disable profiling mode (default)
export RSPEC_AUTOMATION_PROFILE=0
# or
unset RSPEC_AUTOMATION_PROFILE
```

### Detection in Agents/Skills

**At the start of EVERY agent and skill:**

```bash
# Detect profiling mode
PROFILING_MODE="${RSPEC_AUTOMATION_PROFILE:-0}"

if [ "$PROFILING_MODE" = "1" ]; then
  echo "🔍 PROFILING MODE ENABLED" >&2
  echo "   Strict fail-fast with detailed reporting" >&2
  echo "" >&2
fi
```

## Behavior Changes in Profiling Mode

### 🔴 MUST Follow in Profiling Mode

#### 1. Fail Immediately on ANY Error

```bash
# Normal mode:
if ! some_command; then
  echo "Warning: Command failed, trying alternative..." >&2
  alternative_command  # ❌ Self-healing
fi

# Profiling mode:
if ! some_command; then
  generate_profiling_report "command_failed" "some_command returned exit code $?"
  exit 1  # ✅ Fail fast
fi
```

#### 2. NO Self-Healing Attempts

**Forbidden in profiling mode:**
- ❌ Trying alternative tools (e.g., using grep if MCP search fails)
- ❌ Writing replacement scripts
- ❌ Asking user for confirmation to proceed
- ❌ Skipping failed steps
- ❌ Any form of "working around" the issue

**Required:**
- ✅ Stop immediately
- ✅ Report exact error
- ✅ Exit with code 1

#### 3. Detailed Error Context

**Every error report MUST include:**
- What was being attempted
- What command/operation failed
- Exact error message
- Input data that caused failure
- Agent/skill state at time of failure
- Timestamp

#### 4. Validate ALL Prerequisites Strictly

```bash
# Normal mode:
if ! command -v rubocop &> /dev/null; then
  echo "Warning: RuboCop not found, skipping..." >&2
  # Continue ❌
fi

# Profiling mode:
if [ "$PROFILING_MODE" = "1" ]; then
  if ! command -v rubocop &> /dev/null; then
    generate_profiling_report "prerequisite_missing" "rubocop not found in PATH"
    exit 1  # ✅ Fail fast
  fi
fi
```

#### 5. Log Every Decision Point

```bash
if [ "$PROFILING_MODE" = "1" ]; then
  echo "[PROFILE] Checking cache validity..." >&2
  echo "[PROFILE] Source mtime: $source_mtime" >&2
  echo "[PROFILE] Cached mtime: $cached_mtime" >&2
fi

if [ "$source_mtime" -gt "$cached_mtime" ]; then
  [ "$PROFILING_MODE" = "1" ] && echo "[PROFILE] Cache INVALID - proceeding with analysis" >&2
else
  [ "$PROFILING_MODE" = "1" ] && echo "[PROFILE] Cache VALID - skipping analysis" >&2
fi
```

## Profiling Report Format

### File Location

```bash
# Report directory (created if doesn't exist)
PROFILE_REPORT_DIR="${RSPEC_AUTOMATION_PROFILE_DIR:-tmp/rspec_profiling}"
mkdir -p "$PROFILE_REPORT_DIR"

# Report filename (unique per run)
PROFILE_REPORT="$PROFILE_REPORT_DIR/report_$(date +%Y%m%d_%H%M%S)_$$_${COMPONENT_NAME}.yml"
```

### YAML Schema

```yaml
# Profiling Report Schema
profiling_report:
  version: '1.0'

  # Identification
  component_type: 'skill'        # or 'agent' or 'script'
  component_name: 'rspec-write-new'
  timestamp: '2025-11-07T14:32:18Z'

  # Execution context
  execution:
    mode: 'profiling'
    working_directory: '/home/user/project'
    environment:
      ruby_version: '3.2.0'
      rspec_version: '3.12.0'
      linter: 'rubocop'

  # What was being done when failure occurred
  current_step:
    agent: 'rspec-analyzer'       # Current agent in pipeline
    step_number: 1
    step_name: 'Characteristic extraction'
    operation: 'Running metadata_helper.rb'

  # The failure
  failure:
    type: 'script_error'          # See failure types below
    severity: 'critical'          # critical, error, warning
    message: 'metadata_helper.rb exited with code 1'

    # Exact error output
    stderr: |
      Error: Source file not found: app/services/missing.rb
      Expected path: /home/user/project/app/services/missing.rb

    stdout: |
      (empty)

    # What was expected vs what happened
    expected: 'Exit code 0'
    actual: 'Exit code 1'

  # Input data that caused failure
  input:
    source_file: 'app/services/missing.rb'
    method_name: 'process'
    metadata_path: 'tmp/rspec_claude_metadata/metadata_app_services_missing.yml'

  # Agent/skill state
  state:
    completed_steps: ['prerequisites_check']
    pending_steps: ['characteristic_extraction', 'skeleton_generation', 'implementation']
    metadata_exists: false
    spec_file_exists: false

  # Recommendations for fixing
  recommendations:
    - 'Verify source file exists before invoking analyzer'
    - 'Add file existence check to skill prerequisites'
    - 'Consider more descriptive error in metadata_helper.rb'

  # Full execution trace (optional but helpful)
  trace:
    - timestamp: '2025-11-07T14:32:15Z'
      step: 'prerequisites_check'
      status: 'success'
    - timestamp: '2025-11-07T14:32:16Z'
      step: 'detect_linter'
      status: 'success'
      result: 'rubocop'
    - timestamp: '2025-11-07T14:32:18Z'
      step: 'run_analyzer'
      status: 'failed'
      error: 'Script exited with code 1'
```

### Failure Types

**Categorize errors for easier analysis:**

| Type | Description | Example |
|------|-------------|---------|
| **Prerequisites & Environment** | | |
| `prerequisite_missing` | Required tool/file not found | RuboCop not installed, source file missing |
| `permission_denied` | **Insufficient permissions** | **Can't write to tmp/, can't execute script** |
| `path_resolution_error` | Path issues | Can't find git root, invalid relative path |
| `environment_error` | Wrong environment | Ruby version too old, missing gem |
| **Script Execution** | | |
| `script_error` | Ruby script failed | metadata_helper.rb exit 1 |
| `script_timeout` | Script took too long | Extractor running >5 minutes |
| `script_not_executable` | **Script lacks execute permission** | **chmod +x not set on .rb file** |
| **Data & Validation** | | |
| `validation_error` | Data validation failed | Invalid metadata.yml schema |
| `parse_error` | Can't parse input | Malformed YAML, broken JSON |
| `schema_mismatch` | Data doesn't match schema | Missing required field |
| **Agent Logic** | | |
| `agent_error` | LLM agent failed to complete | rspec-analyzer timed out |
| `agent_logic_error` | Agent produced invalid output | Generated code that doesn't compile |
| `agent_decision_error` | Agent made wrong choice | Chose wrong test level |
| `llm_context_exceeded` | Input too large for LLM | Source file >100k tokens |
| **File Operations** | | |
| `file_error` | File operation failed | Can't write to spec file |
| `file_exists_error` | File already exists (shouldn't) | Spec file exists when shouldn't |
| `file_missing_error` | File missing (should exist) | metadata.yml expected but not found |
| `directory_error` | **Can't create/access directory** | **mkdir tmp/ failed** |
| **Generated Code** | | |
| `syntax_error` | Generated code has syntax error | Invalid Ruby syntax in spec |
| `test_failure` | Generated tests fail | Expectation mismatch |
| `rubocop_violation` | Generated code violates style | Auto-correct can't fix offense |
| **System State** | | |
| `unexpected_state` | System in unexpected state | Metadata exists but source newer |
| `cache_corruption` | Cache data corrupted | mtime mismatch, invalid cached data |
| `concurrent_modification` | File changed during execution | Source modified while analyzing |
| **Integration** | | |
| `mcp_error` | **MCP tool unavailable/failed** | **Search MCP server not responding** |
| `git_error` | Git operation failed | git diff failed, not a git repo |
| `bundler_error` | Bundler/gem issue | bundle exec failed, gem not found |

## Integration with Skills

### Skill Template with Profiling

```markdown
---
name: rspec-write-new
description: Generate RSpec tests from source code
---

# Prerequisites

🔴 MUST check profiling mode FIRST:

```bash
PROFILING_MODE="${RSPEC_AUTOMATION_PROFILE:-0}"

if [ "$PROFILING_MODE" = "1" ]; then
  echo "🔍 PROFILING MODE ENABLED" >&2
  PROFILE_REPORT_DIR="${RSPEC_AUTOMATION_PROFILE_DIR:-tmp/rspec_profiling}"
  mkdir -p "$PROFILE_REPORT_DIR"
fi
```

# Error Handling

```bash
function fail_with_profile() {
  local error_type="$1"
  local error_message="$2"

  if [ "$PROFILING_MODE" = "1" ]; then
    generate_profiling_report "$error_type" "$error_message"
  else
    echo "Error: $error_message" >&2
  fi

  exit 1
}

# Usage:
if [ ! -f "$source_file" ]; then
  fail_with_profile "prerequisite_missing" "Source file not found: $source_file"
fi
```

# generate_profiling_report function

```bash
function generate_profiling_report() {
  local error_type="$1"
  local error_message="$2"

  local report_file="$PROFILE_REPORT_DIR/report_$(date +%Y%m%d_%H%M%S)_$$_rspec-write-new.yml"

  cat > "$report_file" <<EOF
profiling_report:
  version: '1.0'

  component_type: 'skill'
  component_name: 'rspec-write-new'
  timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'

  execution:
    mode: 'profiling'
    working_directory: '$(pwd)'

  current_step:
    step_name: '${CURRENT_STEP_NAME:-unknown}'
    operation: '${CURRENT_OPERATION:-unknown}'

  failure:
    type: '$error_type'
    severity: 'critical'
    message: '$error_message'

  input:
    source_file: '${source_file:-unknown}'

  state:
    completed_steps: $(printf '%s\n' "${COMPLETED_STEPS[@]}" | jq -R . | jq -s .)

  recommendations:
    - 'Review specification for this error type'
    - 'Check if prerequisites were validated correctly'
EOF

  echo "" >&2
  echo "❌ PROFILING FAILURE DETECTED" >&2
  echo "   Report: $report_file" >&2
  echo "" >&2
  cat "$report_file" >&2
}
```
```

## Integration with Agents

### Agent Prompt Template

```markdown
# rspec-analyzer Agent

You are the rspec-analyzer agent. You analyze source code to extract test characteristics.

## Profiling Mode Check

**FIRST THING: Check if profiling mode is enabled:**

```bash
PROFILING_MODE="${RSPEC_AUTOMATION_PROFILE:-0}"

if [ "$PROFILING_MODE" = "1" ]; then
  echo "🔍 PROFILING MODE ENABLED" >&2
  echo "   Agent: rspec-analyzer" >&2
  echo "   Strict fail-fast: ANY error stops execution" >&2
  echo "" >&2
fi
```

## Behavior in Profiling Mode

🔴 **CRITICAL RULES:**

1. **NO self-healing** - If ANY command fails, stop immediately
2. **NO alternative approaches** - Don't try workarounds
3. **Generate detailed report** - Use generate_profiling_report function
4. **Exit with code 1** - Always fail fast

**Example:**

```bash
# Run metadata_validator.rb
if ! ruby lib/rspec_automation/metadata_validator.rb "$metadata_path"; then
  if [ "$PROFILING_MODE" = "1" ]; then
    generate_profiling_report "validation_error" "metadata_validator.rb failed for $metadata_path"
    exit 1
  fi

  # Normal mode: might try to fix or warn
  echo "Warning: Validation failed, but continuing..." >&2
fi
```

## Profiling Report Function (copy to agent)

[Same generate_profiling_report function as above]
```

## User Workflow

### 1. Enable Profiling

```bash
# In project root
export RSPEC_AUTOMATION_PROFILE=1
export RSPEC_AUTOMATION_PROFILE_DIR="tmp/profiling"  # Optional, default: tmp/rspec_profiling
```

### 2. Run Skill/Agent Normally

```bash
# Use skill as normal
# It will fail fast on first error and generate report
```

### 3. Review Report

```bash
# Reports are in tmp/profiling/
ls -lt tmp/profiling/

# Read latest report
cat tmp/profiling/report_20251107_143218_12345_rspec-write-new.yml
```

### 4. Fix Specification

Based on report recommendations, update specification or code.

### 5. Iterate

Re-run with profiling mode until all issues resolved.

### 6. Disable Profiling

```bash
unset RSPEC_AUTOMATION_PROFILE
# or
export RSPEC_AUTOMATION_PROFILE=0
```

## Benefits

### For Specification Authors

- **Clear failure points** - Know exactly what failed and why
- **Structured data** - Easy to analyze patterns across failures
- **No guessing** - Agents don't hide errors with workarounds
- **Iterative improvement** - Fix specs based on real-world usage

### For Users

- **Fast debugging** - Reports point to exact issue
- **No surprises** - Failures are explicit, not hidden
- **Transparency** - See exactly what agents are doing

## Testing Criteria

**Profiling mode is correct if:**
- ✅ Enables via environment variable
- ✅ Stops on first error (no self-healing)
- ✅ Generates structured YAML report
- ✅ Reports contain all required fields
- ✅ Can be disabled (normal mode still works)

**Profiling mode MUST NOT:**
- ❌ Try alternative tools/approaches
- ❌ Ask user for confirmation
- ❌ Skip failed steps
- ❌ Generate reports in normal mode (performance)

## Examples

### Example 1: Missing Prerequisite

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# Try to use skill when RuboCop not installed
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_name: 'rspec-polisher'
  timestamp: '2025-11-07T14:32:18Z'

  failure:
    type: 'prerequisite_missing'
    severity: 'critical'
    message: 'rubocop command not found in PATH'

  recommendations:
    - 'Install rubocop gem: gem install rubocop'
    - 'Or add to Gemfile and run bundle install'
    - 'Or disable linting by removing .rubocop.yml'
```

**User action:** Install RuboCop or update specification to handle missing linter gracefully.

---

### Example 2: Script Failure

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# Run analyzer on non-existent file
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_name: 'rspec-analyzer'
  timestamp: '2025-11-07T14:35:22Z'

  current_step:
    step_name: 'Run metadata_helper.rb'

  failure:
    type: 'script_error'
    severity: 'critical'
    message: 'metadata_helper.rb exited with code 1'
    stderr: |
      Error: Source file not found: app/services/missing.rb

  input:
    source_file: 'app/services/missing.rb'

  recommendations:
    - 'Add file existence check before invoking analyzer'
    - 'Update skill to validate source_file path first'
```

**User action:** Update skill specification to check file existence in prerequisites.

---

### Example 3: Validation Error

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# Analyzer generates invalid metadata
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_name: 'rspec-analyzer'
  timestamp: '2025-11-07T14:38:45Z'

  current_step:
    step_name: 'Validate metadata'

  failure:
    type: 'validation_error'
    severity: 'critical'
    message: 'Metadata validation failed'
    stderr: |
      Error: Missing required field: characteristics[0].type
      Error: Invalid value for test_level: 'unknown' (must be unit/integration/request/e2e)

  state:
    metadata_exists: true
    metadata_path: 'tmp/.../metadata.yml'

  recommendations:
    - 'Check analyzer logic for characteristic type detection'
    - 'Review Decision Tree 3 in rspec-analyzer.spec.md'
    - 'Verify test_level determination algorithm'
```

**User action:** Fix analyzer specification's type detection logic.

---

### Example 4: Permission Denied

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# Run in directory where user can't write to tmp/
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_name: 'rspec-analyzer'
  timestamp: '2025-11-07T15:12:33Z'

  current_step:
    step_name: 'Create metadata directory'
    operation: 'mkdir -p tmp/rspec_claude_metadata'

  failure:
    type: 'permission_denied'
    severity: 'critical'
    message: 'Cannot create directory: Permission denied'
    stderr: |
      mkdir: cannot create directory 'tmp/rspec_claude_metadata': Permission denied

  execution:
    working_directory: '/opt/readonly_project'
    user: 'developer'

  recommendations:
    - 'Check write permissions on project directory'
    - 'Run with sudo if necessary (not recommended)'
    - 'Use alternative tmp location: export RSPEC_AUTOMATION_PROFILE_DIR=/tmp/profiling'
    - 'Check if directory is mounted read-only'
```

**User action:** Fix permissions or use alternative tmp directory.

---

### Example 5: MCP Tool Unavailable

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# Agent tries to use MCP search but server down
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_type: 'agent'
  component_name: 'rspec-analyzer'
  timestamp: '2025-11-07T15:18:22Z'

  current_step:
    step_name: 'Search for factory definitions'
    operation: 'MCP search tool invocation'

  failure:
    type: 'mcp_error'
    severity: 'critical'
    message: 'MCP search server not responding'
    stderr: |
      Error: Connection refused to MCP server at unix:///tmp/mcp-search.sock
      Attempted fallback to grep: FORBIDDEN in profiling mode

  execution:
    mcp_server: 'search'
    mcp_endpoint: 'unix:///tmp/mcp-search.sock'

  state:
    attempted_self_healing: false  # ✅ Correctly NOT attempted

  recommendations:
    - 'Check MCP server is running: ls -la /tmp/mcp-*.sock'
    - 'Restart MCP server or Claude Code'
    - 'Check MCP configuration in .claude/mcp.json'
    - 'Agent specification should handle MCP unavailability gracefully'
```

**User action:** Fix MCP server or update agent to handle MCP failures.

**NOTE:** In normal mode, agent MIGHT try grep as fallback. In profiling mode: NEVER.

---

### Example 6: Agent Logic Error (Generated Invalid Code)

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# rspec-implementer generates code with syntax error
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_type: 'agent'
  component_name: 'rspec-implementer'
  timestamp: '2025-11-07T15:25:44Z'

  current_step:
    step_name: 'Validate generated code'
    operation: 'ruby -c spec_file'

  failure:
    type: 'agent_logic_error'
    severity: 'critical'
    message: 'Agent generated code with syntax error'
    stderr: |
      spec/services/payment_service_spec.rb:15: syntax error, unexpected end-of-input
      Expected 'end' to close 'do' block

  state:
    spec_file: 'spec/services/payment_service_spec.rb'
    generated_by: 'rspec-implementer'
    metadata_valid: true

  generated_code_snippet: |
    context 'with valid card' do
      it 'processes payment' do
        expect(result).to eq(true)
      # Missing 'end' here!

  recommendations:
    - 'BUG in rspec-implementer: check block closure logic'
    - 'Review implementer prompt for correct Ruby syntax generation'
    - 'Add syntax validation BEFORE writing file'
    - 'This is a specification bug, not user error'
```

**User action:** Fix rspec-implementer agent specification.

---

### Example 7: File Already Exists (Unexpected State)

**Command:**
```bash
export RSPEC_AUTOMATION_PROFILE=1
# Try to generate test when spec file already exists
```

**Report generated:**
```yaml
profiling_report:
  version: '1.0'
  component_name: 'rspec-write-new'
  timestamp: '2025-11-07T15:32:11Z'

  current_step:
    step_name: 'Prerequisites check'
    operation: 'Check if spec file exists'

  failure:
    type: 'file_exists_error'
    severity: 'error'  # Not critical, user decision needed
    message: 'Spec file already exists'

  state:
    spec_file: 'spec/services/payment_service_spec.rb'
    file_exists: true
    file_size: 2456
    file_mtime: '2025-11-05T10:20:00Z'

  recommendations:
    - 'Use rspec-update-diff skill to update existing test'
    - 'Or use rspec-refactor-legacy skill to refactor'
    - 'Or delete existing file if regeneration desired'
    - 'Skill should ask user what to do (in normal mode)'
```

**User action:** Use correct skill for the situation.

## Related Specifications

- `contracts/exit-codes.spec.md` - Exit code contract (profiling uses same codes)
- `contracts/metadata-format.spec.md` - Metadata validation (profiling checks schema)
- All agent specifications - Each must support profiling mode
- All skill specifications - Each must support profiling mode

---

**This profiling mode enables rapid iteration and improvement of the RSpec automation system based on real-world failures.**
