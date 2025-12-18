# shoulda-matchers (Spec Writer)

Use shoulda-matchers to express Rails model contracts (validations, associations, enums) with readable failures.

## Preconditions

Read `.claude/rspec-testing-config.yml`:

- If `integrations.shoulda_matchers.enabled: false` → do not use shoulda-matchers.
- If `integrations.shoulda_matchers.enabled: true` but `integrations.shoulda_matchers.configured: false`:
  - Default: do not emit shoulda-matchers expectations.
  - AskUserQuestion: proceed without shoulda-matchers vs pause and configure it.

## Context7 Rule

Before using any matcher you are not 100% sure about, look it up via Context7:
- Resolve library id for `shoulda-matchers`
- Read docs for the exact matcher/topic you need (validations, associations, enums)

## Structure (Model Specs)

Keep contract checks separate from behavior specs:

```ruby
# good
RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
  end
end
```

Avoid bundling multiple contracts into one example:

```ruby
# bad
it 'is valid' do
  user = described_class.new
  expect(user).to be_invalid
  expect(user.errors[:email]).to be_present
  expect(user.account).to be_present
end
```

## Factory Interaction

- Prefer the project’s factory integration:
  - `integrations.factories.gem: factory_bot` → use `build(:user)` / `create(:user)` as needed.
  - `integrations.factories.gem: fabrication` → use `Fabricate.build(:user)` / `Fabricate(:user)` as needed.
- If factories are disabled/absent: use minimal model construction (`described_class.new`) only when the matcher supports it.

For some matchers (notably uniqueness), you may need persisted records. Use Context7 + local project patterns to choose the correct setup.

## Coverage Scope

Only assert contracts you can justify from reliable signals:

- If upstream metadata provides structured model DSL facts → prefer that.
- Otherwise, it is acceptable to read the model file and extract obvious declarations (e.g., `validates`, `belongs_to`, `has_many`, `enum`), but do not guess conditional logic.

For complex custom validators or conditional validations, prefer behavior-focused examples over brittle matcher usage.

