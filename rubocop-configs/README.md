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

Simply load the gem with `require:` or `plugins:` - that's all you need!

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
