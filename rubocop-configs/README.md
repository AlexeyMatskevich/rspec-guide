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
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rspec-guide', require: false
  gem 'rubocop-rails', require: false  # For Rails-specific rules
end
```

## Usage

### Option 1: Separate files for each gem

Create separate configuration files and include them in main `.rubocop.yml`:

```yaml
# .rubocop.yml
inherit_from:
  - rubocop-configs/rubocop-rspec.yml
  - rubocop-configs/rubocop-factory_bot.yml
  - rubocop-configs/rubocop-rspec-guide.yml
```

### Option 2: Single configuration file

Copy `.rubocop.yml.example` to project root:

```bash
cp rubocop-configs/.rubocop.yml.example .rubocop.yml
```