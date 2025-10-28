# RSpec Style Guide Claude Skill

This skill helps Claude Code write and review RSpec tests according to our comprehensive style guide.

## Purpose

This skill provides Claude with:
- Step-by-step instructions for generating RSpec tests following our style guide
- A review checklist for validating existing tests
- Template prompts for common testing tasks
- Scripts for running automated checks (RuboCop and RSpec)

## Usage

When this skill is loaded, Claude will automatically use these instructions when:
- Writing new RSpec tests
- Reviewing existing spec files
- Fixing style guide violations
- Running test validation workflows

## Contents

- **INSTRUCTIONS.md**: Core rules and step-by-step algorithm for test generation
- **CHECKLIST.md**: Review points for validating test compliance
- **prompts/**: Template prompts for generating and reviewing specs
- **scripts/**: Automation scripts for running RuboCop and RSpec
- **resources/**: Additional references and documentation links

## Key Principles

1. Test behavior, not implementation
2. Organize tests by characteristics and states
3. Happy path comes first
4. Minimize cognitive load
5. Tests as quality indicators