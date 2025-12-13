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
2. **Spec file(s) exist** — verify paths are valid
3. **Tests currently pass** — don't refactor broken tests
4. **Serena MCP active** — for analyzing corresponding source code

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
- 🟡 **Medium**: Flat structure without contexts (Rule 7), instance variables instead of let (Rule 11), excessive `create` calls (Rule 23)
- 🟢 **Low**: Wrong context naming like if/case (Rule 17), edge cases before happy path (Rule 19)

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
  3. [Rule 7] Flat structure, no characteristic-based contexts
  4. [Rule 11] Using @user instead of let(:user)
  5. [Rule 23] Using create() 12 times, could use build_stubbed

🟢 Minor:
  6. [Rule 17] Context "if valid" should be "when valid"
  7. [Rule 19] Error cases come before happy path

Proposed changes:
  - Restructure contexts by payment status characteristic
  - Convert @variables to let blocks
  - Replace 10 create() with build_stubbed()
  - Rename 3 contexts to use 'when' instead of 'if'
  - Reorder contexts: happy path first

Proceed with refactoring? [Y/n/show details]
```

## Metadata Creation (No Discovery Agent)

Unlike `/rspec-cover`, this command creates metadata directly without discovery-agent:

**Rationale:**
- No waves needed — specs are independent
- No dependency graph — refactoring doesn't change dependencies
- Always full rewrite (no method_mode differentiation)

**For each spec file:**

```yaml
# Created by rspec-refactor command
rewrite: true
spec_path: spec/services/payment_processor_spec.rb
source_path: app/services/payment_processor.rb

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
  file_path: "app/services/payment_processor.rb"
})
```

### 3.2 Design New Structure

Launch test-architect with characteristics:
```
Task(test-architect, {
  class_name: "PaymentProcessor",
  methods: [analysis results],
  preserve_coverage: true
})
```

**Important:** Architect must preserve all behaviors being tested, just reorganize structure.
Architect writes/updates the spec skeleton on disk with placeholders; `structure` is stored in metadata for reference and must not be passed to implementer.

### 3.3 Implement Rewrite

Launch test-implementer:
```
Task(test-implementer, {
  slug: "spec_services_payment_processor",
  rewrite: true,
  # Optional hint (only if metadata/spec_path is missing or stale):
  # spec_file: "spec/services/payment_processor_spec.rb"
})
```

Implementer:
- Finds the spec skeleton from metadata by `slug`
- Fills placeholders (`{COMMON_SETUP}`, `{SETUP_CODE}`, `{EXPECTATION}`) in the spec file
- Preserves behaviors and uses correct patterns (`let`, `build_stubbed`, etc.)

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
