---
description: Cover code with RSpec tests using wave-based dependency ordering
argument-hint: [file_path] [--branch] [--staged]
---

# RSpec Cover Command

Cover code changes with RSpec tests. Uses dependency analysis to order test generation (leaf classes first, dependent classes after).

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
3. **Git available** — for branch/staged modes

If prerequisites missing, inform user and stop.

## Workflow

**Wave-based execution** — files processed in dependency order.

Before starting, create TodoWrite:

- [Phase 1] Discovery
- [1.1] Check prerequisites
- [1.2] Run discovery-agent
- [Phase 2] Approval
- [2.1] Show waves to user
- [2.2] Handle selection
- [Phase 3] Execution (repeat per wave)
- [3.N] Wave N — analyze, architect, implement, review
- [Phase 4] Summary
- [4.1] Report results

**Fail-fast**: If any test in wave N fails, do not proceed to wave N+1.

---

## Phase 1: Discovery

### 1.1 Run Discovery Agent

```
Task(discovery-agent, {
  mode: "branch" | "staged" | "single",
  file_path: (for single mode)
})
```

Discovery agent:
- Runs shell scripts for git operations
- Analyzes complexity via Serena
- Extracts dependencies between changed files
- Calculates waves via topological sort

### 1.2 Handle Discovery Result

**If status: stop** (red zone + new_code):
```
⛔ Cannot proceed with test generation.

1 file in red zone (>300 LOC):
  - app/services/huge_service.rb (450 LOC, 20 methods)

Suggestions:
  - Split HugeService into smaller, focused classes
  - Extract concerns/modules

Refactor first, then re-run /rspec-cover.
```

**If status: error**:
```
❌ Discovery failed: {error message}

Suggestion: {suggestion from agent}
```

**If status: success** — continue to approval.

---

## Phase 2: User Approval

### 2.1 Show Wave-Based Plan

Use AskUserQuestion to display waves:

```
Found 4 files to cover, organized by dependency order:

Wave 0 — Leaf classes (no dependencies):
  ☑ app/models/payment.rb (green, 85 LOC)
  ☑ app/models/user.rb (green, 120 LOC)

Wave 1 — Depends on wave 0:
  ☑ app/services/payment_processor.rb (yellow, 180 LOC)
    ↳ depends on: Payment, User

Wave 2 — Entry points:
  ☑ app/controllers/payments_controller.rb (green, 95 LOC)
    ↳ depends on: PaymentProcessor

Execution order ensures dependencies are tested first.

Proceed with test generation?
```

Options:
- Yes, proceed with all
- Modify selection (deselect files)
- Cancel

### 2.2 Handle User Selection

If user modifies selection:
- Remove deselected files
- Recalculate waves (some may become empty)
- Show updated plan for confirmation

---

## Phase 3: Per-Wave Execution

For each wave **sequentially** (wave 0, then wave 1, etc.):

### 3.1 Analysis (Parallel within wave)

Launch code-analyzer agents for all files in wave:

```
Task(code-analyzer, {
  file_path: "app/models/payment.rb",
  class_name: "Payment",
  mode: "new_code",
  complexity: {zone: "green", loc: 85, methods: 4},
  dependencies: []
})
```

Wait for all analyzers in wave to complete.

### 3.2 Architecture (Parallel within wave)

Launch test-architect agents with analysis results:

```
Task(test-architect, {
  class_name: "Payment",
  methods: [analysis results],
  dependencies: []
})
```

### 3.3 Implementation (Parallel within wave)

Launch test-implementer agents with architecture:

```
Task(test-implementer, {
  structure: [architect output],
  output_path: "spec/models/payment_spec.rb"
})
```

### 3.4 Review (Per wave)

Run test-reviewer for all specs created in this wave:

```
Task(test-reviewer, {
  spec_files: ["spec/models/payment_spec.rb", "spec/models/user_spec.rb"]
})
```

### 3.5 Wave Gate

**If all tests pass**: Report wave success, proceed to next wave.

```
✅ Wave 0 complete: 2 files, 24 examples, all passing
   Proceeding to Wave 1...
```

**If any test fails**: STOP execution, do not proceed to next wave.

```
⚠️ Wave 0 failed: tests not passing

Failures in:
  - spec/models/payment_spec.rb:45 — expected success but got failure

Options:
  1. Show failure details
  2. Attempt auto-fix
  3. Skip failed file, continue wave
  4. Abort
```

Rationale: Higher waves depend on lower wave code. If lower wave tests fail, higher wave tests will likely fail too.

---

## Phase 4: Summary

After all waves complete:

```
✅ Test coverage complete!

Wave 0 (Leaf classes):
  - spec/models/payment_spec.rb (12 examples)
  - spec/models/user_spec.rb (8 examples)

Wave 1 (Services):
  - spec/services/payment_processor_spec.rb (18 examples)

Wave 2 (Entry points):
  - spec/requests/payments_spec.rb (12 examples)

Total: 4 files, 50 examples, all passing

Factories created:
  - spec/factories/payments.rb
  - spec/factories/transactions.rb

Dependency coverage verified:
  ✓ Payment tested before PaymentProcessor
  ✓ PaymentProcessor tested before PaymentsController

Suggested next steps:
  - Run full test suite: bundle exec rspec
  - Check coverage: open coverage/index.html
```

---

## Error Handling

### No Files Found

```
No testable Ruby files found.

If using --branch mode:
  - Ensure you have commits compared to main
  - Check: git diff main...HEAD --name-only

If using single file:
  - Verify the path is correct
```

### Circular Dependencies

Discovery agent handles this with warning:

```
⚠️ Circular dependency detected: ServiceA ↔ ServiceB
   Cycle broken at ServiceA (will be tested first)
```

Execution continues normally.

### Analysis Failed

```
Failed to analyze: app/services/broken_service.rb
Error: Syntax error at line 42

Options:
  1. Skip this file, continue with remaining
  2. Abort entire operation
```

---

## Execution Model

1. **Wave 0** — all files in parallel, wait for tests to pass
2. **Wave 1** — all files in parallel, wait for tests to pass
3. **Wave N** — repeat until all waves complete
4. **Summary** — report results

**Parallelism**: Within each wave, all agents run in parallel.
**Sequentiality**: Waves run one after another.
**Fail-fast**: Wave N+1 only runs if Wave N passes.
