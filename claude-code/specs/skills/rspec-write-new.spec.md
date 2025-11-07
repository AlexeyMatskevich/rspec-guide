# rspec-write-new Skill Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Orchestration Skill
**Location:** `.claude/skills/rspec-write-new/SKILL.md`

## Philosophy / Why This Skill Exists

**Problem:** User has source code but no tests. Writing comprehensive, well-structured RSpec tests manually is time-consuming and error-prone.

**Solution:** rspec-write-new orchestrates 6 specialized agents to:
1. Analyze source code (characteristics, dependencies)
2. Generate test structure (context hierarchy)
3. Add semantic descriptions (it blocks)
4. Implement test bodies (let, subject, expectations)
5. Optimize factory usage
6. Polish and review

**Key Principle:** Sequential orchestration. Each agent completes before next starts. No parallel execution.

**Value:**
- 30-60 second test generation (vs 5-10 minutes manual)
- Follows all 28 rules from guide.en.md
- Consistent quality
- Comprehensive coverage (all characteristics)

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
  echo "   Skill: rspec-write-new" >&2
  echo "   Strict fail-fast: ANY error stops execution" >&2
  PROFILE_REPORT_DIR="${RSPEC_AUTOMATION_PROFILE_DIR:-tmp/rspec_profiling}"
  mkdir -p "$PROFILE_REPORT_DIR"
fi
```

### Before Skill Starts

```bash
# User must provide:
# 1. Source file path
# 2. Method name (optional - can infer from context)

if [ -z "$source_file" ]; then
  [ "$PROFILING_MODE" = "1" ] && generate_profiling_report "prerequisite_missing" "Source file not provided"
  echo "Error: Source file required" >&2
  echo "Usage: Write tests for <source_file>" >&2
  exit 1
fi

if [ ! -f "$source_file" ]; then
  [ "$PROFILING_MODE" = "1" ] && generate_profiling_report "prerequisite_missing" "Source file not found: $source_file"
  echo "Error: Source file not found: $source_file" >&2
  exit 1
fi
```

## Input Contract

**From user:**
```
Natural language request:
  "Write tests for app/services/payment_service.rb"
  "Create RSpec tests for PaymentService#process_payment"
  "I need tests for the calculate method in DiscountCalculator"
```

**Parsed to:**
```
source_file: app/services/payment_service.rb
method_name: process_payment (optional, can auto-detect)
```

## Output Contract

**Creates:**
1. Test file in appropriate location (spec/services/payment_service_spec.rb)
2. Metadata file (tmp/rspec_claude_metadata/metadata_*.yml)
3. Review report (tmp/rspec_claude_metadata/review_report_*.md)

**Shows user:**
- Success message with file location
- Summary of what was created
- Review results (violations, warnings, passes)

## Agent Orchestration Sequence

**🔴 MUST execute sequentially (NEVER parallel):**

```
1. rspec-analyzer
   ↓ (wait for completion)
2. spec_skeleton_generator.rb (Ruby script)
   ↓ (wait for completion)
3. rspec-architect
   ↓ (wait for completion)
4. rspec-implementer
   ↓ (wait for completion)
5. rspec-factory-optimizer
   ↓ (wait for completion)
6. rspec-polisher
   ↓ (wait for completion)
7. rspec-reviewer (automatic, READ-ONLY)
   ↓
✅ Complete
```

**After each agent:**
- Check exit code (0 = success, 1 = error, 2 = warning)
- If exit 1 → STOP pipeline, show user error
- If exit 0 or 2 → Continue to next agent

## Decision Trees

### Decision Tree 1: Method Name Not Provided?

```
User request: "Write tests for app/services/payment_service.rb"

Method name provided?
  NO → Analyze file, find testable methods:
    Found 1 public method? → Use it
    Found multiple? → Ask user which to test
    Found 0? → Error: "No testable methods found"
  YES → Use provided method name
```

### Decision Tree 2: Test File Already Exists?

```
Spec file exists at expected location?
  NO → Create new file, proceed
  YES → Ask user:
    "Spec file exists. Overwrite or append?"
    User says overwrite → Delete old, create new
    User says append → Use rspec-update-diff skill instead
    User cancels → Exit gracefully
```

### Decision Tree 3: Agent Fails - Continue or Stop?

```
Agent exits with code 1 (error):

Is agent optional? (e.g., factory-optimizer)
  YES → Log warning, skip to next agent
  NO → Critical agent failed:
    Show error to user
    Ask: "Try to continue or stop?"
    Continue → Skip failed agent, proceed
    Stop → Exit pipeline, preserve partial work
```

## State Machine

```
[START]
  ↓
[Parse User Request]
  ↓
[Determine Source File and Method]
  ├─ Method unclear? → [Ask User] → Continue
  └─ Clear? → Continue
      ↓
[Check Test File Exists]
  ├─ Exists? → [Ask User: Overwrite?]
  │              ├─ No → [END]
  │              └─ Yes → Continue
  └─ Not exists? → Continue
      ↓
[Invoke rspec-analyzer]
  ├─ Exit 1? → [Show Error] → [Ask: Continue?]
  │              ├─ No → [END]
  │              └─ Yes → Continue
  └─ Exit 0/2? → Continue
      ↓
[Invoke spec_skeleton_generator]
  ├─ Exit 1? → [Error] → [END]
  └─ Exit 0? → Continue
      ↓
[Invoke rspec-architect]
  ├─ Exit 1? → [Error] → [Ask: Continue?]
  └─ Exit 0/2? → Continue
      ↓
[Invoke rspec-implementer]
  ├─ Exit 1? → [Error] → [Ask: Continue?]
  └─ Exit 0/2? → Continue
      ↓
[Invoke rspec-factory-optimizer]
  (optional - warnings OK)
  ↓
[Invoke rspec-polisher]
  (optional - warnings OK)
  ↓
[Invoke rspec-reviewer]
  (automatic, always runs)
  ↓
[Show Results to User]
  ↓
[END]
```

## Algorithm

### Step-by-Step Workflow

**Step 1: Parse User Request**

```ruby
user_request = "Write tests for app/services/payment_service.rb"

# Extract file path
source_file = extract_file_path(user_request)
# → "app/services/payment_service.rb"

# Extract method (if specified)
method_name = extract_method_name(user_request)
# → nil (not specified)

# If method not specified, analyze file
if method_name.nil?
  methods = find_public_methods(source_file)
  if methods.length == 1
    method_name = methods.first
  elsif methods.length > 1
    method_name = ask_user("Which method to test?", methods)
  else
    error("No testable methods found in #{source_file}")
  end
end
```

**Step 2: Determine Spec File Location**

```ruby
# Follow Rails conventions
spec_file = source_file.sub('app/', 'spec/')
                       .sub('.rb', '_spec.rb')

# Example: app/services/payment_service.rb
#       → spec/services/payment_service_spec.rb

# Check if exists
if File.exist?(spec_file)
  response = ask_user("#{spec_file} exists. Overwrite?", ["Yes", "No", "Append"])
  case response
  when "No"
    return "Operation cancelled"
  when "Append"
    return "Use 'rspec-update-diff' skill for updating existing tests"
  when "Yes"
    # Continue, will overwrite
  end
end
```

**Step 3: Invoke rspec-analyzer**

```bash
echo "⚙️ Step 1/6: Analyzing source code..."

# Invoke analyzer agent
output=$(invoke_agent "rspec-analyzer" \
  --source-file "$source_file" \
  --method "$method_name")
exit_code=$?

case $exit_code in
  0)
    echo "✅ Analysis complete"
    metadata_path=$(echo "$output" | tail -1)
    ;;
  1)
    echo "❌ Analysis failed:"
    echo "$output"
    ask_continue || exit 1
    ;;
  2)
    echo "⚠️ Analysis completed with warnings:"
    echo "$output"
    # Continue
    ;;
esac
```

**Step 4: Invoke spec_skeleton_generator**

```bash
echo "⚙️ Step 2/6: Generating test structure..."

ruby lib/rspec_automation/generators/spec_skeleton_generator.rb \
  "$metadata_path" \
  "$spec_file"

if [ $? -ne 0 ]; then
  echo "❌ Structure generation failed"
  exit 1
fi

echo "✅ Structure generated: $spec_file"
```

**Step 5: Invoke rspec-architect**

```bash
echo "⚙️ Step 3/6: Adding semantic descriptions..."

invoke_agent "rspec-architect" \
  --metadata "$metadata_path" \
  --spec-file "$spec_file"

handle_agent_result $?
```

**Step 6: Invoke rspec-implementer**

```bash
echo "⚙️ Step 4/6: Implementing test bodies..."

invoke_agent "rspec-implementer" \
  --metadata "$metadata_path" \
  --spec-file "$spec_file"

handle_agent_result $?
```

**Step 7: Invoke rspec-factory-optimizer**

```bash
echo "⚙️ Step 5/6: Optimizing factory usage..."

invoke_agent "rspec-factory-optimizer" \
  --metadata "$metadata_path" \
  --spec-file "$spec_file"

# Optimizer warnings are OK
if [ $? -eq 1 ]; then
  echo "⚠️ Factory optimization skipped (not critical)"
fi
```

**Step 8: Invoke rspec-polisher**

```bash
echo "⚙️ Step 6/6: Polishing test..."

invoke_agent "rspec-polisher" \
  --spec-file "$spec_file"

# Polisher warnings are OK
handle_agent_result $?
```

**Step 9: Invoke rspec-reviewer (Automatic)**

```bash
echo "📋 Reviewing test against guide.en.md rules..."

invoke_agent "rspec-reviewer" \
  --spec-file "$spec_file" \
  --metadata "$metadata_path"

# Reviewer never fails, always generates report
report_file=$(find tmp/rspec_claude_metadata -name "review_report_*.md" -newest)
```

**Step 10: Show Results**

```bash
echo ""
echo "✅ Test generation complete!"
echo ""
echo "Created files:"
echo "  📝 Test: $spec_file"
echo "  📊 Metadata: $metadata_path"
echo "  📋 Review: $report_file"
echo ""

# Parse review results
violations=$(grep "❌ Violations:" "$report_file" | awk '{print $3}')
warnings=$(grep "⚠️ Warnings:" "$report_file" | awk '{print $3}')
passed=$(grep "✅ Passed:" "$report_file" | awk '{print $3}')

echo "Review Summary:"
echo "  ✅ Passed: $passed rules"
echo "  ⚠️ Warnings: $warnings rules"
echo "  ❌ Violations: $violations rules"

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "⚠️ Some violations found. Review report for details:"
  echo "   cat $report_file"
fi

echo ""
echo "Next steps:"
echo "  1. Review test: code $spec_file"
echo "  2. Run test: bundle exec rspec $spec_file"
if [ "$violations" -gt 0 ] || [ "$warnings" -gt 0 ]; then
  echo "  3. Address review feedback: cat $report_file"
fi
```

## Error Handling

### Error 1: Analyzer Fails (Critical)

```
❌ Analysis failed: Cannot extract characteristics from method

Method appears to have no conditional logic.

This usually means:
  1. Method is too simple (no tests needed)
  2. Method delegates to other methods (test those instead)
  3. Analyzer needs improvement (report issue)

Would you like to:
  [1] Continue anyway (may generate empty test)
  [2] Stop here
```

### Error 2: Source File Changed During Pipeline

```
⚠️ Warning: Source file modified during test generation

Cached metadata may be stale. Test may not match current code.

Recommendation: Re-run skill to regenerate with fresh analysis.

Continue with current test? [Y/n]
```

### Error 3: Test Already Exists

```
⚠️ Test file already exists: spec/services/payment_service_spec.rb

Options:
  [1] Overwrite (delete old, create new)
  [2] Cancel (keep existing test)
  [3] Update (use rspec-update-diff skill instead)

Your choice:
```

## Examples

### Example 1: Simple Success Case

**User request:**
```
"Write tests for app/services/discount_calculator.rb"
```

**Execution:**
```
⚙️ Step 1/6: Analyzing source code...
   Found method: calculate
   Extracting characteristics...
✅ Analysis complete

⚙️ Step 2/6: Generating test structure...
✅ Structure generated: spec/services/discount_calculator_spec.rb

⚙️ Step 3/6: Adding semantic descriptions...
✅ Descriptions added

⚙️ Step 4/6: Implementing test bodies...
✅ Implementation complete

⚙️ Step 5/6: Optimizing factory usage...
ℹ️ No factories used, skipping optimization

⚙️ Step 6/6: Polishing test...
✅ RuboCop: 2 offenses corrected
✅ Tests pass (3 examples)

📋 Reviewing test...
✅ Review complete

✅ Test generation complete!

Created files:
  📝 Test: spec/services/discount_calculator_spec.rb
  📊 Metadata: tmp/rspec_claude_metadata/metadata_app_services_discount_calculator.yml
  📋 Review: tmp/rspec_claude_metadata/review_report_20251107_163000.md

Review Summary:
  ✅ Passed: 28 rules
  ⚠️ Warnings: 0 rules
  ❌ Violations: 0 rules

Next steps:
  1. Review test: code spec/services/discount_calculator_spec.rb
  2. Run test: bundle exec rspec spec/services/discount_calculator_spec.rb
```

**Time:** ~45 seconds

---

### Example 2: Multiple Methods - Ask User

**User request:**
```
"Write tests for app/models/user.rb"
```

**Execution:**
```
⚙️ Analyzing app/models/user.rb...

Found 3 public methods:
  1. full_name
  2. email_domain
  3. activate!

Which method would you like to test?
[Enter number or 'all' for all methods]

> 3

⚙️ Writing tests for User#activate!
[continues with pipeline...]
```

---

### Example 3: Test Exists - Overwrite

**User request:**
```
"Write tests for app/services/payment_service.rb"
```

**Execution:**
```
⚠️ Test file already exists: spec/services/payment_service_spec.rb

Options:
  [1] Overwrite (delete old, create new)
  [2] Cancel (keep existing test)
  [3] Update (use rspec-update-diff skill instead)

Your choice: 1

⚠️ Overwriting existing test. Old file backed up to:
   spec/services/payment_service_spec.rb.backup

⚙️ Step 1/6: Analyzing source code...
[continues with pipeline...]
```

## Integration Points

### Called by User

```
Natural language:
  "Write tests for <file>"
  "Create RSpec tests for <Class>#<method>"
  "I need tests for <description>"
```

### Calls Other Skills

- Does NOT call other skills (self-contained)

### Calls Agents

- rspec-analyzer (critical)
- rspec-architect (critical)
- rspec-implementer (critical)
- rspec-factory-optimizer (optional)
- rspec-polisher (optional)
- rspec-reviewer (automatic)

## Testing Criteria

**Skill is correct if:**
- ✅ Orchestrates agents in correct order
- ✅ Waits for each agent to complete
- ✅ Handles errors gracefully (ask user)
- ✅ Generates working test
- ✅ Shows clear progress and results

**Common issues:**
- Parallel execution (forbidden!)
- Continuing after critical error
- Not showing user what happened
- No review at end

## Related Specifications

- **agents/rspec-analyzer.spec.md** - First agent
- **agents/rspec-reviewer.spec.md** - Last agent
- **skills/rspec-update-diff.spec.md** - Alternative for updating tests
- **skills/rspec-refactor-legacy.spec.md** - Alternative for refactoring

---

**Key Takeaway:** Sequential orchestrator. Each agent completes before next starts. Clear feedback to user at each step.
