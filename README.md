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
| **[patterns.en.md](patterns.en.md)** | Useful patterns for readable tests | 522 |
| **[rspec-testing/](rspec-testing/)** | Claude Code Skill for AI-assisted testing | — |

**Also available in Russian:** [guide.ru.md](guide.ru.md) • [guide.api.ru.md](guide.api.ru.md) • [checklist.ru.md](checklist.ru.md) • [patterns.ru.md](patterns.ru.md)

## 🎯 What's Inside

### Main Guide ([guide.en.md](guide.en.md))

Comprehensive guide with philosophy, 28 practical rules, quick reference, and glossary.

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

## 🔄 Step-by-Step Algorithms

Practical workflows for writing tests and optimizing factories.

### Test Writing Algorithm ([algoritm/test.en.md](algoritm/test.en.md))

10-stage workflow for writing BDD tests from scratch. Guides you from determining the testing level to final validation with linters.

### Factory Optimization Algorithm ([algoritm/factory.en.md](algoritm/factory.en.md))

9-stage workflow for optimizing FactoryBot usage. Helps choose between build/create/stub, organize traits, and avoid common anti-patterns.

Both algorithms reference the main guide rules and include decision trees, examples, and checklists.

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

### 5. Use with Claude Code (AI Assistant)

If using Claude Code, install the RSpec Testing Skill to get automated assistance with all 28 rules. See [installation instructions](#-rspec-testing-skill-for-claude-code).

## 🤖 RSpec Testing Skill for Claude Code

A skill that teaches Claude Code to write RSpec tests following all 28 rules from this guide.

### Installation

```bash
# Global installation
cp -r rspec-testing ~/.claude/skills/rspec-testing

# Project-specific installation
mkdir -p .claude/skills
cp -r rspec-testing .claude/skills/rspec-testing
```

After installation, restart Claude Code. The skill will automatically activate when working with RSpec tests.

**Learn more:** [Skill documentation](rspec-testing/README.md) | [Claude Code Skills](https://docs.claude.com/en/docs/claude-code/skills)

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

### Before: flat structure

```ruby
# Bad: no characteristic hierarchy
describe OrderProcessor do
  it 'processes valid orders' do
    # ...
  end
  
  it 'rejects invalid orders' do
    # ...
  end
end
```

### After: characteristic-based hierarchy

```ruby
# Good: organized by dependent characteristics
describe OrderProcessor do
  describe '#process' do
    context 'when payment is authorized' do  # characteristic: payment_status
      context 'with items in stock' do       # characteristic: inventory_availability
        it 'creates shipment' do
          # ...
        end
      end
      
      context 'with items out of stock' do
        it 'creates backorder' do
          # ...
        end
      end
    end
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
