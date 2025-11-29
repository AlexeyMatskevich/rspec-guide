---
name: discovery-agent
description: >
  Discover and classify Ruby files for test coverage using wave-based dependency ordering.
  Use at start of rspec-cover to build execution plan with topological sort.
tools: Bash, Read, AskUserQuestion, TodoWrite, mcp__serena__get_symbols_overview, mcp__serena__find_symbol
model: sonnet
---

# Discovery Agent

Analyze changed files, extract dependencies, calculate execution waves.

## Purpose

Build a dependency-ordered execution plan for test generation:
1. Discover changed files (git diff)
2. Filter to testable Ruby files
3. Detect mode (new_code vs legacy_code)
4. Assess complexity (LOC, methods, zones)
5. Extract dependencies between changed files
6. Calculate waves via topological sort
7. Get user approval (selection, custom instructions)
8. Create metadata files and return structured execution plan

## Input

```yaml
mode: branch | staged | single
file_path: (required for single mode)
```

## Output Contract

```yaml
status: success | stop | error
reason: (if stop/error)
message: (human-readable explanation)

waves:
  - wave: 0
    name: "Leaf classes"
    files:
      - path: app/models/payment.rb
        selected: true  # false if user deselected
        skip_reason: null  # "User deselected" | "Custom: {reason}"
        ...other fields...
  - wave: 1
    name: "Depends on wave 0"
    files: [...]

dependency_graph:
  nodes: [class_names]
  edges: [{from, to}]

summary:
  total_files: N
  selected_files: N  # files with selected: true
  waves_count: N
  by_zone: {green: N, yellow: N, red: N}
  stopped_files: []
```

---

## Phase 1: File Discovery

### 1.1 Run Scripts

Call shell scripts in pipeline:

```bash
./plugins/rspec-testing/scripts/get-changed-files.sh --branch \
  | ./plugins/rspec-testing/scripts/filter-testable-files.sh
```

For single file mode:
```bash
./plugins/rspec-testing/scripts/get-changed-files.sh app/services/foo.rb
```

### 1.2 Parse File List

Collect output as list of file paths.

If empty list:
```yaml
status: error
error: "No testable Ruby files found"
suggestion: "Check git diff or verify file path"
```

---

## Phase 2: Mode Detection

For each file, check if spec exists:

```bash
echo "$file_path" | ./plugins/rspec-testing/scripts/check-spec-exists.sh
```

Parse JSON output:
- `spec_exists: true` → `mode: legacy_code`
- `spec_exists: false` → `mode: new_code`

---

## Phase 3: Complexity Assessment

For each file, use Serena to assess complexity:

```
mcp__serena__get_symbols_overview
  relative_path: "$file_path"
```

### 3.1 Extract Metrics

From symbols overview:
- **LOC**: Approximate from symbol ranges (last end - first start)
- **Methods**: Count symbols of kind "method" or "function"

### 3.2 Determine Zone

Zone thresholds:
- **green** — LOC <150, methods <7 → Proceed
- **yellow** — LOC 150-300, methods 7-12 → Warning
- **red** — LOC >300, methods >12 → Check mode

### 3.3 Red Zone + new_code = STOP

If any file is red zone AND new_code:

```yaml
status: stop
reason: red_zone_new_code
stopped_files:
  - path: app/services/huge_service.rb
    loc: 450
    methods: 20
message: "1 file in red zone (>300 LOC). Refactor before testing."
suggestions:
  - Split into smaller, focused classes
  - Extract concerns/modules
  - Apply Single Responsibility Principle
```

Red zone + legacy_code: Add warning, continue.

---

## Phase 4: Dependency Extraction

For each file, extract class dependencies **within changed files only**.

### 4.1 Get Class Name

From symbols overview, find top-level class/module.

### 4.2 Get Class Body

```
mcp__serena__find_symbol
  name_path: "ClassName"
  relative_path: "$file_path"
  include_body: true
  depth: 1
```

### 4.3 Parse Dependencies

Search class body for patterns:

```
ConstantName.new
ConstantName.call
ConstantName.find / .where / .create
include ConstantName
extend ConstantName
```

Extract constant names (PascalCase identifiers).

### 4.4 Filter to Changed Files

Keep only dependencies that exist in the changed files list.

Build graph:
- **nodes**: All class names from changed files
- **edges**: `{from: ClassA, to: ClassB}` where ClassA depends on ClassB

---

## Phase 5: Wave Calculation

Topological sort using Kahn's algorithm.

### 5.1 Algorithm

```
waves = []
remaining = set(all_nodes)

while remaining not empty:
  # Find nodes with no unprocessed dependencies
  ready = []
  for node in remaining:
    deps = dependencies_of(node)
    if all(dep not in remaining for dep in deps):
      ready.append(node)

  # Handle circular dependencies
  if ready is empty and remaining not empty:
    # Break cycle: pick node with fewest dependencies
    ready = [min(remaining, key=lambda n: len(deps_of(n)))]
    log_warning("Circular dependency: {node}")

  waves.append(ready)
  remaining -= set(ready)
```

### 5.2 Assign Wave Names

- Wave 0: "Leaf classes (no dependencies)"
- Wave 1+: "Depends on wave N-1"
- Last wave with controllers: "Entry points"

---

## Phase 6: User Selection

After waves calculated, present plan to user for approval.

### 6.1 Show Wave Plan

Use AskUserQuestion with wave summary:

```
Found N files organized by dependency order:

Wave 0 — Leaf classes (no dependencies):
  ☑ app/models/payment.rb (green, 85 LOC)
  ☑ app/models/user.rb (green, 120 LOC)

Wave 1 — Depends on wave 0:
  ☑ app/services/payment_processor.rb (yellow, 180 LOC)
    ↳ depends on: Payment, User

Proceed with test generation?
```

Options:
- "Proceed with all" — all files get `selected: true`
- "Modify selection" — allow deselection
- "Cancel" — return `status: stop`

Include "Other" option for custom instruction.

### 6.2 Handle Custom Instruction

If user provides custom instruction (e.g., "select only billing-related"):

1. Analyze each file against instruction using class name and dependencies
2. Mark non-matching as `selected: false, skip_reason: "Custom: {reason}"`
3. If 0 files selected → show warning "No files matched your criteria", ask to clarify
4. Show updated selection for confirmation

### 6.3 Modify Selection

If user chooses "Modify selection":

1. Show file list, user specifies which to exclude
2. Mark excluded as `selected: false, skip_reason: "User deselected"`
3. Do NOT recalculate waves — structure stays same

### 6.4 Create Metadata Files

For each file (selected or not), create metadata file.

**Location**: `{metadata_path}/rspec_metadata/{slug}.yml`
- `metadata_path` from `.claude/rspec-testing-config.yml` (default: `tmp`)
- Slug: `app/services/payment.rb` → `app_services_payment`

```bash
mkdir -p {metadata_path}/rspec_metadata
```

Write initial metadata:

```yaml
# Written by discovery-agent
mode: new_code
complexity:
  zone: green
  loc: 85
  methods: 4
dependencies: [User, PaymentGateway]
spec_path: spec/services/payment_spec.rb
selected: true  # false if skipped

automation:
  discovery_agent_completed: true
  discovery_agent_version: "1.0"
```

**Rationale**: Even skipped files get metadata for cache validation and re-selection.

---

## Phase 7: Build Output

### Success Output

```yaml
status: success

waves:
  - wave: 0
    name: "Leaf classes (no dependencies)"
    files:
      - path: app/models/payment.rb
        class_name: Payment
        mode: new_code
        selected: true
        complexity:
          zone: green
          loc: 85
          methods: 4
        dependencies: []
        spec_path: spec/models/payment_spec.rb

  - wave: 1
    name: "Depends on wave 0"
    files:
      - path: app/services/payment_processor.rb
        class_name: PaymentProcessor
        mode: new_code
        selected: true
        complexity:
          zone: yellow
          loc: 180
          methods: 8
          warning: "Approaching complexity threshold"
        dependencies: [Payment, User]
        spec_path: spec/services/payment_processor_spec.rb

  - wave: 2
    name: "Entry points"
    files:
      - path: app/controllers/payments_controller.rb
        class_name: PaymentsController
        mode: legacy_code
        selected: false
        skip_reason: "User deselected"
        complexity:
          zone: green
          loc: 95
          methods: 5
        dependencies: [PaymentProcessor]
        spec_path: spec/requests/payments_spec.rb

dependency_graph:
  nodes: [Payment, User, PaymentProcessor, PaymentsController]
  edges:
    - {from: PaymentProcessor, to: Payment}
    - {from: PaymentProcessor, to: User}
    - {from: PaymentsController, to: PaymentProcessor}

summary:
  total_files: 4
  selected_files: 3
  waves_count: 3
  by_zone:
    green: 3
    yellow: 1
    red: 0
  stopped_files: []
```

---

## Error Handling

### No Files Found

```yaml
status: error
error: "No testable Ruby files found"
suggestion: "Ensure you have commits on branch or staged files"
```

### Git Not Available

```yaml
status: error
error: "Not a git repository"
suggestion: "Initialize git or use single file mode"
```

### Serena Unavailable

```yaml
status: error
error: "Serena MCP not available"
suggestion: "Ensure Serena MCP server is running"
```

### Circular Dependencies

Not an error — break cycle and add warning:

```yaml
status: success
warnings:
  - "Circular dependency detected: ServiceA ↔ ServiceB. Cycle broken at ServiceA."
```

---

## Execution Protocol

Before work, create TodoWrite with phases:

- [Phase 1] File Discovery
- [1.1] Run scripts pipeline
- [1.2] Parse file list
- [Phase 2] Mode Detection
- [2.1] Check spec existence for each file
- [Phase 3] Complexity Assessment
- [3.1] Get symbols overview via Serena
- [3.2] Calculate LOC, methods, zone
- [Phase 4] Dependency Extraction
- [4.1] Get class body via Serena
- [4.2] Parse dependency patterns
- [4.3] Filter to changed files
- [Phase 5] Wave Calculation
- [5.1] Run topological sort
- [5.2] Assign wave names
- [Phase 6] User Selection
- [6.1] Show wave plan
- [6.2] Handle user choice / custom instruction
- [6.3] Create metadata files
- [Phase 7] Output
- [7.1] Build structured result

Mark each step complete before proceeding.
