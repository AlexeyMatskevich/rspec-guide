# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive RSpec style guide and testing philosophy documentation repository. Currently in Russian, with English version planned for the future.

Main documents:
- **guide.ru.md** (2833 lines): Complete RSpec style guide covering BDD philosophy, testing patterns, and best practices
- **guide.api.ru.md** (562 lines): Specialized guide on API contract testing and RSpec's limitations in this domain

The repository is documentation-only with no executable code or test suite.

## Content Structure

### Main Guide (guide.ru.md)

The guide follows a structured approach from philosophy to implementation:

1. **Philosophy & Foundations**
   - BDD (Behaviour Driven Development) principles and their relationship to TDD
   - Gherkin language mapping to RSpec constructs (Given/When/Then → let/action/expect)
   - Testing pyramid and level selection (unit/integration/request/E2E)
   - Glossary defining "behavior", behavioral vs interface testing, characteristics and states

2. **RSpec Style Guide Sections**
   - **Behavior and Structure**: Test behavior not implementation; one behavior per `it`; characteristic-based `context` hierarchies
   - **Syntax and Readability**: `describe`/`context`/`it` naming conventions; matcher selection; avoiding implementation coupling
   - **Context and Data Preparation**: `let` vs `let!`, `before` hooks, factories, shared examples
   - **Specification Language**: Precise wording for test descriptions
   - **Tools and Support**: Test isolation, time stability, debugging techniques

3. **Specialized Topics**
   - External services (VCR, WebMock patterns)
   - Ruby/PostgreSQL time precision handling

### API Contract Testing Guide (guide.api.ru.md)

Documents when RSpec is **not** the right tool:

- Anti-patterns: over-splitting fields into separate tests, checking entire JSON hashes with `eq`
- Recommended tools: JSON Schema validators (json_matchers), OpenAPI generators (rspec-openapi, rswag), snapshot testing
- Philosophy: Use RSpec for behavior, specialized tools for contract validation

## Key Philosophy

The guides emphasize:

1. **Test Behavior, Not Implementation**: Focus on observable outcomes that matter to business stakeholders
2. **BDD Language Mapping**: Gherkin's Given/When/Then directly maps to RSpec structure
3. **Characteristic-Based Hierarchies**: Organize `context` blocks by dependent characteristics (happy path first, then corner cases)
4. **Interface vs Behavioral Testing**: Multiple related attributes = single interface test with `aggregate_failures`; multiple independent side effects = separate behavioral tests
5. **Right Tool for the Job**: RSpec excels at behavior/logic; use JSON Schema/OpenAPI tools for API contracts

## Language and Communication

**Working Language:**
- Communication with user: Russian
- Russian documentation files (*.ru.md): Russian prose
- English documentation files (future *.md): English prose
- Code examples: English (Ruby/RSpec conventions) with comments matching file language
- Commit messages: English (standard programming convention)
- Everything else: English (default for technical work)

**Current State:**
- Documentation currently in Russian only
- English version planned for future
- Gherkin examples show both English and Russian keywords side-by-side

## Development Environment

**Devbox Setup:**
- **devbox.json** is configured for Claude Code agents, not for human use
- Agents can install any dependencies needed for tasks (linters, formatters, validators, etc.)
- Currently includes Python; add packages as needed via `devbox add <package>`
- Example use cases: markdown linters, spell checkers, documentation generators

**Repository:**
- Git repository with master branch
- No CI/CD, build scripts, or test runners (documentation only)

**Missing Tooling:**
- Markdown linter not yet configured (should be added when needed)

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

4. **Cross-References**: guide.ru.md references guide.api.ru.md for API contract testing details

5. **No Generic Advice**: Avoid adding common-sense development practices not explicitly covered in existing content

## Files to Ignore

Per .gitignore:
- `.idea/` (JetBrains IDE)
- `PLAN.md` (internal planning)
- `api-section-backup.md` (backup content)
- `.devbox/` (devbox cache)
