# RSpec Automation System - Implementation Plan

**Version:** 1.0
**Created:** 2025-11-07
**Status:** Ready for Implementation

## Document Purpose

This implementation plan provides a complete roadmap for building an RSpec test automation system for Claude Code. All specifications are complete and ready for agent implementation.

**Target Audience:** Claude Code agents implementing this system

**Prerequisites:**
- All specifications in `claude-code/specs/` complete
- Ruby development environment
- RSpec, FactoryBot, RuboCop gems available

## System Overview

### What We're Building

An automated RSpec test generation and maintenance system consisting of:

1. **3 Orchestration Skills** (user-facing)
   - rspec-write-new: Create tests from scratch
   - rspec-update-diff: Update tests based on git changes
   - rspec-refactor-legacy: Refactor existing tests

2. **6 Specialized Agents** (automated workers)
   - rspec-analyzer: Extract characteristics from code
   - rspec-architect: Add semantic descriptions
   - rspec-implementer: Write test bodies
   - rspec-factory-optimizer: Optimize factory usage
   - rspec-polisher: Final cleanup (RuboCop, tests)
   - rspec-reviewer: Review against 28 rules (READ-ONLY)

3. **5 Ruby Scripts** (fast utilities)
   - metadata_helper.rb: Path management, caching
   - metadata_validator.rb: Schema validation
   - factory_detector.rb: Find factories/traits
   - spec_structure_extractor.rb: Parse existing tests
   - spec_skeleton_generator.rb: Generate test structure

4. **Supporting Infrastructure**
   - Metadata format (YAML)
   - Exit code contract (0/1/2)
   - Agent communication protocol
   - 3 core algorithms

### Core Principles

**🔴 MUST Follow:**
1. **Agents are Claude AI, NOT Ruby Scripts**: Agents analyze code using Claude's semantic understanding, NOT AST parsing or grep commands
2. **Sequential Execution**: Agents run one at a time, never in parallel
3. **Fail-Fast**: Clear errors, abort on critical failures
4. **Self-Sufficient**: All guide.en.md knowledge embedded in agents
5. **Cache-Aware**: Skip re-analysis if source unchanged
6. **READ-ONLY Review**: Reviewer never modifies files
7. **Test-Driven**: All scripts must be tested before use

**Design Decisions:**
- **Metadata-driven**: YAML files pass state between agents
- **Placeholder-based**: Skeleton creates structure, agents fill details
- **Git-aware**: Update workflow uses git diff
- **Conservative optimization**: Don't break working tests

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Build core infrastructure and utilities

**Tasks:**

1. **Directory Structure**

   **In rspec-guide repository (source):**
   ```bash
   rspec-guide/
   └── claude-code/          # Distribution directory
       ├── lib/              # Ruby scripts (will go to user's lib/)
       │   └── rspec_automation/
       │       ├── metadata_helper.rb
       │       ├── metadata_validator.rb
       │       ├── factory_detector.rb
       │       ├── extractors/
       │       │   └── spec_structure_extractor.rb
       │       └── generators/
       │           └── spec_skeleton_generator.rb
       ├── agents/           # Agent definitions (will go to user's .claude/agents/)
       │   ├── rspec-analyzer.md
       │   ├── rspec-architect.md
       │   ├── rspec-implementer.md
       │   ├── rspec-factory-optimizer.md
       │   ├── rspec-polisher.md
       │   └── rspec-reviewer.md
       └── skills/           # Skill definitions (will go to user's .claude/skills/)
           ├── rspec-write-new/
           │   ├── SKILL.md
           │   └── REFERENCE.md
           ├── rspec-update-diff/
           │   ├── SKILL.md
           │   └── REFERENCE.md
           └── rspec-refactor-legacy/
               ├── SKILL.md
               └── REFERENCE.md
   ```

   **In user project (after installation):**
   ```bash
   user-project/
   ├── lib/                  # Ruby scripts copied here
   │   └── rspec_automation/
   │       ├── metadata_helper.rb
   │       ├── metadata_validator.rb
   │       ├── factory_detector.rb
   │       ├── extractors/
   │       │   └── spec_structure_extractor.rb
   │       └── generators/
   │           └── spec_skeleton_generator.rb
   ├── .claude/              # Claude Code directory
   │   ├── agents/           # Agents copied here
   │   │   ├── rspec-analyzer.md
   │   │   └── ...
   │   └── skills/           # Skills copied here
   │       ├── rspec-write-new/
   │       └── ...
   ├── spec/                 # User's tests
   └── app/                  # User's code
   ```

   **Installation command:**
   ```bash
   # From user's project root:
   cp -r /path/to/rspec-guide/claude-code/lib ./lib
   cp -r /path/to/rspec-guide/claude-code/agents ./.claude/agents
   cp -r /path/to/rspec-guide/claude-code/skills ./.claude/skills
   ```

   **Important:** Agents use paths relative to project root (e.g., `ruby lib/rspec_automation/metadata_helper.rb`), NOT `.claude/lib/`

2. **Implement Ruby Scripts** (sequential order)
   - [ ] metadata_helper.rb
     - Path resolution (multi-repo support)
     - Cache validation (mtime comparison)
     - Test: All path resolution scenarios
   - [ ] metadata_validator.rb
     - Schema validation (all rules from spec)
     - Circular dependency detection
     - Test: Valid/invalid metadata examples
   - [ ] factory_detector.rb
     - Regex-based factory detection
     - Trait extraction
     - Test: Various factory definitions
   - [ ] spec_structure_extractor.rb
     - RuboCop AST parsing
     - Extract describe/context/it hierarchy
     - Test: Complex existing specs
   - [ ] spec_skeleton_generator.rb
     - Context hierarchy generation
     - Placeholder insertion
     - Context word selection
     - Test: Various characteristic combinations

**Acceptance Criteria:**
- ✅ All 5 Ruby scripts implemented
- ✅ All scripts follow exit code contract (0/1/2)
- ✅ All scripts tested (rspec or manual testing)
- ✅ Scripts handle errors gracefully (stderr messages)
- ✅ Cache validation works correctly (mtime comparison)

**Estimated Time:** 10-15 hours

### Phase 2: Core Agents (Week 3-4)

**Goal:** Implement 6 specialized agents

**Tasks:**

1. **rspec-analyzer** (most complex)
   - [ ] Semantic code analysis using Claude AI (NOT AST parsing)
   - [ ] Characteristic extraction (binary/enum/range)
   - [ ] Dependency detection
   - [ ] Level calculation
   - [ ] Cache check integration
   - [ ] Test: Various Ruby methods

2. **rspec-architect**
   - [ ] Source code semantic analysis
   - [ ] Placeholder detection and replacement
   - [ ] Context word determination
   - [ ] Behavior description generation
   - [ ] Test: Various placeholders

3. **rspec-implementer** (most complex)
   - [ ] Test body generation
   - [ ] let/subject creation
   - [ ] Expectation generation
   - [ ] Factory method selection
   - [ ] Test: Various characteristics

4. **rspec-factory-optimizer**
   - [ ] Factory call detection
   - [ ] Persistence requirement check
   - [ ] create → build_stubbed optimization
   - [ ] Test verification
   - [ ] Test: Unit vs integration tests

5. **rspec-polisher**
   - [ ] Syntax check (ruby -c)
   - [ ] RuboCop auto-correct
   - [ ] Test execution (bundle exec rspec)
   - [ ] Quality checks
   - [ ] Test: Various spec states

6. **rspec-reviewer**
   - [ ] 28 rules checking
   - [ ] Time handling validation
   - [ ] Report generation (markdown)
   - [ ] READ-ONLY verification
   - [ ] Test: Good/bad specs

**Agent Development Order:**
1. rspec-analyzer (foundation for all others)
2. rspec-implementer (generates test bodies)
3. rspec-architect (adds semantics)
4. rspec-factory-optimizer (performance)
5. rspec-polisher (cleanup)
6. rspec-reviewer (validation)

**Acceptance Criteria:**
- ✅ All 6 agents implemented as Claude Code agents
- ✅ Each agent follows input/output contract
- ✅ Sequential execution enforced (no parallelism)
- ✅ Metadata correctly updated by each agent
- ✅ All agents tested with sample code
- ✅ Reviewer is READ-ONLY (never modifies files)

**Estimated Time:** 20-30 hours

### Phase 3: Orchestration Skills (Week 5)

**Goal:** Implement 3 user-facing skills

**Tasks:**

1. **rspec-write-new** (main workflow)
   - [ ] User request parsing
   - [ ] Source file validation
   - [ ] Method name detection
   - [ ] Test file location determination
   - [ ] Sequential agent invocation (7 steps)
   - [ ] Progress reporting
   - [ ] Results presentation
   - [ ] Test: Create various tests

2. **rspec-update-diff** (git-aware)
   - [ ] Git diff detection
   - [ ] Changed file filtering
   - [ ] Test existence check
   - [ ] Metadata comparison (old vs new)
   - [ ] Selective regeneration
   - [ ] Custom code preservation
   - [ ] Test: Update after code changes

3. **rspec-refactor-legacy** (safe refactoring)
   - [ ] Baseline verification (tests pass)
   - [ ] Structure extraction
   - [ ] Comparison (existing vs ideal)
   - [ ] Refactoring plan generation
   - [ ] User approval prompt
   - [ ] Conservative vs full mode
   - [ ] Before/after review
   - [ ] Test: Refactor legacy tests

**Skill Development Order:**
1. rspec-write-new (main workflow, test all agents)
2. rspec-update-diff (builds on write-new)
3. rspec-refactor-legacy (uses structure extractor)

**Acceptance Criteria:**
- ✅ All 3 skills implemented
- ✅ Skills follow Claude Code best practices
- ✅ SKILL.md under 500 lines (progressive disclosure)
- ✅ REFERENCE.md has detailed workflows
- ✅ Error handling with user feedback
- ✅ All prerequisites checked before operations
- ✅ No automatic Gemfile modifications

**Estimated Time:** 15-20 hours

### Phase 4: Documentation (Week 6)

**Goal:** Create user-facing documentation and examples

**Tasks:**

1. **Main README.md Update**
   - [ ] Update section "🤖 RSpec Testing Skill for Claude Code" (around line 127)
   - [ ] Replace old approach (single rspec-testing skill) with new system
   - [ ] Document new architecture: 6 agents + 3 skills + reviewer
   - [ ] Update installation instructions
   - [ ] Add examples for all 3 skills (write-new, update-diff, refactor-legacy)
   - [ ] Keep existing structure and style

2. **claude-code/README.md Creation**
   - [ ] Quickstart guide (5-minute setup)
   - [ ] Installation instructions (manual copy or install.rb)
   - [ ] Architecture overview (simple diagram/explanation)
   - [ ] Usage examples for each skill
   - [ ] Prerequisites list
   - [ ] Troubleshooting basics

3. **Skill Examples**
   - [ ] rspec-write-new example
     - Sample source file (simple service class)
     - Generated test
     - Command/request format
   - [ ] rspec-update-diff example
     - Original code + test
     - Modified code (git diff)
     - Updated test
     - Command/request format
   - [ ] rspec-refactor-legacy example
     - Legacy test (poor structure)
     - Refactored test (follows guide)
     - Before/after comparison
     - Command/request format

4. **Troubleshooting Guide**
   - [ ] Common errors and solutions
   - [ ] Debug strategies (check metadata, run agents manually)
   - [ ] FAQ section
   - [ ] When to file issues

**Acceptance Criteria:**
- ✅ Main README.md section updated
- ✅ claude-code/README.md complete and clear
- ✅ All 3 skills have working examples
- ✅ Troubleshooting guide covers common issues
- ✅ Documentation accurate and helpful

**Estimated Time:** 8-12 hours

### Phase 5: Integration & Testing (Week 7)

**Goal:** End-to-end testing and refinement

**Tasks:**

1. **End-to-End Testing**
   - [ ] Test complete write-new workflow
   - [ ] Test update-diff with git changes
   - [ ] Test refactor-legacy on real code
   - [ ] Test error scenarios (missing files, syntax errors)
   - [ ] Test cache behavior
   - [ ] Test multi-repo scenarios

2. **Ruby Script Testing**
   - [ ] Use devbox for environment setup (devbox.json)
   - [ ] Test scripts individually (manual or RSpec as preferred)
   - [ ] Verify exit codes (0/1/2) correct
   - [ ] Check error messages clarity
   - [ ] Test edge cases

3. **Bug Fixes and Refinements**
   - [ ] Fix issues found in testing
   - [ ] Improve error messages
   - [ ] Add missing edge cases
   - [ ] Update documentation if needed

**Acceptance Criteria:**
- ✅ All workflows tested end-to-end
- ✅ Ruby scripts work correctly (tested with devbox)
- ✅ Error handling verified
- ✅ No critical bugs remaining
- ✅ Documentation matches reality

**Estimated Time:** 8-12 hours

## Total Estimated Time

**55-85 hours** (1.5-2 months at 10-15 hours/week)

**Phase breakdown:**
- Phase 1 (Ruby Scripts): 10-15 hours
- Phase 2 (Agents): 20-30 hours
- Phase 3 (Skills): 15-20 hours
- Phase 4 (Documentation): 8-12 hours
- Phase 5 (Testing): 8-12 hours

## Success Metrics

### Primary Metrics

1. **Documentation Quality**: Clear README, working examples, helpful troubleshooting
2. **Test Generation Quality**: 0 violations of MUST rules (from reviewer)
3. **User Satisfaction**: Can generate tests without manual intervention
4. **Cache Effectiveness**: Skip re-analysis when source unchanged

### Secondary Metrics

1. **Factory Optimization**: Unit tests faster with build_stubbed
2. **Coverage**: All characteristics covered in tests
3. **Maintainability**: Tests follow all 28 rules
4. **Code Quality**: Scripts handle errors gracefully

## Risk Mitigation

### Risk 1: Characteristic Extraction Too Complex

**Impact:** High - foundation for entire system
**Mitigation:** Start with simple cases (if/else), expand gradually
**Fallback:** Manual characteristic specification if auto-detection fails

### Risk 2: LLM Context Limits

**Impact:** Medium - large source files may exceed limits
**Mitigation:** Process methods one at a time, use caching
**Fallback:** Ask user to split large files

### Risk 3: Test Generation Quality

**Impact:** High - poor tests worse than no tests
**Mitigation:** Reviewer provides feedback, iterative improvement
**Fallback:** Manual review and refinement

### Risk 4: Breaking Existing Tests

**Impact:** High - refactoring must be safe
**Mitigation:** Baseline verification, automatic rollback on failure
**Fallback:** Manual review before committing

### Risk 5: Documentation Becomes Stale

**Impact:** Medium - outdated docs confuse users
**Mitigation:** Update docs alongside code changes
**Fallback:** User feedback for corrections

## Testing Strategy

### Unit Testing (Ruby Scripts)

**Environment Setup:**
- Use devbox for consistent environment (devbox.json in repo)
- Install dependencies: `devbox add ruby` or similar
- Run scripts: `devbox run ruby script.rb` if needed

**Approach:** Test however works best - RSpec, manual, or script-based

**Example RSpec test structure (optional):**
```ruby
# spec/lib/rspec_automation/metadata_helper_spec.rb
RSpec.describe RSpecAutomation::MetadataHelper do
  describe '.metadata_path_for' do
    it 'generates correct path for source file' do
      path = described_class.metadata_path_for('app/models/user.rb')
      expect(path).to match(%r{tmp/rspec_claude_metadata/metadata_.*\.yml$})
    end
  end

  describe '.metadata_valid?' do
    it 'returns true when metadata fresh' do
      # Test cache validation
    end
  end
end
```

**Example manual testing:**
```bash
# Test metadata_helper.rb
devbox run ruby lib/rspec_automation/metadata_helper.rb
echo $?  # Should be 0

# Test with invalid input
devbox run ruby script.rb invalid_input
echo $?  # Should be 1
```

**What to verify:**
- Exit codes correct (0/1/2)
- Error messages clear (stderr)
- Results valid (stdout)
- Edge cases handled

### Integration Testing (Agents)

**Approach:** Test each agent with sample input/output

```bash
# Example test scenario
source_file="test/fixtures/sample_service.rb"
metadata_path="test/fixtures/metadata_sample.yml"

# Invoke agent
agent_output=$(invoke_agent "rspec-analyzer" \
  --source-file "$source_file" \
  --method "process")

# Verify output
assert_metadata_valid "$metadata_path"
assert_characteristics_extracted 2
```

**Coverage:** All agent specifications with 3+ examples each

### End-to-End Testing (Skills)

**Approach:** Complete workflows with real code

```bash
# Test rspec-write-new
source_file="app/services/payment_service.rb"

# Invoke skill
invoke_skill "rspec-write-new" "$source_file"

# Verify results
assert_file_exists "spec/services/payment_service_spec.rb"
assert_tests_pass "spec/services/payment_service_spec.rb"
assert_review_passes "spec/services/payment_service_spec.rb"
```

**Coverage:** All 3 skills with realistic scenarios

### Manual Testing Checklist

**Core Workflows:**
- [ ] Generate test for simple service class (write-new)
- [ ] Generate test for complex model with validations (write-new)
- [ ] Update test after adding new method parameter (update-diff)
- [ ] Refactor legacy test with poor structure (refactor-legacy)

**Error Handling:**
- [ ] Missing source file
- [ ] Invalid Ruby syntax in source
- [ ] Test file already exists
- [ ] No characteristics found

**Features:**
- [ ] Cache works (same file analyzed twice skips re-analysis)
- [ ] Reviewer finds violations correctly
- [ ] All 3 skills work end-to-end

**Documentation:**
- [ ] README examples work as written
- [ ] Troubleshooting guide helpful
- [ ] Installation instructions clear

## Dependencies

### Required Gems

```ruby
# Gemfile additions
group :development do
  gem 'parser'           # AST parsing (only for spec_structure_extractor.rb)
  gem 'rubocop'          # Style checking
  gem 'rubocop-rspec'    # RSpec cops
  gem 'rspec'            # Testing framework
  gem 'factory_bot'      # Test factories
end
```

**Note:** The `parser` gem is ONLY used by `spec_structure_extractor.rb` (a Ruby script that parses existing test files). Claude AI agents do NOT use AST parsing - they analyze code semantically using native understanding.

### System Requirements

- Ruby 2.7+
- Git (for update-diff workflow)
- RSpec project structure (spec/, app/)
- FactoryBot (optional, for factory optimization)

### Claude Code Version

- Claude Code 0.5+
- Agent support enabled
- Skill support enabled

## Implementation Guidelines

### For Implementers

**Start Here:**
1. Read `claude-code/specs/OVERVIEW.md`
2. Review contracts (exit-codes, metadata-format, agent-communication)
3. Implement Phase 1 (Ruby scripts) sequentially
4. Test each script before moving to next
5. Proceed to Phase 2 (agents) only after Phase 1 complete

**Development Process:**
1. Read specification thoroughly
2. Implement following spec exactly
3. Write tests (RSpec or manual)
4. Verify error handling
5. Update metadata as specified
6. Move to next component

**Key Reminders:**
- **Agents are Claude AI subagents** - they use Read tool and semantic understanding, NOT Ruby AST parsing scripts
- **NEVER implement agents as Ruby scripts** - see agent specifications for ⚠️ warning headers
- **NEVER run agents in parallel** - sequential only
- **Always check prerequisites** - before every operation
- **Follow exit code contract** - 0/1/2 consistently (Ruby scripts only, not agents)
- **Test everything** - scripts, agents, skills
- **Fail fast** - clear errors better than silent failures

### Code Style

**Ruby Scripts:**
- Follow Ruby style guide
- Use RuboCop for consistency
- Clear error messages to stderr
- Exit codes: 0 (success), 1 (error), 2 (warning)

**Agent Prompts:**
- Clear, specific instructions
- Examples for all major cases
- Decision trees for choices
- Fail-fast error handling

**Skills:**
- SKILL.md under 500 lines
- REFERENCE.md for details
- Prerequisites checked first
- No tool assumptions

## Maintenance Plan

### Regular Updates

**Monthly:**
- Review generated tests quality
- Collect user feedback
- Fix reported bugs
- Update examples

**Quarterly:**
- Review guide.en.md for rule changes
- Update agents to match new rules
- Performance optimization
- New features based on feedback

### Version Management

**Semantic Versioning:**
- Major: Breaking changes to metadata format or agent contracts
- Minor: New features (new agents, skills)
- Patch: Bug fixes, performance improvements

**Version Tracking:**
```yaml
# In metadata.yml
automation:
  analyzer_version: '1.0'
  architect_version: '1.0'
  # ... other agent versions
```

## Getting Help

### Specification References

**All specifications in:**
- `claude-code/specs/OVERVIEW.md` - Start here
- `claude-code/specs/contracts/` - Core contracts
- `claude-code/specs/ruby-scripts/` - Script specifications
- `claude-code/specs/agents/` - Agent specifications
- `claude-code/specs/skills/` - Skill specifications
- `claude-code/specs/algorithms/` - Core algorithms

**Decision Trees:**
- Characteristic extraction: `algorithms/characteristic-extraction.md`
- Context hierarchy: `algorithms/context-hierarchy.md`
- Factory optimization: `algorithms/factory-optimization.md`

### Common Questions

**Q: How do I know what metadata format to use?**
A: See `contracts/metadata-format.spec.md` for complete schema

**Q: What exit code should my script return?**
A: See `contracts/exit-codes.spec.md` - use 0/1/2

**Q: How do agents communicate?**
A: See `contracts/agent-communication.spec.md` for protocol

**Q: Should I run agents in parallel?**
A: **NO!** Always sequential. See agent-communication spec.

**Q: Where should metadata files go?**
A: Use `metadata_helper.rb` - handles multi-repo correctly

**Q: Can I modify files from reviewer?**
A: **NO!** Reviewer is READ-ONLY. See rspec-reviewer spec.

## Next Steps

1. **Review all specifications** in `claude-code/specs/`
2. **Set up development environment** (Ruby, gems)
3. **Start Phase 1** (Ruby scripts) - implement sequentially
4. **Test each component** before moving to next
5. **Follow this plan** - phases designed to build on each other

**Ready to start? Begin with Phase 1, Task 1: metadata_helper.rb**

---

**This plan is complete and ready for implementation. All specifications are in place. Follow phases sequentially for best results.**
