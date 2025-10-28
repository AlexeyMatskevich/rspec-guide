# Review RSpec Tests Prompt Template

## Prompt for Reviewing Existing Specs

Use this template when asking Claude to review and improve existing RSpec tests.

---

Review the RSpec file `[SPEC_FILE_PATH]` for compliance with our style guide.

### Check for These Issues:

#### 1. Structure Violations
- [ ] Missing multiple contexts (needs happy path + edge case)
  - Flag: Only one context or straight `it` blocks
  - Fix: Add contexts for different scenarios
  - Cop: `RSpecGuide/CharacteristicsAndContexts`

- [ ] Wrong ordering (edge cases before happy path)
  - Flag: Error contexts appear first
  - Fix: Reorder to put success scenarios first
  - Cop: `RSpecGuide/HappyPathFirst`

- [ ] Poor context hierarchy
  - Flag: Multiple characteristics in one context
  - Fix: Split into nested contexts (one characteristic per level)

#### 2. Setup Issues
- [ ] Subject defined in contexts
  - Flag: `subject { }` inside context blocks
  - Fix: Move subject to top-level describe
  - Cop: `RSpecGuide/ContextSetup`

- [ ] Empty contexts without setup
  - Flag: Context with no `let` or `before`
  - Fix: Add unique setup or remove context
  - Cop: `RSpecGuide/ContextSetup`

- [ ] Duplicate setup across siblings
  - Flag: Same `let` in multiple contexts
  - Fix: Extract to parent level
  - Cop: `RSpecGuide/DuplicateLetValues`

#### 3. Example Problems
- [ ] Testing implementation instead of behavior
  - Flag: `expect(obj).to receive(:private_method)`
  - Fix: Test observable outcomes instead

- [ ] Identical examples in all contexts
  - Flag: Same `it` block repeated
  - Fix: Extract to `shared_examples`
  - Cop: `RSpecGuide/InvariantExamples`

- [ ] Unclear descriptions
  - Flag: Vague `it` descriptions like "works"
  - Fix: Use specific behavior descriptions

#### 4. Data & Factory Issues
- [ ] Static time/random in factories
  - Flag: `Time.now` without block
  - Fix: Wrap in block `{ Time.now }`
  - Cop: `FactoryBotGuide/DynamicAttributesForTimeAndRandom`

- [ ] Not using FactoryBot
  - Flag: Hand-coded test data
  - Fix: Create factories with traits

#### 5. Anti-patterns
- [ ] Using `any_instance`
  - Flag: `allow_any_instance_of`
  - Fix: Use dependency injection

- [ ] Deprecated syntax
  - Flag: `should` instead of `expect`
  - Fix: Update to modern syntax

### Output Format:

```markdown
## Review Summary

### ✅ Compliant Areas
- [List what's already following the guide]

### ❌ Issues Found

#### Issue 1: [Issue Name]
- **Location**: Line X-Y
- **Problem**: [Describe the violation]
- **Fix**: [Specific correction needed]
- **Example**:
  ```ruby
  # Bad (current)
  [current code]

  # Good (suggested)
  [corrected code]
  ```

#### Issue 2: [Next Issue]
...

### 📋 Automated Checks

Run these commands to verify:
```bash
bundle exec rubocop -DES
bundle exec rspec
```

Current status:
- RuboCop offenses: [X]
- Test failures: [Y]

### 🎯 Priority Fixes

1. [Most critical issue]
2. [Next priority]
3. [Lower priority]
```

### Review Process:

1. **Read** the entire spec file
2. **Identify** violations against checklist
3. **Categorize** issues by severity
4. **Suggest** specific fixes with examples
5. **Verify** with RuboCop and RSpec runs

---

## Example Usage

"Review `spec/models/user_spec.rb` for compliance with our style guide. List all violations with specific fixes. Pay special attention to context structure, setup duplication, and factory usage."