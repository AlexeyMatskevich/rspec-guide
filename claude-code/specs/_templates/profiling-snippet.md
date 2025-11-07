# Profiling Mode Snippet

**Use this snippet in ALL skills and agents.**

## For Skills (Full Version)

```markdown
## Profiling Mode

**Enable for debugging/specification improvement:**

```bash
export RSPEC_AUTOMATION_PROFILE=1
```

**Behavior when enabled:**
- ✅ Strict fail-fast on ANY error
- ✅ Detailed YAML report generated in `tmp/rspec_profiling/`
- ❌ NO self-healing attempts
- ❌ NO alternative approaches

See `contracts/profiling-mode.spec.md` for complete details.

**Default:** Profiling disabled (normal mode with graceful error handling)

## Prerequisites Check

### Step 0: Detect Profiling Mode

```bash
PROFILING_MODE="${RSPEC_AUTOMATION_PROFILE:-0}"

if [ "$PROFILING_MODE" = "1" ]; then
  echo "🔍 PROFILING MODE ENABLED" >&2
  echo "   Skill: {SKILL_NAME}" >&2
  echo "   Strict fail-fast: ANY error stops execution" >&2
  PROFILE_REPORT_DIR="${RSPEC_AUTOMATION_PROFILE_DIR:-tmp/rspec_profiling}"
  mkdir -p "$PROFILE_REPORT_DIR"
fi
```
```

## For Agents (Compact Version)

```markdown
## Profiling Mode

**Enabled via:** `export RSPEC_AUTOMATION_PROFILE=1`

**Behavior:**
- Stop immediately on ANY error (no self-healing)
- Generate detailed report in `tmp/rspec_profiling/`

See `contracts/profiling-mode.spec.md` for details.

### Detection

```bash
PROFILING_MODE="${RSPEC_AUTOMATION_PROFILE:-0}"
[ "$PROFILING_MODE" = "1" ] && echo "🔍 PROFILING: {AGENT_NAME}" >&2
```

### Error Handling

```bash
if some_check_fails; then
  [ "$PROFILING_MODE" = "1" ] && generate_profiling_report "error_type" "error message"
  exit 1
fi
```
```

## generate_profiling_report Function Template

```bash
function generate_profiling_report() {
  local error_type="$1"
  local error_message="$2"

  [ "$PROFILING_MODE" != "1" ] && return  # Skip in normal mode

  local report_file="$PROFILE_REPORT_DIR/report_$(date +%Y%m%d_%H%M%S)_$$_{COMPONENT_NAME}.yml"

  cat > "$report_file" <<EOF
profiling_report:
  version: '1.0'
  component_type: '{TYPE}'  # 'skill' or 'agent'
  component_name: '{COMPONENT_NAME}'
  timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'

  failure:
    type: '$error_type'
    severity: 'critical'
    message: '$error_message'

  # Add more context as needed
EOF

  echo "" >&2
  echo "❌ PROFILING FAILURE" >&2
  echo "   Report: $report_file" >&2
  cat "$report_file" >&2
}
```

## Usage in Prerequisites

```bash
# Example: Check RuboCop availability
if [ "$PROFILING_MODE" = "1" ]; then
  if ! command -v rubocop &> /dev/null; then
    generate_profiling_report "prerequisite_missing" "rubocop not found in PATH"
    exit 1
  fi
fi

# Normal mode: skip gracefully
if ! command -v rubocop &> /dev/null; then
  echo "Warning: RuboCop not available, skipping..." >&2
fi
```

## Usage in Script Execution

```bash
# Run Ruby script
if ! ruby script.rb "$args"; then
  [ "$PROFILING_MODE" = "1" ] && generate_profiling_report "script_error" "script.rb failed with exit code $?"
  exit 1
fi
```

## Usage in Agent Invocation

```bash
# Invoke agent
agent_output=$(invoke_agent "rspec-analyzer" --source "$source_file" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  if [ "$PROFILING_MODE" = "1" ]; then
    generate_profiling_report "agent_error" "rspec-analyzer failed with exit code $exit_code"
  fi
  exit 1
fi
```
