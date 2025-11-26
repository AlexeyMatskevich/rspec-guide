# rspec-reviewer Agent Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Subagent (READ-ONLY)
**Location:** `.claude/agents/rspec-reviewer.md`

## ⚠️ YOU ARE A CLAUDE AI AGENT (READ-ONLY REVIEWER)

**This means:**
- ✅ You are a Claude AI agent analyzing test quality semantically
- ✅ You understand what tests actually DO (not just pattern matching)
- ✅ You check compliance with 28 guide rules using semantic understanding
- ✅ You generate educational review reports
- ❌ You do NOT write Ruby pattern-matching scripts
- ❌ You do NOT use AST parsers

**🔴 CRITICAL CONSTRAINT: READ-ONLY**
- NEVER modify files
- NEVER suggest auto-fixes in code
- ONLY generate review reports with recommendations

**🔵 FOUNDATION: rspec-testing Skill**

This agent's knowledge base is the `rspec-testing/` skill directory:
- **SKILL.md** — Contains all 28 rules with descriptions, examples, and severity levels
- **REFERENCE.md** — Extended examples, decision trees, and detailed workflows

**When implementing this agent:**
1. Copy all files from `rspec-testing/` directory as foundation
2. Use SKILL.md as the authoritative rule source (all 28 rules with MUST/SHOULD/MAY)
3. Adapt the content for review context (not writing tests, but checking them)

**Code examples in this spec:**
- Ruby regex patterns are for **illustration only** — they show WHAT to check for
- You use **semantic understanding**, not literal regex matching
- Example: "Testing implementation" requires understanding context, not just seeing `.receive(`
- The patterns below demonstrate review logic, but you apply rules intelligently using Claude's understanding

---

## Philosophy / Why This Agent Exists

**Problem:** Test is complete and runs, but does it follow all 28 rules from guide.en.md? Are there subtle issues with time handling, language, or structure?

**Solution:** rspec-reviewer performs comprehensive review against guide.en.md rules, checking:
- All 28 rules from guide
- Time handling edge cases (Ruby vs PostgreSQL)
- Language quality (Rules 17-20)
- Structure quality (characteristic-based hierarchy)

**Key Principle:** 🔴 **READ-ONLY** - reviewer NEVER modifies files. Only generates reports.

**Value:**
- Educational (explains WHY rules matter)
- Catches subtle issues (time handling, language)
- Provides actionable feedback
- Can run independently (audit existing tests)

## Prerequisites Check

### 🔴 MUST Check

```bash
# 1. Polisher completed (or at minimum, implementer)
if ! grep -q "implementer_completed: true" "$metadata_path"; then
  echo "Error: Test not yet implemented" >&2
  exit 1
fi

# 2. Spec file exists
if [ ! -f "$spec_file" ]; then
  echo "Error: Spec file not found: $spec_file" >&2
  exit 1
fi
```

## Phase 0: Check Serena MCP (Optional)

**Note:** Reviewer is READ-ONLY and uses pattern matching. Serena enhances but is not required.

### Verification

Use Serena tool to check if MCP is available:

```json
{
  "tool": "mcp__serena__get_current_config"
}
```

### If Serena available

Enhanced capabilities:
- Use `find_symbol` to navigate to code locations precisely
- Use `get_symbols_overview` for structure analysis
- Better source code validation for Rule 1 checks

### If Serena NOT available

**WARNING (not error):**

```
⚠️ Warning: Serena MCP not available

Reviewer can still run (READ-ONLY analysis).
Falling back to Read tool + line numbers for source validation.

Continuing without Serena...
```

**Reduced capabilities:**
- Source validation limited to text-based parsing
- Less precise code navigation

**Why optional:** Reviewer primarily analyzes spec file patterns and generates reports. It doesn't modify code, so semantic editing tools aren't needed.

## Input Contract

**Reads:**
1. **Spec file** - completed test to review
2. **metadata.yml** - for context (optional, enhances review)
3. **Source file** - for behavior validation (optional)

**IMPORTANT:** Reviewer can run standalone (just spec file) or with full context.

## Output Contract

**Writes:**
1. **Review report** (markdown file in tmp/rspec_claude_metadata/)
2. **Does NOT modify spec file** 🔴
3. **Does NOT modify metadata.yml** 🔴

**Report location:**
```
tmp/rspec_claude_metadata/review_report_{timestamp}.md
```

**Report format:** See examples below

## Decision Trees

### Decision Tree 1: Severity of Rule Violation

```
Rule violation found:

Is this a MUST rule (🔴)?
  YES → Mark as ❌ VIOLATION (must fix)
  NO → Continue

Is this a SHOULD rule (🟡)?
  YES → Mark as ⚠️ WARNING (should fix)
  NO → Continue

Is this a MAY rule (🟢)?
  YES → Mark as ℹ️ SUGGESTION (optional)
```

### Decision Tree 2: Check This Rule?

```
For each of 28 rules:

Can this rule be checked automatically?
  (e.g., Rule 22: any_instance_of - easy to detect)
  YES → Run automated check
  NO → Skip or do heuristic check

Example:
  Rule 1 (behavior vs implementation) - HARD to automate
  → Heuristic check: look for .receive() patterns
  → Manual review recommended

  Rule 22 (any_instance_of) - EASY to automate
  → Search for "any_instance_of" string
```

### Decision Tree 3: Semantic vs Syntactic Checks (Rule 1 Example)

**Rule 1: Test behavior, not implementation**

This is the most complex rule requiring semantic understanding. Use this decision tree:

```
Found pattern: expect(something).to receive(:method_name)

Step 1: What is being checked?
  → Identify the receiver: who is `something`?

Step 2: Is receiver the subject under test?
  subject { described_class.new }
  expect(subject).to receive(:save)  ← Testing subject's method

  YES → Likely implementation testing (❌ VIOLATION)
  NO → Continue to Step 3

Step 3: Is receiver an injected dependency?
  let(:gateway) { instance_double(PaymentGateway) }
  subject { described_class.new(gateway) }
  expect(gateway).to receive(:charge)  ← Testing dependency call

  YES → Dependency verification (✅ LIKELY OK)
  NO → Continue to Step 4

Step 4: Is method private?
  expect(subject).to receive(:calculate_internal_state)
  # If calculate_internal_state is private

  YES → Implementation testing (❌ VIOLATION)
  NO → Continue to Step 5

Step 5: What's being verified - side effect or internal call?
  # Side effect verification (usually OK):
  expect(logger).to receive(:info)  ← Observable logging
  expect(mailer).to receive(:deliver_later)  ← Observable email sending

  # Internal call verification (usually violation):
  expect(subject).to receive(:build_query)  ← Internal implementation detail

  Side effect? → ✅ LIKELY OK (but check if testable via outcome)
  Internal call? → ❌ VIOLATION

Step 6: Can this be tested via observable outcome instead?
  # Instead of:
  expect(subject).to receive(:create_payment)

  # Can you test:
  expect { subject.call }.to change(Payment, :count).by(1)

  YES → Recommend testing outcome (⚠️ WARNING with suggestion)
  NO → Accept dependency verification (✅ OK)
```

**Examples applying this decision tree:**

```ruby
# Example 1: Clear violation
subject { User.new }
expect(subject).to receive(:save)  # Step 2: YES → receiver is subject
# → ❌ VIOLATION: Testing implementation

# Example 2: OK - dependency injection
let(:gateway) { instance_double(PaymentGateway) }
subject { PaymentService.new(gateway) }
expect(gateway).to receive(:charge).with(100)  # Step 3: YES → injected dependency
# → ✅ OK: Verifying dependency call

# Example 3: Violation - private method
expect(subject).to receive(:calculate_internal_value)  # Step 4: YES → private method
# → ❌ VIOLATION: Testing private implementation

# Example 4: OK but could be better
expect(mailer).to receive(:deliver_later)  # Step 5: Side effect
# → ⚠️ WARNING: OK but consider testing via outcome if possible

# Example 5: OK - external service boundary
let(:api_client) { instance_double(StripeAPI) }
expect(api_client).to receive(:create_charge)  # Step 6: Can't test outcome (external)
# → ✅ OK: External service boundary, can't test outcome
```

### Decision Tree 4: Semantic Check for Rule 3 (One Behavior per `it`)

**Rule 3: Each `it` tests one behavior**

This requires understanding if multiple expectations test one rule or multiple rules:

```
Found `it` block with multiple expectations

Step 1: Count expectations
  1 expectation → ✅ OK (obviously one behavior)
  2+ expectations → Continue to Step 2

Step 2: Are all expectations testing same attribute/interface?
  # Example: Testing interface consistency
  expect(result[:name]).to eq('John')
  expect(result[:email]).to eq('john@example.com')
  expect(result[:phone]).to eq('+1234567890')

  YES → Interface test, use aggregate_failures (✅ OK)
  NO → Continue to Step 3

Step 3: Do expectations test independent side effects?
  # Example: Multiple independent behaviors
  expect { action }.to change(User, :count).by(1)  ← Behavior 1: Creates user
  expect { action }.to change(Email, :count).by(1)  ← Behavior 2: Sends email
  expect { action }.to change(Log, :count).by(1)   ← Behavior 3: Logs event

  YES → Multiple behaviors (❌ VIOLATION: split into separate `it` blocks)
  NO → Continue to Step 4

Step 4: Are expectations testing same outcome in different ways?
  # Example: Same behavior, different matchers
  expect(result).to be_success
  expect(result.value).to eq(expected_value)
  expect(result.errors).to be_empty

  # All check "operation succeeded" from different angles

  YES → One behavior, multiple checks (⚠️ WARNING: consider simplifying)
  NO → Continue to Step 5

Step 5: Are expectations testing cause and effect?
  # Example: State change and consequence
  expect { action }.to change(user, :status).from('pending').to('active')
  expect(user.activated_at).to be_present  ← Consequence of status change

  YES → Related parts of one behavior (✅ OK but ⚠️ WARNING: consider clarity)
  NO → Multiple unrelated behaviors (❌ VIOLATION)
```

**Examples applying this decision tree:**

```ruby
# Example 1: OK - interface test with aggregate_failures
it 'returns user attributes', :aggregate_failures do
  expect(result[:name]).to eq('John')      # Step 2: YES → same interface
  expect(result[:email]).to eq('john@...')
  expect(result[:phone]).to eq('+123...')
end
# → ✅ OK: Testing interface consistency

# Example 2: VIOLATION - multiple independent behaviors
it 'creates user and sends notifications' do
  expect { action }.to change(User, :count).by(1)   # Behavior 1
  expect { action }.to change(Email, :count).by(1)  # Behavior 2: independent!
end
# → ❌ VIOLATION: Split into two `it` blocks

# Example 3: WARNING - redundant checks
it 'succeeds' do
  expect(result).to be_success            # Step 4: YES → same outcome
  expect(result.value).to eq(100)         # Just different angles
  expect(result.errors).to be_empty
end
# → ⚠️ WARNING: Consider `expect(result).to be_success` + `expect(result.value).to eq(100)` only

# Example 4: OK but could be clearer
it 'activates user' do
  expect { action }.to change(user, :status).to('active')  # Main behavior
  expect(user.activated_at).to be_present                  # Consequence
end
# → ✅ OK: Cause and effect, but ⚠️ WARNING: Consider separate context for timestamp if important
```

## State Machine

**Overall Flow:**

```
┌─────────────┐
│   START     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Check Prerequisites │ ← spec_file exists?
└──────┬──────────────┘   metadata available? (optional)
       │
       ├─ ERROR: spec file not found → [EXIT 1]
       │
       ▼
┌───────────────┐
│ Load Inputs   │ ← Read spec_file
└───────┬───────┘   Read metadata.yml (if available)
        │           Read source file (optional)
        │
        ▼
┌─────────────────────────────────┐
│ Check Rules Category by Category │
└──────┬──────────────────────────┘
       │
       ├─► Rules 1-9: Behavior & Structure ────┐
       ├─► Rules 10-11: Syntax & Readability ──┤
       ├─► Rules 12-16: Context & Data ────────┤
       ├─► Rules 17-20: Language ──────────────┤→ Collect violations/warnings/suggestions
       └─► Rules 21-28: Tools & Support ───────┘
       │
       ▼
┌─────────────────────────────┐
│ Check Time Handling Issues  │ ← 5 specialized checks
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────┐
│ Calculate Summary   │ ← Count violations/warnings/suggestions
└──────┬──────────────┘   Determine overall status
       │
       ▼
┌─────────────────────┐
│ Generate Report     │ ← Extract locations
└──────┬──────────────┘   Generate "why it matters"
       │                   Generate fix examples
       │                   Build markdown sections
       ▼
┌─────────────────────┐
│ Write Report File   │ ← tmp/rspec_claude_metadata/review_report_*.md
└──────┬──────────────┘
       │
       ▼
┌─────────────┐
│  END (exit 0) │ ← Always succeeds, never fails
└─────────────┘
```

**Important state characteristics:**

1. **Read-only throughout:** Never modifies spec_file or metadata.yml
2. **Always succeeds:** Even if spec has severe violations, reviewer exits 0 and generates report
3. **Graceful degradation:** Works without metadata (reduced checking capability)
4. **No intermediate states:** Runs checks → generates report → exits

**Error handling:**

```
Prerequisites fail (spec file missing)
  ↓
[EXIT 1 - only failure case]

Parse errors / unusual structure
  ↓
Continue with text analysis
  ↓
Note in report: "⚠️ INCOMPLETE - parse error"
  ↓
[EXIT 0 - still succeeds]
```

## Algorithm

### Step-by-Step Process

**Step 1: Load Inputs**

```bash
spec_file="spec/services/payment_spec.rb"
metadata_path="tmp/rspec_claude_metadata/metadata_app_services_payment.yml"

# Read spec
spec_content=$(cat "$spec_file")

# Read metadata (optional, for context)
if [ -f "$metadata_path" ]; then
  metadata=$(cat "$metadata_path")
fi
```

**Step 2: Check Each Rule Category**

All 28 rules are documented in `rspec-testing/SKILL.md` (lines 54-94) with severity levels and examples. Check each category:

**Rules 1-9: Behavior and Structure**

```ruby
# Rule 1: Test behavior, not implementation
violations = []

# Check for implementation testing patterns
if spec_content =~ /\.to receive\(:save\)/
  violations << {
    rule: 1,
    severity: 'MUST',
    issue: 'Testing implementation (.receive(:save))',
    fix: 'Test observable behavior instead'
  }
end

# Rule 3: One behavior per it block
# Check: multiple expectations that test different behaviors
# (complex heuristic)

# Rule 7: Happy path first
# Check context order
# (requires parsing structure)

# ... etc for rules 1-9
```

**Rules 10-11: Syntax and Readability**

```ruby
# Rule 10: Use expect syntax (not should)
if spec_content =~ /\.should /
  violations << {
    rule: 10,
    severity: 'MUST',
    issue: 'Using deprecated should syntax'
  }
end

# Rule 11: Choose right matcher
# (heuristic checks for common bad matchers)
```

**Rules 12-16: Context and Data Preparation**

```ruby
# Rule 14: Use build_stubbed for unit tests
if metadata['test_level'] == 'unit' && spec_content =~ /create\(/
  violations << {
    rule: 14,
    severity: 'SHOULD',
    issue: 'Using create in unit test',
    location: find_line_number(spec_content, 'create(')
  }
end

# Rule 15: let vs let! vs before
# (check usage patterns)
```

**Rules 17-20: Language Rules**

```ruby
# Rule 17: describe/context/it form sentence
# Parse and validate sentence structure

# Rule 19: Grammar (Present Simple, no should/can/must)
if spec_content =~ /it ['"]should /
  violations << {
    rule: 19,
    severity: 'SHOULD',
    issue: 'Using "should" in it description'
  }
end

# Rule 20: Context language (when/with/and/but/without)
# Check context descriptions match pattern
```

**Rules 21-28: Tools and Support**

```ruby
# Rule 22: Never use any_instance_of
if spec_content =~ /any_instance_of/
  violations << {
    rule: 22,
    severity: 'MUST',
    issue: 'Using any_instance_of (forbidden)'
  }
end

# Rule 25: Time stability
# Check for Time.now without freezing time
if spec_content =~ /Time\.now/ && !(spec_content =~ /travel_to/)
  violations << {
    rule: 25,
    severity: 'SHOULD',
    issue: 'Using Time.now without travel_to'
  }
end
```

**Step 3: Check Time Handling Edge Cases**

Time handling issues are a common source of flaky tests. Check for these patterns:

**Check 1: Date.parse / Time.parse (ignores Time.zone)**
```ruby
# Pattern to detect
if spec_content =~ /Date\.parse|Time\.parse/
  warnings << {
    rule: 'time-handling',
    severity: 'SHOULD',
    issue: 'Date.parse/Time.parse ignore Time.zone',
    fix: 'Use Time.zone.parse, Time.zone.local, or in_time_zone instead'
  }
end
```

**Why:** `Date.parse` and `Time.parse` ignore `Time.zone`, while ActiveRecord saves timestamps in UTC. Tests with zone-dependent behavior need `Time.zone.parse` or `Time.zone.local`.

**Check 2: Date#wday vs PostgreSQL EXTRACT(DOW)**
```ruby
# Pattern to detect
if spec_content =~ /\.wday/ && (spec_content =~ /EXTRACT\(DOW/ || spec_content =~ /date_trunc/)
  warnings << {
    rule: 'time-handling',
    severity: 'SHOULD',
    issue: 'Date#wday (0=Sunday) ≠ PostgreSQL DOW (0=Sunday, 1=Monday)',
    fix: 'Explicitly verify expected weekday numbers when combining Ruby and SQL'
  }
end
```

**Why:** Ruby's `Date#wday` returns 0 for Sunday, while PostgreSQL `EXTRACT(DOW FROM ...)` returns 0 on Sunday and 1 on Monday. Don't compare numbers directly.

**Check 3: beginning_of_week configuration**
```ruby
# Pattern to detect
if spec_content =~ /beginning_of_week/ && spec_content =~ /date_trunc\('week'/
  warnings << {
    rule: 'time-handling',
    severity: 'SHOULD',
    issue: 'Rails beginning_of_week config vs PostgreSQL ISO week (always Monday)',
    fix: 'Test first day of week via public interface if calendar logic matters'
  }
end
```

**Why:** `Date.current.beginning_of_week` respects `Rails.application.config.beginning_of_week`, while `date_trunc('week', ...)` in PostgreSQL always starts from Monday (ISO standard).

**Check 4: DST transitions and midnight**
```ruby
# Pattern to detect
if spec_content =~ /travel_to.*0[0-3]:00/
  warnings << {
    rule: 'time-handling',
    severity: 'SHOULD',
    issue: 'Time near midnight or DST transition (00:00-03:00)',
    fix: 'Use midday time (12:00) to avoid DST issues, write separate tests for transitions if needed'
  }
end
```

**Why:** PostgreSQL calculates intervals with UTC, while Ruby's `travel_to` can hit non-existent hours during DST. Use middle of day (12:00) to avoid flaky tests.

**Check 5: Time precision (Ruby vs PostgreSQL)**
```ruby
# Pattern to detect
if spec_content =~ /Time\.now/ && spec_content =~ /expect.*eq.*Time/
  warnings << {
    rule: 'time-handling',
    severity: 'SHOULD',
    issue: 'Time.now has microsecond precision, PostgreSQL timestamp may truncate',
    fix: 'Use be_within(1.second) or freeze time with travel_to'
  }
end
```

**Why:** Ruby time has microsecond precision, PostgreSQL may truncate. Direct equality checks (`eq`) can fail.

**Step 4: Generate Report**

This step transforms collected violations/warnings into educational markdown report.

**Algorithm for report generation:**

**4.1: Calculate Summary Statistics**
```ruby
violations = issues.select { |i| i[:severity] == 'MUST' }
warnings = issues.select { |i| i[:severity] == 'SHOULD' }
suggestions = issues.select { |i| i[:severity] == 'MAY' }
time_issues = issues.select { |i| i[:rule] == 'time-handling' }

# Determine overall status
overall_status = if violations.any?
  "❌ NEEDS IMPROVEMENT"
elsif warnings.count > 5
  "⚠️ NEEDS ATTENTION"
elsif warnings.any?
  "✅ GOOD"
else
  "✅ EXCELLENT"
end
```

**4.2: For Each Issue, Extract Location**
```ruby
def extract_location(spec_content, pattern)
  lines = spec_content.split("\n")

  lines.each_with_index do |line, index|
    if line =~ pattern
      return {
        line_number: index + 1,
        code_snippet: extract_context(lines, index)
      }
    end
  end

  { line_number: nil, code_snippet: nil }
end

def extract_context(lines, index, context_lines: 2)
  start_line = [0, index - context_lines].max
  end_line = [lines.length - 1, index + context_lines].min

  lines[start_line..end_line]
    .map.with_index(start_line + 1) { |line, num| "#{num}: #{line}" }
    .join("\n")
end
```

**4.3: Generate "Why It Matters" Explanation**

Use rule descriptions from `rspec-testing/SKILL.md` as foundation:

```ruby
def why_it_matters(rule_number)
  # Map rule number to explanation from SKILL.md
  explanations = {
    1 => "Implementation testing creates tight coupling between tests and code structure. When you refactor (change HOW without changing WHAT), tests break even though behavior is unchanged. This makes refactoring expensive and dangerous.",
    3 => "Multiple behaviors in one test make failures ambiguous. Which behavior failed? Tests become harder to debug and maintain. Each test should verify ONE business rule.",
    22 => "any_instance_of violates Dependency Inversion Principle, makes tests brittle, and hides design problems. Proper dependency injection makes code testable and maintainable.",
    # ... etc for all rules
  }

  explanations[rule_number] || "See rspec-testing/SKILL.md for detailed explanation"
end
```

**4.4: Generate Fix Example**

Transform violation into recommended code:

```ruby
def generate_fix(violation)
  case violation[:rule]
  when 1  # Behavior vs implementation
    {
      current: violation[:code_snippet],
      recommended: transform_to_behavior_test(violation[:code_snippet]),
      explanation: "Test observable outcome instead of internal method call"
    }
  when 22  # any_instance_of
    {
      current: violation[:code_snippet],
      recommended: transform_to_dependency_injection(violation[:code_snippet]),
      explanation: "Use instance_double and inject dependency"
    }
  # ... etc
  end
end

# Example transformations:
def transform_to_behavior_test(code)
  # Pattern: expect(subject).to receive(:save)
  # → expect { subject.call }.to change(Model, :count).by(1)

  code.gsub(/expect\((\w+)\)\.to receive\(:(\w+)\)/) do
    subject_name = $1
    method_name = $2

    # Suggest outcome-based test
    "expect { #{subject_name}.#{method_name} }.to change(Model, :count).by(1)"
  end
end
```

**4.5: Build Report Sections**

```ruby
report = []

# Header
report << "# RSpec Test Review Report\n"
report << "**File:** #{spec_file}"
report << "**Reviewed:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
report << "**Status:** #{overall_status}\n"

# Summary
report << "## Summary"
report << "- ✅ Passed: #{28 - violations.count - warnings.count - suggestions.count} rules"
report << "- ⚠️ Warnings: #{warnings.count} rules"
report << "- ❌ Violations: #{violations.count} rules\n"

# Violations section (most important)
if violations.any?
  report << "## Violations (🔴 MUST fix)\n"

  violations.each do |v|
    report << "### Rule #{v[:rule]}: #{rule_name(v[:rule])}"
    report << "**Severity:** 🔴 MUST"
    report << "**Location:** Line #{v[:location][:line_number]}" if v[:location]
    report << "**Issue:** #{v[:issue]}"
    report << "**Why it matters:** #{why_it_matters(v[:rule])}"

    if v[:fix]
      report << "**Fix:**"
      report << "```ruby"
      report << "# Current (bad)"
      report << v[:code_snippet]
      report << ""
      report << "# Recommended (good)"
      report << v[:fix][:recommended]
      report << "```"
    end

    report << ""
  end
end

# Similar sections for warnings, suggestions, time issues...

# Recommendations (prioritized action plan)
report << "## Recommendations\n"
if violations.any?
  report << "**Priority 1 (Must Fix):**"
  violations.each_with_index do |v, i|
    report << "#{i + 1}. #{v[:issue]} (Rule #{v[:rule]})"
  end
end

report.join("\n")
```

**Report Template Output:**

```markdown
# RSpec Test Review Report

**File:** spec/services/payment_spec.rb
**Reviewed:** 2025-01-08 10:30:00
**Status:** ❌ NEEDS IMPROVEMENT

## Summary
- ✅ Passed: 24 rules
- ⚠️ Warnings: 3 rules
- ❌ Violations: 1 rule

## Violations (🔴 MUST fix)

### Rule 22: Never use any_instance_of
**Severity:** 🔴 MUST
**Location:** Line 45
**Issue:** Using any_instance_of(PaymentGateway)
**Why it matters:** Violates Dependency Inversion Principle, makes tests brittle, and hides design problems. Proper dependency injection makes code testable and maintainable.

**Fix:**
```ruby
# Current (bad)
allow_any_instance_of(PaymentGateway).to receive(:charge)

# Recommended (good)
let(:gateway) { instance_double(PaymentGateway) }
subject { described_class.new(gateway) }
allow(gateway).to receive(:charge)
```

## Recommendations

**Priority 1 (Must Fix):**
1. Remove any_instance_of usage (Rule 22)

**Priority 2 (Should Fix):**
2. Change create to build_stubbed in unit test (Rule 14)
3. Fix grammar in it description (Rule 19)

---
**Next steps:** Fix Priority 1 violations, then address warnings
```

**Step 5: Write Report**

```bash
report_file="tmp/rspec_claude_metadata/review_report_$(date +%Y%m%d_%H%M%S).md"
echo "$report_content" > "$report_file"

echo "✅ Review complete: $report_file"
echo ""
echo "Summary:"
echo "  ✅ Passed: $passed_count"
echo "  ⚠️ Warnings: $warning_count"
echo "  ❌ Violations: $violation_count"

exit 0
```

## Error Handling (Fail Fast)

### Not Really Errors (Warnings in Report)

Reviewer doesn't exit with errors. Always generates report.

**Unusual Situation: Can't Parse Spec**

```markdown
# Review Report

**Status:** ⚠️ INCOMPLETE

## Parse Error

Could not fully parse spec file.
Syntax error or unusual structure detected.

Please check:
- File has valid Ruby syntax: `ruby -c #{spec_file}`
- File follows RSpec structure

Partial review below based on text analysis...
```

## Dependencies

**Must run after:**
- rspec-polisher (reviews polished test)

**Must run before:**
- (nothing - end of pipeline)

**Reads:**
- spec file
- metadata.yml (optional, for context)

**Writes:**
- review report (new file)

## Examples

### Example 1: Good Test (Mostly Passes)

**Input spec:** (well-written test following guide)

**Report:**
```markdown
# RSpec Test Review Report

**File:** spec/services/payment_service_spec.rb
**Reviewed:** 2025-11-07 16:30:00
**Status:** ✅ GOOD

## Summary
- ✅ Passed: 26 rules
- ⚠️ Warnings: 2 rules
- ❌ Violations: 0 rules

## Warnings (🟡 SHOULD fix)

### Rule 14: FactoryBot usage
**Severity:** 🟡 SHOULD
**Location:** Line 15
**Issue:** Using `create(:user)` in unit test
**Fix:** Change to `build_stubbed(:user)` for better performance

### Rule 19: Grammar in descriptions
**Severity:** 🟡 SHOULD
**Location:** Line 25
**Issue:** `it 'should process payment'` uses modal verb
**Fix:** Change to `it 'processes payment'` (Present Simple)

## Passed Rules ✅

Rules 1-13, 15-18, 20-28 — excellent work!

---
**Next steps:** Consider addressing warnings for best practices.
```

---

### Example 2: Serious Issues Found

**Input spec:** (violates several MUST rules)

**Report:**
```markdown
# RSpec Test Review Report

**File:** spec/services/legacy_service_spec.rb
**Reviewed:** 2025-11-07 16:35:00
**Status:** ❌ NEEDS IMPROVEMENT

## Summary
- ✅ Passed: 20 rules
- ⚠️ Warnings: 5 rules
- ❌ Violations: 3 rules

## Violations (🔴 MUST fix)

### Rule 22: any_instance_of usage
**Severity:** 🔴 MUST
**Location:** Line 45
**Issue:** Uses `allow_any_instance_of(PaymentGateway)`
**Why it matters:** Violates Dependency Inversion Principle, makes tests brittle
**Fix:**
```ruby
# Current (bad)
allow_any_instance_of(PaymentGateway).to receive(:charge)

# Recommended (good)
let(:gateway) { instance_double(PaymentGateway) }
subject { described_class.new(gateway) }
allow(gateway).to receive(:charge)
```

### Rule 10: Deprecated syntax
**Severity:** 🔴 MUST
**Location:** Lines 30, 35, 40
**Issue:** Using `should` syntax (deprecated)
**Fix:** Convert to `expect` syntax:
```ruby
# Old: user.should be_valid
# New: expect(user).to be_valid
```

### Rule 1: Testing implementation
**Severity:** 🔴 MUST
**Location:** Line 50
**Issue:** `expect(service).to receive(:create_payment)`
**Why it matters:** Tests internal implementation, not behavior
**Fix:** Test observable outcome instead:
```ruby
# Instead of checking .create_payment called:
expect { result }.to change(Payment, :count).by(1)
```

## Warnings (🟡 SHOULD fix)

[... 5 warnings listed ...]

## Time Handling Issues

### Issue 1: Time.parse without zone
**Location:** Line 67
**Issue:** `Time.parse('2024-01-01')` ignores `Time.zone`
**Fix:** Use `Time.zone.parse('2024-01-01')`

## Recommendations

**Priority 1 (Must Fix):**
1. Remove any_instance_of usage (Rule 22)
2. Convert to expect syntax (Rule 10)
3. Test behavior, not implementation (Rule 1)

**Priority 2 (Should Fix):**
4. Address 5 warnings for better maintainability
5. Fix time handling issues

**Priority 3 (Optional):**
6. Consider refactoring for clarity

---
**Next steps:** Fix Priority 1 violations, then re-run tests and review.
```

---

### Example 3: Standalone Review (No Metadata)

**User request:**
```
User: "Review the test in spec/models/user_spec.rb"
```

**Agent invocation:**
- Claude launches rspec-reviewer subagent
- No metadata file found (standalone mode)
- Agent reviews spec file only (reduced capability)

**Report:**
```markdown
# RSpec Test Review Report

**File:** spec/models/user_spec.rb
**Reviewed:** 2025-11-07 16:40:00
**Status:** ✅ GOOD
**Note:** Reviewed without metadata context

## Summary
- ✅ Passed: 22 rules (8 not checkable without metadata)
- ⚠️ Warnings: 1 rule
- ❌ Violations: 0 rules

## Warnings

### Rule 7: Happy path ordering (partial check)
**Severity:** 🟡 SHOULD
**Issue:** Cannot verify without metadata, but context order looks unusual
**Suggestion:** Ensure positive cases come before negative cases

## Notes

Some rules require metadata for full checking:

**Rules requiring metadata.characteristics[] structure:**
- **Rule 4: Identify characteristics** (need `metadata.characteristics[].name` and `.type`)
  - Why: Can't verify if context hierarchy matches identified characteristics without metadata
  - Partial check: Look for nested contexts, but can't verify correctness

- **Rule 5: Hierarchy by dependencies** (need `metadata.characteristics[].depends_on`)
  - Why: Can't verify context order matches dependency chain without metadata
  - Partial check: Can warn about deeply nested contexts, but can't verify correctness

- **Rule 6: Final context audit** (need `metadata.characteristics[].default`)
  - Why: Can't verify if default values are properly extracted without metadata
  - Partial check: Look for duplicate let definitions, but can't verify if extraction was done

- **Rule 7: Happy path first** (need `metadata.characteristics[].default` and `.type`)
  - Why: Can't identify "happy path" without knowing default characteristic values
  - Partial check: Can warn if first context looks negative, but can't verify

**Rules requiring metadata.test_context:**
- **Rule 14: build_stubbed in units** (need `metadata.test_context.test_level`)
  - Why: Can't distinguish unit tests from integration tests without metadata
  - Partial check: Guess from file path (spec/models → unit, spec/requests → integration)

**Rules requiring metadata.source_info:**
- **Rule 2: Verify what test tests** (need `metadata.source_info` for method signatures)
  - Why: Can't verify if test actually covers method behavior without source info
  - Workaround: Read source file directly if available

**Total impact:**
- **With metadata:** Can check all 28 rules (some fully, some heuristically)
- **Without metadata:** Can check ~20 rules fully (syntax, patterns, language)
- **Partial checking:** 8 rules have reduced accuracy without metadata

**Recommendation:** For complete review, run with metadata context. Standalone review still provides value for syntax, patterns, and language rules.

---
**Status:** Test looks good based on available information.
```

## Integration with Skills

### Automatic Invocation

```markdown
Every skill automatically invokes reviewer at end:

rspec-write-new:
  steps:
    1-5. [all other agents]
    6. rspec-reviewer  # Automatic

User sees review report with results
```

### Standalone Usage

**How user invokes this agent:**

rspec-reviewer is a **Claude AI subagent**, not a bash script. There are 3 ways to invoke it:

**Method 1: Via natural language request**
```
User: "Review tests in spec/services/payment_service_spec.rb"

→ Claude recognizes review intent
→ Launches rspec-reviewer subagent via Task tool
→ Subagent generates report
→ Claude shows report summary to user
```

**Method 2: Via skill**
```
User activates rspec-testing skill, then:
  "Review my existing tests"

→ Skill invokes rspec-reviewer on all spec files
→ Generates reports
→ Shows summary
```

**Method 3: Automatic (as part of pipeline)**
```
User: "Write tests for PaymentService"

→ rspec-write-new skill runs full pipeline:
   1-6. [other agents write test]
   7. rspec-reviewer (automatic)

→ User gets test + review report
```

**Important notes:**
- The "bash command" example in Example 3 (`rspec-reviewer spec/...`) is **illustrative only**
- This is NOT a CLI tool - it's a Claude subagent specification
- Real invocation is via Claude (Task tool, natural language, or skill)
- When implemented, could be wrapped in CLI tool, but that's not required

## Testing Criteria

**Agent is correct if:**
- ✅ Generates report (never fails with exit 1)
- ✅ Detects obvious violations (any_instance_of, should syntax)
- ✅ Provides actionable fix suggestions
- ✅ Never modifies files (READ-ONLY)
- ✅ Report is readable and helpful

**Limitations (expected):**
- Cannot catch all Rule 1 violations (behavior vs implementation is subtle)
- Cannot fully validate complex rules without deep code analysis
- Heuristic checks may have false positives/negatives

## Related Specifications

- **guide.en.md** - All 28 rules being checked
- **agents/rspec-polisher.spec.md** - Previous agent
- **skills/*.spec.md** - All skills invoke reviewer

---

**Key Takeaway:** Educational reviewer. READ-ONLY. Provides feedback, never modifies. Helps improve test quality.
