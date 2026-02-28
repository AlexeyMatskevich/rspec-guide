---
description: Refactor legacy RSpec tests to follow BDD style guide
argument-hint: <spec_file_or_pattern>
---

# RSpec Refactor Command

Rewrite legacy RSpec tests to comply with the 28-rule BDD style guide.

## Usage

```
/rspec-refactor spec/models/user_spec.rb           # single file
/rspec-refactor spec/services/                      # directory
/rspec-refactor spec/**/*_spec.rb --check          # check only, no changes
```

## When to Use

Use this command when:
- Existing tests don't follow BDD principles
- Tests are implementation-focused (mocking everything)
- Context structure is flat or confusing
- Naming doesn't follow when/with/without pattern
- Tests are slow due to excessive `create` instead of `build_stubbed`

## Prerequisites Check

1. **Plugin initialized** — `.claude/rspec-testing-config.yml` exists
   - If missing: "Run `/rspec-init` first to configure the plugin"
2. **Serena MCP active** — for analyzing corresponding source code
3. **Context7 MCP active** — required for library/API docs lookup (RSpec, rspec-rails, factories, shoulda-matchers)
4. **Ruby runtime available** — required to run scripts and tests
5. **Spec file(s) exist** — verify paths are valid
6. **Tests currently pass** — don't refactor broken tests

## Execution Protocol

Create TodoWrite before starting:

- [Phase 1] Analyze existing tests
- [Phase 2] Show refactor plan (approval)
- [Phase 3] Rewrite tests
- [Phase 4] Verify & review
- [Phase 5] Summary

## Workflow Overview

**5 phases, sequential:**

1. **Analyze** — read spec structure, identify violations, map to source code
2. **Plan** — list violations, propose changes, get user approval
3. **Rewrite** (parallel if multiple files) — re-analyze source, design new structure, implement rewrite
4. **Verify** — run tests, compare coverage, compliance check
5. **Summary** — before/after comparison, highlight improvements

## Phase 1: Analyze Existing Tests

### 1.1 Read Spec File

Read the spec file and analyze its structure:
- Number of describe/context/it blocks
- Naming patterns used
- Setup patterns (let/before/instance variables)
- Expectation patterns

### 1.2 Identify Violations

Common issues to check:
- 🔴 **High**: Testing implementation with receive chains (Rule 1), multiple behaviors in one `it` (Rule 3)
- 🟡 **Medium**: Flat structure without contexts (Rule 4.2), instance variables instead of let (Rule 5), excessive `create` calls (Rule 11)
- 🟢 **Low**: Wrong context naming like if/case (Rule 10.1), edge cases before happy path (Rule 4.2)

### 1.3 Map to Source Code

Find corresponding source file:
```ruby
# spec/services/payment_processor_spec.rb
# → app/services/payment_processor.rb
```

Use Serena to verify source exists and get current implementation.

## Phase 2: Show Refactoring Plan

Present findings and proposed changes:

```
Analyzing: spec/services/payment_processor_spec.rb

Found 8 rule violations:

🔴 Critical:
  1. [Rule 1] Line 45: Testing implementation (expect to receive :charge)
  2. [Rule 3] Line 67: Multiple behaviors in single it block

🟡 Medium:
  3. [Rule 4.2] Flat structure, no characteristic-based contexts
  4. [Rule 5] Using @user instead of let(:user)
  5. [Rule 11] Using create() 12 times, could use build_stubbed

🟢 Minor:
  6. [Rule 10.1] Context "if valid" should be "when valid"
  7. [Rule 4.2] Error cases come before happy path

Proposed changes:
  - Restructure contexts by payment status characteristic
  - Convert @variables to let blocks
  - Replace 10 create() with build_stubbed()
  - Rename 3 contexts to use 'when' instead of 'if'
  - Reorder contexts: happy path first

Proceed with refactoring? [Y/n/show details]
```

## Metadata Creation (No Discovery Agent)

Unlike `/rspec-cover`, this command creates the initial metadata directly (no git-based discovery/waves).

**Rationale:**
- No waves needed — specs are independent
- No dependency graph — refactoring doesn’t require wave ordering
- method selection is local to this spec (choose methods from the mapped source file)

**For each spec file:**

```yaml
spec_path: spec/services/payment_processor_spec.rb
source_file: app/services/payment_processor.rb

# Refactor mode: treat all selected methods as unchanged.
methods_to_analyze:
  - name: process
    method_mode: unchanged
    selected: true
    line_range: [1, 100]

automation:
  rspec_refactor_started: true
```

**Location:** `{metadata_path}/rspec_metadata/{slug}.yml`

---

## Phase 3: Rewrite Tests

### 3.1 Re-analyze Source Code

Launch code-analyzer to get fresh characteristics:

```
Task(code-analyzer, {
  slug: "app_services_payment_processor"
})
```

### 3.2 Design New Structure

Launch spec-writer to materialize and rewrite the spec:

```
Task(spec-writer, {
  slug: "app_services_payment_processor"
})
```

Spec-writer:
- Derives `methods[].test_config` via a deterministic script (AskUserQuestion only when low-confidence)
- Patches/rewrites method blocks deterministically via scripts
- Fills placeholders (`{COMMON_SETUP}`, `{SETUP_CODE}`, `{EXPECTATION}`)
- Removes all temporary `# rspec-testing:*` markers from the final spec file
- Writes `automation.spec_writer_completed: true` in metadata

## Phase 4: Verify & Review

### 4.1 Run Tests

```bash
bundle exec rspec spec/services/payment_processor_spec.rb
```

If tests fail:
- Compare with original behavior
- Identify what was lost in translation
- Fix or rollback

### 4.2 Compare Coverage

Ensure refactored tests cover same behaviors:
- Same number of examples (or more)
- Same scenarios tested
- No regression

### 4.3 Compliance Check

Launch test-reviewer:
```
Task(test-reviewer, {
  spec_files: ["spec/services/payment_processor_spec.rb"],
  strict: true
})
```

## Phase 5: Summary

```
✅ Refactoring complete!

Before:
  - Examples: 15
  - Rule violations: 8
  - create() calls: 12
  - Avg test time: 0.8s

After:
  - Examples: 18 (+3 for better coverage)
  - Rule violations: 0
  - create() calls: 2 (only where needed)
  - Avg test time: 0.2s (4x faster)

Changes made:
  ✓ Restructured with 4 characteristic-based contexts
  ✓ Converted 5 instance variables to let blocks
  ✓ Replaced 10 create() with build_stubbed()
  ✓ Split 2 multi-behavior it blocks
  ✓ Fixed 3 context naming issues
  ✓ Reordered happy path first

Backup saved: spec/services/payment_processor_spec.rb.bak

Run 'git diff' to see full changes.
```

## Check-Only Mode

With `--check` flag, don't modify files, just report:

```
/rspec-refactor spec/services/ --check

Scanned: 12 spec files

Summary:
  - Clean (no violations): 5 files
  - Minor issues: 4 files
  - Needs refactoring: 3 files

Files needing attention:
  1. spec/services/payment_processor_spec.rb (8 violations)
  2. spec/services/notification_service_spec.rb (5 violations)
  3. spec/services/report_generator_spec.rb (4 violations)

Run '/rspec-refactor <file>' to fix individual files.
```

## Parallel Processing

When refactoring multiple files:
- Analyze all files in parallel
- Present combined plan
- Refactor files in parallel after approval
- Review all together

## Error Handling

### Tests Already Failing
```
⚠️ Existing tests are failing

Cannot refactor tests that don't pass.
Please fix failing tests first:

  bundle exec rspec spec/services/payment_processor_spec.rb

Failures:
  1. PaymentProcessor#process when valid charges payment
     Expected success but got nil
```

### Cannot Map to Source
```
Cannot find source file for spec.

Looking for: app/services/payment_processor.rb
Tried: lib/payment_processor.rb

Please specify source file:
  /rspec-refactor spec.rb --source app/other/path.rb
```

### Behavior Changed After Refactor
```
⚠️ Test behavior changed after refactoring

Original tests: 15 examples, 0 failures
Refactored tests: 18 examples, 2 failures

This may indicate:
  - Lost test coverage
  - Bug in refactored test
  - Original test was testing wrong behavior

Options:
  1. Show diff
  2. Rollback to backup
  3. Keep refactored version (fix manually)
```

## Backup Strategy

Before modifying any file:
```bash
cp spec/services/payment_processor_spec.rb \
   spec/services/payment_processor_spec.rb.bak
```

To rollback:
```bash
mv spec/services/payment_processor_spec.rb.bak \
   spec/services/payment_processor_spec.rb
```
