# RSpec Style Guide Resources

## Primary Documentation

### Main Style Guide
- **Repository**: [AlexeyMatskevich/rspec-guide](https://github.com/AlexeyMatskevich/rspec-guide)
- **English Guide**: [guide.en.md](https://github.com/AlexeyMatskevich/rspec-guide/blob/main/guide.en.md)
- **Russian Guide**: [guide.ru.md](https://github.com/AlexeyMatskevich/rspec-guide/blob/main/guide.ru.md)
- **Checklist (EN)**: [checklist.en.md](https://github.com/AlexeyMatskevich/rspec-guide/blob/main/checklist.en.md)

### API Testing Guide
- **API Contract Testing**: [guide.api.en.md](https://github.com/AlexeyMatskevich/rspec-guide/blob/main/guide.api.en.md)
- Covers when RSpec is NOT the right tool
- Recommends JSON Schema validators and OpenAPI tools

### RuboCop Integration
- **Custom Cops Gem**: [rubocop-rspec-guide](https://github.com/AlexeyMatskevich/rubocop-rspec-guide)
- **Configuration Examples**: [rubocop-configs](https://github.com/AlexeyMatskevich/rspec-guide/tree/main/rubocop-configs)
- **Example .rubocop.yml**: [.rubocop.yml.example](https://github.com/AlexeyMatskevich/rspec-guide/blob/main/rubocop-configs/.rubocop.yml.example)

## Custom RuboCop Cops

The `rubocop-rspec-guide` gem provides these custom cops:

1. **RSpecGuide/CharacteristicsAndContexts** - Requires at least 2 contexts
2. **RSpecGuide/HappyPathFirst** - Enforces happy path before edge cases
3. **RSpecGuide/ContextSetup** - Requires setup in each context
4. **RSpecGuide/DuplicateLetValues** - Detects duplicate `let` definitions
5. **RSpecGuide/DuplicateBeforeHooks** - Detects duplicate `before` hooks
6. **RSpecGuide/InvariantExamples** - Flags identical examples across contexts
7. **FactoryBotGuide/DynamicAttributesForTimeAndRandom** - Ensures proper factory syntax

## Key Concepts from the Guide

### Testing Philosophy
- **BDD (Behaviour Driven Development)**: Focus on behavior, not implementation
- **Cognitive Load Theory**: Minimize extraneous, maximize germane load
- **Tests as Documentation**: Tests should clearly describe system behavior

### Gherkin Mapping to RSpec
- **Given** → `let`, `let!`, `before` (setup)
- **When** → `subject`, action methods
- **Then** → `expect`, assertions

### Context Organization
- **Characteristic-based hierarchy**: One independent characteristic per context level
- **Happy path first**: Success scenarios before failure scenarios
- **Domain-based combining**: Group auth → authorization → business logic

## External References

### Official RSpec Documentation
- [RSpec Core](https://rspec.info/documentation/core/)
- [RSpec Expectations](https://rspec.info/documentation/expectations/)
- [RSpec Mocks](https://rspec.info/documentation/mocks/)

### FactoryBot
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md)
- [FactoryBot Rails](https://github.com/thoughtbot/factory_bot_rails)

### RuboCop RSpec
- [RuboCop RSpec](https://github.com/rubocop/rubocop-rspec)
- [RuboCop Performance](https://github.com/rubocop/rubocop-performance)

### Time Testing
- [ActiveSupport Testing TimeHelpers](https://api.rubyonrails.org/classes/ActiveSupport/Testing/TimeHelpers.html)
- [Timecop Gem](https://github.com/travisjeffery/timecop) (alternative)

## Related Tools

### API Contract Testing (from guide.api)
- [json_matchers](https://github.com/thoughtbot/json_matchers) - JSON Schema validation
- [rspec-openapi](https://github.com/k0kubun/rspec-openapi) - Generate OpenAPI from RSpec
- [rswag](https://github.com/rswag/rswag) - OpenAPI/Swagger for Rails

### Test Quality Tools
- [SimpleCov](https://github.com/simplecov-ruby/simplecov) - Code coverage
- [mutant](https://github.com/mbj/mutant) - Mutation testing
- [rspec-benchmark](https://github.com/piotrmurach/rspec-benchmark) - Performance testing

## Quick Start Commands

```bash
# Install the custom cops gem
gem install rubocop-rspec-guide

# Or add to Gemfile
gem 'rubocop-rspec-guide', group: :development

# Run with style guide rules
bundle exec rubocop -DES

# Run tests
bundle exec rspec
```