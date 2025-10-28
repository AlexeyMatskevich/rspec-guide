# Generate RSpec Tests Prompt Template

## Prompt for New Spec Generation

Use this template when asking Claude to generate new RSpec tests from scratch.

---

Generate RSpec tests for `[FILE_PATH]` following our strict style guide:

### Requirements:

1. **Identify and Test Public Interface**
   - List all public methods/behaviors to test
   - Create top-level `describe` for the class
   - Define `subject` at describe level only

2. **Structure Contexts by Characteristics**
   - Map independent characteristics (one per context level)
   - Create nested contexts for dependent characteristics
   - Use descriptive naming: "when/with/without"

3. **Implement Happy Path First**
   - Start each method with successful scenario
   - Add normal/valid case before any edge cases
   - Include minimal necessary setup

4. **Add Edge Cases and Error Scenarios**
   - Include at least one negative case per method
   - Test boundaries, nil inputs, error conditions
   - Place these AFTER happy path contexts

5. **Setup and Data**
   - Use `let` for unique context setup
   - Extract common setup to parent level
   - Use FactoryBot with traits for test data
   - Dynamic attributes in blocks: `{ Time.now }`

6. **Handle Duplication**
   - Convert repeated examples to `shared_examples`
   - Move duplicate `let` definitions up
   - Use `it_behaves_like` for common behavior

7. **Validation**
   - Run `bundle exec rubocop -DES`
   - Fix all RSpecGuide/* offenses
   - Run `bundle exec rspec`
   - Ensure all tests pass

### Output Format:

```ruby
# spec/[path]/[file]_spec.rb

require 'rails_helper'  # or 'spec_helper'

RSpec.describe [ClassName] do
  # Subject at top level only
  subject { described_class.new(params).perform }

  # Shared setup
  let(:common_dependency) { ... }

  describe '#method_name' do
    context 'with valid input' do  # Happy path first
      let(:specific_setup) { ... }

      it 'returns expected result' do
        expect(subject).to eq(expected)
      end

      context 'and additional condition' do  # Nested dependent
        let(:additional_setup) { ... }

        it 'handles special case' do
          expect(subject).to ...
        end
      end
    end

    context 'with invalid input' do  # Edge case after
      let(:invalid_setup) { ... }

      it 'raises appropriate error' do
        expect { subject }.to raise_error(ErrorClass)
      end
    end
  end

  # Shared examples if needed
  shared_examples 'common behavior' do
    it 'maintains invariant' do
      expect(subject.invariant).to be_truthy
    end
  end

  # Include shared examples where needed
  it_behaves_like 'common behavior'
end
```

### Post-Generation Tasks:

1. Review generated code for style guide compliance
2. Run RuboCop and fix any offenses
3. Execute tests and ensure they pass
4. Add comments explaining complex logic if needed

---

## Example Usage

"Generate RSpec tests for `app/models/order.rb` following our strict style guide:
- Test the `calculate_total` and `apply_coupon` methods
- Include happy paths and edge cases for each
- Use FactoryBot for test data
- Ensure compliance with our custom RuboCop rules"