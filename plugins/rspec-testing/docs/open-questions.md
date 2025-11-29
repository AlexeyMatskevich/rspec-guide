# Open Questions

Items deferred or unresolved for MVP.

---

## Deferred

### State Machine Automation

**Status**: DEFERRED to post-MVP

**Problem**: State machines (AASM, state_machines gems) have complex transition logic with guards and callbacks.

**Current approach**: Detect state machine presence, extract states, but manual test writing required.

**Future**: May add specialized state machine agent.

---

### Request Spec Patterns

**Status**: UNRESOLVED

**Problem**: No naming conventions for request specs (HTTP method + path).

**Expected pattern**: `describe 'POST /api/v1/campaigns'`

**Current**: Focus on model/service tests. Request specs need documentation.

---

### Describe vs Context Rules

**Status**: UNRESOLVED

**Problem**: When to use nested `describe` vs `context`.

**Pattern observed**:
- `describe '#method_name'` — different methods
- `context 'when ...'` — scenarios within method

**Need**: Explicit documentation in guide.

---

## Critical

### Pipeline Without Discovery-Agent

**Status**: CRITICAL — requires decision

**Problem**: `rspec-refactor` goes directly to `code-analyzer` without `discovery-agent`, but `code-analyzer` expects metadata fields that discovery provides (mode, complexity, dependencies).

**Context**:
- `/rspec-cover` → uses discovery-agent (needs waves, dependencies, mode)
- `/rspec-refactor` → skips discovery, goes to code-analyzer directly
- But code-analyzer spec expects: mode, complexity.zone, dependencies

**Proposed solutions**:

| Variant | Description | Pros | Cons |
|---------|-------------|------|------|
| A. Lazy discovery | code-analyzer runs mini-discovery if metadata missing | Transparent to caller | Logic duplication |
| B. Standalone mode | code-analyzer extracts mode/complexity itself | Agent independence | Different paths = different behavior |
| C. Strict pipeline | All commands always start with discovery | Single pipeline | Overhead for simple cases |

**Impact**: Without decision, `rspec-refactor` may fail or behave inconsistently.

---

### Test Level Determination

**Status**: CRITICAL — requires decision

**Problem**: How to determine `build_stubbed` vs `create` for factory calls without `test_level`.

**Context**:
- Old approach: test_level (unit/integration/request) set in code-analyzer
- New approach: Wave-based pipeline where wave engine controls execution
- test_level field removed from code-analyzer output

**Proposed solutions**:

| Variant | Description | Pros | Cons |
|---------|-------------|------|------|
| A. Wave determines | Wave 0 = build_stubbed, Wave 1+ = create | Consistent with dependency order | May not match actual needs |
| B. Heuristic | Analyze dependencies → no external deps = stubbed | Accurate per-file | More analysis needed |
| C. Always stubbed | Start with build_stubbed, upgrade if tests fail | Simple, iterative | May need re-runs |
| D. User choice | AskUserQuestion per file or globally | Explicit control | Interrupts flow |

**Impact**: Without decision, factory-agent cannot generate correct factory calls.

---

### Factory Scan Timing

**Status**: UNRESOLVED

**Problem**: When and where to scan existing factories for traits.

**Context**:
- Option A: `rspec-init` scans once, stores in config
- Option B: `code-analyzer` scans per-file dependencies
- Option C: `factory-agent` scans on-demand

**Trade-offs**:
- Early scan (rspec-init): Cached, but may be stale
- Per-file (code-analyzer): Fresh, but repeated work
- On-demand (factory-agent): Just-in-time, but late for planning

**Current**: rspec-init detects factory gem and path, but doesn't enumerate traits.

**Need**: Decision on trait enumeration timing and caching strategy

---

## Resolved (for reference)

| Question | Decision | See |
|----------|----------|-----|
| Trait vs Attribute | 4 heuristics | decision-trees.md |
| Agent sequence | discovery → analyzer → architect → factory → impl | agent-communication.md |
| STOP conditions | In discovery-agent (fail-fast) | decision-trees.md |
| Large specs | ~300 lines max | PLUGINS-GUIDE.md Rule 9 |
| Single vs All Methods | ALL methods; 6+ uses AskUserQuestion | code-analyzer.md Phase 3 |
