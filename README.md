# RSpec Style Guide

An opinionated RSpec style guide built around cognitive load theory.
Unlike [Better Specs](https://www.betterspecs.org/) and similar references that collect isolated tips,
this guide provides a single coherent framework: organize tests by dependent characteristics,
treat specs as design feedback, and keep extraneous cognitive load to a minimum.

[![Russian](https://img.shields.io/badge/lang-ru-blue.svg)](guide.ru.md)
[![English](https://img.shields.io/badge/lang-en-blue.svg)](guide.en.md)

## What's here

- **Style guide** — the core document with rules, philosophy, and examples:
  [EN](guide.en.md) | [RU](guide.ru.md)
- **API contract testing** — when RSpec is not the right tool, and what to use instead:
  [EN](guide.api.en.md) | [RU](guide.api.ru.md)
- **Patterns** — reusable patterns for readable tests:
  [EN](patterns.en.md) | [RU](patterns.ru.md)

## Algorithms

Step-by-step workflows that reference the main guide:

- **Writing a test from scratch** — from choosing the spec level to final linter check:
  [EN](algoritm/test.en.md) | [RU](algoritm/test.ru.md)
- **Optimizing factories** — choosing between build/create/stub, organizing traits, avoiding anti-patterns:
  [EN](algoritm/factory.en.md) | [RU](algoritm/factory.ru.md)

## RuboCop

The [rubocop-rspec-guide](https://github.com/AlexeyMatskevich/rubocop-rspec-guide) gem provides custom cops that enforce key guide rules automatically.
Configuration examples and setup instructions: [rubocop-configs/](rubocop-configs/).

## Claude Code plugin (WIP)

[plugins/rspec-testing/](plugins/rspec-testing/) is a Claude Code plugin that teaches the agent to write RSpec tests following this guide. Work in progress.
See its [README](plugins/rspec-testing/README.md) for details.

## Contributing

Open an issue to discuss changes. Maintain both Russian and English versions.

## License

This guide is open source and available for use in your projects.
