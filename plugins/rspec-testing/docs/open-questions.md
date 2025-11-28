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

### Scope: Single Method vs All Methods

**Status**: CRITICAL — requires decision

**Problem**: Agents currently process only 1 method per invocation.

**Real world**: Files have median 3-5 methods.

**Proposed solution**:

| Methods | Action |
|---------|--------|
| 1-5 | Cover all automatically |
| 6-10 | Ask user |
| >10 | Suggest refactoring |

**Impact**: Without this fix, agents skip methods.

---

## Resolved (for reference)

| Question | Decision | See |
|----------|----------|-----|
| Trait vs Attribute | 4 heuristics | decision-trees.md |
| Agent sequence | discovery → analyzer → architect → factory → impl | agent-communication.md |
| STOP conditions | In discovery-agent (fail-fast) | decision-trees.md |
| Large specs | ~300 lines max | PLUGINS-GUIDE.md Rule 9 |
