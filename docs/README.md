# RSpec Testing Agent Documentation

This directory contains comprehensive documentation and tools for writing RSpec tests according to our style guide, both for AI agents and human developers.

## 📋 Requirements

- **Claude Code 2.0+** (for Claude Code workflow) or **Codex CLI** (for Codex workflow)
- Ruby project with Git initialized
- `rubocop-rspec-guide` gem installed

## 📁 Structure Overview

```
docs/
├── rspec-agent-playbook.md          # Main comprehensive guide for agents and humans
├── CHECKLIST.md                      # Universal review checklist for validation
├── rubocop-config-example.yml        # Example .rubocop.yml configuration
├── skill-rspec-style/                # Claude Code skill package
│   ├── README.md                     # Skill overview and usage
│   ├── INSTRUCTIONS.md               # Core rules and step-by-step algorithm
│   ├── CHECKLIST.md                  # (symlink to ../CHECKLIST.md)
│   ├── prompts/                      # Template prompts
│   │   ├── generate_spec.prompt.md  # For generating new specs
│   │   └── review_spec.prompt.md    # For reviewing existing specs
│   ├── scripts/                      # Automation scripts
│   │   ├── run_rubocop.sh          # RuboCop runner with style guide
│   │   └── run_rspec.sh            # RSpec test runner
│   └── resources/                   # Additional references
│       └── links.md                 # Documentation and tool links
└── codex-runbooks/                  # OpenAI Codex CLI guides
    ├── generate_rspec.md            # Step-by-step spec generation
    ├── review_spec.md               # Reviewing and fixing existing specs
    └── quick_reference.md           # Quick commands and patterns
```

## 📚 Main Documents

### [RSpec Agent Playbook](rspec-agent-playbook.md)
**The comprehensive guide** containing:
- Principles of the RSpec Style Guide
- Step-by-step algorithm for agents
- Specializations for Claude Code and Codex CLI
- Instructions for humans writing tests manually
- Acceptance criteria and automated checks
- Common mistakes and fixes
- Prompt templates

### [CHECKLIST.md](CHECKLIST.md)
**Universal review checklist** for all tools and users:
- Works with Claude Code, Codex CLI, and manual reviews
- Complete validation points for style guide compliance
- Organized by categories (structure, setup, examples, etc.)
- Includes RuboCop cop references for automated checking

## 🤖 For AI Agents

### Claude Code Setup

#### 1. Import the Skill

**Option A: Via Claude Skills UI (Recommended)**
- Open Claude Code settings → Skills
- Import the `skill-rspec-style/` folder
- Enable for your workspace

**Option B: Via ZIP**
```bash
zip -r rspec-style-skill.zip skill-rspec-style/
# Upload via Claude Skills interface
```

#### 2. Configure Your Project

```bash
# Install gems
bundle add rubocop-rspec-guide rubocop-rspec rubocop-factory_bot --group development
bundle install

# Get RuboCop config
curl -o .rubocop.yml https://raw.githubusercontent.com/AlexeyMatskevich/rspec-guide/main/docs/rubocop-config-example.yml
```

#### 3. Test the Setup

```bash
# Make scripts executable
chmod +x /path/to/skill-rspec-style/scripts/*.sh

# Run validation
./path/to/skill-rspec-style/scripts/run_rubocop.sh
```

#### 4. Usage

Ask Claude to:
- "Generate RSpec tests following our style guide"
- "Review these tests against the style guide"
- "Run validation scripts"

Scripts are available in Claude's terminal:
```bash
./path/to/skill-rspec-style/scripts/run_rubocop.sh
./path/to/skill-rspec-style/scripts/run_rspec.sh
```

#### 5. Troubleshooting

- **Missing skill**: Re-import the folder and enable in workspace settings
- **Permission denied**: Allow terminal execution and file edits in Claude permissions
- **Scripts not found**: Check paths and use absolute paths if needed

---

### Codex CLI Setup

#### 1. Access the Runbooks

```bash
# Clone this repo or download runbooks
git clone https://github.com/AlexeyMatskevich/rspec-guide.git
cd rspec-guide/docs/codex-runbooks
```

#### 2. Configure Your Project

```bash
# Install gems
bundle add rubocop-rspec-guide rubocop-rspec rubocop-factory_bot --group development
bundle install

# Get RuboCop config
curl -o .rubocop.yml https://raw.githubusercontent.com/AlexeyMatskevich/rspec-guide/main/docs/rubocop-config-example.yml
```

#### 3. Test the Setup

```bash
# Verify Codex access
codex "List files in this repository"

# Check mode
codex /approvals
```

#### 4. Usage

Follow the runbooks:
```bash
# Generate new tests
codex "Generate RSpec tests for app/models/user.rb following docs/codex-runbooks/generate_rspec.md"

# Review existing tests
codex "Review spec/models/user_spec.rb using docs/CHECKLIST.md"

# Run validation
codex exec "bundle exec rubocop -DES spec/"
```

#### 5. Troubleshooting

- **"rubocop-rspec-guide not found"**: Run `bundle add rubocop-rspec-guide --group development`
- **Permission denied**: Check Git status and approval mode (`codex /approvals`)
- **Can't find runbooks**: Use absolute paths to runbooks or copy them to your project

---

### Workflow Comparison

| Task | Claude Code | Codex CLI |
|------|------------|-----------|
| Setup | Import skill folder | Clone repo / download runbooks |
| Config | Install gems + config | Install gems + config |
| Generate | "Generate tests using skill" | Follow runbook interactively |
| Validate | Run bundled scripts | `codex exec "bundle exec rubocop"` |
| Fix | Automatic with checkpoints | Interactive or auto mode |

## 👩‍💻 For Human Developers

### Quick Start

1. **Read the principles** in [rspec-agent-playbook.md](rspec-agent-playbook.md#1-principles-of-the-rspec-style-guide-briefly)
2. **Follow the manual guide** in [Section 5](rspec-agent-playbook.md#5-instruction-guide-for-humans-writing-tests-manually)
3. **Use the checklist** in [CHECKLIST.md](CHECKLIST.md)
4. **Run validation** with the provided scripts

### Key Rules to Remember

✅ **DO:**
- Test behavior, not implementation
- Write happy path first, then edge cases
- One characteristic per context level
- Define subject at top-level describe only
- Use dynamic blocks in factories: `{ Time.now }`

❌ **DON'T:**
- Test private methods
- Put edge cases before happy path
- Define subject in contexts
- Duplicate setup in sibling contexts
- Use static time/random in factories

## 🔧 Validation Tools

### RuboCop Configuration

A complete example configuration is provided in [`rubocop-config-example.yml`](rubocop-config-example.yml).

To use it in your project:
```bash
# Option A: Download directly from GitHub (recommended)
curl -o .rubocop.yml https://raw.githubusercontent.com/AlexeyMatskevich/rspec-guide/main/docs/rubocop-config-example.yml

# Option B: If you have this repo cloned locally
cp /path/to/rspec-guide/docs/rubocop-config-example.yml .rubocop.yml

# Option C: Download and rename
curl -O https://raw.githubusercontent.com/AlexeyMatskevich/rspec-guide/main/docs/rubocop-config-example.yml
mv rubocop-config-example.yml .rubocop.yml
```

The configuration includes:
- All custom cops from `rubocop-rspec-guide`
- Recommended RSpec cops settings
- Appropriate exclusions for spec files

### Quick Validation Commands

```bash
# Check style compliance
bundle exec rubocop -DES spec/

# Run tests
bundle exec rspec

# Both checks
bundle exec rubocop -DES && bundle exec rspec
```

## 📋 Custom RuboCop Cops

The style guide is enforced by these custom cops from `rubocop-rspec-guide`:

1. **RSpecGuide/CharacteristicsAndContexts** - At least 2 contexts required
2. **RSpecGuide/HappyPathFirst** - Happy path before edge cases
3. **RSpecGuide/ContextSetup** - Each context needs unique setup
4. **RSpecGuide/DuplicateLetValues** - No duplicate `let` in siblings
5. **RSpecGuide/DuplicateBeforeHooks** - No duplicate `before` in siblings
6. **RSpecGuide/InvariantExamples** - Extract repeated examples
7. **FactoryBotGuide/DynamicAttributesForTimeAndRandom** - Dynamic blocks required

## 🚀 Getting Started

### Choose Your Tool

1. **Using Claude Code?** → [Jump to Claude Code Setup](#claude-code-setup)
2. **Using Codex CLI?** → [Jump to Codex CLI Setup](#codex-cli-setup)
3. **Manual testing?** → [Jump to Human Developers Section](#-for-human-developers)

### Quick Validation Check

Regardless of your tool, ensure your environment is ready:

```bash
# Check Ruby and Bundler
ruby --version  # Should be 2.7+
bundle --version

# Check Git repository
git status  # Should show a clean working tree

# Install style guide gems
bundle add rubocop-rspec-guide rubocop-rspec rubocop-factory_bot --group development
bundle install

# Verify RuboCop works
bundle exec rubocop --version
```

### For New Tests
1. **Claude Code**: Use skill prompts after [setup](#claude-code-setup)
2. **Codex CLI**: Follow [generate_rspec.md](codex-runbooks/generate_rspec.md) after [setup](#codex-cli-setup)
3. **Manual**: Use [generate_spec.prompt.md](skill-rspec-style/prompts/generate_spec.prompt.md) as template

### For Existing Tests
1. Review with [CHECKLIST.md](CHECKLIST.md)
2. **Claude Code**: Ask "review tests against style guide"
3. **Codex CLI**: Follow [review_spec.md](codex-runbooks/review_spec.md)
4. **Manual**: Run RuboCop and fix offenses iteratively

## 📖 Additional Resources

- **Main Style Guide Repository**: [AlexeyMatskevich/rspec-guide](https://github.com/AlexeyMatskevich/rspec-guide)
- **Custom Cops Gem**: [AlexeyMatskevich/rubocop-rspec-guide](https://github.com/AlexeyMatskevich/rubocop-rspec-guide)
- **Full Documentation Links**: [skill-rspec-style/resources/links.md](skill-rspec-style/resources/links.md)

## ✅ Success Criteria

Tests are considered compliant when:
- RuboCop shows **0 offenses** (especially RSpecGuide/* cops)
- All tests are **green** when running RSpec
- Structure follows the style guide principles
- Code is readable and maintainable

---

*Generated based on Deep Research results for optimal RSpec test generation with AI agents*