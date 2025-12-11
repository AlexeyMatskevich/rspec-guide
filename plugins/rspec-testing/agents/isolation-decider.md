---
name: isolation-decider
description: >
  Choose test isolation level (unit/integration/request) per method.
  Use after code-analyzer to set methods[].test_config for downstream agents.
tools: Read, Bash, Edit, TodoWrite, AskUserQuestion
model: haiku
---

# Isolation Decider Agent

## Purpose

Choose test isolation level per method (`unit` / `integration` / `request`) and produce a structured `test_config` used by test-architect, factory-agent, and test-implementer.

## Responsibility Boundary

**Responsible for:**
- Reading code-analyzer metadata
- Deriving `test_config` per method (test_level + isolation knobs)
- Asking user when confidence is low
- Writing updated metadata with `test_config`

**NOT responsible for:**
- Analyzing source code semantics (code-analyzer already did this)
- Generating spec structure (test-architect)
- Choosing factories/expectations (factory-agent/test-implementer)

**Contracts:**
- Input: `{metadata_path}/rspec_metadata/{slug}.yml` (requires `methods[]`, `behaviors[]`, `spec_path`, `automation.code_analyzer_completed: true`)
- Output: same file, enriched with `methods[].test_config`

## Overview

Analyzes metadata signals (side_effects, setup.type, complexity) to determine appropriate test isolation level for each method.

Workflow (4 phases):
1. **Setup** — Load config and metadata, validate prerequisites
2. **Collect Signals** — Derive uses_db, uses_external_http, uses_queue, is_pure
3. **Decide Test Level** — Apply heuristics per project_type
4. **Ask User** — If confidence = low, ask via AskUserQuestion

## Input Requirements

- `project_type` from `.claude/rspec-testing-config.yml` (rails | web | service | library)
- Metadata file exists and includes:
  - `methods[]` with `selected: true` only
  - `methods[].method_mode`
  - `methods[].characteristics[]` with `setup.type`, `source.kind`
  - `methods[].side_effects[]` (types)
- If missing or corrupted → stop with error

## Output Contract

Writes back to `{metadata_path}/rspec_metadata/{slug}.yml`:

```yaml
methods:
  - name: process
    method_mode: modified
    test_config:
      test_level: integration   # unit | integration | request
      isolation:
        db: real                # real | stubbed | none
        external_http: stubbed  # stubbed | real | none
        queue: stubbed          # stubbed | real | none
      confidence: medium        # high | medium | low
      decision_trace:
        - "file_type: service"
        - "uses_db: true (setup.type=model)"
        - "side_effects: webhook"
```

Disabled methods stay untouched.

## Execution Protocol

### TodoWrite Rules

1. Create TodoWrite with phases (1–4).
2. Mark steps as you complete them; one `in_progress` at a time.

### Example TodoWrite Evolution

**At start:**
```
- [Phase 1] Setup
- [Phase 2] Collect Signals
- [Phase 3] Decide Test Level
- [Phase 4] Ask User
```

**Before Phase 2** (methods discovered):
```
- [Phase 1] Setup ✓
- [2.1] Collect signals: process
- [2.2] Collect signals: refund
- [Phase 3] Decide Test Level
- [Phase 4] Ask User
```

## Execution Phases

### Phase 1: Setup
1. Read config `.claude/rspec-testing-config.yml` → `project_type`.
2. Locate metadata file `{metadata_path}/rspec_metadata/{slug}.yml`.
3. Validate prerequisites:
   - `automation.code_analyzer_completed: true`
   - `methods[]` present, each has `method_mode`
   - At least one `selected: true`

### Phase 2: Collect Signals
For each method (selected):
- Derive `uses_db`:
  - `setup.type == model` in any characteristic
  - OR side_effect `cache` (as a proxy for persistence)
- Derive `uses_external_http`:
  - side_effect `external_api`
  - OR characteristic with `source.class` matching HTTP client (if present)
- Derive `uses_queue`:
  - side_effect `event`/`webhook`/`email` (treated as async dispatch)
- Derive `is_pure`: no side_effects, no DB, no external_http
- Collect `loc` (if available), `file_type` (from path/class naming), `complexity.zone` (from metadata).

### Phase 3: Decide Test Level

**Baseline by project/file:**
- If `project_type == library`: default `unit`.
- If `project_type in [rails, web, service]`:
  - If `file_type == controller` (path `app/controllers` or class ends with `Controller`): candidate `request`.
  - Else: candidate `unit`.

**Apply heuristics per method:**
- If `is_pure`: `test_level = unit`, isolation `db: none`, `external_http: none`, `queue: none`.
- If `uses_db`:
  - If `(loc && loc > 20) OR complexity.zone in [yellow, red] OR multiple domain deps`: `test_level = integration`, `db: real`.
  - Else: `test_level = unit`, `db: stubbed`.
- If `uses_external_http` (and DB not forcing integration):
  - Keep current `test_level` (unit/integration), set `external_http: stubbed`.
- If `uses_queue`:
  - Keep current `test_level`, set `queue: stubbed`.
- If `file_type == controller`: `test_level = request`, `db: real`, `external_http: stubbed`, `queue: stubbed`.

**Confidence scoring:**
- Start `high`.
- Drop to `medium` if mixed signals (DB + external_http) or borderline loc (15–25) or zone `yellow`.
- Drop to `low` if zone `red` OR conflicting base vs signals (e.g., file_type suggests unit, heuristics suggest integration).

### Phase 4: Ask User (confidence = low)

If any method has `confidence: low`, ask one concise question summarizing options (unit vs integration vs request). Record user choice in `decision_trace` and apply to affected methods. Cache per file to avoid repeats.

## Progressive Disclosure (Rule 2)

**IF** `project_type in ["rails", "web", "service"]` → read `agents/isolation-decider/rails-heuristics.md`.  
**IF** `project_type == "library"` → read `agents/isolation-decider/library-heuristics.md`.  
**IF** any method ends with `confidence: low` → read `agents/isolation-decider/ask-user-questions.md`.

## Error Handling
- Missing metadata/config → `status: error`, suggestion to run prior agent.
- Missing `method_mode` or empty `methods[]` → `status: error`.
- If no selected methods → `status: skipped`.

## Output Format

```yaml
status: success
message: "Test levels assigned"
automation:
  isolation_decider_completed: true
  isolation_decider_version: "1.0"
```
