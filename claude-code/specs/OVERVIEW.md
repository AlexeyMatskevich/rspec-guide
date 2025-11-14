# RSpec Automation System: Architecture Overview

**Version:** 1.0
**Created:** 2025-11-07
**Language:** English only

## Purpose

This system automates RSpec test creation following BDD principles and the comprehensive style guide from `guide.en.md` (28 rules).

## Philosophy

### Core Principles

1. **Behavior Over Implementation**: Tests describe observable behavior, not internal mechanics
2. **Characteristic-Based Hierarchy**: Context structure follows dependent characteristics (happy path first)
3. **Cognitive Load Management**: Minimize extraneous load, maximize germane load
4. **Tests as Code Quality Indicators**: Test complexity reveals design problems
5. **Fail Fast**: Explicit errors better than silent failures
6. **Self-Sufficient Components**: All components embed necessary knowledge

### What This System Does

- ✅ Analyzes source code to extract characteristics
- ✅ Generates characteristic-based test structure automatically
- ✅ Guides implementation with proper behavior testing
- ✅ Optimizes FactoryBot usage (build_stubbed vs create)
- ✅ Enforces all 28 rules from guide.en.md
- ✅ Reviews tests for compliance (READ-ONLY)

### What This System Does NOT Do

- ❌ Does NOT work on Windows
- ❌ Does NOT modify source code under test
- ❌ Does NOT generate tests without analyzing source
- ❌ Does NOT try to recover from corrupted metadata
- ❌ Does NOT run tests in parallel
- ❌ Does NOT create tests violating guide.en.md rules

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Invokes Skill                        │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────┐
        │        Orchestration Skills          │
        │  - rspec-write-new                   │
        │  - rspec-update-diff                 │
        │  - rspec-refactor-legacy             │
        └──────────────┬───────────────────────┘
                       │
                       │ Sequential invocation (NEVER parallel)
                       │
        ┏━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
        ▼                                                   ▼
┌───────────────────┐                           ┌──────────────────┐
│  Specialized      │                           │   Ruby Scripts   │
│  Subagents        │◄──────────────────────────│   (Fast Tasks)   │
│                   │   Use for automation      │                  │
│ 1. analyzer       │                           │ • metadata_helper│
│ 2. architect      │                           │ • factory_detect │
│ 3. factory        │                           │ • skeleton_gen   │
│ 4. implementer    │                           │ • struct_extract │
│ 5. polisher       │                           │ • validator      │
│ 6. reviewer       │                           │                  │
└─────────┬─────────┘                           └──────────────────┘
          │
          │ Sequential pipeline
          │
          ▼
    ┌─────────────────────────────────────────────┐
    │         Metadata Exchange Format            │
    │  (YAML files in tmp/rspec_claude_metadata/) │
    │                                             │
    │  • Characteristics extracted from code      │
    │  • Test structure specifications            │
    │  • Factory information                      │
    │  • Progress markers (completed flags)       │
    └─────────────────────────────────────────────┘
```

## Component Categories

### 1. Orchestration Skills (3 skills)

High-level workflows that coordinate subagents:

- **rspec-write-new**: Write tests from scratch
- **rspec-update-diff**: Update tests based on code changes
- **rspec-refactor-legacy**: Refactor existing tests to follow guide

**Location:** `skills/*.spec.md`

**Key Properties:**
- Self-sufficient (embed all necessary knowledge)
- SKILL.md < 500 lines (progressive disclosure)
- Sequential agent orchestration ONLY
- Examples over explanations

### 2. Specialized Subagents (6 agents)

Each handles one specific phase:

- **rspec-analyzer**: Extract characteristics from source code
- **rspec-architect**: Design test structure, apply language rules
- **rspec-factory**: Create/update FactoryBot factories for ActiveRecord models
- **rspec-implementer**: Implement test body (let, subject, expectations)
- **rspec-polisher**: Final quality checks, run tests
- **rspec-reviewer**: Review against 28 rules (READ-ONLY, generates report)

**Location:** `agents/*.spec.md`

**Key Properties:**
- Self-sufficient (embed philosophy and relevant guide rules)
- Sequential execution (step-by-step)
- Fail-fast error handling
- Clear input/output contracts

### 3. Ruby Scripts (5 scripts)

Fast, deterministic tasks:

- **metadata_helper.rb**: Path management for metadata files
- **factory_detector.rb**: Scan factories, extract traits
- **spec_skeleton_generator.rb**: Generate context structure from metadata
- **spec_structure_extractor.rb**: Parse existing RSpec files
- **metadata_validator.rb**: Validate metadata format

**Location:** `ruby-scripts/*.spec.md`

**Key Properties:**
- Exit code contract (0=success, 1=error, 2=warning)
- stdout = data only, stderr = messages only
- Testable standalone
- No silent failures

### 4. Contracts & Formats (3 contracts)

Define communication protocols:

- **metadata-format.spec.md**: YAML schema for metadata files
- **exit-codes.spec.md**: Ruby script exit code contract
- **agent-communication.spec.md**: How agents pass data between phases

**Location:** `contracts/*.spec.md`

### 5. Algorithms (3 algorithms)

Detailed step-by-step processes:

- **characteristic-extraction.md**: How to analyze code and extract characteristics
- **context-hierarchy.md**: How to build characteristic-based context trees
- **factory-optimization.md**: Decision trees for build vs build_stubbed vs create

**Location:** `algorithms/*.spec.md`

## Data Flow

### Primary Pipeline (rspec-write-new)

```
Source Code (app/services/payment_service.rb)
    │
    ▼
[1. rspec-analyzer]
    │ Analyzes code
    │ Uses: factory_detector.rb (optional)
    │ Checks: cache valid? (metadata_helper.rb)
    │ Outputs: metadata.yml with characteristics
    │
    ▼
metadata.yml (characteristics, dependencies, types)
    │
    ▼
[Ruby: spec_skeleton_generator.rb]
    │ Generates: context structure with {CONTEXT_WORD} placeholders
    │
    ▼
spec_skeleton.rb (structure only, no let/it/expect)
    │
    ▼
[2. rspec-architect]
    │ Analyzes: source code + skeleton
    │ Replaces: {CONTEXT_WORD} → with/but/and/without
    │ Adds: it block descriptions (no expectations)
    │ Applies: Rules 17-20 (language rules)
    │ Sorts: happy path first
    │
    ▼
spec_with_structure.rb (contexts + it descriptions, no bodies)
    │
    ▼
[3. rspec-factory]
    │ Analyzes: characteristics with setup.type = factory
    │ Creates: FactoryBot factories for ActiveRecord models
    │ Adds: factory calls to spec (for factory-type setup)
    │
    ▼
spec_with_factories.rb (factories setup done)
    │
    ▼
[4. rspec-implementer]
    │ Analyzes: source code (method signature, dependencies)
    │ Adds: let/let!/before blocks (for data/action setup)
    │ Adds: subject
    │ Adds: expectations (behavior, not implementation)
    │
    ▼
spec_with_body.rb (complete test)
    │
    ▼
[5. rspec-polisher]
    │ Runs: RuboCop checks
    │ Runs: tests
    │ Fixes: minor issues
    │
    ▼
spec_final.rb
    │
    ▼
[6. rspec-reviewer] (automatic, READ-ONLY)
    │ Checks: all 28 rules
    │ Checks: time handling edge cases
    │ Generates: review report
    │
    ▼
review_report.md + final spec file
```

## Key Design Decisions

### 1. Why Ruby Scripts + LLM Agents?

**Ruby scripts** for:
- ✅ Fast, deterministic tasks (path resolution, file parsing)
- ✅ Reducing token usage (70% savings)
- ✅ Consistent formatting (no LLM variability)

**LLM agents** for:
- ✅ Semantic analysis (understanding business logic)
- ✅ Decision making (happy path vs corner cases)
- ✅ Creative naming (test descriptions)
- ✅ Code generation (expectations)

### 2. Why Sequential Execution?

- Each phase depends on previous phase's output
- Parallel execution would require complex state management
- Sequential = easier debugging, clearer error messages
- Follows fail-fast principle (stop at first error)

### 3. Why Metadata-Based Communication?

- Persistent state between agents (survives crashes)
- Human-readable (YAML)
- Cacheable (skip re-analysis if source unchanged)
- Versioned (metadata schema can evolve)
- Inspectable (debug issues)

### 4. Why Self-Sufficient Components?

Following Claude Code best practices:
- No external file references (guide.en.md rules embedded in agents)
- Each component works standalone
- Compressed, adapted knowledge
- Examples over explanations
- Philosophy first (why this exists)

### 5. Why READ-ONLY Reviewer?

- Separation of concerns (generation vs review)
- Educational value (explains WHY rules matter)
- Non-invasive (doesn't break working tests)
- Can run independently (audit existing tests)
- Automatic (runs after every skill)

## Critical Constraints

### MUST Follow (🔴 Non-Negotiable)

1. **English Only**: All documentation, code comments, user-facing messages
2. **Sequential Execution**: NEVER invoke multiple agents in parallel
3. **Fail Fast**: Exit with clear error message, don't try to recover
4. **Exit Code Contract**: Ruby scripts MUST use 0/1/2 correctly
5. **No Windows Support**: System not tested or supported on Windows
6. **Self-Sufficient**: NO references to files outside claude-code/ directory
7. **MUST/SHOULD/MAY Indicators**: Use 🔴🟡🟢 throughout specifications
8. **Test Scripts Before Commit**: All Ruby scripts MUST be tested manually

### SHOULD Follow (🟡 Recommended)

1. **Cache When Possible**: Check metadata validity before re-analyzing
2. **Progressive Disclosure**: SKILL.md < 500 lines, details in REFERENCE.md
3. **Examples Over Explanations**: Show don't tell
4. **Concrete Examples**: Minimum 3 per contract (simple, complex, edge)

### MAY Follow (🟢 Optional)

1. **Optimize Token Usage**: Use Ruby scripts where possible
2. **Batch Operations**: Process multiple files in one session
3. **Informative Progress**: Show user what's happening at each step

## Error Handling Philosophy

### Fail Fast Principle

When things go wrong, **stop immediately** with clear message:

```
❌ BAD: Try to guess what user meant
❌ BAD: Use default values silently
❌ BAD: Continue with partial data

✅ GOOD: "Error: Source file not found: app/services/missing.rb"
✅ GOOD: "Error: metadata.yml corrupted, cannot parse YAML"
✅ GOOD: Exit 1, show error in stderr
```

### When to Abort

**MUST abort (exit 1):**
- Source file not found
- Source file doesn't contain specified method
- metadata.yml corrupted/invalid
- Ruby script not found
- Required dependency missing (e.g., FactoryBot gem)

**MAY continue with warning (exit 2):**
- Factory traits not found (use attributes instead)
- Existing test structure differs from generated (in refactor mode)
- RuboCop violations (polisher can auto-fix some)

**NEVER abort:**
- (empty - when in doubt, abort)

## Installation & Usage

### For End Users

```bash
cd your-rails-project

# Install (copies agents, skills, Ruby scripts to .claude/)
ruby /path/to/rspec-guide/claude-code/install.rb

# Use with Claude Code
claude-code
> "Write tests for app/services/payment_service.rb"
```

### For Developers (Implementing This System)

See `IMPLEMENTATION_PLAN.md` for:
- Phase-by-phase implementation order
- Acceptance criteria for each phase
- Testing requirements
- Timeline estimates

## Documentation Structure

```
claude-code/
├── specs/
│   ├── OVERVIEW.md              # This file (architecture, philosophy)
│   ├── agents/                  # 6 subagent specifications
│   ├── skills/                  # 3 skill specifications
│   ├── ruby-scripts/            # 5 Ruby script specifications
│   ├── contracts/               # 3 communication contracts
│   └── algorithms/              # 3 detailed algorithms
│
├── agents/                      # Actual agent implementations (created during Phase 1-4)
├── skills/                      # Actual skill implementations (created during Phase 2-4)
├── lib/                         # Actual Ruby scripts (created during Phase 0)
│
├── IMPLEMENTATION_PLAN.md       # How to build this system
├── install.rb                   # Installation script for users
└── README.md                    # User-facing quick start
```

## Success Metrics

### Quality Metrics

- ✅ Generated tests pass on first run (>90%)
- ✅ Generated tests follow all 28 guide rules (100%)
- ✅ Test generation time: 30-60 seconds (vs 3-5 minutes manual)
- ✅ Token usage: -70% vs pure LLM approach
- ✅ User edits required: <10%

### Implementation Metrics

- ✅ All Ruby scripts tested standalone
- ✅ Exit codes contract followed (0/1/2)
- ✅ All agents self-sufficient (no external references)
- ✅ All skills < 500 lines in SKILL.md
- ✅ All specifications have 3+ concrete examples

## References

### Source Material (NOT Included in claude-code/)

These files exist in `rspec-guide` repository but are NOT copied to user projects:

- `guide.en.md` - 28 rules RSpec style guide (knowledge embedded in agents)
- `algoritm/test.en.md` - 16-step test writing algorithm (embedded in agents)
- `algoritm/factory.en.md` - 9-step factory optimization algorithm (embedded in factory agent)
- `checklist.en.md` - Quick reference (embedded in reviewer)
- `patterns.en.md` - Useful patterns (embedded in relevant agents)

### Official Claude Code Documentation

**MUST read before implementing each component:**

- **Skills**: https://code.claude.com/docs/en/skills.md
- **Best Practices**: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices
- **Subagents**: https://code.claude.com/docs/en/sub-agents.md

## Next Steps

1. **Read**: This OVERVIEW.md for system understanding
2. **Read**: `contracts/*.spec.md` for communication protocols
3. **Implement**: Following `IMPLEMENTATION_PLAN.md` phase by phase
4. **Test**: Each component before moving to next phase
5. **Integrate**: Verify contracts work between components

---

## Frequently Asked Questions (FAQ)

### Q: Should I write a Ruby AST parser for rspec-analyzer?

**NO.**

rspec-analyzer is a **Claude AI subagent**, not a Ruby script.

As Claude, you understand Ruby code natively. Just:
1. Read the source file using Read tool
2. Analyze the conditionals mentally
3. Apply the logic from `algorithms/characteristic-extraction.md`

You do NOT need to create Ruby scripts with `parser` gem or AST libraries.

### Q: When should I use bash/grep in agents?

**ONLY for:**
- ✅ File existence checks: `[ -f "$file" ]`, `[ -d "$directory" ]`
- ✅ Running Ruby helper scripts: `ruby lib/rspec_automation/factory_detector.rb`
- ✅ Simple metadata validation: `grep "completed: true" metadata.yml`

**NEVER for:**
- ❌ Analyzing source code logic
- ❌ Extracting characteristics from conditionals
- ❌ Understanding what code does
- ❌ Parsing Ruby syntax

### Q: What are "Ruby scripts" vs "agents"?

**Ruby scripts** (in `lib/rspec_automation/`):
- metadata_helper.rb - Path resolution, caching
- factory_detector.rb - Scan factories directory
- spec_skeleton_generator.rb - Generate RSpec structure from YAML
- spec_structure_extractor.rb - Parse existing RSpec files
- metadata_validator.rb - Validate YAML schema

These are **mechanical tools** - they transform data, validate formats, scan files.

**Agents** (Claude AI subagents in `.claude/agents/`):
- **rspec-analyzer** ← This is NOT a Ruby script!
- rspec-architect
- rspec-factory
- rspec-implementer
- rspec-polisher
- rspec-reviewer

These are **Claude agents** - they understand code semantics, make decisions, generate content.

### Q: Why does characteristic-extraction.md have Ruby code?

The Ruby code shows the **LOGIC** Claude should apply.

It's **NOT** meant to be executed as a script.

Think of it as: **"Here's how to think about Ruby code when extracting characteristics."**

The Ruby syntax is used for clarity (since we're analyzing Ruby), but you apply the logic directly without running code.

**Analogy:** It's like a math textbook showing formulas. You don't "execute" the formulas - you understand the logic and apply it.

### Q: How do agents and Ruby scripts work together?

**Example workflow (rspec-analyzer):**

1. **Agent (Claude)** checks cache validity:
   ```bash
   # Agent uses Bash tool to run Ruby helper
   ruby -r lib/rspec_automation/metadata_helper -e "..."
   ```

2. **Agent (Claude)** reads and analyzes source code:
   ```
   # Agent uses Read tool
   # Agent understands Ruby code natively
   # Agent extracts characteristics mentally
   ```

3. **Agent (Claude)** runs factory detector:
   ```bash
   # Agent uses Bash tool to run Ruby script
   factory_data=$(ruby lib/.../factory_detector.rb)
   ```

4. **Agent (Claude)** generates metadata YAML

5. **Agent (Claude)** validates result:
   ```bash
   # Agent uses Bash tool to run Ruby validator
   ruby lib/.../metadata_validator.rb metadata.yml
   ```

**Boundary:**
- **Ruby scripts**: Mechanical operations (file scanning, YAML validation, structure generation)
- **Claude agents**: Understanding code, extracting semantics, making decisions

### Q: What if I see TODO comments about "AST parsing" or "production version"?

These are **outdated placeholders** from initial planning.

**Ignore them.**

The current architecture is:
- Claude agents analyze code directly (no AST parser scripts needed)
- Ruby scripts handle mechanical tasks only
- Specifications have been updated to reflect this

If you see conflicting information, follow **this FAQ** and the **⚠️ IMPORTANT** sections in spec files.

---

**Note**: This system prioritizes correctness over speed, clarity over cleverness, explicit behavior over implicit magic.
