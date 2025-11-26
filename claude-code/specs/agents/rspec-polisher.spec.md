# rspec-polisher Agent Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Subagent
**Location:** `.claude/agents/rspec-polisher.md`

## ⚠️ YOU ARE A CLAUDE AI AGENT (ORCHESTRATOR TYPE)

**This agent is DIFFERENT from others:**
- Unlike analyzer/architect/implementer, polisher DOES run actual bash commands
- You orchestrate external tools: `ruby -c`, `rubocop -A`, `rspec`
- Bash commands in this spec ARE the actual workflow

**However, you are still Claude AI agent:**
- You intelligently handle errors
- You adapt to different configurations (RuboCop vs StandardRB)
- You make decisions about auto-fix vs manual review

**You do NOT analyze code semantics** - you run tools and coordinate their output.

---

## Philosophy / Why This Agent Exists

**Problem:** Test is functionally complete but may have:
- RuboCop violations (style issues)
- Syntax errors
- Tests that don't run
- Minor formatting issues

**Solution:** polisher runs automated checks and fixes:
- RuboCop auto-correct
- Syntax validation
- Test execution (ensure tests actually run)
- Basic quality checks

**Key Principle:** Automated fixes only. No semantic changes. If can't auto-fix, warn user.

**Value:**
- Tests are syntactically correct
- Style consistent with project
- Tests actually run before review
- Saves manual cleanup time

## Prerequisites Check

### 🔴 MUST Check

```bash
# 1. Factory agent completed (or implementer if factory skipped)
if ! grep -q "implementer_completed: true" "$metadata_path"; then
  echo "Error: No previous agent completed" >&2
  exit 1
fi

# 2. Spec file exists
if [ ! -f "$spec_file" ]; then
  echo "Error: Spec file not found: $spec_file" >&2
  exit 1
fi

# 3. Detect linter tool (RuboCop or StandardRB)
LINTER=""
LINTER_COMMAND=""

if [ -f ".rubocop.yml" ] || [ -f ".rubocop_todo.yml" ]; then
  # RuboCop configured
  if command -v rubocop &> /dev/null || bundle exec rubocop --version &> /dev/null 2>&1; then
    LINTER="rubocop"
    LINTER_COMMAND="bundle exec rubocop"
  fi
elif [ -f ".standard.yml" ] || grep -q "standard" Gemfile 2>/dev/null; then
  # StandardRB configured
  if command -v standardrb &> /dev/null || bundle exec standardrb --version &> /dev/null 2>&1; then
    LINTER="standardrb"
    LINTER_COMMAND="bundle exec standardrb"
  fi
elif bundle exec rubocop --version &> /dev/null 2>&1; then
  # Fallback: RuboCop in Gemfile but no config
  LINTER="rubocop"
  LINTER_COMMAND="bundle exec rubocop"
fi

# Note: If no linter found, polisher will skip linting step (not an error)
if [ -z "$LINTER" ]; then
  echo "⚠️  No linter detected (RuboCop/StandardRB)" >&2
  echo "    Skipping style auto-correction" >&2
fi
```

## Phase 0: Check Serena MCP (Optional)

**Note:** Polisher primarily uses external tools (RuboCop, RSpec). Serena is less critical here.

### Verification

Use Serena tool to check if MCP is available:

```json
{
  "tool": "mcp__serena__get_current_config"
}
```

### If Serena NOT available

**WARNING (not error):**

```
⚠️ Warning: Serena MCP not available

Polisher can still run without Serena (uses RuboCop, RSpec).
Some advanced source code navigation may be limited.

Continuing without Serena...
```

### If Serena available

Continue to TodoWrite creation and Phase 1.

**Why optional:** Polisher primarily orchestrates external tools (ruby -c, rubocop, rspec). It doesn't perform semantic code analysis like analyzer or implementer.

## Input Contract

**Reads:**
- Spec file (functionally complete but may have issues)

**No metadata needed** (works purely on spec file)

## Output Contract

**Writes:**
- Updated spec file (polished)
- Updated metadata.yml

**Updates metadata.yml:**
```yaml
automation:
  polisher_completed: true
  polisher_version: '1.0'
  linter: 'rubocop'  # or 'standardrb' or null if none detected
  warnings:
    - "rubocop: 3 offenses auto-corrected"
    - "Tests run successfully"
```

## Decision Trees

### Decision Tree 1: What Linter to Use?

```
Detect linter in project:

Found .rubocop.yml or .rubocop_todo.yml?
  YES → Is rubocop available?
    YES → Use RuboCop with --autocorrect
    NO → Skip linting, warn user
  NO → Continue

Found .standard.yml or 'standard' in Gemfile?
  YES → Is standardrb available?
    YES → Use StandardRB with --fix
    NO → Skip linting, warn user
  NO → Continue

Is rubocop available in bundle?
  YES → Use RuboCop (no config, fallback)
  NO → Skip linting (not an error)
```

### Decision Tree 2: Can Auto-Fix Issue?

```
Found issue (linter offense, syntax error, etc.):

Is this auto-fixable?
  (Linter with --autocorrect/--fix, obvious syntax)
  YES → Fix automatically
  NO → Add to warnings, don't modify

Example:
  Issue: Missing frozen_string_literal comment
  Auto-fix? YES → Add comment

  Issue: Logic error in expectation
  Auto-fix? NO → Warn user
```

### Decision Tree 3: Should Run Tests?

```
All checks passed?
  YES → Run tests (rspec spec_file)
    Tests pass? → Success
    Tests fail? → Warn user (don't modify file)
  NO → Skip test run (file has errors)
```

## Algorithm

### Step-by-Step Process

**Step 1: Syntax Check**

```bash
# Check Ruby syntax
if ! ruby -c "$spec_file" > /dev/null 2>&1; then
  echo "Error: Syntax error in spec file" >&2
  ruby -c "$spec_file" >&2
  echo "" >&2
  echo "Cannot polish file with syntax errors" >&2
  echo "This is likely a bug in rspec-implementer" >&2
  exit 1
fi

echo "✅ Syntax check passed"
```

**Step 2: Linter Auto-Correct**

```bash
# Run linter with auto-correct (if detected in prerequisites)
if [ -n "$LINTER" ]; then
  echo "Running $LINTER auto-correct..."

  case $LINTER in
    rubocop)
      linter_output=$($LINTER_COMMAND --autocorrect "$spec_file" 2>&1)
      ;;
    standardrb)
      linter_output=$($LINTER_COMMAND --fix "$spec_file" 2>&1)
      ;;
  esac

  exit_code=$?

  case $exit_code in
    0)
      echo "✅ $LINTER: No offenses"
      ;;
    1)
      # Offenses corrected
      corrected=$(echo "$linter_output" | grep "corrected" | head -1)
      echo "✅ $LINTER: $corrected"
      warnings+=("$LINTER: $corrected")
      ;;
    2)
      # Linter crashed (error, not offenses)
      echo "❌ $LINTER crashed" >&2
      echo "$linter_output" >&2
      warnings+=("$LINTER error - see output above")
      ;;
    *)
      # Offenses remain (couldn't auto-fix)
      echo "⚠️ $LINTER: Some offenses remain (manual fix needed)"
      warnings+=("$LINTER violations need manual review")
      ;;
  esac
else
  echo "⏭️  Skipping linter (not configured in project)"
fi
```

**Step 3: Run Tests**

```bash
# Only if syntax and RuboCop OK
if [ ${#errors[@]} -eq 0 ]; then
  # Check if RSpec is available
  if bundle exec rspec --version &> /dev/null 2>&1; then
    echo "Running tests..."

    test_output=$(bundle exec rspec "$spec_file" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
      test_count=$(echo "$test_output" | grep -o "[0-9]* example" | awk '{print $1}')
      echo "✅ Tests pass ($test_count examples)"
    else
      echo "⚠️ Tests fail"
      echo "$test_output"
      warnings+=("Tests fail - review needed")
    fi
  else
    echo "⚠️  RSpec not available, skipping test execution" >&2
    warnings+=("RSpec not available for test execution")
  fi
fi
```

**Step 4: Quality Checks**

```bash
# Check for common issues

# 1. Empty it blocks
if grep -E -q "it '[^']*' do[[:space:]]*end" "$spec_file"; then
  warnings+=("Found empty it blocks (no expectations)")
fi

# 2. Missing expectations
it_blocks=$(grep -c "it '" "$spec_file" || true)
expect_count=$(grep -c "expect" "$spec_file" || true)

if [ $it_blocks -gt $expect_count ]; then
  warnings+=("Some it blocks may be missing expectations")
fi

# 3. Redundant examples (same description)
# Extract just descriptions (text inside quotes), ignore indentation
duplicates=$(grep -o "it '[^']*'" "$spec_file" | sort | uniq -d)
if [ -n "$duplicates" ]; then
  warnings+=("Duplicate it descriptions found")
fi
```

**Step 5: Write Output**

```bash
# Update metadata.yml with completion status
# Option 1: Simple append (if metadata structure is flat)
cat >> "$metadata_path" <<EOF

automation:
  polisher_completed: true
  polisher_version: '1.0'
  linter: ${LINTER:-null}
EOF

# Add warnings if any
if [ ${#warnings[@]} -gt 0 ]; then
  echo "  warnings:" >> "$metadata_path"
  for warning in "${warnings[@]}"; do
    # Escape quotes in warning text for YAML
    escaped_warning=$(echo "$warning" | sed 's/"/\\"/g')
    echo "    - \"$escaped_warning\"" >> "$metadata_path"
  done
fi

echo "✅ Polishing complete"
echo "   Warnings: ${#warnings[@]}"

if [ ${#warnings[@]} -gt 0 ]; then
  echo "" >&2
  echo "Warnings:" >&2
  for warning in "${warnings[@]}"; do
    echo "  - $warning" >&2
  done
fi

exit 0
```

## Error Handling (Fail Fast)

### Error 1: Syntax Error (Can't Fix)

```bash
echo "Error: Syntax error in spec file" >&2
ruby -c "$spec_file" >&2
echo "" >&2
echo "This is a bug in previous agent (likely rspec-implementer)" >&2
echo "File cannot be polished with syntax errors" >&2
exit 1
```

### Error 2: Linter Not Available (Warning, Not Critical)

```bash
if [ -z "$LINTER" ]; then
  echo "Warning: No linter detected (RuboCop/StandardRB)" >&2
  echo "    Skipping style auto-correction" >&2
  warnings+=("No linter available")
  # Continue (not critical - linter is optional)
fi
```

**Note:** Missing linter is a WARNING, not an ERROR. Polisher continues with syntax check and test execution.

## Dependencies

**Must run after:**
- rspec-factory (or implementer)

**Must run before:**
- rspec-reviewer (reviewer reads polished result)

**Reads:**
- spec file

**Writes:**
- spec file (polished)
- metadata.yml (marks completion)

**External tools:**
- ruby (🔴 required - syntax check)
- rubocop or standardrb (🟡 optional - style auto-correction)
- rspec (🟡 optional - test execution)

## Examples

### Example 1: Auto-Fix RuboCop Offenses

**Input spec:**
```ruby
RSpec.describe User do
  describe '#name' do
    it 'returns name' do
      expect(user.name).to eq('John')  # Line too long (over 120 chars in reality)
    end
  end
end
```

**Process:**
1. Syntax check: PASS
2. RuboCop: Found offense (line too long)
3. Auto-correct: Break line
4. Run tests: PASS

**Output:**
```ruby
# frozen_string_literal: true

RSpec.describe User do
  describe '#name' do
    it 'returns name' do
      expect(user.name)
        .to eq('John')
    end
  end
end
```

**stderr:**
```
✅ RuboCop: 2 offenses corrected
✅ Tests pass (1 example)
```

---

### Example 2: Tests Fail (Warning)

**Input spec:**
```ruby
RSpec.describe Calculator do
  it 'calculates' do
    expect(calculator.add(1, 2)).to eq(4)  # Wrong expectation!
  end
end
```

**Process:**
1. Syntax: PASS
2. RuboCop: PASS
3. Run tests: FAIL (expected 4, got 3)

**Output:** (file unchanged)

**stderr:**
```
⚠️ Tests fail

Failures:
  1) Calculator calculates
     Failure/Error: expect(calculator.add(1, 2)).to eq(4)
       expected: 4
            got: 3

This requires manual review and fix
```

**Exit code:** 0 (warning, not error)

---

### Example 3: Nothing to Polish

**Input spec:**
```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#name' do
    subject(:result) { user.name }

    let(:user) { build_stubbed(:user, name: 'John') }

    it 'returns name' do
      expect(result).to eq('John')
    end
  end
end
```

**Process:**
1. Syntax: PASS
2. RuboCop: PASS (no offenses)
3. Tests: PASS

**Output:** (unchanged)

**stderr:**
```
✅ Syntax check passed
✅ RuboCop: No offenses
✅ Tests pass (1 example)
✅ No issues found
```

---

### Example 4: StandardRB Auto-Fix

**Prerequisites detected:**
```bash
# .standard.yml exists
# standardrb gem in Gemfile
LINTER="standardrb"
```

**Input spec:**
```ruby
RSpec.describe PaymentService do
  describe '#process' do
    it "charges card" do  # StandardRB prefers single quotes
      expect(service.process).to eq(true)
    end
  end
end
```

**Process:**
1. Syntax: PASS
2. StandardRB: Found offense (string quotes)
3. Auto-fix: Change double quotes to single quotes
4. Tests: PASS

**Output:**
```ruby
# frozen_string_literal: true

RSpec.describe PaymentService do
  describe '#process' do
    it 'charges card' do
      expect(service.process).to eq(true)
    end
  end
end
```

**stderr:**
```
✅ Syntax check passed
✅ standardrb: 1 offense corrected
✅ Tests pass (1 example)
```

**metadata.yml updated:**
```yaml
automation:
  polisher_completed: true
  linter: 'standardrb'
  warnings:
    - "standardrb: 1 offense corrected"
```

---

### Example 5: No Linter Detected

**Prerequisites detected:**
```bash
# No .rubocop.yml, no .standard.yml
# No linter gems in Gemfile
LINTER=""
```

**Process:**
1. Syntax: PASS
2. Linter: SKIPPED (not available)
3. Tests: PASS

**stderr:**
```
⚠️  No linter detected (RuboCop/StandardRB)
    Skipping style auto-correction
✅ Syntax check passed
⏭️  Skipping linter (not configured in project)
✅ Tests pass (1 example)
```

**metadata.yml updated:**
```yaml
automation:
  polisher_completed: true
  linter: null
  warnings:
    - "No linter available"
```

**Exit code:** 0 (success - linter is optional)

## Integration with Skills

### From rspec-write-new skill

```markdown
Sequential execution:
1-4. [previous agents]
5. rspec-factory
6. rspec-polisher ← final cleanup before review
7. rspec-reviewer ← reviews polished result
```

## Testing Criteria

**Agent is correct if:**
- ✅ Auto-fixes safe issues (style, formatting)
- ✅ Detects but doesn't break on test failures
- ✅ Syntax errors caught early
- ✅ Doesn't modify semantics (only style)

**Should NOT:**
- Change test logic
- Fix failing tests by changing expectations
- Make semantic changes

## Related Specifications

- **agents/rspec-factory.spec.md** - Previous agent
- **agents/rspec-reviewer.spec.md** - Next agent

---

**Key Takeaway:** Automated cleanup only. Safe style fixes, detect issues, don't break semantics.
