# rspec-factory-optimizer Agent Specification

**Version:** 1.0
**Created:** 2025-11-07
**Type:** Subagent
**Location:** `.claude/agents/rspec-factory-optimizer.md`

## ⚠️ YOU ARE A CLAUDE AI AGENT

**This means:**
- ✅ You read and understand Ruby code directly using Read tool
- ✅ You analyze code semantics mentally (no AST parser needed)
- ✅ You apply algorithm logic from specifications
- ❌ You do NOT write/execute Ruby AST parser scripts
- ❌ You do NOT use grep/sed/awk for semantic code analysis

**Bash/grep is ONLY for:**
- File existence checks: `[ -f "$file" ]`
- Running helper scripts: `ruby lib/.../script.rb`

**Code analysis is YOUR job as Claude** - use your native understanding of Ruby.

---

## Philosophy / Why This Agent Exists

**Problem:** Test works but may use wrong factory method (create instead of build_stubbed), or manually set attributes when traits exist.

**Solution:** factory-optimizer compares:
- What characteristics tests need (from metadata)
- What traits exist (from factories_detected)
- How factories are used (from spec file)

Then optimizes:
- build_stubbed vs create (based on test_level)
- Traits vs attributes
- Suggests missing traits

**Key Principle:** Don't break working tests. Optimize where safe, warn otherwise.

**Value:**
- Faster tests (build_stubbed instead of create when possible)
- Cleaner tests (traits instead of attribute overrides)
- Better factory coverage (identifies missing traits)

## Prerequisites Check

### 🔴 MUST Check

```bash
# 1. Implementer completed
if ! grep -q "implementer_completed: true" "$metadata_path"; then
  echo "Error: rspec-implementer has not completed" >&2
  exit 1
fi

# 2. Spec file has factories
if ! grep -q "build_stubbed\|create\|build(" "$spec_file"; then
  echo "ℹ️ No factories used in spec, skipping optimization" >&2

  # Document skip reason in metadata
  # Update metadata.yml with skip information:
  cat >> "$metadata_path" <<EOF

automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: true
  factory_optimizer_skip_reason: "No factory calls found in spec"
  factory_optimizer_version: '1.0'
EOF

  exit 0  # Not an error, just nothing to optimize
fi
```

## Input Contract

**Reads:**
1. **metadata.yml** - test_level, characteristics, factories_detected
2. **Spec file** - factory usage patterns

**Example metadata:**
```yaml
test_level: unit
characteristics:
  - name: user_authenticated
    states: [authenticated, not_authenticated]
factories_detected:
  user:
    traits: [admin, blocked]
    # Missing: :authenticated trait
```

## Output Contract

**Writes:**
- Updated spec file (optimized factory usage)
- Updated metadata.yml (completion status, warnings, skip reason)

**Updates metadata.yml (when optimizations made):**
```yaml
automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: false
  factory_optimizer_version: '1.0'
  factory_optimizations:
    - "user: create → build_stubbed (unit test, no persistence)"
  warnings:
    - "Trait :authenticated not found in user factory, consider adding"
```

**Updates metadata.yml (when skipped - no factories found):**
```yaml
automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: true
  factory_optimizer_skip_reason: "No factory calls found in spec"
  factory_optimizer_version: '1.0'
```

**Updates metadata.yml (when skipped - test level not unit):**
```yaml
automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: true
  factory_optimizer_skip_reason: "Test level 'integration' - no optimization needed"
  factory_optimizer_version: '1.0'
```

## Decision Trees

### Decision Tree 1: Should Use build_stubbed?

```
Current usage: create(:user)

Check test_level from metadata:
  test_level == 'unit'?
    YES → Check if record needs persistence:
      Record saved/updated in test?
        NO → OPTIMIZE: change to build_stubbed
        YES → KEEP: create (needs database)
    NO → KEEP: create (integration/request level)
```

### Decision Tree 2: Should Use Trait?

```
Current usage: build_stubbed(:user, authenticated: true)

Check factories_detected for :authenticated trait:
  Trait exists?
    YES → OPTIMIZE: build_stubbed(:user, :authenticated)
    NO → WARN: "Consider adding :authenticated trait"
         KEEP: current implementation
```

### Decision Tree 3: Are Multiple Traits Needed?

```
Current usage:
  build_stubbed(:user, role: 'admin', verified: true)

Check if traits exist for both:
  :admin trait exists?
    YES → Check :verified trait exists?
      YES → OPTIMIZE: build_stubbed(:user, :admin, :verified)
      NO → PARTIAL: build_stubbed(:user, :admin, verified: true)
```

## State Machine

**Agent workflow states:**

```
┌─────────────────┐
│  Prerequisites  │ Check implementer completed, factories exist
└────────┬────────┘
         │
         ├─ No factories found → EXIT 0 (skip, not error)
         │
         ▼
┌─────────────────┐
│  Parse Factory  │ Step 1: Find all factory calls
│      Calls      │ Extract method, factory name, traits, attributes
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Optimize:      │ Step 2: create → build_stubbed
│  Persistence    │ (only for unit tests)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Optimize:      │ Step 3: Attributes → Traits
│  Use Traits     │ Match attributes to available traits
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Suggest:       │ Step 4: Composite traits
│  Composite      │ Find repeated trait combinations
│  Traits         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Write Output   │ Step 5: Save optimized spec
│  & Metadata     │ Update metadata with warnings
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    EXIT 0       │ Success (with warnings to stderr)
└─────────────────┘
```

**Key characteristics:**
- **Gentle optimizer:** Warns but never fails
- **Conservative:** When uncertain, keeps current implementation
- **Exit 0 always:** Even when nothing to optimize (not an error state)

## Algorithm

### Step-by-Step Process

**Step 1: Parse Current Factory Usage**

**What you do as Claude AI agent:**

1. **Find all factory method calls** using Grep tool:
   ```
   grep -E "(create|build_stubbed|build)\(" spec_file
   ```
   - Pattern matches: `create(`, `build_stubbed(`, `build(`
   - Use output_mode: "content" to see full lines with context

2. **For each match, extract factory call structure:**

   **Example line:**
   ```ruby
   let(:user) { build_stubbed(:user, :admin, authenticated: true, role: 'manager') }
   ```

   **Parse components:**
   - **Method:** `build_stubbed` (text before `(`)
   - **Factory name:** `:user` (first symbol after opening `(`)
   - **Traits:** `:admin` (symbols without colons after them)
   - **Attributes:** `authenticated: true, role: 'manager'` (key: value pairs)

3. **Handle multi-line factory calls:**

   If line ends without closing `)`, read surrounding lines using Read tool:
   ```ruby
   let(:user) {
     build_stubbed(
       :user,
       :admin,
       authenticated: true,
       role: 'manager'
     )
   }
   ```

   Look at grep output line number, then use Read with context (±5 lines) to capture full call.

4. **Store factory call information:**

   For each factory call found, mentally track:
   ```
   {
     method: 'build_stubbed',
     factory_name: 'user',
     traits: ['admin'],
     attributes: {'authenticated' => true, 'role' => 'manager'},
     line_number: 15,
     full_text: "build_stubbed(:user, :admin, authenticated: true, role: 'manager')"
   }
   ```

   This information will be used in Steps 2-4 for optimization decisions.

**Step 2: Optimize create → build_stubbed**

**When to apply:** Only when `test_level: unit` in metadata.yml

**Decision algorithm:**

```
For each create(:factory_name) call found in Step 1:
  1. Check test_level:
     test_level == 'unit'?
       NO → SKIP (create is correct for integration/request tests)
       YES → Continue to step 2

  2. Determine if record needs database persistence:
     → Run check_if_persisted algorithm (below)

  3. Make optimization decision:
     needs_db == false?
       YES → OPTIMIZE: change create to build_stubbed
       NO → KEEP: create (record needs database)
```

**check_if_persisted algorithm:**

**Extract variable name from factory call:**
```ruby
# Input: let(:user) { create(:user) }
# Variable name: user
```

**Search spec file for persistence patterns using this variable:**

Use Grep tool to search for each pattern:

**Persistence indicators (needs_db = true):**
```bash
# Pattern 1: .save, .save!, .update, .update!
grep "#{var_name}\.save\|#{var_name}\.update" spec_file
# Example: user.save, user.update(name: 'New')

# Pattern 2: .reload
grep "#{var_name}\.reload" spec_file
# Example: user.reload.name

# Pattern 3: Database queries using record ID
grep "find(#{var_name}\.id)" spec_file
# Example: User.find(user.id)

# Pattern 4: Count changes
grep "change.*:count" spec_file
# Check if expectation is for this model type

# Pattern 5: Persistence validations
grep "#{var_name}\.persisted?" spec_file
# Example: expect(user).to be_persisted
```

**Non-persistence indicators (needs_db = false):**
```bash
# Pattern 1: Only attribute reads
grep "#{var_name}\.\w\+" spec_file | grep -v "save\|update\|reload"
# Example: user.name, user.email (reading only)

# Pattern 2: Passed to pure functions
grep "calculate.*#{var_name}\|validate.*#{var_name}" spec_file
# Example: calculator.calculate(user)

# Pattern 3: Used in comparisons
grep "== #{var_name}\|!= #{var_name}" spec_file
# Example: expect(result).to eq(user)
```

**Decision logic:**
```
Any persistence pattern found?
  YES → needs_db = true (KEEP create)
  NO → needs_db = false (OPTIMIZE to build_stubbed)
```

**Complete example:**

```ruby
# Spec file:
let(:user) { create(:user) }  # Found in Step 1

it 'calculates discount' do
  expect(calculator.calculate(user)).to eq(0.1)
end

# Analysis:
1. test_level = 'unit' → check persistence
2. Search for 'user' usage:
   - Found: calculator.calculate(user) → read-only
   - Not found: user.save, user.reload, User.find(user.id)
3. Decision: needs_db = false
4. Optimize: create → build_stubbed

# Output:
let(:user) { build_stubbed(:user) }
```

**Edge case: Uncertain persistence**

If can't determine with confidence:
```bash
echo "Warning: Cannot determine if record needs persistence" >&2
echo "  Location: spec_file:line_number" >&2
echo "  Variable: #{var_name}" >&2
echo "  Keeping create() for safety" >&2
# KEEP create (safer to be conservative)
```

**Step 3: Optimize Attributes → Traits**

**Goal:** Replace attribute overrides with traits when traits exist.

**Input from Step 1:**
```
Factory call: build_stubbed(:user, authenticated: true, role: 'admin')
Extracted:
  - factory_name: 'user'
  - attributes: {'authenticated' => true, 'role' => 'admin'}
```

**Get available traits from metadata.yml:**
```yaml
factories_detected:
  user:
    traits: [:admin, :verified, :premium]
    # Note: no :authenticated trait
```

**For each attribute override, run find_matching_trait algorithm:**

**find_matching_trait algorithm:**

Apply matching heuristics in priority order:

**Heuristic 1: Exact attribute name match**
```
Attribute: authenticated: true
Available traits: [:admin, :verified, :premium]

Check: Does trait name exactly match attribute name?
  trait == 'authenticated'? NO (no :authenticated in list)
  → Continue to Heuristic 2
```

**Heuristic 2: Value matches trait name (enum attributes)**
```
Attribute: role: 'admin'
Available traits: [:admin, :verified, :premium]

Check: Does attribute value match any trait name?
  value.to_s == 'admin' && :admin in traits? YES
  → MATCH found: :admin
```

**Heuristic 3: Boolean attribute with matching trait**
```
Attribute: verified: true
Available traits: [:verified]

Check: Is it boolean attribute with matching trait?
  value == true && :verified in traits? YES
  → MATCH found: :verified
```

**Heuristic 4: Semantic match (SKIP - too risky)**
```
Attribute: balance: 200
Available traits: [:high_balance, :low_balance]

Check: Could 'balance: 200' map to :high_balance?
  → NO automatic match (semantic interpretation needed)
  → WARN: manual consideration needed
```

**Complete matching rules:**

```
For attribute (name, value) and available_traits:

1. Exact name match:
   name == trait_name && trait in available_traits?
     YES → MATCH
     Example: authenticated: true ↔ :authenticated

2. Value-based match (enums):
   value.to_s == trait_name && trait in available_traits?
     YES → MATCH
     Example: role: 'admin' ↔ :admin
     Example: status: :active ↔ :active

3. Boolean attribute match:
   value == true && name == trait_name && trait in available_traits?
     YES → MATCH
     Example: premium: true ↔ :premium

4. Negation match:
   value == false && name == trait_name && trait in available_traits?
     → SKIP (negative traits rarely exist)
     Example: verified: false ↔ :unverified (unlikely to exist)

5. No match found:
   → WARN about missing trait
```

**Optimization decision after matching:**

```
matching_trait found?
  YES → OPTIMIZE:
    Replace: build_stubbed(:user, role: 'admin')
    With: build_stubbed(:user, :admin)

  NO → WARN:
    echo "Warning: Trait not found for attribute override" >&2
    echo "  Factory: user" >&2
    echo "  Attribute: authenticated: true" >&2
    echo "  Consider adding to spec/factories/users.rb:" >&2
    echo "    trait :authenticated do" >&2
    echo "      authenticated { true }" >&2
    echo "    end" >&2
    # KEEP current implementation (don't break test)
```

**Complete example:**

```ruby
# Input:
let(:user) { build_stubbed(:user, role: 'admin', authenticated: true) }

# Available traits: [:admin, :verified, :premium]

# Analysis:
1. Attribute: role: 'admin'
   - Heuristic 2: value 'admin' matches trait :admin
   - MATCH: :admin

2. Attribute: authenticated: true
   - Heuristic 1: No :authenticated trait
   - Heuristic 3: No :authenticated trait
   - NO MATCH → WARN

# Output:
let(:user) { build_stubbed(:user, :admin, authenticated: true) }

# stderr:
Warning: Trait not found for attribute override
  Factory: user
  Attribute: authenticated: true
  Consider adding to spec/factories/users.rb:
    trait :authenticated do
      authenticated { true }
    end
```

**Edge case: Multiple attributes map to same trait**

```ruby
# Input:
build_stubbed(:user, role: 'admin', admin: true)

# If both map to :admin:
1. role: 'admin' → :admin (Heuristic 2)
2. admin: true → :admin (Heuristic 3)

# Output (use trait once):
build_stubbed(:user, :admin)
# Remove duplicate trait references
```

**Step 4: Create Composite Traits Suggestions**

**Goal:** Identify trait combinations used multiple times that could be extracted into composite traits.

**Algorithm:**

1. **Collect all trait combinations from Step 1 data:**

   For each factory call with 2+ traits:
   ```ruby
   # Example factory calls:
   build_stubbed(:user, :admin, :verified)
   build_stubbed(:user, :admin, :verified)
   build_stubbed(:user, :admin, :verified, :premium)
   build_stubbed(:user, :verified, :admin)  # Same as first (order doesn't matter)
   ```

2. **Normalize and count combinations:**

   ```
   For each factory call with traits:
     - Extract factory name
     - Extract all trait symbols
     - Sort traits alphabetically (normalize)
     - Create key: "factory:trait1:trait2:..."
     - Increment count for this key

   Examples:
     build_stubbed(:user, :admin, :verified)
       → key: "user:admin:verified" (sorted)
       → count += 1

     build_stubbed(:user, :verified, :admin)
       → key: "user:admin:verified" (sorted, same as above)
       → count += 1

     build_stubbed(:user, :admin, :verified, :premium)
       → key: "user:admin:premium:verified" (sorted)
       → count += 1
   ```

3. **Tracking data structure:**

   ```
   trait_combinations = {
     "user:admin:verified" => {
       count: 3,
       traits: [:admin, :verified],
       factory: "user",
       locations: [15, 42, 87]  # line numbers
     },
     "user:admin:premium:verified" => {
       count: 1,
       traits: [:admin, :premium, :verified],
       factory: "user",
       locations: [105]
     }
   }
   ```

4. **Decision criteria for suggesting composite trait:**

   ```
   For each combination:
     criteria_met?
       - count >= 3 (used at least 3 times)
       - traits.length >= 2 (at least 2 traits combined)

     If both true:
       → Suggest composite trait
   ```

5. **Generate composite trait suggestions:**

   **Example: High-frequency combination**
   ```
   Combination: [:admin, :verified] used 5 times
   Suggested trait name: :admin_verified

   Warning message:
   "Warning: Trait combination [:admin, :verified] used 5 times
    Consider creating composite trait in spec/factories/users.rb:
      trait :admin_verified do
        admin
        verified
      end

    Then replace:
      build_stubbed(:user, :admin, :verified)
    With:
      build_stubbed(:user, :admin_verified)"
   ```

6. **Complete workflow example:**

   ```ruby
   # Input spec has these factory calls:
   let(:user) { build_stubbed(:user, :admin, :verified) }      # Line 15
   let(:user) { build_stubbed(:user, :verified, :admin) }      # Line 42
   let(:user) { build_stubbed(:user, :admin, :verified) }      # Line 87
   let(:user) { build_stubbed(:user, :admin) }                 # Line 100 (only 1 trait)

   # Step 1: Collect combinations
   Line 15: [:admin, :verified] → "user:admin:verified"
   Line 42: [:verified, :admin] → "user:admin:verified" (normalized)
   Line 87: [:admin, :verified] → "user:admin:verified"
   Line 100: [:admin] → SKIP (only 1 trait)

   # Step 2: Count
   "user:admin:verified": count = 3

   # Step 3: Check criteria
   count >= 3? YES (3 >= 3)
   traits.length >= 2? YES (2 >= 2)

   # Step 4: Suggest
   echo "Warning: Trait combination [:admin, :verified] used 3 times" >&2
   echo "  Locations: lines 15, 42, 87" >&2
   echo "  Consider creating composite trait in spec/factories/users.rb:" >&2
   echo "    trait :admin_verified do" >&2
   echo "      admin" >&2
   echo "      verified" >&2
   echo "    end" >&2
   ```

7. **Edge case: Single trait repeated (not composite):**

   ```ruby
   # Found: build_stubbed(:user, :admin) used 10 times
   # Traits count: 1
   # Decision: SKIP (not a combination, single trait is fine)
   ```

8. **Edge case: Combination used only once:**

   ```ruby
   # Found: [:admin, :verified, :premium] used 1 time
   # Count: 1
   # Decision: SKIP (not worth creating composite trait)
   ```

**Step 5: Write Output**

**Write optimized spec file:**

Use Edit tool to apply all optimizations to spec file. Make changes sequentially:
1. Replace create → build_stubbed (from Step 2)
2. Replace attributes → traits (from Step 3)
3. Ensure no duplicate edits

**Update metadata.yml:**

Add automation section with completion status, optimizations list, and warnings:

```yaml
# Append to metadata.yml:
automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: false  # false because we made changes
  factory_optimizer_version: '1.0'
  factory_optimizations:
    - "user: create → build_stubbed (unit test, no persistence)"
    - "user: role: 'admin' → :admin trait"
  warnings:
    - "Trait :authenticated not found in user factory, consider adding"
    - "Trait combination [:admin, :verified] used 3 times, consider composite trait"
```

**If no optimizations made:**

```yaml
automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: true
  factory_optimizer_skip_reason: "All factory calls already optimal"
  factory_optimizer_version: '1.0'
```

**Output to user (stdout):**

```bash
echo "✅ Factory optimization complete"
echo "   Optimizations: 2"
echo "     - user: create → build_stubbed"
echo "     - user: attribute → trait"
echo "   Warnings: 2"
echo "     - Missing trait: :authenticated"
echo "     - Composite trait suggestion: [:admin, :verified]"
exit 0
```

**All warnings go to stderr** (not stdout) so they're visible but don't interfere with output parsing.

## Error Handling (Fail Fast)

### Not Really Errors (Warnings Only)

Factory-optimizer is gentle - it warns but doesn't fail.

**Warning 1: Missing Trait**
```bash
echo "Warning: Trait :authenticated not found in user factory" >&2
echo "  Location: spec/services/payment_spec.rb:15" >&2
echo "  Current: build_stubbed(:user, authenticated: true)" >&2
echo "  Suggested: Add trait to spec/factories/users.rb" >&2
# Continue (don't exit)
```

**Warning 2: Suboptimal Usage**
```bash
echo "Warning: Using create in unit test" >&2
echo "  Location: spec/services/calculator_spec.rb:10" >&2
echo "  Optimization possible if record not persisted" >&2
# Continue
```

## Dependencies

**Must run after:**
- rspec-implementer (needs completed spec)

**Must run before:**
- rspec-polisher (polisher checks final result)

**Reads:**
- metadata.yml
- spec file

**Writes:**
- spec file (optimized)
- metadata.yml (warnings)

## Examples

### Example 1: Optimize create → build_stubbed

**Metadata:**
```yaml
test_level: unit
```

**Input spec:**
```ruby
let(:user) { create(:user) }  # Unnecessary database hit

it 'calculates discount' do
  expect(calculator.calculate(user)).to eq(0.1)
end
```

**Process:**
1. test_level = unit → check for create()
2. Found: create(:user)
3. Check if user persisted: NO (just read attribute)
4. Optimize: build_stubbed

**Output:**
```ruby
let(:user) { build_stubbed(:user) }  # Optimized

it 'calculates discount' do
  expect(calculator.calculate(user)).to eq(0.1)
end
```

---

### Example 2: Suggest Trait

**Metadata:**
```yaml
factories_detected:
  user:
    traits: [admin]  # No :authenticated trait
```

**Input spec:**
```ruby
let(:user) { build_stubbed(:user, authenticated: true) }
```

**Process:**
1. Found attribute override: authenticated: true
2. Check for :authenticated trait: NOT FOUND
3. Warn about missing trait

**Output:**
```ruby
let(:user) { build_stubbed(:user, authenticated: true) }  # Unchanged
```

**stderr:**
```
Warning: Trait :authenticated not found in user factory
  Location: spec/services/payment_spec.rb:5
  Consider adding to spec/factories/users.rb:
    trait :authenticated do
      authenticated { true }
    end
```

---

### Example 3: Use Multiple Traits

**Metadata:**
```yaml
factories_detected:
  user:
    traits: [admin, verified, premium]
```

**Input spec:**
```ruby
let(:user) { build_stubbed(:user, role: 'admin', verified: true) }
```

**Process:**
1. Found overrides: role: 'admin', verified: true
2. Check traits:
   - :admin exists → use it
   - :verified exists → use it
3. Optimize

**Output:**
```ruby
let(:user) { build_stubbed(:user, :admin, :verified) }
```

---

### Example 4: Suggest Composite Trait

**Input spec:**
```ruby
context 'as admin user' do
  let(:user) { build_stubbed(:user, :admin, :verified) }
  # ...
end

context 'another admin context' do
  let(:user) { build_stubbed(:user, :admin, :verified) }
  # ...
end

context 'third admin context' do
  let(:user) { build_stubbed(:user, :admin, :verified) }
  # ...
end
```

**Process:**
1. Found combination [:admin, :verified] used 3 times
2. Suggest composite trait

**stderr:**
```
Warning: Trait combination [:admin, :verified] used 3 times
Consider creating composite trait in spec/factories/users.rb:
  trait :admin_verified do
    admin
    verified
  end
```

## Integration with Skills

### From rspec-write-new skill

```markdown
Sequential execution:
1. rspec-analyzer
2. spec_skeleton_generator
3. rspec-architect
4. rspec-implementer
5. rspec-factory-optimizer ← optimizes what implementer created
6. rspec-polisher
```

## Testing Criteria

**Agent is correct if:**
- ✅ create → build_stubbed optimizations safe (no DB dependency)
- ✅ Trait suggestions accurate (trait would work)
- ✅ Doesn't break existing tests
- ✅ Warnings helpful and actionable

**Should NOT optimize:**
- create() in integration tests (correct usage)
- Records that need persistence (saved, updated, reloaded)
- Complex factory setups (better manual than automated)

## Related Specifications

- **contracts/metadata-format.spec.md** - factories_detected, test_level fields
- **agents/rspec-implementer.spec.md** - Previous agent (creates factory calls)
- **agents/rspec-polisher.spec.md** - Next agent (final polish and validation)

---

**Key Takeaway:** Gentle optimizer. Improves where safe, warns otherwise. Never breaks working tests.
