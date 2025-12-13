# RSpec Testing Plugin

Automated RSpec test writing with BDD principles, parallel processing, and Serena MCP integration.

## Installation

```bash
# From Claude Code, add the plugin:
/plugin marketplace add ./plugins/rspec-testing
/plugin install rspec-testing@local
```

## Requirements

- **RSpec** configured in the project
- **Serena MCP server** active (required for semantic code analysis)
- **FactoryBot** (optional, for model tests)

## Commands

| Command | Description |
|---------|-------------|
| `/rspec-cover <target>` | Cover code with tests (single file, branch, or staged) |
| `/rspec-refactor <spec>` | Refactor legacy tests to follow BDD style guide |

### /rspec-cover

Cover code changes with RSpec tests. Automatically detects new vs modified code.

```bash
/rspec-cover app/services/payment_processor.rb  # single file
/rspec-cover --branch                            # all changes on branch
/rspec-cover --staged                            # staged files only
```

**Workflow:**
1. Discover changed files
2. Analyze code (parallel) — extract characteristics
3. Design test structure (parallel) — create context hierarchy
4. Implement tests (parallel) — fill spec placeholders
5. Review — run tests, check compliance
6. Summary — report results

### /rspec-refactor

Rewrite legacy tests to comply with the 28-rule BDD style guide.

```bash
/rspec-refactor spec/models/user_spec.rb    # single file
/rspec-refactor spec/services/              # directory
/rspec-refactor spec/ --check               # check only, no changes
```

## Agents

The plugin uses 4 specialized agents:

| Agent | Purpose |
|-------|---------|
| **code-analyzer** | Analyze source code, extract characteristics |
| **test-architect** | Design test structure, context hierarchy |
| **test-implementer** | Fill spec placeholders, update factories |
| **test-reviewer** | Run tests, check compliance, fix issues |

## Philosophy

This plugin follows the 28-rule RSpec style guide:

- **Test behavior, not implementation** — focus on observable outcomes
- **One it = one behavior** — keep tests focused
- **Characteristic-based contexts** — organize by what varies
- **Happy path first** — successful scenario before edge cases
- **Three-phase tests** — Given → When → Then

## Key Features

### Parallel Processing

Multiple files are processed concurrently:
- All files analyzed simultaneously
- All structures designed simultaneously
- All specs implemented simultaneously

This dramatically speeds up coverage for branches with many changes.

### Serena MCP Integration

Uses semantic code analysis for:
- Accurate method boundary detection
- Understanding Ruby semantics (blocks, procs)
- Reliable factory editing
- Dependency analysis

### Automatic Factory Management

Creates and updates FactoryBot factories as needed:
- Detects existing factories and traits
- Creates missing factories
- Adds traits for test scenarios

## Development Status

- [x] Plugin skeleton
- [x] code-analyzer agent
- [x] test-architect agent
- [x] test-implementer agent
- [x] test-reviewer agent
- [x] /rspec-cover command
- [x] /rspec-refactor command
- [ ] Testing on real projects
- [ ] Refinements based on usage
