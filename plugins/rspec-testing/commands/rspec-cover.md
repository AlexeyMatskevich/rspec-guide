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

**Method-level wave execution** — methods processed in dependency order.

Before starting, create TodoWrite:

- [Phase 1] Discovery
- [1.1] Check prerequisites
- [1.2] Run discovery-agent (includes user approval)
- [1.3] Filter to selected methods
- [Phase 2] Execution (repeat per wave)
- [2.N] Wave N — analyze selected methods, decide isolation, write specs, review
- [Phase 3] Summary
- [3.1] Report results

**Fail-fast**: If any test in wave N fails, do not proceed to wave N+1.

**Key change**: Discovery-agent now returns `method_waves[]` with individual methods as wave items. Methods are grouped by file for efficient processing.

---

## Phase 1: Discovery

### 1.1 Run Discovery Agent

```
Task(discovery-agent, {
  discovery_mode: "branch" | "staged" | "single",
  file_path: (for single discovery_mode)
})
```

Discovery agent:

- Runs shell scripts for git operations
- Analyzes complexity via Serena
- Extracts dependencies between changed files
- Calculates waves via topological sort
- Shows waves to user for approval (AskUserQuestion)
- Handles custom instructions (e.g., "select only billing-related")
- Creates metadata files for each file

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

**If status: success** — filter waves to `selected: true` methods, continue to execution.

### 1.3 Filter Selected Methods

From discovery result, keep only methods where `selected: true`.

If no methods selected (all skipped or user cancelled):

```
No methods selected for test generation.
```

---

## Phase 2: Per-Wave Execution

For each wave **sequentially** (wave 0, then wave 1, etc.):

**Note**: Wave items are methods, but agents process files. Methods from the same file in the same wave are grouped for efficient processing.

### 2.1 Group Methods by File

From wave N, group selected methods by source_file:

```yaml
# Wave 0 methods grouped:
app/models/payment.rb:
  - Payment#validate
  - Payment#charge
app/models/user.rb:
  - User#full_name
```

### 2.2 Analysis (Parallel within wave)

Launch code-analyzer agents for each file group:

```
Task(code-analyzer, {
  slug: "app_models_payment"
})
```

Agent reads all data (`source_file`, `class_name`, `complexity`, `methods_to_analyze`) from metadata file.

Wait for all analyzers in wave to complete.

### 2.2b Isolation Decision (Parallel within wave)

Launch isolation-decider agents for each file:

```
Task(isolation-decider, {
  slug: "app_models_payment"
})
```

Agent reads metadata, derives `methods[].test_config` (test_level, isolation, confidence), and writes back. Uses haiku model for cost efficiency.

Wait for all isolation-deciders in wave to complete.

### 2.3 Spec Writing (Parallel within wave)

Launch spec-writer agents with metadata reference:

```
Task(spec-writer, {
  slug: "app_models_payment"
})
```

Spec-writer reads metadata by `slug`, materializes/paches the spec skeleton via scripts, fills placeholders (`{COMMON_SETUP}`, `{SETUP_CODE}`, `{EXPECTATION}`), then strips all temporary `# rspec-testing:*` markers from the final spec file.

Wait for all spec-writers in wave to complete.

### 2.4 Review (Per wave)

Run test-reviewer for all specs created in this wave:

```
Task(test-reviewer, {
  spec_files: ["spec/models/payment_spec.rb", "spec/models/user_spec.rb"]
})
```

### 2.5 Wave Gate

**If all tests pass**: Report wave success, proceed to next wave.

```
✅ Wave 0 complete: 3 methods (2 files), 24 examples, all passing
   Proceeding to Wave 1...
```

**If any test fails**: STOP execution, do not proceed to next wave.

```
⚠️ Wave 0 failed: tests not passing

Failures in:
  - spec/models/payment_spec.rb:45 — Payment#charge expected success

Options:
  1. Show failure details
  2. Attempt auto-fix
  3. Skip failed method, continue wave
  4. Abort
```

Rationale: Higher waves depend on lower wave methods. If lower wave tests fail, higher wave tests will likely fail too.

---

## Phase 3: Summary

After all waves complete:

```
✅ Test coverage complete!

Wave 0 (Leaf methods):
  app/models/payment.rb:
    - Payment#validate (6 examples)
    - Payment#charge (6 examples)
  app/models/user.rb:
    - User#full_name (4 examples)

Wave 1 (Depends on wave 0):
  app/services/payment_processor.rb:
    - PaymentProcessor#process (12 examples)
    - PaymentProcessor#refund (6 examples)

Wave 2 (Entry points):
  app/controllers/payments_controller.rb:
    - PaymentsController#create (8 examples)

Total: 6 methods (3 files), 42 examples, all passing

Factories created:
  - spec/factories/payments.rb
  - spec/factories/transactions.rb

Dependency coverage verified:
  ✓ Payment#validate tested before PaymentProcessor#process
  ✓ PaymentProcessor#process tested before PaymentsController#create

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
⚠️ Circular dependency detected: PaymentProcessor#process ↔ RefundService#refund
   Cycle broken at PaymentProcessor#process (will be tested first)
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

1. **Wave 0** — all methods (grouped by file) in parallel, wait for tests to pass
2. **Wave 1** — all methods (grouped by file) in parallel, wait for tests to pass
3. **Wave N** — repeat until all waves complete
4. **Summary** — report results

**Wave items**: Public methods (not files). Methods from the same file in the same wave are grouped.
**Parallelism**: Within each wave, all file groups run in parallel.
**Sequentiality**: Waves run one after another.
**Fail-fast**: Wave N+1 only runs if Wave N passes.
