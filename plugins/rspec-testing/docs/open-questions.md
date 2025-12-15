# Open Questions

Items deferred or unresolved for MVP.

---

## Deferred

### Mock vs Integration Testing

**Status**: DEFERRED to spec-writer/factory-agent design phase

**Problem**: When should spec-writer use stubs vs real objects for external domains?

**Context**:
- code-analyzer identifies external domain calls with `domain_class`, `domain_method`
- spec-writer must decide: stub or integrate?
- `stub_returns` was removed from code-analyzer (Responsibility Boundary violation)

**Factors to consider**:
- Speed (stubs faster)
- Reliability (stubs more predictable)
- Realism (integration catches more bugs)
- Database setup complexity

**Current approach**: spec-writer will derive stub implementation from `domain_class` + `domain_method` via Serena inspection when needed.

**Future**: May need explicit `test_level` or similar heuristic to guide stubbing decisions.

---

### State Machine Automation

**Status**: DEFERRED to post-MVP

**Problem**: State machines (AASM, state_machines gems) have complex transition logic with guards and callbacks.

**Current approach**: Detect state machine presence, extract states, but manual test writing required.

**Future**: May add specialized state machine agent.

---

### Scenario 3 Custom Instructions (spec-writer)

**Status**: DEFERRED to post-MVP

**Problem**: When spec-writer upserts an existing method describe block (method_mode: modified/unchanged), manually written tests are lost.

**Current approach**: Default is to regenerate (overwrite). User can recover from git.

**Future**: Add config field in `.claude/rspec-testing-config.yml` via rspec-init for custom instructions:

```yaml
spec_writer:
  regenerate_strategy: overwrite | merge | ask
  custom_instructions: "Preserve manually added integration tests"
```

**Open questions**:
- How to detect "manual" vs "generated" tests?
- What merge strategy to use?
- Should this be per-project or per-file?

---

## Critical

### Test Level Determination

**Status**: RESOLVED (handled by isolation-decider)

**Decision**:
- Add dedicated `isolation-decider` agent that writes `methods[].test_config` (test_level + isolation, confidence, decision_trace).
- Downstream agents (spec-writer/factory-agent) read `test_config` instead of deriving levels themselves.
- User is asked only when confidence is low.

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
| Pipeline Without Discovery-Agent | rspec-refactor creates metadata at command level, no discovery | flow-architecture.md |
| Mode terminology | discovery_mode (branch/staged/single), method_mode (new/modified/unchanged) | flow-architecture.md |
| Trait vs Attribute | 4 heuristics | decision-trees.md |
| Agent sequence | discovery → analyzer → isolation → (factory, optional) → spec-writer → review | agent-communication.md |
| STOP conditions | In discovery-agent (fail-fast) | decision-trees.md |
| Large specs | ~300 lines max | PLUGINS-GUIDE.md Rule 9 |
| Single vs All Methods | ALL methods; 6+ uses AskUserQuestion | code-analyzer.md Phase 3 |
| Describe vs Context | describe=subject (`#`/`.method`), context=conditions | spec_structure_generator.rb:314 |
| Request Spec Patterns | `describe 'HTTP_METHOD /path'` | post-MVP (focus on model/service) |
