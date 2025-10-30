# RuboCop Configuration Examples for RSpec

This folder contains RuboCop configuration examples for RSpec projects.

## File Structure

- **rubocop-rspec.yml** - Rules for `rubocop-rspec` gem (RSpec-specific checks)
- **rubocop-factory_bot.yml** - Rules for `rubocop-factory_bot` gem (FactoryBot-specific checks)
- **rubocop-rspec-guide.yml** - Rules for `rubocop-rspec-guide` gem (Custom cops enforcing RSpec Style Guide)
- **.rubocop.yml.example** - Complete configuration combining all rules

## Required Gems

```ruby
# Gemfile
group :development, :test do
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rspec-guide', require: false
end
```

## Quick Start

### Complete Setup Example

Here's a complete `.rubocop.yml` showing how to use all three RSpec-related gems together:

```yaml
# .rubocop.yml

# Load all RSpec-related extensions
require:
  - rubocop-rspec
  - rubocop-rspec_rails  # If using Rails
  - rubocop-factory_bot
  - rubocop-rspec-guide

# RSpec cops (from rubocop-rspec)
RSpec/VerifiedDoubles:
  Enabled: true

RSpec/MessageSpies:
  Enabled: true
  EnforcedStyle: have_received

RSpec/MultipleExpectations:
  Max: 1
  Exclude:
    - 'spec/requests/**/*_spec.rb'
    - 'spec/system/**/*_spec.rb'

# FactoryBot cops (from rubocop-factory_bot)
FactoryBot/CreateList:
  Enabled: true

FactoryBot/SyntaxMethods:
  Enabled: true

# RSpec Style Guide cops (from rubocop-rspec-guide)
RSpecGuide/MinimumBehavioralCoverage:
  Enabled: true

RSpecGuide/HappyPathFirst:
  Enabled: true

RSpecGuide/ContextSetup:
  Enabled: true

RSpecGuide/DuplicateLetValues:
  Enabled: true
  WarnOnPartialDuplicates: true

FactoryBotGuide/DynamicAttributeEvaluation:
  Enabled: true
```

**Note:** `rubocop-rspec-guide` v0.4.0+ automatically injects its configuration, so no `inherit_gem` is needed.

## Usage

### Option 1: Separate files for each gem (Recommended)

Partial configs are self-contained and can be safely inherited. Each file includes the necessary `require:` block for its gem.

```yaml
# .rubocop.yml
inherit_from:
  - rubocop-configs/rubocop-rspec.yml
  - rubocop-configs/rubocop-factory_bot.yml
  - rubocop-configs/rubocop-rspec-guide.yml
```

That's it! Each partial config automatically loads its gem, so no additional `require:` needed in your main config.

**Why use partial configs?**
- Single source of truth - update once, apply everywhere
- Easier to manage in monorepos
- Can mix and match (e.g., only use rubocop-rspec + rubocop-rspec-guide)

### Option 2: Single configuration file

Copy `.rubocop.yml.example` to project root:

```bash
cp rubocop-configs/.rubocop.yml.example .rubocop.yml
```

This example file inherits from all partial configs for easier maintenance.

## Important Notes

### rubocop-rspec-guide v0.4.0+

Starting from **v0.4.0**, `rubocop-rspec-guide` automatically injects its configuration, including RSpec Language settings. This means:

- ✅ **No need** for `inherit_gem: rubocop-rspec-guide: config/default.yml`
- ✅ Automatic support for `let_it_be` and `let_it_be!` (from test-prof/rspec-rails)
- ✅ Better performance (InvariantExamples 4.25x faster)

Simply load the gem with `require:` - that's all you need!

See [rubocop-rspec-guide changelog](https://github.com/rspec-guide/rubocop-rspec-guide/blob/main/CHANGELOG.md) for details.

### Customizing Partial Configs

Each partial config is self-contained with its `require:` block. If you inherit them and need to override settings:

```yaml
# .rubocop.yml
inherit_from:
  - rubocop-configs/rubocop-rspec.yml
  - rubocop-configs/rubocop-factory_bot.yml
  - rubocop-configs/rubocop-rspec-guide.yml

# Override specific rules
RSpec/MultipleExpectations:
  Max: 3  # More lenient than default

# Add more excludes to existing ones
RSpec/ExampleLength:
  Exclude:
    - 'spec/integration/**/*_spec.rb'  # Adds to existing excludes
```

## Examples from Partial Configs

### RSpec Configuration (rubocop-rspec.yml)

Key cops for RSpec best practices:
- `RSpec/VerifiedDoubles` - Use real doubles instead of stubs
- `RSpec/MessageSpies` - Prefer `have_received` over `receive`
- `RSpec/MultipleExpectations` - One expectation per test (except integration)
- `RSpec/NestedGroups` - Limit nesting to 3 levels
- `RSpec/LeadingSubject` - Subject before hooks (Given/When/Then order)

### FactoryBot Configuration (rubocop-factory_bot.yml)

Key cops for FactoryBot best practices:
- `FactoryBot/CreateList` - Prefer `create_list` over `Array.new { create }`
- `FactoryBot/SyntaxMethods` - Use `create`/`build` instead of `FactoryBot.create`
- `FactoryBotGuide/DynamicAttributeEvaluation` - Wrap method calls in blocks

### RSpec Style Guide Configuration (rubocop-rspec-guide.yml)

Cops enforcing [RSpec Style Guide](https://github.com/AlexeyMatskevich/rspec-guide):
- `RSpecGuide/MinimumBehavioralCoverage` - At least 2 behavioral variations
- `RSpecGuide/HappyPathFirst` - Happy path before edge cases
- `RSpecGuide/ContextSetup` - Contexts must have setup (let/before)
- `RSpecGuide/DuplicateLetValues` - Detect duplicate let across contexts
- `RSpecGuide/InvariantExamples` - Extract repeated examples to shared_examples

## Troubleshooting

### "Cop not found" errors

If you see errors like `RSpec/VerifiedDoubles: Cop not found`, it means the extension wasn't loaded.

**Solution:** Ensure you have either:
1. The `require:` block in your main `.rubocop.yml`, OR
2. Used `inherit_from:` with our partial configs (they include `require:`)

### Arrays don't merge in RuboCop

When overriding cops with `Exclude:` lists, arrays replace rather than merge:

```yaml
# This REPLACES the existing excludes, not adds to them
RSpec/ExampleLength:
  Exclude:
    - 'spec/integration/**/*_spec.rb'
```

If you need to add to existing excludes, you must repeat them or use the partial config approach.

## Contributing

Found an issue or have a suggestion? Please open an issue in the [rspec-guide](https://github.com/AlexeyMatskevich/rspec-guide) repository.
