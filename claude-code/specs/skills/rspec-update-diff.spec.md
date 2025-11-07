# rspec-update-diff Skill Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Orchestration Skill
**Location:** `.claude/skills/rspec-update-diff/SKILL.md`

## Philosophy / Why This Skill Exists

**Problem:** Code changed (git diff), tests need updating. Manually updating tests is tedious and error-prone.

**Solution:** rspec-update-diff automatically:
1. Detects changed files (git diff)
2. Finds corresponding tests
3. Re-analyzes changed methods
4. Updates test structure if needed
5. Updates expectations if behavior changed

**Key Principle:** Preserve what works. Only update what changed. Don't regenerate entire test.

**Value:**
- Faster than manual updates
- Catches new characteristics (new if/case branches)
- Updates expectations to match new behavior
- Preserves custom test code

## Prerequisites Check

### Before Skill Starts

```bash
# 1. Must be in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a git repository" >&2
  echo "rspec-update-diff requires git to detect changes" >&2
  exit 1
fi

# 2. Must have uncommitted changes or specify commit range
if git diff --quiet && [ -z "$commit_range" ]; then
  echo "No changes detected" >&2
  echo "Working directory is clean" >&2
  exit 0
fi
```

## Input Contract

**From user:**
```
Natural language request:
  "Update tests for my changes"
  "Update tests for changed files"
  "Update tests based on git diff"
  "Update tests for app/services/payment_service.rb"
```

**Parsed to:**
```
mode: auto (detect from git diff) | manual (specific file)
target_file: null (auto) | "app/services/payment_service.rb" (manual)
commit_range: null (working directory) | "HEAD~5..HEAD" (specific commits)
```

## Output Contract

**Updates:**
- Existing test files (preserves structure where possible)
- Metadata files (re-analyzes changed methods)
- Review reports (new reviews for updated tests)

**Shows user:**
- List of files analyzed
- List of tests updated
- Summary of changes made
- Review results

## Agent Orchestration Sequence

**For each changed file:**

```
1. rspec-analyzer (re-analyze, check cache)
   ↓
2. Compare old metadata vs new metadata
   ↓
3. IF structure changed:
     a. spec_skeleton_generator (regenerate structure)
     b. rspec-architect (update descriptions)
   ELSE:
     Skip structure update
   ↓
4. rspec-implementer (update expectations if needed)
   ↓
5. rspec-factory-optimizer (optional)
   ↓
6. rspec-polisher (optional)
   ↓
7. rspec-reviewer (automatic)
```

**🔴 MUST:** Process files sequentially, not in parallel

## Decision Trees

### Decision Tree 1: What Files Changed?

```
User specified file?
  YES → Use that file only
  NO → Detect from git:
    git diff --name-only
    Filter: only app/**/*.rb files
    Exclude: spec/, test/, config/

Example:
  git diff --name-only
  → app/services/payment_service.rb
  → app/models/user.rb
  → config/routes.rb (skip, not source code)
```

### Decision Tree 2: Does Test Exist?

```
For source file: app/services/payment_service.rb

Test file: spec/services/payment_service_spec.rb

Test exists?
  YES → Update existing test
  NO → Ask user:
    "No test exists. Create new test?"
    Yes → Use rspec-write-new instead
    No → Skip this file
```

### Decision Tree 3: Did Characteristics Change?

```
Re-run rspec-analyzer:
  → New metadata generated

Compare with old metadata:
  characteristics changed?
    (different states, new characteristics, etc.)
    YES → Regenerate test structure
    NO → Keep existing structure, update expectations only

Example:
  Old: characteristics: [user_authenticated]
  New: characteristics: [user_authenticated, payment_method]
  → Structure changed, regenerate
```

### Decision Tree 4: Preserve Custom Code?

```
Scan existing test for custom code:
  - Custom helper methods
  - Shared examples
  - Manual before/after hooks
  - Comments with "CUSTOM" or "MANUAL"

Custom code found?
  YES → Warn user:
    "Test has custom code. Regeneration may lose changes."
    Options:
      [1] Backup and regenerate
      [2] Skip this test (keep as-is)
      [3] Manual merge (show diff)
  NO → Safe to regenerate
```

## Algorithm

### Step-by-Step Workflow

**Step 1: Detect Changed Files**

```bash
# Get changed files from git
if [ -n "$target_file" ]; then
  # User specified file
  changed_files=("$target_file")
else
  # Auto-detect from git
  if [ -n "$commit_range" ]; then
    changed_files=($(git diff --name-only "$commit_range" | grep '^app/.*\.rb$'))
  else
    changed_files=($(git diff --name-only | grep '^app/.*\.rb$'))
  fi
fi

echo "Found ${#changed_files[@]} changed files"
```

**Step 2: For Each Changed File**

```bash
for source_file in "${changed_files[@]}"; do
  echo ""
  echo "========================================="
  echo "Processing: $source_file"
  echo "========================================="

  # Determine spec file
  spec_file=$(echo "$source_file" | sed 's|^app/|spec/|; s|\.rb$|_spec.rb|')

  # Check if test exists
  if [ ! -f "$spec_file" ]; then
    echo "⚠️ No test exists for $source_file"
    ask_create_new "$source_file" "$spec_file"
    continue
  fi

  # Get metadata path
  metadata_path=$(ruby -r lib/rspec_automation/metadata_helper -e "
    puts RSpecAutomation::MetadataHelper.metadata_path_for('$source_file')
  ")

  # Backup old metadata
  if [ -f "$metadata_path" ]; then
    cp "$metadata_path" "${metadata_path}.old"
  fi

  # Re-analyze (cache will be invalid due to file change)
  echo "⚙️ Re-analyzing $source_file..."
  invoke_agent "rspec-analyzer" \
    --source-file "$source_file" \
    --method "auto"

  # Compare metadata
  if [ -f "${metadata_path}.old" ]; then
    if diff -q "$metadata_path" "${metadata_path}.old" > /dev/null; then
      echo "✅ No structural changes, updating expectations only"
      update_mode="expectations_only"
    else
      echo "⚠️ Characteristics changed, regenerating structure"
      update_mode="full_regeneration"
    fi
  else
    update_mode="full_regeneration"
  fi

  # Process based on mode
  case $update_mode in
    expectations_only)
      update_expectations_only "$spec_file" "$metadata_path"
      ;;
    full_regeneration)
      check_custom_code_and_regenerate "$spec_file" "$metadata_path"
      ;;
  esac

  # Always run optimizer, polisher, reviewer
  run_finishing_agents "$spec_file" "$metadata_path"

  echo "✅ Updated: $spec_file"
done
```

**Step 3: Update Expectations Only**

```bash
function update_expectations_only() {
  spec_file="$1"
  metadata_path="$2"

  echo "⚙️ Updating expectations (preserving structure)..."

  # Only run implementer (updates expectations)
  invoke_agent "rspec-implementer" \
    --spec-file "$spec_file" \
    --metadata "$metadata_path" \
    --mode "update"

  # Implementer in update mode:
  # - Keeps existing structure
  # - Re-analyzes source code
  # - Updates expect statements to match current behavior
  # - Preserves custom code
}
```

**Step 4: Full Regeneration (with Custom Code Check)**

```bash
function check_custom_code_and_regenerate() {
  spec_file="$1"
  metadata_path="$2"

  # Check for custom code
  if grep -q "CUSTOM\|MANUAL\|def.*helper\|shared_examples" "$spec_file"; then
    echo "⚠️ Test contains custom code"
    echo ""
    response=$(ask_user "Regenerate test? (custom code may be lost)" \
      ["Backup and regenerate", "Skip this file", "Show diff"])

    case $response in
      "Skip this file")
        echo "Skipping $spec_file"
        return
        ;;
      "Show diff")
        # Generate new version in temp file
        generate_new_test_to_temp "$metadata_path"
        show_diff "$spec_file" "$temp_file"
        # Ask again...
        ;;
      "Backup and regenerate")
        cp "$spec_file" "${spec_file}.backup"
        echo "Backed up to ${spec_file}.backup"
        # Fall through to regeneration
        ;;
    esac
  fi

  # Regenerate
  echo "⚙️ Regenerating test structure..."

  # Run full pipeline (skip analyzer, already done)
  ruby lib/rspec_automation/generators/spec_skeleton_generator.rb "$metadata_path" "$spec_file"
  invoke_agent "rspec-architect" --spec-file "$spec_file" --metadata "$metadata_path"
  invoke_agent "rspec-implementer" --spec-file "$spec_file" --metadata "$metadata_path"
}
```

**Step 5: Run Finishing Agents**

```bash
function run_finishing_agents() {
  spec_file="$1"
  metadata_path="$2"

  invoke_agent "rspec-factory-optimizer" --spec-file "$spec_file" --metadata "$metadata_path" || true
  invoke_agent "rspec-polisher" --spec-file "$spec_file" || true
  invoke_agent "rspec-reviewer" --spec-file "$spec_file" --metadata "$metadata_path"
}
```

**Step 6: Show Summary**

```bash
echo ""
echo "========================================="
echo "Update Summary"
echo "========================================="
echo "Files processed: ${#changed_files[@]}"
echo "Tests updated: ${updated_count}"
echo "Tests skipped: ${skipped_count}"
echo ""
echo "Updated tests:"
for file in "${updated_files[@]}"; do
  echo "  ✅ $file"
done

if [ ${#skipped_files[@]} -gt 0 ]; then
  echo ""
  echo "Skipped tests:"
  for file in "${skipped_files[@]}"; do
    echo "  ⏭️ $file"
  done
fi

echo ""
echo "Next steps:"
echo "  1. Review changes: git diff spec/"
echo "  2. Run updated tests: bundle exec rspec ${updated_files[*]}"
echo "  3. Commit if satisfied: git add spec/ && git commit"
```

## Error Handling

### Error 1: No Changes Detected

```
ℹ️ No changes detected

Working directory is clean. Use one of:
  1. Make changes to source files first
  2. Specify commit range: "update tests for HEAD~5..HEAD"
  3. Specify file manually: "update tests for app/services/payment.rb"
```

### Error 2: Test Has Failing Specs

```
⚠️ Existing test has failing examples

Before updating, existing test fails:
  3 examples, 1 failure

Options:
  [1] Update anyway (may introduce more failures)
  [2] Fix existing failures first
  [3] Skip this file

Your choice:
```

### Error 3: Git Repository Not Found

```
❌ Not a git repository

rspec-update-diff requires git to detect changes.

Initialize git:
  git init
  git add .
  git commit -m "Initial commit"

Or use rspec-write-new for creating tests without git.
```

## Examples

### Example 1: Simple Update (Expectations Only)

**User request:**
```
"Update tests for my changes"
```

**Git changes:**
```bash
$ git diff app/services/discount_calculator.rb
-    when :regular then 0.0
+    when :regular then 0.05  # Changed discount
```

**Execution:**
```
Found 1 changed file
=========================================
Processing: app/services/discount_calculator.rb
=========================================

⚙️ Re-analyzing...
✅ Analysis complete

✅ No structural changes, updating expectations only

⚙️ Updating expectations...
   Found changed return value: 0.0 → 0.05
   Updating expectation in spec

✅ Updated: spec/services/discount_calculator_spec.rb

📋 Review: All checks pass

Update Summary:
  Files processed: 1
  Tests updated: 1

Next steps:
  1. Review: git diff spec/
  2. Run: bundle exec rspec spec/services/discount_calculator_spec.rb
```

**Time:** ~15 seconds

---

### Example 2: Structural Change (New Characteristic)

**Git changes:**
```ruby
# Added new condition
def process_payment(user, amount, currency)  # New parameter
  unless user.authenticated?
    raise AuthenticationError
  end

  # NEW: Currency handling
  case currency
  when :usd
    # ...
  when :eur
    # ...
  end

  # ... rest of method
end
```

**Execution:**
```
Processing: app/services/payment_service.rb

⚙️ Re-analyzing...
✅ New characteristic found: currency

⚠️ Characteristics changed, regenerating structure

Comparing old vs new:
  Old: [user_authenticated]
  New: [user_authenticated, currency]

⚙️ Regenerating test structure...
⚙️ Adding semantic descriptions...
⚙️ Implementing test bodies...

✅ Updated with new structure

📋 Review: 1 warning (consider adding :eur trait to factory)
```

---

### Example 3: Custom Code Detected

**Existing test has custom helper:**
```ruby
RSpec.describe PaymentService do
  # CUSTOM HELPER - Do not remove
  def create_test_payment(amount)
    # Custom logic here
  end

  describe '#process_payment' do
    # ... tests ...
  end
end
```

**Execution:**
```
Processing: app/services/payment_service.rb

⚠️ Test contains custom code (helper method detected)

Regenerating may lose custom code.

Options:
  [1] Backup and regenerate
  [2] Skip this file
  [3] Show diff

Your choice: 1

Backed up to spec/services/payment_service_spec.rb.backup

⚙️ Regenerating...
✅ Updated

⚠️ Note: Custom helper was backed up. Restore manually if needed.
```

## Integration Points

### Called by User

```
"Update tests for my changes"
"Update tests for changed files"
"Update tests based on git diff HEAD~3..HEAD"
```

### Calls Agents

Same as rspec-write-new, but:
- May skip structure generation (if unchanged)
- Implementer runs in "update" mode (preserve more)
- Always checks for custom code before regeneration

## Testing Criteria

**Skill is correct if:**
- ✅ Detects changes correctly (git diff)
- ✅ Preserves working tests when possible
- ✅ Updates only what changed
- ✅ Warns about custom code
- ✅ Shows clear diff summary

## Related Specifications

- **skills/rspec-write-new.spec.md** - Similar pipeline
- **agents/rspec-analyzer.spec.md** - Re-analysis with cache check
- **skills/rspec-refactor-legacy.spec.md** - Different use case

---

**Key Takeaway:** Surgical updates. Preserve what works, update what changed. Git-aware workflow.
