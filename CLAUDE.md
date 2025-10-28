# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive RSpec style guide and testing philosophy documentation repository. Available in both Russian and English.

Main documents:
- **guide.ru.md** (3535 lines) / **guide.en.md** (3258 lines): Complete RSpec style guide covering BDD philosophy, testing patterns, and best practices (28 rules total)
- **guide.api.ru.md** (608 lines) / **guide.api.en.md** (608 lines): Recommendations and thoughts on API contract testing, boundaries of RSpec applicability, and alternative tools
- **checklist.ru.md** (77 lines) / **checklist.en.md** (78 lines): Quick checklist for code review with links to all 28 rules, organized by categories
- **rubocop-configs/**: RuboCop configuration examples for enforcing RSpec style guide rules

Supporting materials:
- **rubocop-rspec-guide gem** (https://github.com/AlexeyMatskevich/rubocop-rspec-guide): Custom RuboCop cops for automated rule enforcement

The repository is documentation-only with no executable code or test suite.

## Content Structure

### Main Guide (guide.ru.md / guide.en.md)

The guide follows a structured approach from philosophy to implementation:

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

The guide is built around two central themes:

1. **Cognitive Load Management** (внутренняя/посторонняя/релевантная нагрузка): Test structure should minimize extraneous load and maximize germane load
2. **Tests as Code Quality Indicators**: Test complexity reveals code design problems (инкапсуляция, tight coupling, Do One Thing violations)

Supporting principles:

1. **Test Behavior, Not Implementation**: Focus on observable outcomes that matter to business stakeholders
2. **BDD Language Mapping**: Gherkin's Given/When/Then directly maps to RSpec structure
3. **Characteristic-Based Hierarchies**: Organize `context` blocks by dependent characteristics (happy path first, then corner cases)
4. **Domain-Based Combining at Integration Level**: Combine details within single business domain; each nesting level = domain transition (authentication → authorization → business domain)
5. **Interface vs Behavioral Testing**: Multiple related attributes = single interface test with `aggregate_failures`; multiple independent side effects = separate behavioral tests
6. **Right Tool for the Job**: RSpec excels at behavior/logic; use JSON Schema/OpenAPI tools for API contracts

## Language and Communication

**Working Language:**
- Communication with user: Russian
- Russian documentation files (*.ru.md): Russian prose
- English documentation files (*.en.md): English prose
- Code examples: English (Ruby/RSpec conventions) with comments matching file language
- Commit messages: English (standard programming convention)
- Everything else: English (default for technical work)

**Current State:**
- **Both Russian and English versions available** (guide.ru.md / guide.en.md, guide.api.ru.md / guide.api.en.md, checklist.ru.md / checklist.en.md)
- Russian guides include bilingual Gherkin examples (Дано/Given, Когда/When, Тогда/Then)
- English guides use English-only Gherkin examples (Given/When/Then)

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

1. **Language Consistency**:
   - Russian prose in *.ru.md files
   - Code examples in English (Ruby/RSpec conventions)
   - Comments in code examples match file language (Russian in *.ru.md)

2. **Pedagogical Example Structure**:
   The guide uses a specific pattern for teaching:
   - Present bad example first (allows reader to identify issues independently)
   - Present good example second (shows solution)
   - Reader thinks about differences before reading explanation
   - Explanation comes last (confirms or clarifies reader's understanding)

   **Quality Annotations** (in order of severity):
   - `# отвратительно` (atrocious) - worst possible approach
   - `# ужасно` (terrible) - very bad practice
   - `# очень плохо` (very bad) - seriously flawed
   - `# плохо` (bad) - standard negative example
   - `# нормально` (okay) - intermediate solution that solves main issue but not optimal
   - `# хорошо` (good) - recommended approach

   The severity annotations emphasize how problematic an anti-pattern is. `# нормально` examples typically appear between `# плохо` and `# хорошо` to show progressive improvement.

   **Exception**: Rule #2 contains a section marked "Надуманный пример" (contrived example) - the only place this phrase appears. This is the only example with just a bad case and no good counterpart, because creating a practical good example for that specific anti-pattern is too difficult. Avoid using "Надуманный пример" elsewhere.

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

   **Philosophy Section Exception**:
   - In philosophy sections ("Про RSpec", "Что можно изучить по тестам", "Пирамида тестирования")
   - KEEP thought-expressing comments that show reader's thinking process
   - Examples: `# из этого описания не понятно...`, `# это описание рассказывает нам...`
   - These comments have pedagogical value - they demonstrate the thought process, not just technical notes

4. **Cross-References**: guide.ru.md references guide.api.ru.md for API contract testing details

5. **No Generic Advice**: Avoid adding common-sense development practices not explicitly covered in existing content

## Files to Ignore

Per .gitignore:
- `.idea/` (JetBrains IDE)
- `.devbox/` (devbox cache)
- `ACTION_PLAN*.md` (temporary planning documents)
- `automation-research.md` (research notes for RuboCop automation)
