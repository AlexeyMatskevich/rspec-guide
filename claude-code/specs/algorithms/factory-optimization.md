# Factory Optimization Algorithm

**Version:** 1.0
**Created:** 2025-11-07
**Used by:** rspec-factory agent

## Purpose

This algorithm defines how to optimize FactoryBot factory usage in RSpec tests based on test level and persistence requirements.

**Core Principle (Rule 14 from guide.en.md):** Use `build_stubbed` for unit tests (fast, no DB), `create` for integration tests (need persistence).

## Definitions

**Factory Methods:**
- `build` - Creates object in memory (no DB save)
- `build_stubbed` - Creates object with stubbed persistence methods (fastest)
- `create` - Creates and saves object to database (slowest)

**Test Levels:**
- **unit** - Single class/module, no external dependencies → use `build_stubbed`
- **integration** - Multiple classes, database interactions → use `create`
- **request** - HTTP requests, full stack → use `create`
- **e2e** - End-to-end user scenarios → use `create`

**Persistence Check:** Determine if object's persisted state matters for test behavior

## Algorithm Overview

```
1. Determine test level from metadata
2. Find all factory calls in spec
3. For each factory call:
   a. Identify current method (create/build/build_stubbed)
   b. Check if persistence required
   c. Determine optimal method based on test level
   d. Replace if optimization safe
4. Verify tests still pass
5. Return optimization report
```

## Decision Tree: Which Factory Method?

```
What is test_level?

Unit test?
  Does test check persistence? (saved?, persisted?, id)
    YES → create (can't optimize)
    NO → build_stubbed (optimize!)

Integration/Request/E2E test?
  Does test use associations? (user.orders, post.comments)
    YES → create (associations need DB)
    NO → Does test check persistence?
      YES → create (can't optimize)
      NO → MAYBE optimize to build_stubbed (risky!)

When in doubt → Don't optimize (preserve behavior)
```

## Step-by-Step Process

### Step 1: Determine Test Level

```ruby
metadata = YAML.load_file(metadata_path)
test_level = metadata.dig('test_context', 'test_level')

# test_level values: 'unit', 'integration', 'request', 'e2e'
```

**Test level indicators:**
```ruby
def detect_test_level_from_spec(spec_content)
  if spec_content =~ /type:\s*:request/ || spec_content.include?('rails_helper')
    'request'
  elsif spec_content =~ /RSpec\.describe.*Controller/
    'request'
  elsif spec_content =~ /RSpec\.describe.*,.*type:\s*:model/
    'unit'
  else
    'unit'  # Default
  end
end
```

### Step 2: Find Factory Calls

```ruby
def find_factory_calls(spec_content)
  factory_calls = []

  # Pattern: create(:factory_name, ...)
  spec_content.scan(/\b(create|build|build_stubbed)\s*\(\s*:(\w+)([^\)]*)\)/) do
    factory_calls << {
      method: $1,
      factory: $2,
      args: $3,
      full_match: $&
    }
  end

  factory_calls
end

# Example matches:
# create(:user, name: 'John')
# build(:post, author: user)
# build_stubbed(:comment)
```

### Step 3: Check if Persistence Required

**Persistence is required when:**
1. Test calls `.id`, `.persisted?`, `.saved?` on object
2. Test uses associations that need DB (has_many, belongs_to)
3. Test performs database queries on object
4. Object is passed to another service that requires persisted records

```ruby
def requires_persistence?(factory_call, spec_content, let_name)
  factory = factory_call[:factory]

  # Check 1: Does test check persistence methods?
  if spec_content =~ /#{let_name}\.(id|persisted\?|saved\?|reload)/
    return true
  end

  # Check 2: Does test access associations?
  if spec_content =~ /#{let_name}\.\w+\.(create|build|<<|push)/
    return true
  end

  # Check 3: Does test query based on this object?
  if spec_content =~ /where\(.*#{let_name}|find_by\(.*#{let_name}/
    return true
  end

  # Check 4: Is object used in background job or service?
  if spec_content =~ /perform.*#{let_name}|\.call\(.*#{let_name}/
    return true  # Conservative: assume persistence needed
  end

  false  # Safe to use build_stubbed
end
```

### Step 4: Determine Optimal Method

```ruby
def optimal_factory_method(test_level, requires_persistence)
  case test_level
  when 'unit'
    requires_persistence ? :create : :build_stubbed
  when 'integration', 'request', 'e2e'
    :create  # Always use create for integration tests
  else
    :create  # Conservative default
  end
end

# Examples:
# test_level: unit, persistence: false → build_stubbed
# test_level: unit, persistence: true → create
# test_level: integration, persistence: false → create (conservative)
# test_level: integration, persistence: true → create
```

### Step 5: Apply Optimization

```ruby
def optimize_factory_calls(spec_content, factory_calls, test_level)
  optimizations = []
  modified_content = spec_content.dup

  factory_calls.each do |call|
    current_method = call[:method]
    factory = call[:factory]

    # Determine let name (if defined)
    let_name = find_let_name_for_factory(spec_content, call[:full_match])

    # Check if persistence required
    needs_persistence = requires_persistence?(call, spec_content, let_name)

    # Determine optimal method
    optimal = optimal_factory_method(test_level, needs_persistence)

    # Apply optimization if different and safe
    if optimal != current_method.to_sym && optimal == :build_stubbed
      old_call = call[:full_match]
      new_call = old_call.sub(current_method, optimal.to_s)

      modified_content.sub!(old_call, new_call)

      optimizations << {
        factory: factory,
        from: current_method,
        to: optimal,
        let_name: let_name,
        reason: "unit test, no persistence required"
      }
    end
  end

  [modified_content, optimizations]
end
```

### Step 6: Verify Tests Still Pass

**🔴 MUST verify tests pass after optimization**

```bash
# Write optimized spec to temp file
temp_file="/tmp/spec_optimized_$$.rb"
echo "$optimized_content" > "$temp_file"

# Run tests
if bundle exec rspec "$temp_file" > /dev/null 2>&1; then
  # Tests pass - optimization safe
  cp "$temp_file" "$spec_file"
  echo "✅ Optimization successful"
else
  # Tests fail - revert optimization
  echo "⚠️ Optimization broke tests, reverting"
  rm "$temp_file"
  exit 2  # Warning (not critical error)
fi
```

## Complete Example

**Input spec (before optimization):**
```ruby
# Unit test
RSpec.describe User, type: :model do
  describe '#full_name' do
    subject(:result) { user.full_name }

    let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns full name' do
      expect(result).to eq('John Doe')
    end
  end
end
```

**Analysis:**
- Test level: `unit` (model test)
- Factory call: `create(:user, ...)`
- Persistence check: No `.id`, `.persisted?`, associations, or queries
- Optimal method: `build_stubbed`

**Output spec (after optimization):**
```ruby
RSpec.describe User, type: :model do
  describe '#full_name' do
    subject(:result) { user.full_name }

    let(:user) { build_stubbed(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns full name' do
      expect(result).to eq('John Doe')
    end
  end
end
```

**Optimization report:**
```
✅ Optimized 1 factory call:
  - user: create → build_stubbed (unit test, no persistence required)
```

## Edge Cases

### Edge Case 1: Can't Optimize - Persistence Required

**Input:**
```ruby
let(:user) { create(:user) }

it 'saves user' do
  expect(user.persisted?).to be true  # Checks persistence!
end
```

**Analysis:**
- Test checks `.persisted?` → requires persistence
- Can't optimize to `build_stubbed`

**Output:** No change (create remains)

### Edge Case 2: Can't Optimize - Associations Used

**Input:**
```ruby
let(:post) { create(:post) }

it 'creates comment' do
  post.comments.create(body: 'Nice post')  # Uses association
  expect(post.comments.count).to eq(1)
end
```

**Analysis:**
- Test uses `post.comments` association → requires DB
- Can't optimize to `build_stubbed`

**Output:** No change

### Edge Case 3: Multiple Factory Calls

**Input:**
```ruby
let(:user) { create(:user) }
let(:admin) { create(:user, :admin) }
let(:post) { create(:post, author: user) }

it 'does something' do
  expect(user.name).to eq('John')  # No persistence check
end
```

**Analysis:**
- `user`: No persistence required → optimize to `build_stubbed`
- `admin`: No persistence required → optimize to `build_stubbed`
- `post`: Uses association (author: user) → keep `create` (conservative)

**Output:**
```ruby
let(:user) { build_stubbed(:user) }
let(:admin) { build_stubbed(:user, :admin) }
let(:post) { create(:post, author: user) }  # Not optimized (association)
```

### Edge Case 4: Integration Test - Conservative Approach

**Input:**
```ruby
# Integration test
RSpec.describe PaymentService do
  let(:user) { create(:user) }

  it 'processes payment' do
    service.process(user)
    # ...
  end
end
```

**Analysis:**
- Test level: `integration`
- Conservative approach: Don't optimize integration tests (complex dependencies)

**Output:** No change (keep `create` for safety)

### Edge Case 5: Trait with Dynamic Attributes

**Input:**
```ruby
let(:user) { create(:user, :with_orders) }
```

**Analysis:**
- Trait `:with_orders` likely creates associated records
- Requires database for associations
- Can't optimize

**Output:** No change

### Edge Case 6: Factory Used in Background Job

**Input:**
```ruby
let(:user) { create(:user) }

it 'enqueues job' do
  SomeJob.perform_later(user)
  # ...
end
```

**Analysis:**
- Background jobs typically require persisted records (id needed)
- Conservative: Don't optimize

**Output:** No change

## Optimization Safety Rules

**🔴 MUST: Never optimize if:**
1. Test level is `integration`, `request`, or `e2e` (conservative approach)
2. Test checks persistence (`.id`, `.persisted?`, `.reload`)
3. Test uses associations (`user.posts`, `post.comments`)
4. Object passed to service/job (may require persistence)
5. Object used in database queries (`where`, `find_by`)

**🟡 SHOULD: Be cautious when:**
1. Multiple factory calls in same let block
2. Factory uses traits (may create associations)
3. Test uses complex setup (before hooks, shared examples)

**🟢 MAY: Safely optimize when:**
1. Test level is `unit`
2. Test only accesses attributes (no persistence methods)
3. No associations involved
4. Object not passed to external services

## Testing Optimization Impact

**Performance benchmark example:**

```ruby
# Before optimization (create)
Benchmark.bm do |x|
  x.report("create") { 1000.times { create(:user) } }
end
# → ~2.5 seconds

# After optimization (build_stubbed)
Benchmark.bm do |x|
  x.report("build_stubbed") { 1000.times { build_stubbed(:user) } }
end
# → ~0.3 seconds (8x faster!)
```

**Typical improvements:**
- Unit tests: 5-10x faster
- Test suite: 20-40% faster overall (if many unit tests)

## Integration with Metadata

**Metadata provides test context:**

```yaml
test_context:
  test_level: unit  # Used by optimizer
  target_file: app/models/user.rb
  test_file: spec/models/user_spec.rb
```

**Optimizer uses test_level to make decisions:**
- `unit` → aggressive optimization (prefer `build_stubbed`)
- `integration`/`request`/`e2e` → conservative (keep `create`)

## Error Handling

### Error 1: Tests Fail After Optimization

```bash
⚠️ Optimization broke tests

Tests were passing with 'create(:user)'
Tests now failing with 'build_stubbed(:user)'

Reverting optimization...
✅ Reverted to original

This indicates test requires persistence.
Consider adding explicit persistence check or keeping 'create'.
```

**Exit code:** 2 (warning, not critical error)

### Error 2: Can't Parse Factory Calls

```bash
⚠️ Could not parse factory call

Found unusual factory syntax:
  FactoryBot.create(:user)  # Instead of create(:user)

Skipping optimization for this call.
```

**Action:** Skip this call, continue with others

### Error 3: Metadata Missing Test Level

```bash
⚠️ Test level not specified in metadata

Defaulting to 'unit' for optimization.

Consider adding test_level to metadata:
  test_context:
    test_level: unit
```

**Action:** Use conservative default (`unit`), warn user

## Related Specifications

- **agents/rspec-factory.spec.md** - Implements this algorithm
- **contracts/metadata-format.spec.md** - test_context.test_level
- **ruby-scripts/factory-detector.spec.md** - Finds available factories

---

**Key Takeaway:** Unit tests → `build_stubbed` (fast). Integration tests → `create` (safe). Always verify tests pass after optimization.
