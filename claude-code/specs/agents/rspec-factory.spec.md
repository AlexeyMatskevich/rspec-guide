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

#### Example DT-3: Bundling FAIL - Unrelated Attributes (Priority 2)

**Input:**
```yaml
characteristic:
  name: user_setup
  setup: {type: factory, class: User, source: "spec/support/user_setup.rb:10"}
```

**Source code at spec/support/user_setup.rb:10:**
```ruby
user.role = 'admin'           # authorization domain
user.billing_plan = 'premium' # billing domain
```

**Logic:**
```
1. Check: 'user_setup' in SEMANTIC_ROLES? → NO
2. Read source code: 2 attributes
3. Check: are_semantically_related?
   → role (authorization) vs billing_plan (billing)
   → Different prefixes, different business domains
   → NO, NOT related
4. Skip Priority 2 (bundling not applicable)
5. Continue to Priority 3
6. Check: trait exists? → NO
7. Continue to Priority 4
8. Check: single attribute? → NO (2 attributes)
9. Fallback: use attributes
10. Decision: Use separate attributes
```

**Output spec:**
```ruby
# Do NOT create bundling trait, use attributes
let(:user) { build_stubbed(:user, role: 'admin', billing_plan: 'premium') }
```

**Reason:** Attributes from different business domains. Bundling trait would be artificial and confusing.

---

#### Example DT-4: Simplicity Default (Priority 4)

**Input:**
```yaml
characteristic:
  name: email_verified
  setup: {type: factory, class: User, source: "app/models/user.rb:120"}
```

**Source code:**
```ruby
user.email_verified = true
```

**Logic:**
```
1. Check: 'email_verified' in SEMANTIC_ROLES? → NO
2. Read source code: 1 attribute
3. Skip Priority 2 (< 2 attributes)
4. Check Priority 3: trait :email_verified exists? → NO
5. Check Priority 4: binary + 1 attribute? → YES
6. Decision: Use attribute
7. Reason: "Simplicity Default - single boolean is clear"
```

**Output spec:**
```ruby
let(:user) { build_stubbed(:user, email_verified: email_verified) }
```

---

#### Example DT-5: 5-File Rule - Use Existing Trait (Priority 3)

**Input:**
```yaml
characteristic:
  name: enabled
  setup: {type: factory, class: User}

factories_detected:
  user:
    traits: [enabled]  # ← Trait exists!
```

**Logic:**
```
1. Check: 'enabled' in SEMANTIC_ROLES? → NO
2. Read source code: 1 attribute
3. Skip Priority 2 (< 2 attributes)
4. Check Priority 3: trait :enabled exists? → YES
5. Decision: USE existing trait
6. Reason: "Trait exists - use for consistency"
```

**Output spec:**
```ruby
let(:user) { build_stubbed(:user, :enabled) }
```

---

#### Example DT-6: 5-File Rule - Create New Trait (Priority 3)

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
6. REFACTOR existing specs: Replace attribute usage with new trait
```

**Output factory:**
```ruby
trait :trial_expired do
  trial_expired { true }
  trial_expires_at { 1.week.ago }
end
```

**Refactoring existing specs (CRITICAL for 5-File Rule):**

When creating a new trait via 5-File Rule, factory agent MUST refactor all existing specs that use this attribute.

**Step 6: Refactor existing usage**

For each file found in usage search (step 3):

```ruby
# BEFORE (attribute usage):
let(:user) { create(:user, trial_expired: true) }
let(:user) { build(:user, trial_expired: true) }
let(:user) { build_stubbed(:user, trial_expired: true) }

# AFTER (trait usage):
let(:user) { create(:user, :trial_expired) }
let(:user) { build(:user, :trial_expired) }
let(:user) { build_stubbed(:user, :trial_expired) }
```

**Implementation using Edit tool:**

```ruby
# For each file in usage search results:
files_to_update = [
  "spec/services/trial_service_spec.rb",
  "spec/models/user_spec.rb",
  "spec/controllers/billing_controller_spec.rb",
  "spec/mailers/trial_mailer_spec.rb",
  "spec/jobs/trial_expiration_job_spec.rb",
  "spec/requests/api/subscriptions_spec.rb"
]

files_to_update.each do |file|
  # Read file, find all instances of trial_expired: true
  # Replace with :trial_expired using Edit tool

  # Pattern to find:
  # - create(:user, trial_expired: true)
  # - build(:user, trial_expired: true)
  # - build_stubbed(:user, trial_expired: true)

  # Replace with:
  # - create(:user, :trial_expired)
  # - build(:user, :trial_expired)
  # - build_stubbed(:user, :trial_expired)
end
```

**Example refactoring for one file:**

Before (spec/services/trial_service_spec.rb):
```ruby
RSpec.describe TrialService do
  describe '#expire_trials' do
    let(:user) { create(:user, trial_expired: true) }

    it 'sends expiration email' do
      expect { service.expire_trials }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
```

After:
```ruby
RSpec.describe TrialService do
  describe '#expire_trials' do
    let(:user) { create(:user, :trial_expired) }  # ← Refactored

    it 'sends expiration email' do
      expect { service.expire_trials }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
```

**Handling false values:**

```ruby
# If attribute was false, keep as attribute (traits are for positive states):
let(:user) { build(:user, trial_expired: false) }
# → NO CHANGE (false typically doesn't need trait)

# UNLESS there's a specific negative trait:
trait :trial_active do
  trial_expired { false }
  trial_expires_at { 1.week.from_now }
end
# Then replace:
let(:user) { build(:user, :trial_active) }
```

**Updated metadata warnings:**

```yaml
automation:
  factory_completed: true
  warnings:
    - "Created trait :trial_expired in spec/factories/users.rb"
    - "Refactored 6 spec files to use :trial_expired trait:"
    - "  - spec/services/trial_service_spec.rb (1 replacement)"
    - "  - spec/models/user_spec.rb (1 replacement, 1 kept as attribute)"
    - "  - spec/controllers/billing_controller_spec.rb (1 replacement)"
    - "  - spec/mailers/trial_mailer_spec.rb (1 replacement)"
    - "  - spec/jobs/trial_expiration_job_spec.rb (1 replacement)"
    - "  - spec/requests/api/subscriptions_spec.rb (1 replacement, 1 kept as attribute)"
```

**Why this is critical:**

1. **Consistency:** All specs use the same pattern (trait) instead of scattered attributes
2. **Maintainability:** Changing trait definition updates all usage automatically
3. **Discoverability:** Developers know to use `:trial_expired` trait, not `trial_expired: true`
4. **Justifies 5-File Rule:** High reuse → create trait → refactor all usage → benefit realized

**Important:** This refactoring happens ONLY for Generation Mode when creating NEW trait. Optimization Mode suggests refactoring but doesn't execute automatically.

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
6. **DOES NOT automatically refactor other specs** (unlike Generation Mode)

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

**Key difference from Generation Mode:**

| Mode | Trait Creation | Spec Refactoring |
|------|----------------|------------------|
| Generation | Creates new traits when needed | ✅ **Refactors ALL existing specs** to use new trait |
| Optimization | Suggests traits, may create | ❌ Only optimizes CURRENT spec, suggests refactoring others |

**Rationale:** Generation Mode is creating new code from scratch → safe to refactor project-wide. Optimization Mode works on existing tests → conservative, only suggests changes.

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

## State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│                              START                                  │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Check Prerequisites                            │
│  • architect_completed = true?                                      │
│  • Spec file exists?                                                │
│  • Has factory-type characteristics?                                │
└─────────────────────────────────────────────────────────────────────┘
                  ├─ Missing? → [Error] → [END: exit 1]
                  └─ All OK? → Continue
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         Load Inputs                                 │
│  • metadata.yml (characteristics, test_level, factories_detected)   │
│  • spec file content                                                │
│  • existing factory files                                           │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│              Filter Factory-Type Characteristics                    │
│  • setup.type = 'factory'                                           │
│  • NOT composite (implementer handles)                              │
│  • NOT range with threshold (implementer calculates)                │
└─────────────────────────────────────────────────────────────────────┘
                  ├─ No factory chars? → [Warning] → [END: exit 2]
                  └─ Has factory chars? → Continue
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         Detect Mode                                 │
│  • {SETUP_CODE} placeholders exist? → Generation Mode               │
│  • No placeholders? → Optimization Mode                             │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
            ┌─────────────────────┴─────────────────────┐
            ↓                                           ↓
    [Generation Mode]                          [Optimization Mode]
    Fill placeholders                          Optimize existing code
            ↓                                           ↓
            └─────────────────────┬─────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│              For Each Factory Characteristic:                       │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────────────────────────┐
        │   Step 1: Apply DT-1 (Factory Method)       │
        │   build_stubbed vs create                   │
        │   (based on test_level)                     │
        │   See: Decision Tree 1                      │
        └─────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────────────────────────┐
        │   Step 2: Read Source Code                  │
        │   Extract attributes at setup.source        │
        │   (needed for bundling decision)            │
        └─────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────────────────────────┐
        │   Step 3: Apply DT-2 (Trait vs Attribute)   │
        │   4-Priority Hierarchy:                     │
        │   1. Semantic Exception (SEMANTIC_ROLES)    │
        │   2. Bundling (are_semantically_related?)   │
        │   3. 5-File Rule (count_attribute_usage)    │
        │   4. Simplicity Default                     │
        │   See: Decision Tree 2                      │
        └─────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────────────────────────┐
        │   Step 4: Create/Update Factory File        │
        │   (if trait needed)                         │
        │   • Factory exists? → Add trait             │
        │   • No factory? → Create new file           │
        └─────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────────────────────────┐
        │   Step 5: Generate Factory Call             │
        │   build_stubbed(:model, trait/attributes)   │
        │   CRITICAL: Reference characteristic.name   │
        │   variables (shadowing pattern)             │
        │   See: Shadowing Pattern section            │
        └─────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────────────────────────┐
        │   Step 6: Fill Placeholder or Optimize      │
        │   Generation: Replace {SETUP_CODE}          │
        │   Optimization: Replace create → stubbed,   │
        │                 suggest traits              │
        └─────────────────────────────────────────────┘
                                  ↓
                    [Next characteristic]
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│       Generation Mode ONLY: Refactor Existing Specs                │
│       (if created new trait via 5-File Rule)                        │
│  • Search for attribute usage in all spec files                    │
│  • Replace attribute: value with :trait in ALL files               │
│  • Update metadata with refactoring statistics                     │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│               Apply Placement Algorithm                             │
│  • Find earliest characteristic.level among all chars               │
│  • Create let(:model) in parent block of earliest level            │
│  • Use shadowing pattern (references characteristic.name vars)     │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Write Updated Spec File                          │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                 Write Updated Factory Files                         │
│  (if created/updated any traits)                                   │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Update Metadata                                │
│  • automation.factory_completed = true                              │
│  • warnings[] (if any issues)                                       │
│  • (Generation Mode) refactoring_stats[]                            │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                       Print Summary                                 │
│  • Characteristics processed                                        │
│  • Factory calls created                                            │
│  • Traits created/updated                                           │
│  • Placeholders filled (Generation) or optimizations (Optimization) │
│  • (Generation Mode) Specs refactored                               │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         END: exit 0                                 │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Decision Points

1. **Prerequisites Check** → Ensures architect completed, spec file exists
2. **Mode Detection** → Generation ({SETUP_CODE} exists) vs Optimization (no placeholders)
3. **DT-1: Factory Method** → `build_stubbed` (unit/request) vs `create` (integration)
4. **DT-2: Trait vs Attribute** → 4-Priority Hierarchy (Semantic → Bundling → 5-File → Simplicity)
5. **Refactoring Logic** → Generation Mode refactors ALL specs when creating trait via 5-File Rule
6. **Placement Algorithm** → Find earliest level, create let in parent block

### Exit Points

- **exit 0**: Success (all factory characteristics processed)
- **exit 1**: Error (prerequisites failed, spec file missing)
- **exit 2**: Warning (no factory-type characteristics to process)

### Mode-Specific Paths

**Generation Mode:**
- Fills `{SETUP_CODE}` placeholders created by skeleton
- Automatically refactors existing specs when creating new traits via 5-File Rule
- Coordinates with implementer via `automation.factory_completed` flag

**Optimization Mode:**
- Optimizes existing factory calls (`create` → `build_stubbed`)
- Suggests trait extraction based on 5-File Rule
- Does NOT automatically refactor other specs (conservative approach)

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

### Edge Case 4: Multiple Characteristics, Same Class

**Scenario:** Multiple characteristics share same model class (User)

**Input metadata:**
```yaml
characteristics:
  - name: authenticated
    level: 1
    setup: {type: factory, class: User}

  - name: premium
    level: 2
    depends_on: authenticated
    when_parent: [authenticated]
    setup: {type: factory, class: User}
```

**Factory agent algorithm:**
1. Find earliest characteristic: `authenticated` (level 1)
2. Create `let(:user)` in parent of level 1 → describe block
3. Other characteristics (premium) use same let via shadowing
4. Include all attributes in single factory call

**Output:**
```ruby
describe 'PremiumService' do
  # Factory creates ONE let(:user) at describe level
  # (parent of level 1, where User first appears)
  let(:user) { build_stubbed(:user, authenticated: authenticated, premium: premium) }

  context 'when authenticated' do
    let(:authenticated) { true }  # Skeleton created

    context 'and premium' do
      let(:premium) { true }  # Skeleton created

      it 'grants premium access' do
        # user object references both authenticated=true and premium=true via shadowing
      end
    end

    context 'and NOT premium' do
      let(:premium) { false }
      # user object references authenticated=true and premium=false
    end
  end
end
```

**Result:** One `let(:user)` for all User characteristics via shadowing pattern.

---

### Edge Case 5: Nested Dependencies (3 levels)

**Scenario:** Deep nesting (authenticated → premium → vip)

**Input metadata:**
```yaml
characteristics:
  - name: authenticated
    level: 1
    setup: {type: factory, class: User}

  - name: premium
    level: 2
    depends_on: authenticated
    when_parent: [authenticated]
    setup: {type: factory, class: User}

  - name: vip
    level: 3
    depends_on: premium
    when_parent: [premium]
    setup: {type: factory, class: User}
```

**Factory agent algorithm:**
1. Find earliest characteristic: `authenticated` (level 1)
2. Create let(:user) in describe block (parent of level 1)
3. All other characteristics (premium, vip) use same let via shadowing

**Output:**
```ruby
describe 'VipService' do
  # ONE let(:user) at top level, includes all attributes
  let(:user) { build_stubbed(:user, authenticated: authenticated, premium: premium, vip: vip) }

  context 'when authenticated' do
    let(:authenticated) { true }

    context 'and premium' do
      let(:premium) { true }

      context 'and vip' do
        let(:vip) { true }

        it 'grants vip access' do
          # user has all three: authenticated=true, premium=true, vip=true
        end
      end
    end
  end
end
```

**Result:** Single factory call handles arbitrarily deep nesting via shadowing.

**Note:** Polisher may optimize if `let(:user)` duplicated across files → lift to shared_context.

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
