# Flow Architecture

Decision record for mode system and command pipelines.

**Status**: ACCEPTED
**Date**: 2024-12-XX

---

## Terminology

Avoid "mode" overloading. Use specific terms:

| Term | Values | Meaning |
|------|--------|---------|
| **discovery_mode** | branch \| staged \| single | How to collect changed files |
| **method_mode** | new \| modified \| unchanged | Per-method mode from git diff |

### method_mode definitions

| method_mode | Condition | spec-writer Action |
|-------------|-----------|-------------------|
| `new` | Method didn't exist before (or file is new) | Insert new describe block |
| `modified` | Method body changed (in git diff) | Upsert/replace describe block |
| `unchanged` | Method exists but wasn't touched | Upsert/replace if user selected |

**Note**: Deleted files are filtered out in discovery-agent Phase 1.2.

---

## Commands and Pipelines

### /rspec-cover

**Purpose**: Cover code changes with tests.

**Input**: `discovery_mode: branch | staged | single`

**Pipeline**:
```
discovery-agent → code-analyzer → isolation-decider → (factory-agent, optional) → spec-writer → test-reviewer
```

**Discovery-agent responsibilities**:
- Collect files based on discovery_mode (git diff)
- Determine method_mode per method (git diff + Serena)
- Build dependency graph
- Calculate waves (topological sort)
- Get user approval
- Create metadata files (public)

**Isolation-decider responsibilities**:
- Read code-analyzer metadata
- Derive `methods[].test_config` (test_level + isolation, confidence, decision_trace)
- Ask user only when confidence is low
- Write back metadata for spec-writer (and factory-agent if used)

### /rspec-refactor

**Purpose**: Rewrite legacy tests to BDD style.

**Input**: `paths: string | string[]` (spec file or directory or glob)

**Pipeline**:
```
[command creates metadata] → code-analyzer → isolation-decider → (factory-agent, optional) → spec-writer → test-reviewer
```

**Command-level responsibilities** (NO discovery-agent):
- Parse input paths (single path, array, glob pattern)
- Validate spec files exist
- Find corresponding source files (reverse mapping)
- Create metadata with `rewrite: true` flag
- No waves — files processed independently or in parallel

**Rationale**: No wave engine needed. Simple 1:1 spec→source mapping. Command handles metadata creation directly.

**Note**: rspec-refactor sets `method_mode: unchanged` for all selected methods (no git diff semantics). It still rewrites the spec deterministically via spec-writer.

---

## Flow 1: /rspec-cover Variations

All variations use the same pipeline. method_mode is determined per-method via git diff analysis.

### Variation 1: Completely new code

```
Source: new files only
method_mode: new (all methods)
Action: Create spec file, insert describe blocks for all methods
```

### Variation 2: Mixed new and existing

```
Source: new classes + new methods in existing files
method_mode: new (all methods in new classes, new methods in existing files)
Action:
  - New class → create spec file, insert all describe blocks
  - Existing class → insert describe blocks for new methods
```

### Variation 3: Changes to existing methods

```
Source: modified methods in existing files
method_mode: modified
Action: Regenerate existing describe blocks with updated structure
```

### Variation 4: Only new methods (no new classes)

```
Source: new methods added to existing files
method_mode: new
Action: Insert new describe blocks into existing spec
```

### Variation 5: Minor changes (few lines)

```
Source: small edits to existing methods
method_mode: modified
Action: Regenerate describe blocks, review edge case coverage
```

### Variation 6: Unchanged methods (user selected)

```
Source: methods not in git diff but explicitly selected by user
method_mode: unchanged
Action: Regenerate describe blocks (user wants to improve coverage)
```

**Note**: Deleted files are filtered out in discovery-agent Phase 1.2.
Deleted methods within modified files are not tracked (spec cleanup is manual).

---

## Flow 2: /rspec-refactor

### Input formats

```bash
/rspec-refactor spec/models/user_spec.rb           # single file
/rspec-refactor spec/services/billing/             # directory
/rspec-refactor "spec/**/*_spec.rb"                # glob pattern
/rspec-refactor spec/a_spec.rb spec/b_spec.rb      # multiple files
```

### Command-level metadata creation

```ruby
# Pseudocode for command
paths = parse_input(args)  # handles string, array, glob
specs = expand_paths(paths)

specs.each do |spec_path|
  source_file = find_source_file(spec_path)
  slug = path_to_slug(source_file)

  metadata = {
    spec_path: spec_path,
    source_file: source_file,
    # Refactor mode: treat selected methods as unchanged.
    methods_to_analyze: methods.map { |m| { name: m, method_mode: "unchanged", selected: true } },
    automation: { rspec_refactor_started: true },
    # No waves/dependency graph — not needed for refactor
  }

  write_metadata("#{metadata_path}/rspec_metadata/#{slug}.yml", metadata)
end

# Then call code-analyzer for each
```

### No discovery-agent because

1. **No waves needed** — specs are independent, can process in parallel
2. **No dependency graph** — refactoring doesn't add new dependencies
3. **Simple mapping** — spec path → source path is deterministic
4. **Refactor mode** — set `method_mode: unchanged` for selected methods

---

## Agent Mode Usage

How each agent uses method_mode:

| Agent | Receives | Uses | How |
|-------|----------|------|-----|
| discovery-agent | — | SETS | Determines method_mode per method |
| code-analyzer | method_mode | NO | Analyzes all selected methods equally |
| spec-writer | method_mode | YES | Chooses insert vs upsert/replace strategy |
| test-reviewer | method_mode | NO | Reviews the resulting spec file |

### spec-writer behavior by method_mode

| method_mode | Action |
|-------------|--------|
| `new` | Insert new describe block into spec |
| `modified` | Upsert/replace describe block |
| `unchanged` | Upsert/replace (user explicitly selected) |

**Edge case**: If method_mode is `new` but describe block already exists → AskUserQuestion.

### Placeholder filling

spec-writer fills placeholders (`{COMMON_SETUP}`, `{SETUP_CODE}`, `{EXPECTATION}`) in the spec file it materialized/patched.

### Spec file creation

Independent of method_mode. spec-writer always checks:
- If spec file doesn't exist → create deterministically (skeleton generator)
- Then proceed with per-method patching (for existing spec files)

---

## Open Questions Resolved

### Pipeline Without Discovery-Agent (was CRITICAL)

**Decision**: Variant B modified — command creates metadata directly.

rspec-refactor doesn't need discovery-agent overhead. Command handles:
- Path parsing (single, array, glob)
- Source file mapping
- Metadata creation with `rewrite: true` flag

### staged mode not implemented

**Decision**: Fix discovery-agent to pass discovery_mode to script.

```bash
# Before
./scripts/get-changed-files.sh --branch

# After
./scripts/get-changed-files.sh --$discovery_mode
```

### Mode terminology (was CRITICAL)

**Decision**: Replace file-level modes with per-method modes.

- Removed `file_mode` (was: new_code, legacy_code, deleted)
- Added `method_mode` per method (new, modified, unchanged)
- Spec file creation is independent of method_mode
- code-analyzer doesn't differentiate by method_mode (analyzes all selected methods equally)

---

## Related Files

- `agents/discovery-agent.md` — sets method_mode per method
- `agents/code-analyzer.md` — analyzes selected methods
- `agents/spec-writer.md` — materializes skeleton + fills placeholders
- `commands/rspec-cover.md` — uses discovery_mode
- `commands/rspec-refactor.md` — creates metadata directly for refactor mode
- `docs/metadata-schema.md` — schema definitions
- `docs/open-questions.md` — resolved questions
