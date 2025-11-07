# Agent Specifications Review - Improvement Plan

**Goal:** Evaluate and improve agent specifications for Claude Code Sonnet 4.5 implementation

**Criteria:**
- Sequential algorithm clarity
- Complete edge case handling
- No external dependencies (inline all referenced files)
- Claude AI native instructions (not Ruby pseudocode)
- Implementability by Claude Code Sonnet 4.5

---

## 1. rspec-analyzer.spec.md (1058 lines)

**Overall Rating:** 8/10 - Very good, needs improvements

**Status:** ✅ Reviewed

### Strengths:
- Clear philosophy and prerequisites
- 5 decision trees covering key decisions
- State machine visualization
- 4 examples (unit, integration, too simple, cached)
- Error handling (5 error types)

### Critical Issues:

#### 1.1 Terminal states algorithm unclear (lines 589-665)
**Problem:** Shows Ruby code `def identify_terminal_states(characteristic)` but agent is Claude AI, not script
**Resolution needed:**
- ✅ User confirmed: terminal_states MUST be written to metadata.yml (array format)
- ❌ Algorithm shows Ruby function instead of Claude logic
- **Fix:** Replace Ruby code with heuristic rules for Claude to apply mentally

#### 1.2 when_parent format inconsistency (line 144 vs 663)
**Problem:**
- Line 144: `when_parent: authenticated` (string)
- Line 663: `when_parent: [authenticated]` (array)
**Resolution:** ✅ User confirmed: ALWAYS array format
**Fix:** Update all examples to use array format

#### 1.3 Level assignment for independent characteristics unclear (lines 258-308)
**Problem:** Decision Tree 5 mentions "strength hierarchy" (auth → authz → business) but doesn't explain HOW to determine layer
**Resolution:** ✅ User confirmed: agent reasons independently
**Fix:** Add explicit reasoning guidelines (keywords, patterns, context clues)

#### 1.4 Reference to characteristic-extraction.md (line 438)
**Problem:** External file dependency, creates synchronization issues
**Found contradictions:**
- ❌ Terminal states: NOT in extraction.md but IN analyzer.md
- ❌ when_parent: NOT in extraction.md but IN analyzer.md
- ⚠️ Output YAML fields differ (condition_expression, default, line_number)
- ⚠️ Range with 3+ states: extraction.md says `type: range`, analyzer.md says `sequential` or `enum`
- ⚠️ Boolean && level assignment: extraction.md says both level 1, analyzer.md says consecutive unique levels

**Resolution:** ✅ User chose Option B - rewrite analyzer spec, inline all algorithm, remove reference
**Fix:** Merge characteristic-extraction.md into rspec-analyzer.spec.md inline

#### 1.5 Source location extraction (lines 451-502)
**Problem:** Not explicitly explained how to parse Read tool output format `45→ if user.authenticated?`
**Fix:** Add clear instructions: "Read tool shows `linenum→code`, extract linenum before →"

#### 1.6 Factory detector failure handling (lines 668-683)
**Problem:** Shows Bash code with exit code handling, unclear if agent executes or conceptual
**Fix:** Explicitly state "Use Bash tool to run ruby lib/.../factory_detector.rb, capture exit code"

#### 1.7 Metadata validation update (line 734)
**Problem:** Comment says `# Update validation section` but unclear who does this (agent or validator)
**Fix:** Clarify that metadata_validator.rb updates this, agent just runs it

#### 1.8 Too Complex error (lines 788-801)
**Problem:** Not mentioned in State Machine or Decision Trees
**Fix:** Add check in State Machine after "Extract Characteristics"

### Action Items:
- [ ] Inline characteristic-extraction.md content
- [ ] Replace terminal_states Ruby code with Claude heuristics
- [ ] Fix all when_parent examples to array format
- [ ] Add strength layer determination guidelines
- [ ] Clarify Read tool output parsing
- [ ] Add "Too Complex" check to State Machine
- [ ] Resolve contradictions from extraction.md merge

---

## 2. rspec-architect.spec.md (824 lines)

**Overall Rating:** 7.5/10 - Good structure, algorithm details incomplete

**Status:** ✅ Reviewed

### Strengths:
- Clear role definition (bridge structure ↔ semantics)
- Good use of source location comments (`# Logic: path:line`)
- 4 decision trees
- State machine
- 3 examples (replacement, no placeholders, reordering)

### Critical Issues:

#### 2.1 Reference to context-hierarchy.md (line 376)
**Problem:** External dependency `Read algorithms/context-hierarchy.md for full details`
**Status:** File exists but creates synchronization issue
**Resolution:** ✅ User chose Option B (same as analyzer) - inline everything
**Fix:** Merge context-hierarchy.md into rspec-architect.spec.md

#### 2.2 Step 3: Ruby pseudocode instead of Claude instructions (lines 430-491)
**Problem:**
```ruby
placeholders = spec_content.scan(/context ['"](\{CONTEXT_WORD\}[^'"]+)['"]/)
placeholders.each do |placeholder_text|
  # ... extract_context_block, read_source_at_location, analyze_code_path
end
```
Uses undefined functions, unclear if agent writes this code or applies logic mentally

**Fix:** Rewrite as step-by-step Claude instructions:
1. "Use Grep tool to find all `{CONTEXT_WORD}` patterns"
2. "For each match, use Read tool to extract surrounding context block"
3. "Find `# Logic: path:line` comment above placeholder"
4. etc.

#### 2.3 analyze_behaviors black box (lines 503-521)
**Problem:** `behaviors = analyze_behaviors(method_body, characteristic_path)` - no implementation
**Missing:** How to detect returns/raises/creates/calls from source code
**Fix:** Add detailed behavior detection algorithm:
- Scan for `return` statements → type: returns
- Scan for `raise` statements → type: raises
- Scan for `.create`, `.save`, `.update` → type: creates
- Scan for `SomeService.call`, external method calls → type: calls

#### 2.4 happy_path?() unclear for edge cases (lines 566-574)
**Problem:** Markers given but incomplete:
- What if context starts with 'and'? (happy or corner?)
- What if context is 'when user is authenticated'? (no markers)
- How to determine "default/expected behavior" for level 1?

**Fix:** Add complete decision tree:
```
if context.start_with?('with') → happy
elsif context.start_with?('but', 'without') → corner
elsif context.include?('NOT', 'invalid', 'error') → corner
elsif level == 1 and metadata.default exists → check default match
else → analyze source code for raise/return nil patterns
```

#### 2.5 Rules 17-20 not detailed (lines 525-551)
**Problem:** Rules mentioned but not explained:
- Rule 17: "form valid sentence" - what is invalid?
- Rule 18: "understandable by anyone" - how to detect jargon?
- Rule 19: Grammar rules listed but no algorithm
- Rule 20: Context words listed but no application algorithm

**Fix:** Either inline rules from guide.en.md or remove step (implementer can handle)

#### 2.6 Decision Tree 3: Multiple valid outcomes unclear (lines 256-281)
**Problem:**
```ruby
case user_type
when :admin → return full_access_token  # Valid
when :user → return limited_access_token  # Valid
when :guest → return read_only_token  # Valid
```
All paths valid - which is happy path?

**Fix:** Add tie-breaker rules:
1. Check metadata.default
2. Check first state in metadata.states array
3. Most permissive/feature-rich outcome
4. Alphabetical as last resort

### Action Items:
- [ ] Inline context-hierarchy.md content
- [ ] Rewrite Step 3 Ruby code as Claude instructions
- [ ] Add analyze_behaviors algorithm
- [ ] Complete happy_path?() decision tree
- [ ] Inline Rules 17-20 or remove step
- [ ] Add tie-breaker for multiple valid outcomes

---

## 3. rspec-implementer.spec.md (812 lines)

**Overall Rating:** 8.5/10 - Best spec so far, clear and detailed

**Status:** ✅ Reviewed

### Strengths:
- Very clear philosophy and role definition
- Excellent use of source location comments (`# Logic:`)
- Step 7 explicitly documents cleanup of `# Logic:` comments
- 4 decision trees covering key decisions
- Good examples (unit, integration, error, fallback)
- Clear test_level → factory method mapping
- Rule 1 enforcement algorithm (Step 6)

### Critical Issues:

#### 3.1 Step 1: Ruby pseudocode for method analysis (lines 336-346)
**Problem:**
```ruby
method_params = ['user', 'amount']
method_type = 'instance'
return_type = analyze_return_statements(method_body)
```
Same pattern as analyzer/architect - Ruby code instead of Claude instructions

**Fix:** Rewrite as:
```
1. Use Read tool to read source file
2. Find method definition line (search for "def method_name")
3. Extract parameters from definition (between parentheses)
4. Check if "def self." → class method, else → instance method
5. Scan method body for return statements to understand return_type
```

#### 3.2 Step 2: Subject definition algorithm (lines 348-362)
**Problem:** Shows Ruby if/elsif code
**Fix:** Decision tree format:
```
Method type?
  instance → subject(:result) { described_class.new.method_name(params) }
  class → subject(:result) { described_class.method_name(params) }

Where to place?
  → At top of outermost describe block (before any context)
```

#### 3.3 Step 3: determine_setup black box (line 394)
**Problem:** `determine_setup(char_name, state, method_params, test_level, factories_detected)` - no implementation

**Missing algorithm:**
- How to map characteristic_name to parameter_name?
- How to convert state to factory trait or attribute?
- How to combine multiple characteristics affecting same parameter?

**Example missing:**
```ruby
# Context path: ['user_authenticated=authenticated', 'payment_method=card', 'balance=sufficient']
# All three affect 'user' parameter
# How to combine?
# → let(:user) { build_stubbed(:user, :authenticated, payment_method: :card, balance: 200) }
```

**Fix:** Add explicit algorithm:
```
For each characteristic in context path:
  1. Extract char_name and state
  2. Determine which parameter this affects (usually matches char prefix)
  3. Check if trait exists in factories_detected
  4. If trait → add to traits list
  5. If no trait → add to attributes hash

Combine all for same parameter:
  let(:param) { factory_method(:model, *traits, **attributes) }
```

#### 3.4 Step 4: analyze_code_path black box (line 433)
**Problem:** `behavior = analyze_code_path(source_code, context_path)` - no implementation

**Missing:**
- How to identify behavior[:type] (:creates_record, :returns_value, :raises_error, :calls_service)?
- How to extract behavior[:model], behavior[:class], behavior[:error_class]?
- What if multiple behaviors in same path?

**Fix:** Add behavior detection algorithm:
```
Scan source code for patterns:

Pattern: ".create!(", ".save!", ".update!" → type: creates_record
  Extract model: Payment.create! → model: Payment

Pattern: "raise ErrorClass" → type: raises_error
  Extract: raise InsufficientFundsError → error_class: InsufficientFundsError

Pattern: "return value" or last expression → type: returns_value
  Determine value_type:
    - Variable that was created/fetched → :object
    - Literal (true, false, nil, number, string) → :literal
    - Calculation → :calculated

Pattern: "ServiceClass.call", "service.method" → type: calls_service
  Extract service class and method name

Multiple patterns found?
  → Multiple behaviors, need multiple expectations
```

#### 3.5 Step 6: Forbidden patterns (lines 485-503)
**Good concept but incomplete**

Missing patterns:
```ruby
/allow\([^)]+\)\.to receive/,     # Avoid stubs unless necessary
/instance_double/,                  # Careful with test doubles
/expect_any_instance_of/,          # Deprecated pattern
```

Also missing: **What to do when pattern detected?**
- Just warn? (current)
- Fail with error?
- Auto-fix?

**Recommendation:** Warn + suggest alternative
```
Found: expect(user).to receive(:save)
Suggest: expect { result }.to change { user.reload.saved_at }
```

#### 3.6 Reference to characteristic-extraction.md (line 807)
**Problem:** External dependency again
**Fix:** Remove or inline (already planned for analyzer)

### Minor Issues:

#### 3.7 Decision Tree 2 incomplete (lines 223-245)
**Missing case:** What if it description doesn't match any pattern?

Example: `it 'processes payment successfully'` - generic, no action verb

**Fix:** Add fallback:
```
it description is generic/unclear?
  → Analyze source code path
  → Infer behavior from code
  → Add comment: # TODO: verify expectation matches intent
```

#### 3.8 Error 2: Missing Factory (lines 574-582)
**Good:** Warning, not error (continues execution)
**Missing:** What if factory doesn't exist at all?

Current: "Using attributes instead of factory"
But: How to create attributes without factory?

**Fix:** Add fallback algorithm:
```
Factory missing?
  1. Try: FactoryBot.build(model_name, attributes)
  2. If fails: model_class.new(attributes)
  3. If still fails: raise error with instructions
```

#### 3.9 Example 4: Attribute fallback (lines 749-770)
**Shows output but not algorithm**

How did agent determine `authenticated: true`?
- trait name → attribute name mapping?
- state name → attribute value mapping?

**Fix:** Add mapping rules:
```
Trait missing: :authenticated
→ Convert to attribute:
  1. Remove : prefix → authenticated
  2. Assume boolean → authenticated: true
  3. For enum: payment_method: :card
  4. For range: balance: 200 (sufficient → high value)
```

### Action Items:
- [ ] Rewrite Step 1 as Claude instructions (not Ruby code)
- [ ] Convert Step 2 to decision tree
- [ ] Add determine_setup algorithm with combination logic
- [ ] Add analyze_code_path behavior detection algorithm
- [ ] Expand forbidden patterns list with suggestions
- [ ] Add Decision Tree 2 fallback for generic it descriptions
- [ ] Add factory missing fallback algorithm
- [ ] Document trait → attribute mapping rules
- [ ] Remove characteristic-extraction.md reference

### Overall Assessment:

**Implementability: 75%**

✅ Agent can handle:
- Simple cases (unit tests, single parameters)
- Error expectations (raise_error)
- Return value checks (basic types)
- build_stubbed vs create selection

❌ Agent may struggle with:
- Combining multiple characteristics on same parameter
- Generic it descriptions
- Complex behavior detection (multiple side effects)
- Trait missing → attribute fallback logic

---

## 4. rspec-factory-optimizer.spec.md (449 lines)

**Overall Rating:** 7/10 - Shorter spec, simpler agent, but missing critical algorithms

**Status:** ✅ Reviewed

### Strengths:
- Clear philosophy (gentle optimizer, never break tests)
- Good exit code handling (0 if nothing to optimize)
- 3 decision trees for optimization decisions
- 4 good examples (optimize, suggest, multiple traits, composite)
- Warnings-only approach (no hard failures)
- Recognizes safe vs unsafe optimizations

### Critical Issues:

#### 4.1 Step 1: Ruby regex parsing (lines 142-156)
**Problem:** Shows Ruby code with regex scanning
```ruby
factory_calls = spec_content.scan(/(create|build_stubbed|build)\(:(\w+)[^)]*\)/)
factory_calls.each do |method, factory_name, args|
  # Extract attributes being overridden
end
```

**Issues:**
- Same Ruby pseudocode pattern as other specs
- Regex doesn't handle multi-line factory calls
- Doesn't extract actual args content (just [^)]*?)

**Fix:** Rewrite as Claude instructions:
```
1. Use Grep tool to find all factory method calls in spec file
   Pattern: "build_stubbed\|create\|build"
2. For each match, use Read tool to extract full call (handle multi-line)
3. Parse factory call structure:
   - Method: build_stubbed / create / build
   - Factory name: symbol after method
   - Traits: symbols in arguments
   - Attributes: key-value pairs in arguments
```

#### 4.2 Step 2: check_if_persisted black box (line 167)
**Problem:** `needs_db = check_if_persisted(call, spec_content)` - no implementation

**Missing algorithm:** How to determine if record needs database?

**Fix:** Add explicit detection algorithm:
```
Check if record is persisted in test:

Scan spec for patterns involving this variable:
  - #{var}.save, #{var}.update → needs DB
  - #{var}.reload → needs DB
  - change(Model, :count) → needs DB
  - Model.find(#{var}.id) → needs DB

Scan spec for patterns NOT needing DB:
  - Only reads attributes: #{var}.name, #{var}.email
  - Used in calculations: calculate(#{var})
  - Passed to pure methods: validator.check(#{var})

Decision:
  Any persistence pattern found → needs_db = true
  Only read patterns → needs_db = false
```

#### 4.3 Step 3: find_matching_trait black box (line 191)
**Problem:** `matching_trait = find_matching_trait(attr, value, available_traits)` - no implementation

**Missing:** How to match attribute to trait name?

**Examples that need clarification:**
```ruby
# Attribute: authenticated: true
# Trait: :authenticated
# Match? YES (exact name match)

# Attribute: role: 'admin'
# Trait: :admin
# Match? YES (value matches trait name)

# Attribute: verified: true
# Trait: :verified
# Match? YES (exact name match)

# Attribute: balance: 200
# Trait: :high_balance
# Match? UNCLEAR (semantic match, not literal)
```

**Fix:** Add matching algorithm:
```
Matching heuristics (in priority order):

1. Exact name match:
   attr_name == trait_name → MATCH
   Example: authenticated: true ↔ :authenticated

2. Value matches trait name:
   attr_value.to_s == trait_name → MATCH
   Example: role: 'admin' ↔ :admin

3. Boolean attribute with matching trait:
   attr: true && trait exists with same name → MATCH
   Example: premium: true ↔ :premium

4. Semantic match (SKIP - too risky):
   balance: 200 ↔ :high_balance (don't auto-match)
   → Warn about manual consideration
```

#### 4.4 Step 4: Composite trait detection regex (line 212)
**Problem:** Hardcoded regex for exactly 2 traits
```ruby
spec_content.scan(/build_stubbed\(:(\w+), :(\w+), :(\w+)\)/)
```

This only matches 2 traits, misses:
- Single trait: `build_stubbed(:user, :admin)`
- 3+ traits: `build_stubbed(:user, :admin, :verified, :premium)`

**Fix:** Generalize algorithm:
```
For each factory call:
  1. Extract all traits used (any number)
  2. Normalize: sort traits alphabetically
  3. Create key: "factory_name:trait1:trait2:..."
  4. Track frequency: combinations[key] += 1

After scanning all calls:
  combinations.each do |key, count|
    if count >= 3 && traits.length >= 2
      suggest composite trait
    end
  end
```

#### 4.5 Reference to factory-optimization.md (line 444)
**Problem:** External reference again
```
Related Specifications:
- algorithms/factory-optimization.md - Detailed decision trees
```

**Status:** ✅ File exists
**Resolution:** Same as analyzer/architect - inline content (Option B)

### Minor Issues:

#### 4.6 No State Machine
**Missing:** Unlike other agents, no state machine visualization
**Impact:** Medium - harder to understand flow
**Fix:** Add state machine showing: Prerequisites → Parse → Optimize create → Optimize traits → Suggest composite → Write

#### 4.7 Example 1: check_if_persisted unclear (lines 281-310)
**Example shows:**
- Input: `let(:user) { create(:user) }`
- Output: `let(:user) { build_stubbed(:user) }`
- Reason: "just read attribute"

**But:** How did agent determine it's "just read attribute"?
- Need to scan entire spec for user usage
- Algorithm for this is missing (relates to 4.2)

#### 4.8 Exit code 0 when nothing to optimize (line 60)
**Good:** Not treating "no factories" as error
**Question:** Should this be logged to metadata?
```yaml
automation:
  factory_optimizer_completed: true
  factory_optimizer_skipped: true  # No factories found
  factory_optimizer_version: '1.0'
```

### Action Items:
- [ ] Rewrite Step 1 Ruby regex as Claude instructions
- [ ] Add check_if_persisted algorithm
- [ ] Add find_matching_trait matching heuristics
- [ ] Fix composite trait detection (support any number of traits)
- [ ] Inline factory-optimization.md content
- [ ] Add State Machine visualization
- [ ] Document skip reason in metadata

### Overall Assessment:

**Implementability: 60%**

✅ Agent can handle:
- Simple create → build_stubbed (if check_if_persisted implemented)
- Exact trait name matches
- Warning generation

❌ Agent may struggle with:
- Multi-line factory calls (regex limitation)
- Semantic trait matching (balance → high_balance)
- Complex persistence detection (indirect DB usage)
- Composite trait patterns (hardcoded regex)

**Severity:** Medium - Agent is optional (tests work without it), but won't provide much value without missing algorithms

---

## 5. rspec-polisher.spec.md (580 lines)

**Overall Rating:** 9.5/10 - Excellent spec, nearly perfect

**Status:** ✅ Reviewed

### Strengths:
- **DIFFERENT agent type:** Orchestrator, not analyzer - clearly stated
- Bash commands ARE the algorithm (not pseudocode)
- 3 decision trees for tool selection
- Excellent error handling (warnings vs errors)
- 5 comprehensive examples covering all scenarios
- Handles missing tools gracefully (linter optional)
- No semantic changes - only style/syntax
- Exit code 0 even with warnings (correct behavior)
- No external file dependencies

### What Makes This Spec Great:

#### Best practices followed:
1. **Clear agent type declaration** (lines 8-20): Orchestrator vs Analyzer
2. **Actual Bash workflow** (not Ruby pseudocode): Steps 1-5 are executable
3. **Graceful degradation**: Missing linter = warning, not error
4. **Comprehensive tool detection** (lines 63-90): RuboCop, StandardRB, fallback
5. **5 examples covering**:
   - Auto-fix success
   - Tests fail (warning only)
   - Nothing to fix
   - StandardRB (not just RuboCop)
   - No linter detected

### Minor Issues:

#### 5.1 Step 4: Quality checks regex (lines 248-270)
**Potential problems:**

```bash
# Line 254: Empty it blocks check
if grep -q "it '[^']*' do\s*end" "$spec_file"; then
```

**Issue:** `\s` is not valid in basic grep (needs grep -E or grep -P)

**Fix:**
```bash
if grep -E -q "it '[^']*' do\s*end" "$spec_file"; then
```

Or more robust:
```bash
if grep -E -q "it '[^']*' do[[:space:]]*end" "$spec_file"; then
```

#### 5.2 Step 4: Duplicates detection (line 267)
```bash
duplicates=$(grep "it '" "$spec_file" | sort | uniq -d)
```

**Problem:** This finds duplicate LINES, not duplicate descriptions
**Example miss:**
```ruby
it 'returns name' do  # Line 1
it 'returns name' do  # Line 2 (different indentation = different line)
```

**Fix:**
```bash
# Extract just descriptions, ignore indentation
duplicates=$(grep -o "it '[^']*'" "$spec_file" | sort | uniq -d)
```

#### 5.3 Step 2: Linter exit code handling (lines 206-221)
**Good logic but incomplete:**

Current:
```bash
case $exit_code in
  0) # No offenses
  1) # Offenses corrected
  *) # Offenses remain
esac
```

**Missing:** What if linter crashes (exit code 2)?
- RuboCop exit code 2 = error (not offenses)
- Should distinguish between "offenses" and "crash"

**Fix:**
```bash
case $exit_code in
  0) echo "✅ No offenses" ;;
  1) echo "✅ Offenses corrected" ;;
  2)
    echo "❌ Linter crashed" >&2
    echo "$linter_output" >&2
    warnings+=("$LINTER error - see output")
    ;;
  *) echo "⚠️ Offenses remain" ;;
esac
```

#### 5.4 Step 3: Test execution always runs (line 231)
```bash
if [ ${#errors[@]} -eq 0 ]; then
  test_output=$(bundle exec rspec "$spec_file" 2>&1)
```

**Question:** What if RSpec gem not installed?
- Current: Will fail with "bundle exec: rspec: command not found"
- Should check RSpec availability first?

**Suggestion:** Add prerequisite check:
```bash
if bundle exec rspec --version &> /dev/null 2>&1; then
  # Run tests
else
  echo "⚠️  RSpec not available, skipping test execution" >&2
  warnings+=("RSpec not available for test execution")
fi
```

#### 5.5 Metadata updates not shown (lines 276-278)
**Good:** Documents that metadata is updated
**Missing:** How to update YAML from Bash?

Current:
```bash
# Update metadata
# Add: automation.polisher_completed = true
# Add: automation.warnings = [...]
```

**Options:**
1. Use ruby -e with YAML library
2. Use yq tool (if available)
3. Simple append (if metadata structure allows)

**Recommendation:** Add explicit update method:
```bash
# Update metadata with Ruby
ruby -r yaml -e "
  metadata = YAML.load_file('$metadata_path')
  metadata['automation'] ||= {}
  metadata['automation']['polisher_completed'] = true
  metadata['automation']['linter'] = '$LINTER'
  metadata['automation']['warnings'] = $(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
  File.write('$metadata_path', YAML.dump(metadata))
"
```

### Action Items:
- [ ] Fix Step 4 regex (use grep -E for `\s`)
- [ ] Fix duplicate detection (extract descriptions only)
- [ ] Add linter exit code 2 handling (crash vs offenses)
- [ ] Add RSpec availability check before test execution
- [ ] Document metadata update method (Ruby/yq)

### Overall Assessment:

**Implementability: 95%**

✅ Agent can handle:
- All primary workflows
- Tool detection (RuboCop, StandardRB)
- Graceful degradation (missing tools)
- Warning vs error distinction
- Auto-fix safe issues

⚠️ Minor fixes needed:
- Regex escaping in quality checks
- Linter crash handling
- RSpec availability check

**Severity:** Low - Spec is excellent, issues are edge cases

**Why this spec works well:**
1. Agent type matches content (orchestrator, not analyzer)
2. Bash is the implementation language (not pseudocode)
3. Comprehensive examples
4. No black box functions
5. Clear tool dependencies

---

## 6. rspec-reviewer.spec.md (586 lines)

**Overall Rating:** 8/10 - Good conceptual spec, but vague on implementation

**Status:** ✅ Reviewed

### Strengths:
- **READ-ONLY constraint** clearly stated (lines 18-21)
- Semantic analyzer, not pattern matcher (lines 11-26)
- Comprehensive coverage (all 28 rules from guide.en.md)
- 3 good examples (good test, serious issues, standalone)
- Educational report format (WHY, not just WHAT)
- Can run standalone (with or without metadata)
- Never fails (always generates report)

### Critical Issues:

#### 6.1 Step 2: Ruby pseudocode throughout (lines 146-250)
**Problem:** Entire algorithm written as Ruby code

Examples:
```ruby
violations = []
if spec_content =~ /\.to receive\(:save\)/
  violations << {
    rule: 1,
    severity: 'MUST',
    issue: 'Testing implementation'
  }
end
```

**Same issue as all other specs** - this looks like code to execute, not instructions for Claude

**BUT:** Line 24-26 says "Code examples show WHAT to check, use semantic understanding"

**Confusion:** Are these patterns or actual implementation?

**Fix:** Either:
1. Rewrite as Claude instructions (like other agents)
2. Or clearly state "This Ruby code is for illustration only, you apply logic semantically"

#### 6.2 No explanation of "semantic understanding" (line 26)
**Claims:** "Testing implementation requires understanding context, not just seeing `.receive(`"

**Missing:** HOW to understand context?

**Example missing:**
```ruby
# Pattern match finds this:
expect(service).to receive(:create_payment)  # ← Implementation testing?

# But THIS is OK:
expect(payment_gateway).to receive(:charge)  # ← Dependency injection, not implementation

# How to tell the difference?
# - If receiver is subject/described_class → likely implementation
# - If receiver is injected dependency → likely OK
# - Requires understanding test structure and design patterns
```

**Fix:** Add decision tree for semantic vs syntactic checks:
```
For Rule 1 (behavior vs implementation):

Syntactic check (pattern matching):
  - Scan for .receive(:save), .receive(:create), etc.
  - Flag as potential violation

Semantic check (understanding):
  1. Is receiver the subject under test? → Implementation testing
  2. Is receiver an injected dependency? → Dependency check (OK)
  3. Is method private? → Implementation (violation)
  4. Is method public interface? → Behavior (depends on context)
```

#### 6.3 All 28 rules not documented (line 148)
**Says:** "See `guide.en.md` for all 28 rules"

**Problem:** External reference again + agent needs to know ALL rules inline

**Missing:** What are the 28 rules? Which are:
- 🔴 MUST (violations)
- 🟡 SHOULD (warnings)
- 🟢 MAY (suggestions)

**Fix:** Inline complete rule list with severity and checkability:
```markdown
## Complete Rule Checklist

### Rules 1-9: Behavior and Structure
1. **Test behavior, not implementation** (🔴 MUST) - Heuristic check
2. **Write tests for public interface** (🔴 MUST) - Manual review
3. **One behavior per it block** (🟡 SHOULD) - Heuristic check
...

### Rules 10-11: Syntax and Readability
10. **Use expect syntax** (🔴 MUST) - Automated check: /.should /
11. **Choose right matcher** (🟡 SHOULD) - Pattern checks
...

### Rules 12-16: Context and Data Preparation
...

### Rules 17-20: Language Rules
17. **Form valid sentence** (🟡 SHOULD) - Parse structure
18. **Understandable by anyone** (🟢 MAY) - Manual review
19. **Grammar** (🟡 SHOULD) - Pattern checks: /should |can |must /
20. **Context language** (🟡 SHOULD) - Check when/with/and/but/without
...

### Rules 21-28: Tools and Support
22. **Never any_instance_of** (🔴 MUST) - Automated check: /any_instance_of/
25. **Time stability** (🟡 SHOULD) - Check Time.now without travel_to
...
```

#### 6.4 Step 3: Time handling checks (lines 252-271)
**Good:** Specific checks for Ruby vs PostgreSQL time issues

**Problem:** References "guide.en.md line 3252+" - external reference

**Also missing:** Complete time handling checklist

**Should include:**
- Date.parse vs Time.zone.parse
- Date#wday vs PostgreSQL DOW
- DST transitions
- Time precision (Ruby vs PostgreSQL)
- Time.now vs Time.current
- Date arithmetic edge cases

**Fix:** Inline complete time handling section from guide.en.md

#### 6.5 Report generation (Step 4, lines 273-307)
**Shows:** Markdown template

**Missing:** How to populate template?
- How to count passed/warnings/violations?
- How to sort issues by severity?
- How to generate "Why it matters" explanations?
- How to generate fix code examples?

**Example 2 (lines 408-491)** shows great report with:
- Location: Line 45
- Why it matters: explanation
- Fix: code example

**But:** Algorithm for generating this is black box

**Fix:** Add report generation algorithm:
```
For each violation:
  1. Extract location (line number)
  2. Extract code snippet (5 lines context)
  3. Lookup rule description from guide
  4. Generate "why it matters" (from rule philosophy)
  5. Generate fix example (pattern replacement + guide example)
```

#### 6.6 No State Machine
**Missing:** Unlike most other agents, no state machine diagram

**Impact:** Hard to understand flow

**Fix:** Add:
```
[START]
  ↓
[Check Prerequisites]
  ↓
[Load Spec File]
  ↓
[Load Metadata (optional)]
  ↓
[For Each Rule Category]
  ├─ Syntax checks (automated)
  ├─ Pattern checks (regex)
  └─ Heuristic checks (semantic)
      ↓
[Time Handling Checks]
  ↓
[Calculate Summary]
  ↓
[Generate Report]
  ↓
[Write Report File]
  ↓
[END: exit 0 always]
```

### Minor Issues:

#### 6.7 Example 3: "not checkable without metadata" (line 513)
**Lists:** 8 rules not checkable

**Missing:** Which 8 rules? Why not checkable?

**Should document:**
```
Rules requiring metadata:
- Rule 4: Characteristic types → needs metadata.characteristics[].type
- Rule 5: Dependencies → needs metadata.characteristics[].depends_on
- Rule 7: Happy path first → needs metadata.characteristics[].default
- Rule 14: build_stubbed vs create → needs metadata.test_level
- ...
```

#### 6.8 Standalone usage (lines 495-534)
**Good:** Can run without metadata

**Question:** How does agent know to generate report without tool invocation?

Current spec shows Bash command:
```bash
rspec-reviewer spec/models/user_spec.rb
```

But agent is Claude AI, not Bash script. How does user invoke?

**Options:**
1. Via skill: "Review tests in spec/..."
2. Via subagent invocation
3. Via some CLI wrapper

**Should clarify** invocation method

### Action Items:
- [ ] Clarify Ruby code purpose (illustration vs implementation)
- [ ] Add semantic vs syntactic check decision trees
- [ ] Inline all 28 rules with severity and checkability
- [ ] Inline time handling complete checklist from guide.en.md
- [ ] Add report generation algorithm (how to populate template)
- [ ] Add State Machine visualization
- [ ] Document which rules need metadata (with reasons)
- [ ] Clarify standalone invocation method

### Overall Assessment:

**Implementability: 70%**

✅ Agent can handle:
- Automated checks (any_instance_of, should syntax)
- Pattern matching (regex-based rules)
- Report generation (basic structure)
- Standalone operation

❌ Agent may struggle with:
- Semantic understanding (Rule 1 - behavior vs implementation)
- Rules requiring deep analysis (Rule 3 - one behavior per it)
- Generating "why it matters" explanations (no source)
- Fix examples (no pattern library)
- Rules not documented in spec (external reference to guide.en.md)

**Severity:** Medium - Agent can provide value with automated checks, but will miss subtle violations without semantic understanding algorithms

---

## Summary: Agent Ratings

| Agent | Lines | Rating | Implementability | Severity |
|-------|-------|--------|-----------------|----------|
| rspec-analyzer | 1058 | 8/10 | 75% | High |
| rspec-architect | 824 | 7.5/10 | 65% | High |
| rspec-implementer | 812 | 8.5/10 | 75% | High |
| rspec-factory-optimizer | 449 | 7/10 | 60% | Medium |
| rspec-polisher | 580 | 9.5/10 | 95% | Low |
| rspec-reviewer | 586 | 8/10 | 70% | Medium |

**Best spec:** rspec-polisher (9.5/10) - orchestrator type, Bash is implementation, comprehensive examples, no black boxes

**Worst spec:** rspec-factory-optimizer (7/10) - missing critical algorithms, hardcoded regex, no state machine

**Most critical to fix:** rspec-analyzer, rspec-architect, rspec-implementer (pipeline core, high severity)

---

## Common Patterns Across Specs

### Issues Found:

#### 1. External File References (HIGH PRIORITY)
**Problem:** Specs reference algorithm files that may contradict main spec
- analyzer → characteristic-extraction.md (contradictions found)
- architect → context-hierarchy.md
- factory-optimizer → factory-optimization.md
- reviewer → guide.en.md (28 rules)

**Impact:** Synchronization nightmares, contradictory instructions
**Solution:** Inline all content (User chose Option B)

#### 2. Ruby Pseudocode vs Claude Instructions (HIGH PRIORITY) ⚠️ CRITICAL UNDERSTANDING

**Problem:** Most specs show Ruby code without Claude instructions context

**Real-world impact from user experience:**
> "When I asked you to write subagent from spec, you wrote a dumb Ruby script that literally copied pseudocode. The script couldn't handle different cases and was absolutely useless."

**Why this is critical:**
- Agent may literally write the Ruby code as a script
- Script won't have semantic understanding or edge case handling
- Agent needs **instructions on WHAT to do and HOW to think**
- Agent THEN chooses tools (bash/grep/Read/temporary scripts)

**Current state:**
- analyzer: Step 7b shows `def identify_terminal_states` with no instructions
- architect: Step 3 shows `placeholders.each do |placeholder_text|` without context
- implementer: Steps 1-4 are Ruby functions without decision trees
- factory-optimizer: Steps 1-3 regex scanning without alternatives
- reviewer: Step 2 entire algorithm in Ruby

**Exception:**
- ✅ polisher: Bash IS the implementation (correct for orchestrator type)

**Correct approach:**
```
✅ GOOD: Claude instructions first, Ruby as example
Step 3: Extract characteristics

Instructions:
1. Read source file using Read tool
2. Identify all conditional statements
3. For each conditional, determine:
   - Characteristic name (use semantic understanding)
   - States (analyze all code paths)
   - Dependencies (understand nesting context)

Example implementation approach (Ruby):
```ruby
# This shows the LOGIC, agent may use different tools
conditionals.each do |cond|
  name = semantic_analysis(cond)  # Agent does this with understanding
  states = extract_states(cond)   # Agent chooses how
end
```

Tools you may use:
- Read for file access
- Grep for pattern finding
- Native understanding for semantics
- Bash/Ruby scripts IF needed for specific steps
```

❌ BAD: Just Ruby code
```ruby
# Step 3: Extract characteristics
conditionals.each do |cond|
  # ... code without instructions
end
```

**Solution:**
1. Add Claude instructions BEFORE Ruby examples
2. Mark Ruby code as "Example logic" or "Illustrative approach"
3. Emphasize semantic understanding requirements
4. Provide decision trees for complex logic
5. List available tools explicitly

#### 3. Black Box Functions (HIGH PRIORITY)
**Problem:** Functions called but never defined
- analyzer: `identify_terminal_states()`, `analyze_return_statements()`
- architect: `analyze_behaviors()`, `happy_path?()`
- implementer: `determine_setup()`, `analyze_code_path()`
- factory-optimizer: `check_if_persisted()`, `find_matching_trait()`
- reviewer: `generate_why_it_matters()`

**Impact:** Agent can't implement without algorithms
**Solution:** Add complete algorithms for each black box function

#### 4. Incomplete Edge Case Handling (MEDIUM PRIORITY)
**Problem:** Decision trees miss branches
- analyzer: What if 7+ nesting levels? (mentioned in error but not in flow)
- architect: Multiple valid outcomes - which is happy path?
- implementer: Generic it descriptions without action verbs
- factory-optimizer: Multi-line factory calls
- reviewer: Semantic vs syntactic checks

**Impact:** Agent fails or makes wrong decisions on edge cases
**Solution:** Add else/default branches to all decision trees

#### 5. Missing State Machines (MEDIUM PRIORITY)
**Problem:** Only 5/6 agents have state machine diagrams
- ❌ factory-optimizer: No state machine

**Impact:** Harder to understand agent flow
**Solution:** Add state machines to all agents

#### 6. Inconsistent Formats (LOW PRIORITY)
**Problem:** Small inconsistencies across specs
- when_parent: string vs array (analyzer)
- terminal_states: documented vs not documented (analyzer vs extraction)
- YAML field names: different across specs

**Impact:** Minor confusion, potential bugs
**Solution:** Standardize formats across all specs

---

## Prioritized Action Plan

### 🔴 CRITICAL (Must Fix Before Implementation)

**Priority 1: Inline External References**
- [ ] Merge characteristic-extraction.md into rspec-analyzer.spec.md
- [ ] Merge context-hierarchy.md into rspec-architect.spec.md
- [ ] Merge factory-optimization.md into rspec-factory-optimizer.spec.md
- [ ] Extract and inline 28 rules from guide.en.md into rspec-reviewer.spec.md
- [ ] Extract and inline time handling section from guide.en.md into rspec-reviewer.spec.md

**Estimated effort:** 8-12 hours (content merge + contradiction resolution)

**Priority 2: Define Black Box Algorithms**
- [ ] analyzer: `identify_terminal_states()` → heuristic rules
- [ ] architect: `analyze_behaviors()` → pattern detection algorithm
- [ ] architect: `happy_path?()` → complete decision tree
- [ ] implementer: `determine_setup()` → parameter mapping + combination logic
- [ ] implementer: `analyze_code_path()` → behavior type detection
- [ ] factory-optimizer: `check_if_persisted()` → persistence pattern scan
- [ ] factory-optimizer: `find_matching_trait()` → trait matching heuristics
- [ ] reviewer: Report generation → template population algorithm

**Estimated effort:** 10-15 hours (8 algorithms to define)

**Priority 3: Add Claude Instructions Around Ruby Code**
- [ ] analyzer: Add instructions before Steps 1, 3-7 (keep Ruby as examples)
- [ ] architect: Add instructions before Steps 1-5 (keep Ruby as examples)
- [ ] implementer: Add instructions before Steps 1-4 (keep Ruby as examples)
- [ ] factory-optimizer: Add instructions before Steps 1-4 (keep Ruby as examples)
- [ ] reviewer: Add instructions before Step 2 (keep Ruby as examples)

**For each step:**
1. Add "Instructions:" section with Claude workflow
2. Add "Example logic (Ruby):" to existing code blocks
3. Add "Tools you may use:" list
4. Emphasize semantic understanding where needed
5. Keep Ruby examples for logic illustration

**Estimated effort:** 8-10 hours (5 specs, more complex than rewrite)

### 🟡 IMPORTANT (Should Fix for Quality)

**Priority 4: Complete Decision Trees**
- [ ] analyzer: Add "Too Complex" check to state machine
- [ ] architect: Add tie-breaker for multiple valid outcomes
- [ ] implementer: Add fallback for generic it descriptions
- [ ] factory-optimizer: Generalize composite trait detection regex
- [ ] reviewer: Add semantic vs syntactic check decision trees

**Estimated effort:** 4-6 hours

**Priority 5: Add Missing State Machines**
- [ ] factory-optimizer: Add state machine diagram

**Estimated effort:** 30 minutes

**Priority 6: Standardize Formats**
- [ ] Fix when_parent to always be array
- [ ] Fix terminal_states documentation
- [ ] Standardize YAML field names across specs

**Estimated effort:** 2-3 hours

### 🟢 NICE TO HAVE (Polish)

**Priority 7: Minor Issues**
- [ ] polisher: Fix regex escaping (grep -E)
- [ ] polisher: Add linter exit code 2 handling
- [ ] polisher: Add RSpec availability check
- [ ] polisher: Document metadata update method
- [ ] All specs: Add more examples for edge cases

**Estimated effort:** 2-3 hours

---

## Total Estimated Effort

- Critical: 26-37 hours (increased Priority 3 from 6-8h to 8-10h)
- Important: 6.5-9.5 hours
- Nice to have: 2-3 hours

**Total: 34.5-49.5 hours** (4-6 working days)

**Note:** Priority 3 takes longer because we're adding instructions AROUND existing Ruby code, not just replacing it.

---

## Recommendations

### Approach A: Fix All At Once
**Pros:**
- Complete consistency across all specs
- All agents ready for implementation
- No half-broken pipeline

**Cons:**
- 4-6 days of work before any agent can be tested
- Risk of scope creep
- User can't provide feedback on individual fixes

### Approach B: Incremental (RECOMMENDED)
**Pros:**
- Test each agent after fixes
- User provides feedback incrementally
- Can reprioritize based on learnings

**Cons:**
- Pipeline may be partially broken during fixes
- Requires careful coordination

**Suggested order:**
1. Fix analyzer (Priority 1-3) → Test → Iterate
2. Fix architect (Priority 1-3) → Test → Iterate
3. Fix implementer (Priority 1-3) → Test → Iterate
4. Fix factory-optimizer (Priority 1-3) → Test → Iterate
5. Fix polisher (Priority 7) → Test → Iterate
6. Fix reviewer (Priority 1-3) → Test → Iterate
7. Address Priority 4-6 (decision trees, state machines, formats)

### Approach C: MVP First
**Focus on core 3 agents:**
1. analyzer
2. architect
3. implementer

Skip optional agents (factory-optimizer, polisher, reviewer) until core works.

**Pros:**
- Fastest path to working pipeline
- Focus on highest value
- Can add optional agents later

**Cons:**
- Less polished output
- No quality checks

---

## Next Steps

**User Decision Needed:**

1. **Which approach?** (A, B, or C)
2. **Start with which agent?** (Recommendation: analyzer)
3. **Inline content depth?** (Full merge vs summary with key algorithms)

After decision, I will:
1. Create detailed fix plan for first agent
2. Execute fixes
3. Present result for review
4. Move to next agent
