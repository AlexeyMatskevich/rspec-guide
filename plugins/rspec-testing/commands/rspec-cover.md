---
description: Cover code with RSpec tests following BDD principles
argument-hint: [file_path] [--branch]
---

# RSpec Cover Command

Cover code changes with RSpec tests. Automatically detects new code vs modified code.

## Usage

```
/rspec-cover app/services/payment_processor.rb  # single file
/rspec-cover --branch                            # all changes on current branch
/rspec-cover --staged                            # staged files only
```

## Prerequisites Check

Before starting, verify:

1. **Plugin initialized** — `.claude/rspec-testing-config.yml` exists
   - If missing: "Run `/rspec-init` first to configure the plugin"
2. **Serena MCP active** — required for semantic code analysis
3. **Target files exist** — verify paths are valid

If prerequisites missing, inform user and stop.

## Workflow Overview

**6 phases, sequential** (this command orchestrates all phases):

1. **Discovery** (this command) — get changed files, classify (new/modified), build order, show plan → user approval
2. **Analysis** (parallel code-analyzer agents) — extract characteristics, identify dependencies, check factories
3. **Architecture** (parallel test-architect agents) — design context hierarchy, apply naming rules, order happy path first
4. **Implementation** (parallel test-implementer agents) — generate spec files, create factories, write expectations
5. **Review** (test-reviewer agent) — run tests, check compliance, apply fixes
6. **Summary** — report created files, coverage stats, next steps

## Phase 1: Discovery

### 1.1 Get Changed Files

**For single file:**
```bash
# Verify file exists
ls -la $FILE_PATH
```

**For branch mode:**
```bash
# Get files changed compared to main/master
git diff main...HEAD --name-only | grep '\.rb$' | grep -v '_spec\.rb$'
```

**For staged mode:**
```bash
git diff --cached --name-only | grep '\.rb$' | grep -v '_spec\.rb$'
```

### 1.2 Filter Files

Exclude:
- `_spec.rb` files (test files themselves)
- `db/migrate/` (migrations)
- `config/` (configuration)
- `bin/`, `script/` (scripts)

Include:
- `app/models/`
- `app/services/`
- `app/controllers/`
- `lib/`

### 1.3 Classify Files

For each file, determine:

| Pattern | Classification |
|---------|----------------|
| New file (no spec exists) | new_code |
| Modified file (spec exists) | update_existing |
| Modified file (no spec) | new_code |

### 1.4 Build Execution Order

Order by test level (dependencies):
1. Unit tests first (models, services, libs)
2. Integration tests second (controllers)
3. Request specs last

### 1.5 Show Plan to User

Use AskUserQuestion to confirm:

```
Found 5 files to cover with tests:

Unit tests:
  1. app/services/payment_processor.rb (new_code)
  2. app/models/transaction.rb (new_code)

Integration tests:
  3. app/controllers/payments_controller.rb (update_existing)

Proceed with test generation?
```

Options:
- Yes, proceed
- Modify selection
- Cancel

## Phase 2: Analysis (Parallel)

Launch code-analyzer agents in parallel for each file:

```
Task(code-analyzer, {
  file_path: "app/services/payment_processor.rb",
  analyze_all_methods: true
})

Task(code-analyzer, {
  file_path: "app/models/transaction.rb",
  analyze_all_methods: true
})
```

**Wait for all agents to complete, collect results.**

Each analyzer returns:
```yaml
class_name: PaymentProcessor
methods:
  - name: process
    characteristics: [...]
    dependencies: [...]
test_level: unit
factories:
  available: [user, payment]
  missing: [transaction]
```

## Phase 3: Architecture (Parallel)

Launch test-architect agents with analysis results:

```
Task(test-architect, {
  class_name: "PaymentProcessor",
  methods: [analysis results],
  test_level: "unit"
})
```

Each architect returns:
```yaml
structure:
  describe: PaymentProcessor
  methods:
    - describe: "#process"
      contexts: [...]
```

## Phase 4: Implementation (Parallel)

Launch test-implementer agents with architecture:

```
Task(test-implementer, {
  structure: [architect output],
  output_path: "spec/services/payment_processor_spec.rb"
})
```

Each implementer creates spec files and returns:
```yaml
files_created:
  - spec/services/payment_processor_spec.rb
  - spec/factories/transactions.rb
```

## Phase 5: Review

Launch test-reviewer for all created specs:

```
Task(test-reviewer, {
  spec_files: [list of created specs]
})
```

Reviewer runs tests and checks compliance:
```yaml
status: pass
tests_run: 24
tests_passed: 24
rule_violations: []
```

If issues found, reviewer attempts auto-fixes.

## Phase 6: Summary

Display final report:

```
✅ Test coverage complete!

Files covered: 3
Spec files created: 3
Total examples: 42
All tests passing: ✅

Created:
  - spec/services/payment_processor_spec.rb (18 examples)
  - spec/models/transaction_spec.rb (12 examples)
  - spec/requests/payments_spec.rb (12 examples)

Factories created:
  - spec/factories/transactions.rb

No rule violations detected.

Suggested next steps:
  - Run full test suite: bundle exec rspec
  - Check coverage: open coverage/index.html
```

## Error Handling

### No Files Found
```
No Ruby files found to cover.

If using --branch mode, ensure you have commits compared to main.
If using single file, verify the path is correct.
```

### Analysis Failed
```
Failed to analyze: app/services/broken_service.rb
Error: Syntax error at line 42

Skipping this file. Continue with remaining files? [Y/n]
```

### Tests Failed
```
⚠️ Some tests are failing

Failures:
  1. spec/services/payment_processor_spec.rb:45
     Expected success but got failure

Options:
  1. Show failure details
  2. Attempt auto-fix
  3. Skip and continue
  4. Abort
```

## Parallel Execution Note

This command orchestrates multiple agents in parallel where possible.

**Parallel phases:**
- Phase 2: All code-analyzer agents run simultaneously
- Phase 3: All test-architect agents run simultaneously
- Phase 4: All test-implementer agents run simultaneously

**Sequential phases:**
- Phase 1 (Discovery) must complete before Phase 2
- Phase 5 (Review) waits for all implementations

This pattern significantly speeds up multi-file coverage compared to sequential processing.
