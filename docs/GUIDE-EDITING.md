# Guide Editing Instructions

Instructions for editing human-facing documentation: guide.*.md, checklist.*.md, patterns.*.md, guide.api.*.md

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

## Editing Guidelines

When working with these guides:

### 1. Language Consistency and Synchronization

- Russian prose in \*.ru.md files, English prose in \*.en.md files
- When editing one language version, update the corresponding translation
- Maintain symmetrical structure, rule numbering, and content across language pairs
- Code examples use English identifiers (Ruby/RSpec conventions)
- Comments in code examples match file language (Russian in \*.ru.md, English in \*.en.md)

### 2. Pedagogical Example Structure

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

### 3. Code Example Quality

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

### 4. Cross-References

- Russian guides: guide.ru.md references guide.api.ru.md for API contract testing details
- English guides: guide.en.md references guide.api.en.md for API contract testing details
- Maintain symmetrical cross-reference structure across language pairs

### 5. No Generic Advice

Avoid adding common-sense development practices not explicitly covered in existing content.
