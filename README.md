# RSpec Style Guide

> Comprehensive guide to writing maintainable, readable RSpec tests with a focus on reducing cognitive load

[![Russian](https://img.shields.io/badge/lang-ru-blue.svg)](guide.ru.md)
[![English](https://img.shields.io/badge/lang-en-blue.svg)](guide.en.md)

---

## About

This is a comprehensive RSpec style guide focused on **reducing cognitive load** and using **tests as code quality indicators**. The guide covers BDD philosophy, testing patterns, and 28 practical rules with extensive examples.

**Key principles:**
- Test behavior, not implementation
- Organize tests by characteristics and states
- Use cognitive load framework to write maintainable tests
- Leverage tests to identify design problems in production code

## 📚 Documentation

| Document | Description | Lines |
|----------|-------------|-------|
| **[guide.en.md](guide.en.md)** | Complete RSpec style guide with 28 rules | 3,258 |
| **[guide.api.en.md](guide.api.en.md)** | API contract testing guide | 608 |
| **[checklist.en.md](checklist.en.md)** | Quick code review checklist | 78 |
| **[rspec-testing/](rspec-testing/)** | Claude Code Skill for AI-assisted testing | — |

**Also available in Russian:** [guide.ru.md](guide.ru.md) • [guide.api.ru.md](guide.api.ru.md) • [checklist.ru.md](checklist.ru.md)

## 🎯 What's Inside

### Main Guide ([guide.en.md](guide.en.md))

**Philosophy & Foundations**
- BDD (Behaviour Driven Development) principles
- Gherkin mapping to RSpec (Given/When/Then)
- Testing pyramid and level selection
- Cognitive load framework (intrinsic, extraneous, germane)
- Tests as code quality indicators

**28 Practical Rules** organized by topics:
- Behavior and Structure
- Syntax and Readability
- Context and Data Preparation
- Specification Language
- Tools and Support

**Quick Reference**
- Common problem diagnostics
- FactoryBot decision tree
- Navigation with inline glossary links

### API Contract Testing Guide ([guide.api.en.md](guide.api.en.md))

When RSpec is **not** the right tool:
- Anti-patterns: over-splitting, excessive detail
- Tools comparison: JSON Schema, rspec-openapi, RSwag, snapshot testing
- Code-first vs spec-first approaches
- Quick diagnostic decision trees

### Code Review Checklist ([checklist.en.md](checklist.en.md))

Quick reference for reviewing RSpec tests organized by categories:
- Philosophy and Structure
- Code Organization
- Data Preparation
- Description Language
- Technical Aspects
- Anti-patterns

## 🤖 RuboCop Integration

Automated enforcement via [rubocop-rspec-guide](https://github.com/AlexeyMatskevich/rubocop-rspec-guide) gem with 7 custom cops:

| Cop | Description |
|-----|-------------|
| **CharacteristicsAndContexts** | Requires at least 2 contexts (happy path + edge cases) |
| **HappyPathFirst** | Enforces ordering (success before errors) |
| **ContextSetup** | Requires contexts to have setup (let/before/subject) |
| **DuplicateLetValues** | Detects duplicate let across sibling contexts |
| **DuplicateBeforeHooks** | Detects duplicate before hooks |
| **InvariantExamples** | Finds repeated examples in all leaf contexts |
| **DynamicAttributesForTimeAndRandom** | Ensures Time.now and SecureRandom use blocks |

**Configuration examples:** See [rubocop-configs/](rubocop-configs/) directory

## 🚀 Quick Start

### 1. Understand the Philosophy

Start with the "why" to understand the reasoning behind the rules:
- [Cognitive Load Framework](guide.en.md#why-we-write-tests-this-way-cognitive-load)
- [Tests as Quality Indicators](guide.en.md#tests-as-code-quality-indicators)

### 2. Browse the Rules

Explore the 28 rules organized by category:
- [Complete Table of Contents](guide.en.md#table-of-contents)

### 3. Use During Code Review

Keep the checklist handy when reviewing tests:
- [Code Review Checklist](checklist.en.md)

### 4. Automate with RuboCop

Install and configure automated enforcement:

```ruby
# Gemfile
group :development, :test do
  gem 'rubocop-rspec', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rspec-guide', require: false
end
```

```bash
bundle install
```

Copy configuration from [rubocop-configs/.rubocop.yml.example](rubocop-configs/.rubocop.yml.example) to your project's `.rubocop.yml`.

## 🤖 RSpec Testing Skill for Claude Code

A Claude Code Skill that helps AI write and update RSpec tests following this style guide's principles.

### What It Does

The skill teaches Claude to:
- Write behavior-focused tests (not implementation details)
- Create characteristic-based context hierarchies
- Place happy path before edge cases
- Use clear, readable test descriptions
- Validate tests with linters and test runners

### Installation

Copy the skill to Claude Code:

```bash
# Global installation (applies to all projects)
cp -r rspec-testing ~/.claude/skills/rspec-testing

# Project-specific installation
mkdir -p .claude/skills
cp -r rspec-testing .claude/skills/rspec-testing
```

After installation, restart Claude Code to load the skill.

### Verification

To verify the skill is properly installed, ask Claude directly:

```
What Skills are available?
```

Claude will list all available skills from all sources (personal, project, and plugin skills).

You can also verify manually by checking the filesystem:

```bash
# Check personal skills
ls ~/.claude/skills/

# Check project skills
ls .claude/skills/

# View the skill content
cat ~/.claude/skills/rspec-testing/SKILL.md
```

**Learn more:** [View available skills in Claude Code documentation](https://docs.claude.com/en/docs/claude-code/skills#view-available-skills)

### Usage

Once installed, Claude automatically applies the skill when you:
- **Ask to write tests**: "Write RSpec tests for the OrderProcessor class"
- **Request test coverage**: "Add test coverage for the calculate_discount method"
- **Need to update tests**: "Update user_spec.rb to test the new validation"
- **Want to refactor**: "Refactor payment_spec.rb to improve clarity"

The skill guides Claude through:
1. Identifying what to test (public interface only)
2. Mapping behavior characteristics
3. Creating proper context hierarchy
4. Writing happy path first, then edge cases
5. Validating with project's linter and running tests

### How It Works

Claude Code Skills are **model-invoked** — Claude automatically uses the skill when it detects you're working with RSpec tests. No manual activation needed.

**Progressive Disclosure Structure:**
- **[SKILL.md](rspec-testing/SKILL.md)** (~350 lines) — All 28 rules in directive format, always loaded by Claude
- **[REFERENCE.md](rspec-testing/REFERENCE.md)** (~950 lines) — Detailed workflows, extended examples, decision trees (loaded on-demand)

The skill contains:
- All 28 rules from this style guide in clear, directive language
- Common patterns with code examples
- Step-by-step workflows for writing and updating tests
- Decision trees for complex choices (create vs build_stubbed, aggregate_failures, shared_examples)
- Generic validation workflow (works with RuboCop, Standard, or any linter)

This structure keeps Claude's context efficient while providing deep guidance when needed.

## 💡 Key Concepts

### Cognitive Load Management

The guide is built around reducing cognitive load in tests:

- **Intrinsic load**: Inherent complexity of the task (unavoidable)
- **Extraneous load**: How information is presented (minimize this!)
- **Germane load**: Building mental models (maximize this!)

Every rule in the guide helps reduce extraneous load and increase germane load.

### Characteristic-Based Hierarchies

Organize test contexts by dependent characteristics:

```ruby
describe DiscountCalculator do
  describe '#calculate' do
    # Level 1: Segment (independent characteristic)
    context 'when segment is b2c' do
      # Level 2: Premium status (depends on segment)
      context 'with premium subscription' do
        it 'applies 20% discount' do
          # ...
        end
      end

      context 'without premium subscription' do
        it 'applies 5% discount' do
          # ...
        end
      end
    end
  end
end
```

**Principles:**
- One characteristic per context level
- Happy path before corner cases
- Each nesting level clarifies one aspect of behavior

### Domain-Based Combining (Integration Level)

At integration/request spec level, combine details within single business domain:

- **Typical layers**: authentication → authorization → business domain
- **One corner case per layer** is sufficient
- **Avoid duplicating unit tests** at integration level

### Interface vs Behavioral Testing

- **Multiple related attributes** = single interface test with `aggregate_failures`
- **Multiple independent side effects** = separate behavioral tests

## 📖 Examples

### Before (Testing Implementation)

```ruby
# Bad: testing internal calls
it 'calls validator' do
  expect(validator).to receive(:validate)
  subject.process
end
```

### After (Testing Behavior)

```ruby
# Good: testing observable behavior
context 'when data is valid' do
  it 'processes successfully' do
    expect(subject.process).to be_success
  end
end

context 'when data is invalid' do
  it 'returns validation error' do
    result = subject.process
    expect(result).to be_error
    expect(result.error_type).to eq(:validation)
  end
end
```

## 🔗 Related Resources

- [Better Specs](https://www.betterspecs.org/) - RSpec best practices
- [RuboCop RSpec Documentation](https://docs.rubocop.org/rubocop-rspec/) - Official RuboCop RSpec docs
- [Thoughtbot RSpec Guide](https://github.com/thoughtbot/guides/tree/main/testing-rspec) - Thoughtbot's testing guide

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improving the guide:

1. Open an issue to discuss the change
2. Ensure examples follow the guide's own rules
3. Maintain both Russian and English versions

## 📜 License

This guide is open source and available for use in your projects.

---

**Questions or feedback?** Open an issue in this repository.
