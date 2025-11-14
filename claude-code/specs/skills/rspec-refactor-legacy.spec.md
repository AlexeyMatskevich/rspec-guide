# rspec-refactor-legacy Skill Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Orchestration Skill
**Location:** `.claude/skills/rspec-refactor-legacy/SKILL.md`

## Philosophy / Why This Skill Exists

**Problem:** Existing tests work but don't follow guide.en.md (wrong structure, poor language, testing implementation, etc.)

**Solution:** rspec-refactor-legacy:
1. Audits existing test structure
2. Compares with ideal structure (from code analysis)
3. Identifies gaps and issues
4. Refactors while preserving behavior
5. Ensures tests still pass

**Key Principle:** Don't break working tests. Refactor iteratively. Verify tests pass after each change.

**Value:**
- Improves test quality without rewriting from scratch
- Preserves domain knowledge embedded in tests
- Applies guide.en.md rules to legacy code
- Safe refactoring (tests pass before and after)

## Prerequisites Check

### Before Skill Starts

```bash
# 1. Test file must exist
if [ ! -f "$spec_file" ]; then
  echo "Error: Test file not found: $spec_file" >&2
  echo "Use rspec-write-new to create new tests" >&2
  exit 1
fi

# 2. Tests must pass (baseline)
echo "Verifying tests pass..."
if ! bundle exec rspec "$spec_file" > /dev/null 2>&1; then
  echo "Error: Tests currently failing" >&2
  echo "Fix failing tests before refactoring" >&2
  exit 1
fi

echo "✅ Tests pass (baseline established)"
```

## Input Contract

**From user:**
```
Natural language request:
  "Refactor spec/models/user_spec.rb"
  "Improve tests for PaymentService"
  "Apply guide rules to legacy tests"
```

**Parsed to:**
```
spec_file: spec/models/user_spec.rb
refactor_mode: full (restructure) | conservative (improve only)
```

## Output Contract

**Updates:**
- Existing test file (refactored)
- Creates backup (.backup file)
- Metadata (from fresh analysis)
- Review report (before and after)

**Shows user:**
- Before/after comparison
- What changed and why
- Verification that tests still pass
- Review improvements

## Agent Orchestration Sequence

```
1. Baseline check (tests pass?)
   ↓
2. spec_structure_extractor (audit existing)
   ↓
3. rspec-analyzer (analyze source, in audit mode)
   ↓
4. Compare: existing vs ideal structure
   ↓
5. Generate refactoring plan
   ↓
6. Ask user approval
   ↓
7. Create backup
   ↓
8. IF full mode:
     Regenerate with full pipeline
   ELSE conservative mode:
     Apply targeted improvements only
   ↓
9. Run tests (verify still pass)
   ↓
10. rspec-reviewer (show improvements)
```

## Decision Trees

### Decision Tree 1: Refactor Mode

```
How much refactoring needed?

Review violations:
  High severity issues (MUST rules)?
    YES → Recommend full refactor
    NO → Conservative improvements OK

Structural issues (wrong hierarchy)?
  YES → Full refactor needed
  NO → Conservative improvements OK

Ask user:
  "Refactor mode:"
  [1] Full (regenerate structure)
  [2] Conservative (improve language, fix violations)
  [3] Review only (no changes)
```

### Decision Tree 2: Preserve What?

```
Analyzing existing test:

Has custom helper methods?
  YES → Preserve, add to refactored test
  NO → OK to replace

Has shared examples?
  YES → Preserve
  NO → OK

Has manual before/after hooks doing complex setup?
  YES → Preserve, may need manual merge
  NO → Replace with let blocks

Has comments explaining business logic?
  YES → Preserve comments
  NO → OK
```

### Decision Tree 3: Safe to Apply Change?

```
For each proposed change:

Run tests with change:
  Pass? → Keep change
  Fail? → Revert, mark as manual task
```

## Algorithm

### Step-by-Step Workflow

**Step 1: Baseline Check**

```bash
echo "Establishing baseline..."

# Run existing tests
test_output=$(bundle exec rspec "$spec_file" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ Tests currently failing" >&2
  echo "$test_output" >&2
  echo "" >&2
  echo "Fix failures before refactoring" >&2
  exit 1
fi

example_count=$(echo "$test_output" | grep -o "[0-9]* example" | awk '{print $1}')
echo "✅ Baseline: $example_count examples passing"
```

**Step 2: Extract Existing Structure**

```bash
echo "⚙️ Extracting existing test structure..."

existing_structure=$(ruby lib/rspec_automation/extractors/spec_structure_extractor.rb "$spec_file")

# Save for comparison
echo "$existing_structure" > /tmp/existing_structure.json
```

**Step 3: Analyze Source Code**

```bash
echo "⚙️ Analyzing source code (audit mode)..."

# Extract source file from test
source_file=$(grep -m 1 "describe\|context" "$spec_file" | \
              sed 's/.*describe\s\+\([A-Z][A-Za-z:]*\).*/\1/' | \
              # Convert class name to file path
              sed 's/::/\//g; s/\(.*\)/\L\1/')

source_file="app/models/${source_file}.rb"  # Adjust path logic

invoke_agent "rspec-analyzer" \
  --source-file "$source_file" \
  --mode "audit"
```

**Step 4: Compare Structures**

```bash
echo "⚙️ Comparing existing vs ideal structure..."

# Compare characteristics
existing_contexts=$(jq '.describe_blocks[].children[].description' /tmp/existing_structure.json)
ideal_characteristics=$(yq '.characteristics[].name' "$metadata_path")

gaps=()
issues=()

# Identify gaps (characteristics in code but not in tests)
# Identify issues (wrong structure, wrong language)

echo ""
echo "Analysis Results:"
echo "  Gaps found: ${#gaps[@]}"
echo "  Issues found: ${#issues[@]}"
```

**Step 5: Generate Refactoring Plan**

```bash
echo ""
echo "========================================="
echo "Refactoring Plan"
echo "========================================="

echo ""
echo "Structural Issues:"
for issue in "${structural_issues[@]}"; do
  echo "  - $issue"
done

echo ""
echo "Language Issues:"
for issue in "${language_issues[@]}"; do
  echo "  - $issue"
done

echo ""
echo "Missing Coverage:"
for gap in "${gaps[@]}"; do
  echo "  - $gap"
done

echo ""
echo "Recommended Mode:"
if [ ${#structural_issues[@]} -gt 3 ]; then
  echo "  🔴 FULL REFACTOR (major structural problems)"
else
  echo "  🟡 CONSERVATIVE (targeted improvements)"
fi
```

**Step 6: Ask User Approval**

```bash
refactor_mode=$(ask_user "Choose refactor mode:" \
  ["Full refactor", "Conservative improvements", "Review only"])

case $refactor_mode in
  "Review only")
    echo "Generating review report only..."
    invoke_agent "rspec-reviewer" --spec-file "$spec_file"
    exit 0
    ;;
  "Conservative improvements")
    conservative_refactor "$spec_file"
    ;;
  "Full refactor")
    full_refactor "$spec_file"
    ;;
esac
```

**Step 7: Conservative Refactor**

```bash
function conservative_refactor() {
  spec_file="$1"

  echo "⚙️ Applying conservative improvements..."

  # Backup
  cp "$spec_file" "${spec_file}.backup"
  echo "Backed up to ${spec_file}.backup"

  # Apply targeted fixes
  fixes_applied=0

  # Fix 1: Replace 'should' with 'expect'
  if grep -q "\.should " "$spec_file"; then
    echo "  Fixing: should → expect syntax"
    # (complex sed/ruby transformation)
    fixes_applied=$((fixes_applied + 1))
  fi

  # Fix 2: Remove 'should' from it descriptions
  if grep -q "it ['\"]\s*should " "$spec_file"; then
    echo "  Fixing: it descriptions (remove 'should')"
    sed -i "s/it ['\"]should \(.*\)['\"]/it '\1'/" "$spec_file"
    fixes_applied=$((fixes_applied + 1))
  fi

  # Fix 3: Add frozen_string_literal
  if ! grep -q "frozen_string_literal" "$spec_file"; then
    echo "  Adding: frozen_string_literal comment"
    sed -i "1i# frozen_string_literal: true\n" "$spec_file"
    fixes_applied=$((fixes_applied + 1))
  fi

  # Fix 4: Apply RuboCop auto-correct
  echo "  Running: RuboCop auto-correct"
  bundle exec rubocop --autocorrect "$spec_file" > /dev/null 2>&1

  echo ""
  echo "✅ Applied $fixes_applied improvements"

  # Verify tests still pass
  verify_tests_pass "$spec_file"
}
```

**Step 8: Full Refactor**

```bash
function full_refactor() {
  spec_file="$1"

  echo "⚠️ Full refactor will regenerate test structure"
  echo ""

  # Check for custom code
  custom_code=$(grep -n "CUSTOM\|def .*helper\|shared_examples" "$spec_file" || true)

  if [ -n "$custom_code" ]; then
    echo "⚠️ Custom code detected:"
    echo "$custom_code"
    echo ""

    response=$(ask_user "Custom code will be lost. Continue?" ["Yes", "No"])
    if [ "$response" = "No" ]; then
      echo "Cancelled"
      return
    fi
  fi

  # Backup
  cp "$spec_file" "${spec_file}.backup"
  echo "Backed up to ${spec_file}.backup"

  # Run full pipeline (like write-new, but overwriting)
  echo "⚙️ Regenerating test structure..."

  ruby lib/rspec_automation/generators/spec_skeleton_generator.rb "$metadata_path" "$spec_file"
  invoke_agent "rspec-architect" --spec-file "$spec_file" --metadata "$metadata_path"
  invoke_agent "rspec-factory" --spec-file "$spec_file" --metadata "$metadata_path" || true
  invoke_agent "rspec-implementer" --spec-file "$spec_file" --metadata "$metadata_path"
  invoke_agent "rspec-polisher" --spec-file "$spec_file" || true

  echo "✅ Refactoring complete"

  # Verify tests still pass
  verify_tests_pass "$spec_file"
}
```

**Step 9: Verify Tests Pass**

```bash
function verify_tests_pass() {
  spec_file="$1"

  echo ""
  echo "⚙️ Verifying tests still pass..."

  test_output=$(bundle exec rspec "$spec_file" 2>&1)
  exit_code=$?

  if [ $exit_code -eq 0 ]; then
    new_count=$(echo "$test_output" | grep -o "[0-9]* example" | awk '{print $1}')
    echo "✅ Tests pass ($new_count examples)"

    if [ "$new_count" -ne "$example_count" ]; then
      echo ""
      echo "⚠️ Example count changed:"
      echo "  Before: $example_count examples"
      echo "  After: $new_count examples"
      echo ""
      echo "Review changes carefully"
    fi
  else
    echo "❌ Tests now failing!" >&2
    echo "" >&2
    echo "$test_output" >&2
    echo "" >&2
    echo "Restoring backup..." >&2
    cp "${spec_file}.backup" "$spec_file"
    echo "Restored from backup" >&2
    exit 1
  fi
}
```

**Step 10: Show Before/After Review**

```bash
echo ""
echo "========================================="
echo "Refactoring Summary"
echo "========================================="

# Generate before review (from backup)
echo "Generating before review..."
invoke_agent "rspec-reviewer" \
  --spec-file "${spec_file}.backup" \
  > /tmp/review_before.md

# Generate after review
echo "Generating after review..."
invoke_agent "rspec-reviewer" \
  --spec-file "$spec_file" \
  > /tmp/review_after.md

# Compare
before_violations=$(grep "❌ Violations:" /tmp/review_before.md | awk '{print $3}')
after_violations=$(grep "❌ Violations:" /tmp/review_after.md | awk '{print $3}')

before_warnings=$(grep "⚠️ Warnings:" /tmp/review_before.md | awk '{print $3}')
after_warnings=$(grep "⚠️ Warnings:" /tmp/review_after.md | awk '{print $3}')

echo ""
echo "Improvements:"
echo "  Violations: $before_violations → $after_violations ($(($before_violations - $after_violations)) fixed)"
echo "  Warnings: $before_warnings → $after_warnings ($(($before_warnings - $after_warnings)) fixed)"
echo ""

if [ $after_violations -eq 0 ] && [ $after_warnings -eq 0 ]; then
  echo "🎉 Test now fully compliant with guide!"
else
  echo "Review report: cat /tmp/review_after.md"
fi

echo ""
echo "Next steps:"
echo "  1. Review changes: git diff $spec_file"
echo "  2. Compare reviews: diff /tmp/review_before.md /tmp/review_after.md"
echo "  3. Commit if satisfied: git add $spec_file && git commit"
```

## Error Handling

### Error 1: Tests Failing at Start

```
❌ Tests currently failing

Cannot refactor failing tests (unknown baseline).

Fix failures first:
  bundle exec rspec spec/models/user_spec.rb

Then re-run refactor skill.
```

### Error 2: Refactored Tests Fail

```
❌ Tests now failing after refactoring!

Failures:
  [test output]

Restoring backup...
✅ Restored from spec/models/user_spec.rb.backup

Refactoring failed. This indicates:
  1. Behavior changed unintentionally (bug in agents)
  2. Tests were flaky (pass/fail randomly)
  3. Tests depended on specific order

Manual review needed.
```

### Error 3: Cannot Find Source File

```
⚠️ Cannot determine source file from test

Test: spec/models/user_spec.rb
Expected source: app/models/user.rb
Status: Not found

Cannot perform structural analysis without source file.

Options:
  [1] Specify source file manually
  [2] Conservative refactor only (language improvements)
  [3] Review only (no changes)

Your choice:
```

## Examples

### Example 1: Conservative Refactor

**Input test:** (old style, but working)
```ruby
describe User do
  it 'should return full name' do
    user.name.should == 'John Doe'
  end
end
```

**Execution:**
```
✅ Baseline: 1 example passing

⚙️ Analyzing...

Issues found:
  - Using deprecated 'should' syntax (Rule 10)
  - Using 'should' in description (Rule 19)

Recommended: CONSERVATIVE improvements

Choose refactor mode: Conservative improvements

⚙️ Applying improvements...
  Fixing: should → expect syntax
  Fixing: it descriptions
  Adding: frozen_string_literal comment
  Running: RuboCop auto-correct

✅ Applied 4 improvements

⚙️ Verifying tests...
✅ Tests pass (1 example)

Improvements:
  Violations: 2 → 0 (2 fixed)
  Warnings: 1 → 0 (1 fixed)

🎉 Test now fully compliant!
```

**Output test:**
```ruby
# frozen_string_literal: true

RSpec.describe User do
  it 'returns full name' do
    expect(user.name).to eq('John Doe')
  end
end
```

---

### Example 2: Full Refactor

**Input test:** (poor structure)
```ruby
describe PaymentService do
  it 'processes payments' do
    # All logic in one test
    user = User.new(authenticated: true, payment_method: :card, balance: 100)
    expect(service.process(user, 50)).to be_a(Payment)

    user.balance = 0
    expect { service.process(user, 50) }.to raise_error(InsufficientFundsError)
  end
end
```

**Execution:**
```
✅ Baseline: 1 example passing

⚙️ Analyzing...

Structural issues:
  - Multiple behaviors in one it block (Rule 3)
  - No characteristic-based contexts (Rule 4)
  - Missing test cases (only 2 scenarios, code has 6)

Recommended: FULL REFACTOR

Choose mode: Full refactor

⚠️ Full refactor will regenerate structure

Backed up to spec/services/payment_service_spec.rb.backup

⚙️ Regenerating...
[full pipeline runs]

✅ Refactoring complete

⚙️ Verifying...
✅ Tests pass (6 examples)

⚠️ Example count changed:
  Before: 1 example
  After: 6 examples

Improvements:
  Violations: 3 → 0
  Warnings: 5 → 1
  Coverage: 2 scenarios → 6 scenarios
```

## Integration Points

### Called by User

```
"Refactor spec/models/user_spec.rb"
"Improve tests for PaymentService"
"Apply guide rules to legacy tests"
```

### Calls Agents

- spec_structure_extractor (audit existing)
- rspec-analyzer (compare with ideal)
- Full pipeline if full refactor mode
- rspec-reviewer (before and after)

## Testing Criteria

**Skill is correct if:**
- ✅ Tests pass before and after refactoring
- ✅ Improvements measurable (violations reduced)
- ✅ Preserves custom code when possible
- ✅ Backs up before changes
- ✅ Reverts if tests fail

## Related Specifications

- **skills/rspec-write-new.spec.md** - Full pipeline
- **skills/rspec-update-diff.spec.md** - Surgical updates
- **ruby-scripts/spec-structure-extractor.spec.md** - Audit tool

---

**Key Takeaway:** Safe refactoring. Baseline → Changes → Verify. Preserve what works, improve what doesn't. Always backup.
