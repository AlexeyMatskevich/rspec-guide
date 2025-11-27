# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Comprehensive RSpec style guide and testing philosophy documentation. **Maintained in symmetrical Russian and English translations.**

Main documents:

- **guide.ru.md / guide.en.md**: Complete RSpec style guide (28 rules, ~3500 lines each)
- **guide.api.ru.md / guide.api.en.md**: API contract testing guide (608 lines each)
- **checklist.ru.md / checklist.en.md**: Quick checklist for code review
- **patterns.ru.md / patterns.en.md**: Useful patterns for writing readable tests
- **rubocop-configs/**: RuboCop configuration examples
- **plugins/rspec-testing/**: Claude Code plugin for RSpec testing

Supporting materials:

- **rubocop-rspec-guide gem** (https://github.com/AlexeyMatskevich/rubocop-rspec-guide): Custom RuboCop cops

The repository is documentation-only with no executable code or test suite.

## Context-Specific Instructions

Load additional instructions based on what you're working on:

| Working on...                                             | Read this file          |
| --------------------------------------------------------- | ----------------------- |
| guide.*.md, checklist.*.md, patterns.*.md, guide.api.*.md | docs/GUIDE-EDITING.md   |
| plugins/, agents/, commands/                              | docs/PLUGINS-GUIDE.md   |
| algoritm/                                                 | (general conventions)   |
| rubocop-configs/                                          | (see section below)     |

## Development Environment

**Devbox Setup:**

- **devbox.json** is configured for Claude Code agents, not for human use
- Agents can install any dependencies needed for tasks (linters, formatters, validators, etc.)
- Add packages as needed via `devbox add <package>`, remove via `devbox rm <package>`,
  call runtime if there is no devbox environment via `devbox run <runtime>`

**Repository:**

- Git repository with main branch
- No CI/CD, build scripts, or test runners (documentation only)

## RuboCop Configuration & Automation

**rubocop-configs Directory:**

- **rubocop-rspec.yml**: Standard RuboCop RSpec rules configuration
- **rubocop-factory_bot.yml**: FactoryBot-specific rules configuration
- **rubocop-rspec-guide.yml**: Custom cops from rubocop-rspec-guide gem
- **.rubocop.yml.example**: Complete combined configuration example
- **README.md**: Installation and usage instructions

**Custom RuboCop Cops (rubocop-rspec-guide gem):**

The repository has a companion gem (https://github.com/AlexeyMatskevich/rubocop-rspec-guide) with custom cops enforcing guide rules:

1. **RSpecGuide/CharacteristicsAndContexts**: Requires at least 2 contexts in describe block (happy path + edge cases)
2. **RSpecGuide/HappyPathFirst**: Enforces ordering so successful scenarios precede edge cases
3. **RSpecGuide/ContextSetup**: Requires contexts to have setup (let/let!/let_it_be/before)
4. **RSpecGuide/DuplicateLetValues**: Identifies duplicate variable definitions across sibling contexts
5. **RSpecGuide/DuplicateBeforeHooks**: Detects duplicate before hooks across sibling contexts
6. **RSpecGuide/InvariantExamples**: Flags identical examples repeated across all leaf contexts
7. **FactoryBotGuide/DynamicAttributesForTimeAndRandom**: Ensures time and random values are wrapped in blocks

## Git and Commit Workflow

**IMPORTANT: Always ask before committing**

- **Never commit automatically** - even outside plan mode
- After making changes, show diff summary and **explicitly ask**: "Изменения готовы. Хочешь закоммитить?"
- Wait for user's explicit confirmation (e.g., "да", "коммитимся", "commit")
- Only then run `git add` and `git commit`

**Commit message guidelines:**

- Write in English (standard programming convention)
- Use imperative mood ("Add feature" not "Added feature")
- First line: brief summary (50 chars max)
- Blank line, then detailed description if needed
- Reference related rules/sections when relevant

## Files to Ignore

Per .gitignore:

- `.idea/` (JetBrains IDE)
- `.devbox/` (devbox cache)
- `ACTION_PLAN*.md` (temporary planning documents)
- `automation-research.md` (research notes for RuboCop automation)

## Serena MCP Server Integration

This project uses Serena MCP server for semantic code analysis via Language Server Protocol (LSP). Serena provides symbol-level code navigation and editing tools that complement Claude Code's built-in capabilities.

### Configuration

- **Context**: `ide-assistant` (tools are pre-filtered to avoid duplication with Claude Code's native file/shell tools)
- **Project**: Activate current project via `activate_project` mcp tool if it not already activated
- **Dashboard**: Available at http://localhost:24282/dashboard/index.html

### Core Serena Tools (ide-assistant context)

**Symbol Navigation** (prefer over grep/file search):

- `find_symbol` - Global/local symbol search by name/substring
- `find_referencing_symbols` - Find all references to a symbol
- `get_symbols_overview` - Top-level symbols in a file

**Symbol-Level Editing** (prefer over line-based edits):

- `insert_after_symbol` / `insert_before_symbol` - Add code relative to symbol definitions
- `replace_symbol_body` - Replace entire symbol definition
- `rename_symbol` - Refactor symbol names across codebase

**Project Management**:

- `get_current_config` - View active configuration
- `write_memory` / `read_memory` / `list_memories` - Persistent project-specific notes

**Cognitive Tools**:

- `think_about_collected_information` - Evaluate completeness of gathered context
- `think_about_task_adherence` - Check alignment with current task
- `think_about_whether_you_are_done` - Verify task completion

### Best Practices

1. **Code Navigation**: Always prefer `find_symbol` and `find_referencing_symbols` over text-based grep. These tools understand code structure semantically.

2. **Code Editing**: Use symbol-level operations (`replace_symbol_body`, `insert_after_symbol`) instead of line-based replacements when modifying functions, methods, or classes.

3. **Project Memory**: Use `write_memory` to store important findings (architecture decisions, patterns discovered, test commands) that persist across sessions.

4. **Before Major Refactoring**:
   - Use `find_referencing_symbols` to understand impact
   - Consider `rename_symbol` for LSP-powered refactoring
   - Check project memories for relevant context

### Tool Selection Guidelines

**Use Serena tools when**:

- Searching for function/class/method definitions
- Finding all usages of a symbol
- Refactoring symbol names
- Understanding code structure at symbol level
- Storing/retrieving project-specific knowledge

**Use Claude Code native tools when**:

- Running shell commands (tests, builds)
- Reading/writing entire files
- File system operations
- General text search in non-code files
