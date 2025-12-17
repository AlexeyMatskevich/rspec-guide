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

## Scope / Not Supported

This plugin focuses on `unit` / `integration` / `request` style specs and does not support:

- **E2E / browser-driven specs**: Capybara-style `feature` / `system` specs
- **View specs**: `rspec:view`, `rspec:mailer`

## Commands

| Command                  | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `/rspec-cover <target>`  | Cover code with tests (single file, branch, or staged) |
| `/rspec-refactor <spec>` | Refactor legacy tests to follow BDD style guide        |

### /rspec-cover

Cover code changes with RSpec tests. Automatically detects new vs modified code.

```bash
/rspec-cover app/services/payment_processor.rb  # single file
/rspec-cover --branch                            # all changes on branch
/rspec-cover --staged                            # staged files only
```

**Workflow:**

1. Discover changed files
2. Analyze code (parallel) — extract characteristics + behavior bank
3. Write specs (parallel) — derive `methods[].test_config`, materialize skeleton, fill placeholders, strip markers
4. Review — run tests, check compliance
5. Summary — report results

### /rspec-refactor

Rewrite legacy tests to comply with the 28-rule BDD style guide.

```bash
/rspec-refactor spec/models/user_spec.rb    # single file
/rspec-refactor spec/services/              # directory
/rspec-refactor spec/ --check               # check only, no changes
```

## Agents

The plugin uses these agents:

| Agent                        | Purpose                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------- |
| **discovery-agent**          | Discover files/methods to test, build method-level waves, write initial metadata |
| **code-analyzer**            | Analyze source code, extract characteristics and behaviors                       |
| **factory-agent** (optional) | Create/update factories and traits (if used)                                     |
| **spec-writer**              | Derive `test_config`, materialize skeleton via scripts, fill placeholders, strip markers |
| **test-reviewer**            | Run tests, check compliance, fix issues                                          |

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

### Rails Bootstrap (New Spec Files)

For Rails projects, when a target spec file does not exist, spec skeleton creation uses Rails RSpec generators (`bundle exec rails generate rspec:*`) for supported file types, then patches deterministic method blocks into the file.

## Development Status

- [x] Plugin skeleton
- [x] code-analyzer agent
- [x] spec-writer agent
- [x] test-reviewer agent
- [x] /rspec-cover command
- [x] /rspec-refactor command
- [ ] Testing on real projects
- [ ] Refinements based on usage
