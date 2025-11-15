# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive RSpec style guide and testing philosophy documentation repository. **Maintained in symmetrical Russian and English translations.**

Main documents (available in both languages):

- **guide.ru.md** (3535 lines) / **guide.en.md** (3258 lines): Complete RSpec style guide covering BDD philosophy, testing patterns, and best practices (28 rules total)
- **guide.api.ru.md** (608 lines) / **guide.api.en.md** (608 lines): Recommendations and thoughts on API contract testing, boundaries of RSpec applicability, and alternative tools
- **checklist.ru.md** (77 lines) / **checklist.en.md** (78 lines): Quick checklist for code review with links to all 28 rules, organized by categories
- **patterns.ru.md** (522 lines) / **patterns.en.md** (522 lines): Useful patterns for writing readable tests (named subject, merge, lambda subject, traits, shared context)
- **rubocop-configs/**: RuboCop configuration examples for enforcing RSpec style guide rules (language-neutral)

Supporting materials:

- **rubocop-rspec-guide gem** (https://github.com/AlexeyMatskevich/rubocop-rspec-guide): Custom RuboCop cops for automated rule enforcement

The repository is documentation-only with no executable code or test suite.

## Content Structure

### Main Guide (guide.ru.md / guide.en.md)

Both language versions follow identical structured approach from philosophy to implementation:

1. **Navigation & Quick Reference**
   - Complete table of contents with links to all 28 rules
   - Quick Reference section with common problem diagnostics
   - FactoryBot decision tree (build vs build_stubbed)
   - Extensive inline glossary links throughout the document

2. **Philosophy & Foundations**
   - BDD (Behaviour Driven Development) principles and their relationship to TDD
   - Gherkin language mapping to RSpec constructs (Given/When/Then → let/action/expect)
   - Testing pyramid and level selection (unit/integration/request/E2E)
   - **Cognitive load framework** (intrinsic, extraneous, germane) - central theme integrated throughout
   - **Tests as code quality indicators** - how test complexity reveals design problems
   - Comprehensive glossary with inline links:
     - Core concepts: behavior, characteristics, states, domain
     - Testing types: behavioral testing, interface testing
     - Design principles: Do One Thing, SRP, Encapsulation, DI, Tight Coupling, Leaky Abstraction

3. **RSpec Style Guide (28 Rules)**
   - **Behavior and Structure**: Test behavior not implementation; one behavior per `it`; characteristic-based `context` hierarchies
   - **Syntax and Readability**: `describe`/`context`/`it` naming conventions; matcher selection; avoiding implementation coupling
   - **Context and Data Preparation**: `let` vs `let!`, `before` hooks, factories, shared examples
   - **Specification Language**: Precise wording for test descriptions (when/with/without/and/but/NOT)
   - **Tools and Support**: Test isolation, time stability, debugging techniques

4. **Specialized Topics**
   - API contract testing (cross-reference to guide.api.ru.md)
   - External services (VCR, WebMock patterns)
   - Ruby/PostgreSQL time precision handling
   - Migration strategies for legacy tests

### API Contract Testing Guide (guide.api.ru.md / guide.api.en.md)

Documents when RSpec is **not** the right tool:

- **Navigation**: Table of contents, inline glossary links, Quick Reference section
- **Anti-patterns**: over-splitting fields into separate tests, checking entire JSON hashes with `eq`
- **Recommended tools**: JSON Schema validators (json_matchers), OpenAPI generators (rspec-openapi, rswag), snapshot testing
- **Tool comparison**: code-first vs spec-first approaches, when to use each tool
- **Quick diagnostics**: Decision trees for common API testing problems
- **Philosophy**: Use RSpec for behavior, specialized tools for contract validation
- **Glossary**: API contract, code-first, spec-first, OpenAPI, JSON Schema, snapshot testing

## Key Philosophy

The guide is built around two central themes (consistent across both language versions):

1. **Cognitive Load Management** (RU: внутренняя/посторонняя/релевантная нагрузка | EN: intrinsic/extraneous/germane load): Test structure should minimize extraneous load and maximize germane load
2. **Tests as Code Quality Indicators**: Test complexity reveals code design problems (encapsulation violations, tight coupling, Do One Thing violations)

Supporting principles:

1. **Test Behavior, Not Implementation**: Focus on observable outcomes that matter to business stakeholders
2. **BDD Language Mapping**: Gherkin's Given/When/Then directly maps to RSpec structure
3. **Characteristic-Based Hierarchies**: Organize `context` blocks by dependent characteristics (happy path first, then corner cases)
4. **Domain-Based Combining at Integration Level**: Combine details within single business domain; each nesting level = domain transition (authentication → authorization → business domain)
5. **Interface vs Behavioral Testing**: Multiple related attributes = single interface test with `aggregate_failures`; multiple independent side effects = separate behavioral tests
6. **Right Tool for the Job**: RSpec excels at behavior/logic; use JSON Schema/OpenAPI tools for API contracts

## Language and Communication

**Bilingual Documentation:**

This repository maintains **symmetrical translations** in Russian and English:

- **guide.ru.md ↔ guide.en.md**: Full RSpec style guide (28 rules, ~3500 lines each)
- **guide.api.ru.md ↔ guide.api.en.md**: API contract testing guide (608 lines each)
- **checklist.ru.md ↔ checklist.en.md**: Quick reference checklist (~77 lines each)

**Content Synchronization:**

- Russian and English versions must have equivalent content
- When updating one language version, update the corresponding translation
- Both languages have **equal importance** in this repository
- Maintain parallel structure, rule numbering, and section organization

**Language Rules:**

- **Communication with user**: Follow user's language preference (Russian or English)
- **Documentation files (\*.ru.md)**: Russian prose with Russian comments in code examples
- **Documentation files (\*.en.md)**: English prose with English comments in code examples
- **Code examples**: English identifiers (Ruby/RSpec conventions), comments match file language
- **Commit messages**: English (standard programming convention)
- **Technical work defaults**: English

**Language-Specific Details:**

- Russian guides include bilingual Gherkin examples: Дано/Given, Когда/When, Тогда/Then
- English guides use English-only Gherkin examples: Given/When/Then
- Quality annotations in Russian guides: `# плохо`, `# хорошо`, `# нормально`
- Quality annotations in English guides: `# bad`, `# good`, `# okay`

## Development Environment

**Devbox Setup:**

- **devbox.json** is configured for Claude Code agents, not for human use
- Agents can install any dependencies needed for tasks (linters, formatters, validators, etc.)
- Add packages as needed via `devbox add <package>`, remove via `devbox add <package>`,
  call runtime if there is no devbox envierment via `devbox run <runtime>`
- Example use cases: markdown linters, spell checkers, documentation generators

**Repository:**

- Git repository with master branch
- No CI/CD, build scripts, or test runners (documentation only)

**Missing Tooling:**

- Markdown linter not yet configured (should be added when needed)

## Skills Development and Maintenance

**Current Skills:**

- **rspec-testing/** — RSpec Testing Skill for writing and updating RSpec tests following BDD principles

**Best Practices Reference:**

- **MUST follow**: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices
- All skills in this repository follow Claude Code official guidelines

**RSpec Testing Skill (rspec-testing/):**

Structure:

- **SKILL.md** (511 lines) — Main skill file with overview, 28 rules, decision trees, troubleshooting
- **REFERENCE.md** (943 lines) — Detailed workflows, extended examples, decision trees with examples
- Progressive disclosure: SKILL.md → REFERENCE.md

Current state:

- ✅ Size: 511 lines (close to recommended 500)
- ✅ YAML frontmatter correct (name, description)
- ✅ Prerequisites check (never modifies Gemfile automatically)
- ✅ Brief examples for key rules (Rules 1, 3, 7, 11, 19)
- ✅ Decision trees (quick answers with links to detailed versions)
- ✅ Troubleshooting section (Symptoms → Cause → Fix)
- ✅ Progressive disclosure (SKILL.md for overview, REFERENCE.md for details)
- ✅ No tool assumptions (checks prerequisites, asks user)

**Guidelines for Skill Updates:**

1. **Always follow best practices**:
   - Keep SKILL.md under 500 lines (progressive disclosure for longer content)
   - Include prerequisites check (never modify project files automatically)
   - Provide examples over explanations
   - Use decision trees for common choices
   - Include troubleshooting section
   - NEVER assume tools are installed

2. **Progressive disclosure pattern**:
   - SKILL.md = overview, quick reference, brief examples
   - REFERENCE.md = detailed workflows, extended examples, full decision trees
   - One level deep references only

3. **When updating skills**:
   - Update both SKILL.md and REFERENCE.md if content split between them
   - Maintain cross-references between files
   - Check file size stays reasonable (SKILL.md target: <500 lines)
   - Verify YAML frontmatter remains valid
   - Test that all reference links work

4. **Content principles**:
   - "Default assumption: Claude is already smart" — include only specific knowledge Claude doesn't have
   - Examples over explanations — show input/output pairs
   - Solve, don't punt — scripts should handle errors explicitly
   - No deeply nested references

5. **Validation**:
   - YAML frontmatter valid (name, description)
   - All internal links work
   - File size reasonable
   - Prerequisites checked before operations
   - No assumptions about installed tools

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

**Note**: TravelWithoutTravelBack cop was removed as TravelBack always happens automatically.

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

## Editing Guidelines

When working with these guides:

1. **Language Consistency and Synchronization**:
   - Russian prose in _.ru.md files, English prose in _.en.md files
   - When editing one language version, update the corresponding translation
   - Maintain symmetrical structure, rule numbering, and content across language pairs
   - Code examples use English identifiers (Ruby/RSpec conventions)
   - Comments in code examples match file language (Russian in _.ru.md, English in _.en.md)

2. **Pedagogical Example Structure** (consistent in both language versions):
   The guide uses a specific pattern for teaching:
   - Present bad example first (allows reader to identify issues independently)
   - Present good example second (shows solution)
   - Reader thinks about differences before reading explanation
   - Explanation comes last (confirms or clarifies reader's understanding)

   **Quality Annotations** (in order of severity, with language-specific terms):
   - RU: `# отвратительно` | EN: `# atrocious` — worst possible approach
   - RU: `# ужасно` | EN: `# terrible` — very bad practice
   - RU: `# очень плохо` | EN: `# very bad` — seriously flawed
   - RU: `# плохо` | EN: `# bad` — standard negative example
   - RU: `# нормально` | EN: `# okay` — intermediate solution that solves main issue but not optimal
   - RU: `# хорошо` | EN: `# good` — recommended approach

   The severity annotations emphasize how problematic an anti-pattern is. Intermediate examples (`# нормально`/`# okay`) typically appear between bad and good to show progressive improvement.

   **Exception**: Rule #2 contains a section marked "Надуманный пример" (RU) / "Contrived example" (EN) - the only place this phrase appears. This is the only example with just a bad case and no good counterpart, because creating a practical good example for that specific anti-pattern is too difficult. Avoid using this phrase elsewhere.

3. **Code Example Quality**:
   - Examples follow the guide's own rules—they're pedagogical tools
   - Maintain characteristic-based context hierarchy in examples
   - Keep Gherkin mappings accurate (Given→let, When→action, Then→expect)

   **Example Isolation Principle**:
   - `# плохо` examples violate ONLY the rule they illustrate (not multiple rules)
   - `# хорошо` examples follow ALL guideline rules (not just fixing one issue)
   - `# нормально` examples fix the main issue but remain suboptimal in other ways

   **Example Brevity**:
   - Use `...` and comments to omit irrelevant details
   - Focus on specifics relevant to the current rule
   - Keep examples clear, concise, and focused rather than showing complete realistic tests
   - Currently, the guide doesn't fully follow this ideal—examples could be more concise

   **Philosophy Section Exception** (applies to both language versions):
   - In philosophy sections (RU: "Про RSpec", "Что можно изучить по тестам", "Пирамида тестирования" | EN: "About RSpec", "What can be learned from tests", "Testing pyramid")
   - KEEP thought-expressing comments that show reader's thinking process
   - Examples:
     - RU: `# из этого описания не понятно...`, `# это описание рассказывает нам...`
     - EN: `# from this description it's unclear...`, `# this description tells us...`
   - These comments have pedagogical value - they demonstrate the thought process, not just technical notes

4. **Cross-References**:
   - Russian guides: guide.ru.md references guide.api.ru.md for API contract testing details
   - English guides: guide.en.md references guide.api.en.md for API contract testing details
   - Maintain symmetrical cross-reference structure across language pairs

5. **No Generic Advice**: Avoid adding common-sense development practices not explicitly covered in existing content

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

### Available Modes

Modes dynamically adjust both the system prompt AND the available toolset. Use `switch_modes` tool to change modes during session.

| Mode            | Purpose                                   | When to Use                                         |
| --------------- | ----------------------------------------- | --------------------------------------------------- |
| `planning`      | Strategic analysis and task decomposition | Before implementing complex features or refactoring |
| `interactive`   | Dialogue-based development (default)      | Standard coding tasks, iterative development        |
| `one-shot`      | Single comprehensive response             | Generating reports, initial plans, code reviews     |
| `no-onboarding` | Skip project analysis                     | When project structure is already familiar          |

**Mode combinations**: Can activate multiple modes simultaneously (e.g., `planning` + `one-shot` for comprehensive reports). Note: Some modes are semantically incompatible (e.g., `interactive` + `one-shot`).

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

- `switch_modes` - Change active modes
- `get_current_config` - View active configuration
- `write_memory` / `read_memory` / `list_memories` - Persistent project-specific notes

**Cognitive Tools**:

- `think_about_collected_information` - Evaluate completeness of gathered context
- `think_about_task_adherence` - Check alignment with current task
- `think_about_whether_you_are_done` - Verify task completion

### Best Practices

1. **Code Navigation**: Always prefer `find_symbol` and `find_referencing_symbols` over text-based grep. These tools understand code structure semantically.

2. **Code Editing**: Use symbol-level operations (`replace_symbol_body`, `insert_after_symbol`) instead of line-based replacements when modifying functions, methods, or classes.

3. **Mode Switching Strategy**:
   - Start complex tasks with `switch_modes` to `planning`
   - Generate implementation plan
   - Switch back to `interactive` for execution
   - Use `one-shot` for final summaries or reviews

4. **Project Memory**: Use `write_memory` to store important findings (architecture decisions, patterns discovered, test commands) that persist across sessions.

5. **Before Major Refactoring**:
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
