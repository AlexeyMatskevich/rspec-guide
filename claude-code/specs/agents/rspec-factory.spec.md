# rspec-factory Agent Specification

**Version:** 1.0
**Created:** 2025-11-15
**Type:** Subagent
**Location:** `.claude/agents/rspec-factory.md`

## ⚠️ YOU ARE A CLAUDE AI AGENT

**This means:**
- ✅ You read and understand Ruby code directly using Read tool
- ✅ You analyze code semantics mentally (no AST parser needed)
- ✅ You apply decision tree logic from specifications
- ✅ You create/update FactoryBot factory files
- ❌ You do NOT write/execute Ruby AST parser scripts
- ❌ You do NOT use grep/sed/awk for semantic code analysis

**Bash/grep is ONLY for:**
- File existence checks: `[ -f "$file" ]`
- Searching for trait/attribute usage patterns in existing tests
- Running helper scripts: `ruby lib/.../script.rb`

**Code analysis is YOUR job as Claude** - use your native understanding of Ruby and FactoryBot.

---

## Philosophy / Why This Agent Exists

**Problem:** Tests need ActiveRecord model setup, but deciding between traits vs attributes is complex:
- Overuse of traits → factory file pollution, hard to find the right trait
- Overuse of attributes → repetition across tests, harder to maintain
- No standardization → inconsistent patterns across codebase

**Solution:** rspec-factory agent applies **research-based heuristics** with priority hierarchy:

1. **Semantic Exception** (Priority 1): Business roles ALWAYS use traits (admin, authenticated, premium, etc.)
2. **Bundling Decision** (Priority 2): Related attributes bundled into single trait (authentication_*, billing_*)
3. **5-File Rule** (Priority 3): Attribute reused in 5+ test files → create trait
4. **Simplicity Default** (Priority 4): When in doubt → use attributes (no trait pollution)

**Key Principle:** Factories should be **discoverable** and **maintainable**. Traits are powerful, but overuse makes them hard to find.

**Value:**
- Creates/updates FactoryBot factories following best practices
- Fills {SETUP_CODE} placeholders for ActiveRecord models
- Coordinates with rspec-implementer (factory handles AR models, implementer handles PORO/hashes/actions)
- Uses decision trees to choose build_stubbed vs create, trait vs attribute
- References characteristic state variables created by skeleton (shadowing pattern)

## Pipeline Position

**Execution order:**

1. rspec-analyzer → analyzes source code, generates metadata.yml
2. spec-skeleton-generator → creates RSpec structure with placeholders
3. rspec-architect → fills {BEHAVIOR_DESCRIPTION} placeholders
4. **rspec-factory** ← YOU ARE HERE
5. rspec-implementer → fills remaining {SETUP_CODE} for non-factory types

**Why this order?**
- Factory agent handles ActiveRecord models (setup.type = factory)
- Implementer handles PORO/hashes/actions (setup.type = data | action)
- Clean separation of concerns through setup.type field

## Prerequisites Check

### 🔴 MUST Check

```bash
# 1. Architect completed
if ! grep -q "architect_completed: true" "$metadata_path"; then
  echo "Error: rspec-architect has not completed" >&2
  echo "Run rspec-architect first" >&2
  exit 1
fi

# 2. Spec file exists
if [ ! -f "$spec_file" ]; then
  echo "Error: Spec file not found: $spec_file" >&2
  exit 1
fi

# 3. Metadata has characteristics with factory type
has_factory_chars=$(ruby -ryaml -e "
  data = YAML.load_file('$metadata_path')
  chars = data['characteristics'] || []
  has_factory = chars.any? { |c| c['setup']['type'] == 'factory' }
  puts has_factory
")

if [ "$has_factory_chars" != "true" ]; then
  echo "No characteristics with setup.type = factory, skipping factory agent" >&2
  exit 2  # Exit 2 = warning, not error (valid scenario)
fi
```

### 🟡 SHOULD Check (Warnings)

```bash
# Check if spec/factories/ directory exists
if [ ! -d "spec/factories" ]; then
  echo "Warning: spec/factories/ directory not found, will create it" >&2
fi
```

## Input Contract

**Reads:**
1. **metadata.yml** - characteristics with setup.type = factory, setup.class, setup.source, test_level, factories_detected
2. **Spec file** - structure with `{SETUP_CODE}` placeholders and `let(characteristic.name)` blocks from skeleton
3. **Source code** - method implementation to understand attribute usage patterns
4. **Existing factory files** - to detect existing traits and avoid duplicates

**Example metadata.yml (relevant fields):**
```yaml
target:
  class: PaymentService
  method: process
  file: app/services/payment_service.rb

test_level: unit

characteristics:
  - name: authenticated          # ← Smart naming: removed "user_" prefix
    type: binary
    setup:
      type: factory              # ← Factory agent processes this
      class: User                # ← Model class
      source: "app/services/payment_service.rb:45"
    states: [authenticated, not_authenticated]

  - name: payment_method
    type: enum
    setup:
      type: data                 # ← Factory agent SKIPS this (implementer handles)
      class: null
      source: "app/services/payment_service.rb:52"
    states: [card, paypal, bank_transfer]

factories_detected:
  user:
    file: "spec/factories/users.rb"
    traits: ["admin", "blocked"]
    trait_usage:
      admin:
        count: 229
        files: 47
```

**Example spec file (input):**
```ruby
RSpec.describe PaymentService do
  describe '#process' do
    subject(:result) { service.process }

    let(:service) { described_class.new }

    {COMMON_SETUP}

    context 'when authenticated' do
      # Logic: app/services/payment_service.rb:45
      let(:authenticated) { true }    # ← Created by skeleton (shadowing pattern)
      {SETUP_CODE}                    # ← Factory fills this for User model

      context 'and payment_method is card' do
        let(:payment_method) { :card }  # ← Created by skeleton
        {SETUP_CODE}                    # ← Implementer fills this (setup.type = data)

        it 'processes payment successfully' do
          {EXPECTATION}
        end
      end
    end

    context 'when NOT authenticated' do
      # Logic: app/services/payment_service.rb:45
      let(:authenticated) { false }
      {SETUP_CODE}

      it 'raises AuthenticationError' do
        {EXPECTATION}
      end
    end
  end
end
```

## Output Contract

**Writes:**
1. **Spec file** - {SETUP_CODE} placeholders filled for factory-type characteristics
2. **Factory files** - created/updated in spec/factories/
3. **metadata.yml** - updated with automation.factory_completed flag

**Example spec file (output):**
```ruby
RSpec.describe PaymentService do
  describe '#process' do
    subject(:result) { service.process }

    let(:service) { described_class.new }
    let(:user) { build_stubbed(:user, authenticated: authenticated) }  # ← NEW: Factory created

    context 'when authenticated' do
      # Logic: app/services/payment_service.rb:45
      let(:authenticated) { true }    # ← Skeleton created, factory references it

      context 'and payment_method is card' do
        let(:payment_method) { :card }
        {SETUP_CODE}                    # ← Remains for implementer

        it 'processes payment successfully' do
          {EXPECTATION}
        end
      end
    end

    context 'when NOT authenticated' do
      # Logic: app/services/payment_service.rb:45
      let(:authenticated) { false }

      it 'raises AuthenticationError' do
        {EXPECTATION}
      end
    end
  end
end
```

**Updated metadata.yml:**
```yaml
automation:
  factory_completed: true
  factory_version: '1.0'
  warnings:
    - "Created trait :authenticated in spec/factories/users.rb"
```

## Scope and Responsibilities

### ✅ Factory Agent Handles

**Characteristics to process:**
- setup.type = 'factory' (ActiveRecord models)
- characteristic.type NOT 'composite' (implementer handles composite even with factory type)
- characteristic.type NOT 'range' with offset (implementer calculates offset values)

**What factory agent does:**
1. Read source code at setup.source to understand attribute usage
2. Apply Decision Trees to choose:
   - build_stubbed vs create (based on test_level)
   - trait vs attribute (based on heuristics)
3. Create/update factory files in spec/factories/
4. Fill {SETUP_CODE} placeholders with factory calls
5. Reference characteristic.name variables from skeleton (shadowing pattern)

### ❌ Factory Agent SKIPS

**NOT handled by factory agent:**
- setup.type = 'data' → implementer creates PORO/hashes
- setup.type = 'action' → implementer creates before hooks
- characteristic.type = 'composite' → implementer handles (even if setup.type = factory)
- characteristic.type = 'range' with offset → implementer calculates values
- {COMMON_SETUP} placeholder → implementer fills shared setup
- {EXPECTATION} placeholders → implementer fills expectations

**Coordination pattern:**
```
Factory agent:    processes setup.type = factory (simple cases)
Implementer:      processes everything else + complex factory cases
```

## Decision Trees

### Decision Tree 1: build_stubbed vs create

**Input:** test_level from metadata.yml

**Algorithm:**
```
if test_level == 'unit':
  → build_stubbed   # No DB access, fastest

elif test_level == 'integration':
  → build_stubbed   # Usually sufficient (no DB needed for integration tests)

elif test_level == 'request' or test_level == 'system':
  → create          # Need real DB records for HTTP requests

else:
  → build_stubbed   # Default to fastest option
```

**Rationale:**
- Unit tests: NEVER need DB (test logic in isolation)
- Integration tests: Usually don't need DB (test object interactions)
- Request/System tests: Need DB (real HTTP requests, database-backed responses)

**Example:**
```yaml
test_level: unit
```

**Output:**
```ruby
let(:user) { build_stubbed(:user, authenticated: authenticated) }
```

### Decision Tree 2: Trait vs Attribute

**IMPORTANT:** This is logic for Claude AI agent, NOT Ruby script. You analyze code mentally and apply heuristics.

**Input:**
- characteristic (from metadata)
- factories_detected (from analyzer, includes trait_usage stats)
- source code at setup.source

**Algorithm with priority hierarchy:**

```
┌─────────────────────────────────────────┐
│ Priority 1: SEMANTIC EXCEPTION          │
│ (Business roles ALWAYS use traits)      │
└─────────────────────────────────────────┘

SEMANTIC_ROLES = [
  'admin', 'manager', 'supervisor', 'operator',
  'authenticated', 'verified', 'confirmed', 'approved',
  'blocked', 'suspended', 'banned', 'deleted', 'archived',
  'premium', 'vip', 'pro', 'enterprise',
  'active', 'inactive', 'enabled', 'disabled',
  'published', 'draft'
]

if characteristic.name in SEMANTIC_ROLES:
  if trait exists in factories_detected:
    → USE trait :name
  else:
    → CREATE trait :name

  Reason: "Semantic Exception - business role"
  Exit algorithm → DONE

┌─────────────────────────────────────────┐
│ Priority 2: BUNDLING DECISION           │
│ (Multiple related attributes → trait)   │
└─────────────────────────────────────────┘

Read source code at setup.source
Extract all attributes being set (e.g., user.foo = bar lines)

if attributes.count >= 2:
  if are_semantically_related?(attributes):
    if bundling_trait exists:
      → USE trait :name
    else:
      → CREATE bundling trait :name

    Reason: "Bundling - N related attributes"
    Exit algorithm → DONE

┌─────────────────────────────────────────┐
│ Priority 3: 5-FILE RULE                 │
│ (High reuse → trait for discoverability)│
└─────────────────────────────────────────┘

Search for attribute usage in existing tests:
  count_usage = count_attribute_usage_in_existing_tests(characteristic)

if count_usage.files >= 5:
  if trait exists:
    → USE trait :name
  else:
    → CREATE trait :name

  Reason: "5-File Rule - used in N files"
  Exit algorithm → DONE

┌─────────────────────────────────────────┐
│ Priority 4: SIMPLICITY DEFAULT          │
│ (When in doubt → attributes, no traits) │
└─────────────────────────────────────────┘

→ USE attribute (no trait)
Reason: "Simplicity Default - single attribute, low reuse"
```

**Helper: are_semantically_related?(attributes)**

Determines if multiple attributes should be bundled into single trait.

**IMPORTANT:** This is logic for Claude AI agent, NOT Ruby script. You analyze code mentally and apply heuristics.

**Input:** Array of attribute names being set in source code at setup.source location

**Heuristics for bundling (ANY positive match → potentially RELATED):**

**Heuristic 1: Common prefix** (strongest indicator)
```ruby
['authenticated', 'authentication_token', 'authentication_expires_at']
→ Prefix: authentication*
→ RELATED ✅

['role', 'billing_plan']
→ Different prefixes
→ NOT RELATED ❌
```

**Heuristic 2: Attribute dependencies** (one attribute drives others)
```ruby
['suspended', 'suspended_at', 'suspended_reason']
→ One main attribute (suspended) with metadata (*_at, *_reason)
→ RELATED ✅
```

**Heuristic 3: Temporal/state attributes**
```ruby
['trial_started_at', 'trial_ends_at', 'trial_expired']
→ All describe trial state
→ Prefix trial* + temporal logic
→ RELATED ✅
```

**Heuristic 4: Foreign key + associations**
```ruby
['user_id', 'user']
→ Foreign key pattern
→ RELATED ✅
```

**Heuristic 5: Contextual analysis** (Claude reads source code)
```ruby
# If attributes set in same block with shared logic
if user.premium?
  user.billing_plan = 'premium'
  user.features_enabled = ['advanced', 'priority_support']
  user.billing_cycle = 'monthly'
end
→ Premium context, all attributes for premium state
→ RELATED ✅
```

**Negative indicators (ANY match → NOT RELATED, overrides all positive):**

**CRITICAL: Different business domains**
```ruby
['is_admin', 'billing_plan']
→ authorization vs billing domains
→ NOT RELATED ❌

# Even if set in same conditional block!
if user.special?
  user.is_admin = true          # authorization domain
  user.billing_plan = 'premium' # billing domain
end
→ Different domains OVERRIDES contextual coupling
→ NOT RELATED ❌
```

**Priority rules:**
1. **Domain mismatch (#5 negative) OVERRIDES ALL positive heuristics**
2. Contextual analysis (#5 positive) CANNOT override domain mismatch
3. In ambiguous cases → NOT related (apply Simplicity Default)
4. Multiple positive heuristics increase confidence, but domain mismatch is absolute veto

**Returns:**
- `true` → create bundling trait
- `false` → use separate attributes

**Helper: count_attribute_usage_in_existing_tests(characteristic)**

Counts how many test files use this attribute to inform 5-File Rule decision.

**IMPORTANT:** This is guidance for Claude AI agent, NOT Ruby script. You use Grep tool to search and analyze results.

**Input:** characteristic object from metadata

**Algorithm:**

1. Determine search patterns:
   ```
   characteristic.name = "trial_expired"
   characteristic.setup.class = "User"

   Search patterns:
   - create(:user, trial_expired: true)
   - build(:user, trial_expired: true)
   - build_stubbed(:user, trial_expired: true)
   - attributes_for(:user, trial_expired: true)
   ```

2. Search in existing spec files:
   ```bash
   grep -r "trial_expired:" spec/ --include="*_spec.rb"
   ```

3. Count unique files:
   ```
   files = unique file paths
   total_uses = total matches
   ```

4. Return statistics:
   ```json
   {
     "files": 6,
     "total_uses": 15,
     "sample_files": [
       "spec/services/trial_service_spec.rb",
       "spec/models/user_spec.rb",
       "spec/controllers/billing_controller_spec.rb"
     ]
   }
   ```

**Interpretation for 5-File Rule:**

```
if usage.files < 5:
  → Low reuse
  → DO NOT create trait
  → Use attributes (Simplicity Default)
  → Example: { files: 2, total_uses: 3 }

if usage.files >= 5:
  → High reuse
  → CREATE trait
  → Improves discoverability
  → Example: { files: 12, total_uses: 47 }

if usage.files == 0:
  → Unused
  → No existing usage
  → Follow other priorities (Semantic, Bundling, Simplicity)
```

**Returns:** object with usage statistics (files, total_uses, sample_files)

### Decision Examples

#### Example DT-1: Semantic Exception (Priority 1)

**Input:**
```yaml
characteristic:
  name: admin
  setup: {type: factory, class: User, source: "app/models/user.rb:45"}

factories_detected:
  user:
    file: "spec/factories/users.rb"
    traits: []  # No traits yet
```

**Logic:**
```
1. Check: 'admin' in SEMANTIC_ROLES? → YES
2. Check: trait :admin exists? → NO
3. Decision: CREATE trait :admin
4. Reason: "Semantic Exception - business role"
```

**Output factory (spec/factories/users.rb):**
```ruby
FactoryBot.define do
  factory :user do
    # Base attributes...

    trait :admin do
      is_admin { true }
      access_control_list { AccessControlList.admin }
    end
  end
end
```

**Output spec:**
```ruby
let(:user) { build_stubbed(:user, :admin) }
```

---

#### Example DT-2: Bundling (Priority 2)

**Input:**
```yaml
characteristic:
  name: authenticated
  setup: {type: factory, class: User, source: "app/models/user.rb:45"}
```

**Source code at app/models/user.rb:45:**
```ruby
user.authenticated = true
user.authentication_token = SecureRandom.hex(16)
user.authentication_expires_at = 24.hours.from_now
```

**Logic:**
```
1. Check: 'authenticated' in SEMANTIC_ROLES? → YES (Priority 1 applies)
2. Read source code: 3 attributes set
3. Check: are_semantically_related?
   → Common prefix: authentication* → YES, related
4. Decision: CREATE bundling trait :authenticated
5. Reason: "Semantic Exception + Bundling - 3 related attributes"
```

**Output factory:**
```ruby
trait :authenticated do
  authenticated { true }
  authentication_token { SecureRandom.hex(16) }
  authentication_expires_at { 24.hours.from_now }
end
```

**Output spec:**
```ruby
let(:user) { build_stubbed(:user, :authenticated) }
```

---

#### Example DT-3: 5-File Rule (Priority 3)

**Input:**
```yaml
characteristic:
  name: trial_expired
  setup: {type: factory, class: User}

factories_detected:
  user:
    traits: []
```

**Usage search results:**
```bash
$ grep -r "trial_expired:" spec/ --include="*_spec.rb"
spec/services/trial_service_spec.rb:  let(:user) { create(:user, trial_expired: true) }
spec/models/user_spec.rb:  let(:user) { build(:user, trial_expired: false) }
spec/controllers/billing_controller_spec.rb:  let(:user) { create(:user, trial_expired: true) }
spec/mailers/trial_mailer_spec.rb:  let(:user) { create(:user, trial_expired: true) }
spec/jobs/trial_expiration_job_spec.rb:  let(:user) { create(:user, trial_expired: true) }
spec/requests/api/subscriptions_spec.rb:  let(:user) { create(:user, trial_expired: false) }
```

**Logic:**
```
1. Check: 'trial_expired' in SEMANTIC_ROLES? → NO
2. Read source code: only 1 attribute
   → Not bundling candidate
3. Count usage: 6 unique files (>= 5)
4. Decision: CREATE trait :trial_expired
5. Reason: "5-File Rule - used in 6 files"
```

**Output factory:**
```ruby
trait :trial_expired do
  trial_expired { true }
  trial_expires_at { 1.week.ago }
end
```

---

#### Example DT-4: Simplicity Default (Priority 4)

**Input:**
```yaml
characteristic:
  name: email_confirmed
  setup: {type: factory, class: User}
```

**Usage search results:**
```bash
$ grep -r "email_confirmed:" spec/ --include="*_spec.rb"
spec/models/user_spec.rb:  let(:user) { create(:user, email_confirmed: true) }
spec/services/email_service_spec.rb:  let(:user) { build(:user, email_confirmed: false) }
```

**Logic:**
```
1. Check: 'email_confirmed' in SEMANTIC_ROLES? → NO (not 'confirmed', different name)
2. Read source code: only 1 attribute
   → Not bundling candidate
3. Count usage: 2 files (< 5)
4. Decision: USE attribute (no trait)
5. Reason: "Simplicity Default - single attribute, low reuse"
```

**Output spec:**
```ruby
let(:user) { build_stubbed(:user, email_confirmed: email_confirmed) }
```

(No factory file changes)

---

## Algorithm Modes

This agent operates in a unified mode that intelligently handles both new test generation and existing test optimization.

### Mode Detection

The agent automatically determines its operational mode by checking for `{SETUP_CODE}` placeholders in the spec file:

```bash
if grep -q '{SETUP_CODE}' "$spec_file"; then
  mode="generation"  # Creating new tests (write-new flow)
else
  mode="optimization"  # Improving existing tests (update-diff, refactor-legacy)
fi
```

### Generation Mode (write-new flow)

**Trigger:** Spec file contains `{SETUP_CODE}` placeholders

**Actions:**
1. Applies all 4 priorities (Semantic → Bundling → 5-File → Simplicity) for trait vs attribute decisions
2. Creates factory files if they don't exist
3. Adds traits to existing factories when needed
4. Fills `{SETUP_CODE}` placeholders with appropriate factory calls
5. References `characteristic.name` variables (shadowing pattern)
6. Uses `build_stubbed` vs `create` based on `test_level`

**Example flow:**
```ruby
# Input: {SETUP_CODE} placeholder in context
context 'when authenticated' do
  let(:authenticated) { true }
  {SETUP_CODE}  # ← Agent fills this

  it 'processes payment' do
    {EXPECTATION}
  end
end

# Output after factory agent:
context 'when authenticated' do
  let(:authenticated) { true }
  let(:user) { build_stubbed(:user, :authenticated) }  # ← Filled by factory agent

  it 'processes payment' do
    {EXPECTATION}  # ← Left for implementer
  end
end
```

**Output:**
- Partially filled spec file (factory-type `{SETUP_CODE}` filled, data/action remain)
- Created/updated factory files in `spec/factories/`
- `automation.factory_completed = true`

### Optimization Mode (update-diff, refactor-legacy flows)

**Trigger:** Spec file has NO `{SETUP_CODE}` placeholders (fully implemented tests)

**Actions:**
1. Parses existing factory calls in the spec
2. Optimizes `create` → `build_stubbed` based on `test_level`
3. Applies Priority 3 (5-File Rule) using `trait_usage` statistics to suggest trait creation
4. Suggests replacing attributes with traits when `usage.files >= 5`
5. Suggests composite traits for repeated trait combinations (3+ uses)

**Example flow:**
```ruby
# Input: Existing test with suboptimal factory usage
let(:user) { create(:user, suspended: true) }  # create in unit test (slow)

# Analysis:
# - test_level = 'unit' → should use build_stubbed
# - trait :suspended exists with trait_usage.files = 12 (high reuse)

# Output optimization suggestions:
# 1. create → build_stubbed (unit test doesn't need DB)
# 2. suspended: true → :suspended (trait used in 12 files)

let(:user) { build_stubbed(:user, :suspended) }  # Optimized
```

**Output:**
- Optimized spec file with improved factory usage
- Suggested trait additions (in `automation.warnings[]`)
- `automation.factory_optimizations[]` list of changes made

### Unified Decision Tree

Both modes use the same **Decision Tree 2** (trait vs attribute with 4 priorities), but optimization mode particularly focuses on **Priority 3 (5-File Rule)** since it has access to `trait_usage` statistics from existing tests.

**Why unified?** The decision logic is identical - what matters is whether to create a trait based on:
- Semantic importance (admin, manager)
- Bundling (multiple related attributes)
- Usage patterns (5+ files)
- Simplicity default (single boolean)

The mode only affects **whether we're filling placeholders or optimizing existing code**, not the decision-making process itself.

### Mode Coordination

**Generation mode coordination:**
- Factory agent fills `{SETUP_CODE}` for `setup.type = factory`
- Implementer fills remaining `{SETUP_CODE}` for `setup.type = data | action`
- Clean handoff via `automation.factory_completed` flag

**Optimization mode coordination:**
- Factory agent runs independently
- No dependencies on implementer (optimizing existing code)
- Can run multiple times on same spec file

---

## Algorithm

### Step 1: Load Inputs

```ruby
# Read metadata
metadata = YAML.load_file(metadata_path)
characteristics = metadata['characteristics']
test_level = metadata['test_level']
factories_detected = metadata['factories_detected'] || {}

# Read spec file
spec_content = File.read(spec_file)

# Extract factory-type characteristics
factory_chars = characteristics.select { |c|
  c['setup']['type'] == 'factory' &&
  c['type'] != 'composite' &&  # Skip composite
  !(c['type'] == 'range' && c['threshold_value'])  # Skip range with threshold
}

if factory_chars.empty?
  puts "No factory-type characteristics to process"
  exit 2  # Warning, not error
end
```

### Step 2: Process Each Factory Characteristic

For each characteristic with setup.type = factory:

```ruby
factory_chars.each do |char|
  model_class = char['setup']['class']     # e.g., "User"
  char_name = char['name']                 # e.g., "authenticated"
  source_location = char['setup']['source'] # e.g., "app/models/user.rb:45"

  # 1. Determine build_stubbed vs create
  factory_method = decide_factory_method(test_level)

  # 2. Read source code at location
  source_code = read_source_at_location(source_location)

  # 3. Decide trait vs attribute
  decision = decide_trait_vs_attribute(
    characteristic: char,
    factories_detected: factories_detected,
    source_code: source_code
  )

  # 4. Create/update factory if needed
  if decision.create_trait?
    create_or_update_trait(
      model: model_class,
      trait_name: char_name,
      attributes: decision.attributes
    )
  end

  # 5. Generate factory call
  factory_call = generate_factory_call(
    model: model_class,
    method: factory_method,
    use_trait: decision.use_trait?,
    trait_name: char_name,
    characteristic: char
  )

  # 6. Fill {SETUP_CODE} placeholder
  fill_setup_code_placeholder(
    spec_content: spec_content,
    context_name: char_name,
    setup_code: factory_call
  )
end
```

### Step 3: Write Outputs

```ruby
# Write updated spec file
File.write(spec_file, spec_content)

# Update metadata with completion flag
metadata['automation'] ||= {}
metadata['automation']['factory_completed'] = true
metadata['automation']['factory_version'] = '1.0'
metadata['automation']['warnings'] = warnings

File.write(metadata_path, metadata.to_yaml)

# Print summary
puts "Factory agent completed:"
puts "- Processed #{factory_chars.count} characteristics"
puts "- Created/updated #{updated_factories.count} factory files"
puts "- Filled {SETUP_CODE} for #{filled_count} contexts"
```

### Step 4: Exit

```bash
exit 0  # Success
```

---

## Shadowing Pattern (CRITICAL)

The skeleton generator creates `let(characteristic.name)` blocks for states. Factory agent MUST reference these variables.

**Example:**

**Skeleton output:**
```ruby
context 'when authenticated' do
  let(:authenticated) { true }   # ← Skeleton created
  {SETUP_CODE}
end

context 'when NOT authenticated' do
  let(:authenticated) { false }  # ← Skeleton created (shadows parent)
  {SETUP_CODE}
end
```

**Factory fills {SETUP_CODE}:**
```ruby
context 'when authenticated' do
  let(:authenticated) { true }
  let(:user) { build_stubbed(:user, authenticated: authenticated) }  # ← References skeleton variable

context 'when NOT authenticated' do
  let(:authenticated) { false }
  let(:user) { build_stubbed(:user, authenticated: authenticated) }  # ← Same code, different value
```

**Why this works:**
- Skeleton creates `let(:authenticated)` with state value (true/false)
- Factory creates `let(:user)` that references `authenticated` variable
- When context changes, `let(:authenticated)` is shadowed → factory automatically gets new value
- Same factory code works in all contexts (DRY principle)

**CRITICAL:** Always reference characteristic.name variable, NOT hard-coded values.

**❌ WRONG:**
```ruby
context 'when authenticated' do
  let(:user) { build_stubbed(:user, authenticated: true) }  # ← Hard-coded!
```

**✅ CORRECT:**
```ruby
context 'when authenticated' do
  let(:user) { build_stubbed(:user, authenticated: authenticated) }  # ← References variable
```

---

## Complete Examples

### Example 1: Simple Binary (Semantic Exception)

**Input metadata:**
```yaml
target:
  class: AdminPanel
  method: show
  file: app/controllers/admin_panel_controller.rb

test_level: request

characteristics:
  - name: admin
    type: binary
    setup:
      type: factory
      class: User
      source: "app/controllers/admin_panel_controller.rb:12"
    states: [admin, not_admin]

factories_detected:
  user:
    file: "spec/factories/users.rb"
    traits: []
```

**Input spec (after skeleton + architect):**
```ruby
RSpec.describe AdminPanelController do
  describe '#show' do
    {COMMON_SETUP}

    context 'when admin' do
      # Logic: app/controllers/admin_panel_controller.rb:12
      let(:admin) { true }
      {SETUP_CODE}

      it 'renders admin dashboard' do
        {EXPECTATION}
      end
    end

    context 'when NOT admin' do
      let(:admin) { false }
      {SETUP_CODE}

      it 'redirects to home page' do
        {EXPECTATION}
      end
    end
  end
end
```

**Factory agent decisions:**

```
DT1: test_level = request → create (need DB for request tests)
DT2: 'admin' in SEMANTIC_ROLES → CREATE trait :admin
```

**Created factory (spec/factories/users.rb):**
```ruby
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }

    trait :admin do
      is_admin { true }
      role { 'admin' }
    end
  end
end
```

**Output spec:**
```ruby
RSpec.describe AdminPanelController do
  describe '#show' do
    let(:user) { create(:user, :admin) }  # ← NEW: In {COMMON_SETUP} position

    context 'when admin' do
      let(:admin) { true }

      it 'renders admin dashboard' do
        {EXPECTATION}
      end
    end

    context 'when NOT admin' do
      let(:admin) { false }

      it 'redirects to home page' do
        {EXPECTATION}
      end
    end
  end
end
```

**Updated metadata:**
```yaml
automation:
  factory_completed: true
  factory_version: '1.0'
  warnings:
    - "Created trait :admin in spec/factories/users.rb"
    - "Created factory file spec/factories/users.rb"
```

---

### Example 2: Mixed (Factory + Data Types)

**Input metadata:**
```yaml
test_level: unit

characteristics:
  - name: authenticated
    type: binary
    setup:
      type: factory  # ← Factory processes
      class: User
      source: "app/services/payment_service.rb:45"
    states: [authenticated, not_authenticated]

  - name: payment_method
    type: enum
    setup:
      type: data     # ← Factory SKIPS (implementer handles)
      class: null
      source: "app/services/payment_service.rb:52"
    states: [card, paypal, bank_transfer]

factories_detected:
  user:
    file: "spec/factories/users.rb"
    traits: ["admin"]
```

**Input spec:**
```ruby
RSpec.describe PaymentService do
  describe '#process' do
    {COMMON_SETUP}

    context 'when authenticated' do
      let(:authenticated) { true }
      {SETUP_CODE}

      context 'and payment_method is card' do
        let(:payment_method) { :card }
        {SETUP_CODE}

        it 'processes payment' do
          {EXPECTATION}
        end
      end
    end
  end
end
```

**Factory agent processing:**

```
Process characteristic 'authenticated':
  - setup.type = factory → PROCESS
  - DT1: test_level = unit → build_stubbed
  - DT2: 'authenticated' in SEMANTIC_ROLES → CREATE trait

Process characteristic 'payment_method':
  - setup.type = data → SKIP (implementer will handle)
```

**Created factory:**
```ruby
# spec/factories/users.rb (updated)
trait :authenticated do
  authenticated { true }
  authentication_token { SecureRandom.hex(16) }
end
```

**Output spec:**
```ruby
RSpec.describe PaymentService do
  describe '#process' do
    let(:user) { build_stubbed(:user, authenticated: authenticated) }  # ← NEW

    context 'when authenticated' do
      let(:authenticated) { true }

      context 'and payment_method is card' do
        let(:payment_method) { :card }
        {SETUP_CODE}  # ← Remains for implementer (data type)

        it 'processes payment' do
          {EXPECTATION}
        end
      end
    end
  end
end
```

---

## Edge Cases

### Edge Case 1: Composite Characteristic (Skip)

**Input:**
```yaml
characteristics:
  - name: user_state
    type: composite  # ← Composite type
    setup:
      type: factory
      class: User
```

**Factory agent decision:**
```
Check: characteristic.type == 'composite' → YES
Decision: SKIP (implementer handles composite setup)
```

**No factory code generated.** Implementer will handle this with multiple let blocks.

---

### Edge Case 2: Range with Threshold (Skip)

**Input:**
```yaml
characteristics:
  - name: balance_sufficient
    type: range
    setup:
      type: factory
      class: Account
    threshold_value: 1000
    threshold_operator: '>='
```

**Factory agent decision:**
```
Check: characteristic.type == 'range' with threshold → YES
Decision: SKIP (implementer calculates offset values)
```

**No factory code generated.** Implementer will calculate 1050/950 values.

---

### Edge Case 3: No Existing Factory File

**Input:**
```yaml
characteristics:
  - name: admin
    setup:
      type: factory
      class: User

factories_detected: {}  # ← No factories exist yet
```

**Factory agent behavior:**

```bash
# 1. Create directory
mkdir -p spec/factories

# 2. Create factory file
cat > spec/factories/users.rb <<'EOF'
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }

    trait :admin do
      is_admin { true }
    end
  end
end
EOF

# 3. Add warning to metadata
warnings:
  - "Created factory file spec/factories/users.rb"
  - "Created trait :admin in spec/factories/users.rb"
```

---

## Exit Code Contract

| Exit Code | Meaning | stdout | stderr |
|-----------|---------|--------|--------|
| `0` | Success | Summary message | Empty |
| `2` | Warning (No factory chars) | Skip message | Warning |
| `1` | Critical Error | Empty | Error message |

**Exit 0 scenarios:**
- Factory agent processed ≥1 characteristics
- Created/updated factory files successfully
- Filled {SETUP_CODE} placeholders

**Exit 2 scenarios:**
- No characteristics with setup.type = factory (valid, implementer handles everything)
- Spec file already has no {SETUP_CODE} placeholders (already filled)

**Exit 1 scenarios:**
- Architect not completed (architect_completed != true)
- Spec file not found
- Cannot write factory files (permission denied)
- Invalid factory syntax in existing files

---

## Implementation Notes

### Factory File Management

**File location pattern:**
```
Model class: User
Factory file: spec/factories/users.rb

Model class: PaymentService
Factory file: spec/factories/payment_services.rb
```

**Creating new factory:**
```ruby
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    name { Faker::Name.name }

    # Traits added here
  end
end
```

**Updating existing factory:**
1. Read existing file
2. Parse FactoryBot.define block
3. Find factory :model_name
4. Check if trait exists
5. Add trait if missing
6. Write file

### Placement Algorithm: Finding First Appearance

**Key Principle:** Factory agent determines where to create `let(:model)` blocks **once at the optimal level**, referencing state variables created by skeleton. The skeleton creates `let` blocks for states in child contexts, overriding values through shadowing.

**Algorithm Steps:**

For each characteristic with setup.type = factory:

**Step 1: Find FIRST appearance**
- Locate the FIRST context (earliest, minimum nesting level) where this characteristic is used
- This is determined by the characteristic hierarchy in metadata.yml

**Step 2: Create let in PARENT block**
- Create `let(:model_name)` in the PARENT block of that first context:
  - If characteristic used at context level 1 → create in `describe`
  - If at context level 2 → create in context level 1
  - And so on

**Step 3: Handle multiple characteristics of same class**
- If multiple characteristics share the same class (e.g., both use `User`):
  - Find the earliest one (minimum nesting level)
  - Create `let(:user)` at its parent level
  - Other characteristics reuse the same `let` via shadowing pattern

**Step 4: Do NOT optimize manually**
- Factory agent creates `let` where it's first needed
- Do NOT hoist higher than necessary
- Polisher will automatically lift duplicates in next phase
- Trust the pipeline coordination

**Examples:**

**Example P-1: Single characteristic at level 1**
```ruby
# Metadata: authenticated (level 1)
# Decision: Create let(:user) in describe (parent of level 1)

describe 'PaymentService' do
  let(:user) { build_stubbed(:user, authenticated: authenticated) }
  #                                  ^^^^^^^^^^^ references variable (defined below)

  context 'when authenticated' do
    let(:authenticated) { true }  # ← Skeleton created (shadowing)
    # Test uses user from parent
  end

  context 'when NOT authenticated' do
    let(:authenticated) { false }  # ← Skeleton created (shadowing)
    # Same user definition, different value
  end
end
```

**Example P-2: Multiple characteristics, same class**
```ruby
# Metadata:
# - authenticated (level 1, User)
# - premium (level 2, User, depends_on: authenticated)
# Decision: authenticated is earliest → create let(:user) at describe level

describe 'SubscriptionService' do
  let(:user) { build_stubbed(:user, authenticated: authenticated, premium: premium) }
  # ← Created ONCE at describe (earliest parent)

  context 'when authenticated' do
    let(:authenticated) { true }

    context 'and premium' do
      let(:premium) { true }
      # Uses user from describe, both variables shadowed
    end

    context 'and NOT premium' do
      let(:premium) { false }
      # Same user, different premium value
    end
  end
end

# NOTE: Polisher may later optimize if it detects duplication patterns
```

**Example P-3: Multiple models**
```ruby
# Metadata:
# - admin (level 1, User)
# - status (level 1, Order)

describe 'OrderProcessor' do
  let(:user) { build_stubbed(:user, admin: admin) }    # ← First
  let(:order) { build_stubbed(:order, user: user, status: status) }  # ← Second (depends on user)
  # Order: dependencies first, then dependents

  context 'when admin' do
    let(:admin) { true }

    context 'and status is pending' do
      let(:status) { :pending }
    end
  end
end
```

**Coordination with Implementer:**
- Factory agent uses this algorithm for `setup.type = factory` (ActiveRecord models)
- Implementer uses SAME algorithm for `setup.type = data` (PORO/hashes) and `setup.type = action`
- Both create `let` blocks at optimal level, referencing skeleton-created state variables

### Warnings and Logging

Add warnings to metadata.automation.warnings:

```yaml
warnings:
  - "Created trait :authenticated in spec/factories/users.rb"
  - "Created factory file spec/factories/users.rb"
  - "Trait :admin already exists, reused"
  - "Using attribute for low-reuse characteristic: email_confirmed (used in 2 files)"
```

These help user understand factory agent decisions.

---

## Testing the Agent

### Validation Checklist

✅ **Prerequisites:**
- [ ] Rejects if architect_completed != true
- [ ] Skips (exit 2) if no factory-type characteristics
- [ ] Creates spec/factories/ if missing

✅ **Decision Trees:**
- [ ] Applies build_stubbed for unit tests
- [ ] Applies create for request tests
- [ ] Creates traits for SEMANTIC_ROLES
- [ ] Creates bundling traits for related attributes
- [ ] Creates traits for 5-File Rule
- [ ] Uses attributes for Simplicity Default

✅ **Shadowing Pattern:**
- [ ] References characteristic.name variables (NOT hard-coded values)
- [ ] Factory code identical across contexts (DRY)

✅ **Coordination:**
- [ ] Skips setup.type = data (implementer handles)
- [ ] Skips setup.type = action (implementer handles)
- [ ] Skips characteristic.type = composite
- [ ] Skips characteristic.type = range with threshold

✅ **Output:**
- [ ] Creates/updates factory files
- [ ] Fills {SETUP_CODE} for factory types
- [ ] Sets automation.factory_completed = true
- [ ] Adds warnings for transparency

---

## Version History

**v1.0 (2025-11-15):**
- Initial specification
- Decision trees for factory method and trait vs attribute
- Shadowing pattern support
- Coordination with implementer via setup.type
