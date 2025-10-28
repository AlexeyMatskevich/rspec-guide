# RSpec Testing Agent Playbook

## 1. Principles of the RSpec Style Guide (Briefly)

The RSpec Style Guide emphasizes a behavior-first approach to testing, aiming to reduce cognitive load and use tests as indicators of code quality. Key principles include:

- **Test behavior, not implementation**: Focus on externally observable outcomes rather than internal method calls or state changes. Tests should verify what the code does (the business result), not how it does it.
- **Organize tests by characteristics and states**: Structure your `describe`/`context` blocks around characteristics of the subject under test and their possible states or inputs. Each context should represent one scenario or condition (e.g. user role, input type, config flag).
- **"Happy path" comes first**: In each group of tests, write the successful or common case scenario before edge cases or error cases. This ensures the primary expected behavior is clear and upfront, with corner cases handled afterward.
- **Minimize extraneous cognitive load**: Write tests in a way that's easy to read and understand. Avoid unnecessary complexity, keep setup consistent, and use clear descriptions. Every rule in the guide aims to reduce unnecessary complexity and help the reader build a mental model of the system.
- **Tests as quality indicators**: Treat tests as first-class code. Well-structured tests can reveal design problems in production code. If tests are hard to write or understand, it often signals issues in the code's API or responsibilities.

These principles form the basis of the style guide and will guide both automated agents and human developers in writing maintainable RSpec tests.

## 2. Step-by-Step Algorithm for an Agent (General Workflow)

An AI agent (like Anthropic's Claude Code or OpenAI's Codex CLI) can follow a structured workflow to generate and evolve RSpec tests that conform to the style guide. The process is as follows:

### Step 2.1: Identify the SUT (Subject Under Test)
The agent should determine which class or method is being tested (the SUT) and its public interface or behavior. Typically this comes from the context (e.g. the file or function name). The agent sets up a top-level `describe` block for the SUT (and a nested `describe` for the specific method, if applicable). The `subject` should be defined at the outer `describe` level so it's clear what is being tested. For example, if testing a class `OrderProcessor`, use `describe OrderProcessor do ...` with `subject { OrderProcessor.new(...).perform }` at the top level (or a suitable public method call in the subject).

### Step 2.2: Map out characteristics and contexts
Next, the agent analyzes the SUT to enumerate independent characteristics or input dimensions that affect behavior. These become the basis for organizing nested `context` blocks. Independent characteristics (e.g. user type, account status, locale, etc.) should be top-level contexts, and dependent or secondary factors nested inside their relevant parent context. Only one characteristic per context level is allowed. For example, if testing a discount calculator, an independent characteristic might be customer segment ("b2c" vs "b2b"), and a dependent characteristic could be subscription status ("with premium" vs "without premium") under the b2c segment. The agent should plan a hierarchy like:

```ruby
context 'when segment is b2c' do    # Characteristic 1
  context 'with premium subscription' do    # Characteristic 2 (dependent)
    ...examples...
  end
  context 'without premium subscription' do
    ...examples...
  end
end
```

This "characteristic-based hierarchy" ensures each context's description adds one piece of information about the scenario.

### Step 2.3: Ensure both happy path and edge cases are covered
For each describe/context group, the agent must include at least two contexts: one for the normal or happy path scenario and another for a negative or edge case. The custom cop `CharacteristicsAndContexts` will actually enforce that a `describe` has at least one positive and one alternative context. The agent should generate the happy-path context first, followed by contexts for error conditions, boundary inputs, or other corner cases (the `HappyPathFirst` rule enforces this order). For example, in a user login feature, first context might be "with valid credentials" (happy path) and the second "with invalid password" (edge case).

### Step 2.4: Provide distinct setup in each context
Every `context` block should differ in setup from its parent or siblings – that's the point of the context. The agent should use `let`, `let!`, `let_it_be` (for persistent setup), or `before` hooks inside each context to establish the scenario's unique state. The `ContextSetup` rule requires that each context has some setup content to distinguish it. Common setup applicable to all contexts should be defined at a higher level (e.g., in the parent context or describe). Additionally, as noted, `subject` should remain at the top-level describe (to define the object under test) and not be re-defined in nested contexts. The agent should ensure any subject is only defined once, and use `RSpec/LeadingSubject` (enabled in RuboCop) to catch violations of this. If a context has no unique setup (no `let` or `before`), that's a flag that the context might be redundant or incorrectly structured.

### Step 2.5: Write examples focusing on observable behavior
Within each context, the agent writes one or more `it` examples. Each `it` should describe one observable behavior or outcome. The descriptions should read as a specification (e.g. `it "applies a 20% discount"` or `it "returns an error message"`). The expectations inside should verify end results or outputs, not internal implementation details. For instance, prefer checking that a method's return value or side-effect is correct, rather than that an internal method was called (which would violate "test behavior, not implementation"). If multiple contexts all need to assert the same invariant behavior, the agent should abstract those into a `shared_examples`. The `InvariantExamples` cop flags identical examples repeated in all leaf contexts. The agent should respond by DRY-ing up such repeated `it` blocks: e.g., use `shared_examples 'common behavior'` and include it with `it_behaves_like` in each context. This way, the invariant is specified once and reused, reducing duplication.

### Step 2.6: Avoid duplication in setup across contexts
If the agent notices that sibling contexts define the same `let` variables or run the same `before` hooks, that is a cue to refactor. The `DuplicateLetValues` and `DuplicateBeforeHooks` cops will catch if a `let` or `before` is defined with the same content in all contexts of a describe. The agent should then extract that common setup to the parent context or describe, so it's defined once. Partial duplication (e.g., two out of three contexts share a `let`) is also warned as a sign of a suboptimal test hierarchy. The agent should restructure contexts to minimize such partial overlaps if possible (perhaps indicating an additional higher-level context that could group those two).

### Step 2.7: Use appropriate data factories and time helpers
For test data, the agent should utilize FactoryBot for creating objects and use traits to vary attributes, instead of hand-coding data in each test (per style rules 12–14). This makes tests more declarative. Importantly, any use of dynamic time or random values in factories must be done through lazy evaluation blocks. The `DynamicAttributesForTimeAndRandom` cop ensures that things like `Time.now` or `SecureRandom.hex` appear inside a block in factory definitions (e.g., `created_at { Time.now }`). The agent will adjust any factory definitions accordingly to avoid "stale" values being captured at load time. Overall, use time helpers (like Rails' `travel_to` or `freeze_time` from `ActiveSupport::Testing::TimeHelpers` if needed) to stabilize time-sensitive code, and avoid random flakiness by controlling randomness (e.g., seeding or using deterministic inputs).

### Step 2.8: Handle integration tests with care
If the SUT is at the integration or request spec level (e.g., testing an API endpoint or a feature that involves multiple components), the agent should combine multiple layers of behavior in a single scenario rather than isolating every detail. The guide's Domain-Based Combining principle suggests grouping typical layers (authentication → authorization → business logic) in one flow. Only one corner-case scenario per layer is needed at this high level. The agent must also avoid duplicating unit test logic in integration specs. For example, an API request spec should check high-level response and one or two critical fields, not exhaustively verify every field (which would be better done by contract tests or schema validation). The agent should ensure integration tests focus on how components work together (e.g., an end-to-end request succeeds or fails under certain conditions) rather than re-testing every model validation or service method (which unit tests cover).

### Step 2.9: Automated style and correctness checks (iterative)
After generating the test code, the agent should run automated checks:
- **Style linting**: Run RuboCop with the rubocop-rspec-guide rules enabled to catch any violations of the guide's rules in the tests. This will flag the issues mentioned above (missing contexts, ordering, duplicate setup, etc.) as offenses. The agent should address each offense by adjusting the code (e.g., if `RSpecGuide/HappyPathFirst` triggers, reorder contexts). The RuboCop run should be clean (0 offenses) when done.
- **Test execution**: Run the RSpec suite to ensure all tests pass (green). If any tests fail (perhaps due to mistakes in the test code or mismatched expectations), the agent should debug and fix them. Failures might also highlight areas where the production code doesn't handle a scenario – those should be double-checked with the user requirements.

The cycle is: generate tests → lint (fix style) → run tests (fix failures), repeating until both lint and tests are green.

By following these steps, an agent can autonomously create RSpec tests that adhere strictly to the style guide. The custom cops from the guide's RuboCop plugin act as automated acceptance criteria, providing immediate feedback for the agent to correct the structure.

## 3. Specialization for Claude Code (Anthropic's AI Coding Assistant)

Claude Code is an AI coding assistant that can work in an IDE or command-line interface with an agentic workflow. To get the best results in writing RSpec tests with Claude Code, consider the following tips tailored to its features:

- **Use the IDE and Terminal modes in tandem**: Claude Code integrates into development environments (e.g. a VS Code-like setting or its own CLI). You can instruct it in an IDE-like chat, and also execute commands in a sandboxed terminal. Leverage the terminal to run test commands (`bundle exec rspec`) or linting (`bundle exec rubocop`) as part of the workflow. Claude Code is capable of both writing code and executing shell commands, while maintaining state.

- **Leverage Checkpoints for safe iteration**: Claude Code 2.0 introduced Checkpoints, which allow the agent to save the state of your code at certain milestones and revert if needed. When generating tests, you might let Claude plan and write a batch of specs, then set a checkpoint before running them. If the changes or test run go awry, you can quickly roll back to the checkpoint (restoring the previous code). This encourages the agent to take bold steps (like refactoring a large test file) with a safety net. In practice, you can manually trigger a checkpoint (or Claude might do so automatically before big edits) and later use a "restore" command if needed.

- **Employ a plan-execute-review loop (semi-autonomous mode)**: Claude Code is designed to plan multi-step tasks, execute them, and pause for review with human oversight. You can prompt Claude to outline a test plan (which contexts and examples it will create) as a plan step. Then approve or refine that plan. Next, let it execute the plan by writing the code. After it writes the tests, review the diff of changes (Claude usually presents a unified diff of what it changed). Use this opportunity to catch any issues (like a description that seems off or an overly complex context). This workflow – plan → code → review – aligns with best practices for agentic coding to keep you in the loop. Claude Code's interface allows diff review and even inline approval or rejection of changes as needed.

- **Incorporate the RSpec style guide as a Claude Skill**: One powerful feature is Claude Skills, which are packages of instructions, resources, and scripts that Claude can load contextually for specialized tasks. You can bundle the RSpec Style Guide's key rules and steps into a custom skill (e.g. `rspec-style` skill). This skill's instructions would summarize the do's and don'ts (from the guide and checklist), and could include helper scripts (like a shell script to run RuboCop with the guide's config, or run RSpec). When this skill is present, Claude will automatically bring in those instructions when it detects a relevant task (like writing tests). This means Claude has the style guide's rules "in mind" without you having to prompt it with the entire guideline each time, helping with the context window limitations. Make sure the skill's content is concise and focused, as it will consume some prompt tokens when loaded.

- **Use the skill to enforce guide rules during generation**: With the custom skill loaded, you can simply instruct Claude Code at a high level ("generate RSpec tests for X class according to our rspec-style guidelines"). The skill's instructions should guide Claude in structuring contexts, using `let` vs `before`, ordering tests, etc. For example, the skill can have an INSTRUCTIONS.md that outlines the step-by-step algorithm from section 2, so Claude internally follows that. The skill can also include a CHECKLIST.md derived from the guide's checklist – Claude could refer to it after generating tests to self-evaluate compliance.

- **Run automated checks via Claude's integrated terminal**: Claude Code has a secure sandboxed terminal where it can run shell commands you approve. Instruct Claude to run the linters and tests after writing the specs (you might say: "Now run RuboCop and RSpec to verify everything"). Ensure the RuboCop config (with rubocop-rspec-guide enabled) is in the project so that when Claude runs `rubocop`, it will flag style violations. When Claude gets the output (which it will see in the terminal), it can then autonomously fix any offenses or test failures. Claude Code's autonomous mode plus checkpoints will shine here: it can iterate fixes, and you have checkpoints to revert if it somehow makes things worse. In practice, you might allow it to loop a couple of times: fix offenses, run rubocop again, fix test failures, etc., until clean.

- **Use Claude's semi-autonomous "checkpoints" mode for guardrails**: In the latest version, Claude Code allows setting up semi-autonomous runs where it will proceed through a list of steps with minimal intervention but will use checkpoints and criteria to avoid going astray. For example, you can initiate an autonomous sequence: "Plan tests -> Write tests -> Run rubocop -> Fix offenses -> Run tests -> Fix failures", and instruct Claude to stop if more than, say, 5 files are modified or if a certain time elapses, etc. Always review each checkpoint output (diffs, test results) to ensure the changes align with your expectations.

- **Configure Claude Code's permissions and tools for efficiency**: By default, Claude Code will ask permission for actions like file edits or running certain commands. Since writing tests and running them will be frequent, you can pre-allow certain safe operations. For example, use the `/permissions` command to always allow the Edit tool (file modifications) for your spec files, and allow running `bundle exec rspec` and `bundle exec rubocop` commands. This reduces friction so you're not approving the same action repeatedly. Make sure to keep dangerous actions (like deploying, or external network calls) disallowed unless explicitly needed.

- **Package the guide's workflow into a Claude Skill (for reuse)**: As mentioned, creating a skill folder (e.g., `skill-rspec-style/`) in your repo or local Claude config can greatly streamline the process. This skill can contain:
  - README.md with a summary of what the skill does.
  - INSTRUCTIONS.md with the distilled rules and the algorithm steps (for the agent to follow).
  - CHECKLIST.md with points the agent (or user) should verify (like at least 2 contexts, subject usage, etc.).
  - prompts/ with template prompts (perhaps one for generating a new spec from scratch, one for reviewing an existing spec).
  - scripts/ like run_rubocop.sh and run_rspec.sh that Claude can execute to perform checks.

Claude skills can also include code (Ruby scripts or others) if some tasks are easier to do via code than prompting. In our case, most style checks are covered by RuboCop, but in theory you could have a script that parses an RSpec file to count contexts or similar. Once this skill is loaded, whenever you ask Claude Code to work on RSpec tests, it will find this skill relevant and use its instructions automatically.

By specializing Claude Code with these configurations and workflows, you enable it to produce high-quality RSpec tests with minimal manual intervention while still keeping you, the developer, in control of the important decisions.

## 4. Specialization for Codex CLI (OpenAI's CLI Coding Agent)

OpenAI's Codex CLI is a local coding agent that can read, modify, and execute code in your project. To make Codex CLI write RSpec tests to spec, we can use its features effectively:

- **Understanding Codex CLI's approval modes**: Codex CLI has three approval settings that balance autonomy and safety: Read-Only, Auto, and Full Access. By default it starts in Auto mode, which allows it to read and write files and run safe commands within the project directory without asking every time. However, if it tries something potentially risky (like editing outside the workspace or making network calls), it will pause for approval. Read-Only mode is more restrictive: Codex can analyze code and propose changes, but any actual file edit or command execution will require your explicit approval. Full Access mode is the most permissive: Codex will perform all actions (edits, commands) without asking. For generating tests, the recommended approach is:
  - Start in Read-Only (or Auto with caution) for the planning phase. This way Codex can inspect the codebase and outline which classes or methods need tests, and how to structure them, without making changes until you're ready.
  - Switch to Auto mode for the generation phase. In Auto, Codex can create spec files and write content autonomously (limited to your project folder) which is ideal for iterating on test code quickly. It will still stop if something unusual is attempted, which is a good safety measure.
  - Use Full Access sparingly. Full Access might be useful if you trust the agent and want it to do a lot of mechanical refactoring or creation across many files without interruption (for example, adding spec files for dozens of classes in one go). Even then, it's best to use it in a sandbox branch and after committing current work, since it won't ask before changing things. Generally, stick to Auto for most test generation to have a balance of speed and control.
  - You can change modes on the fly with the `/approvals` command in an interactive session (e.g., `/approvals readonly` or `/approvals full`). In non-interactive use (using `codex exec`), you can specify `--full-auto` flag to run with Full Access for that command.

- **Step 1: Plan tests in Read-Only mode**. Launch Codex in your repository (ensure your project is a Git repo, since Codex requires that for safety). In the interactive prompt, you might start with a query like: "List all public methods in app/models/order.rb that lack tests, and propose a context hierarchy for each according to our RSpec style guide." In Read-Only mode, Codex will read the file and possibly related files, then produce an outline plan. It might respond with something like:
  - Method `calculate_total`: contexts: when order has discount, when no discount (happy path first).
  - Method `apply_coupon`: contexts: when coupon is valid (happy), when coupon is expired (edge), when coupon is invalid (edge).

  Review this plan. You can discuss with Codex to refine it (e.g., "Combine expired and invalid coupon into one context of 'invalid coupon' if behavior is similar"). This planning step ensures the agent understands the requirements and the style (we can remind it: "Remember: at least one happy and one edge context per method.").

- **Step 2: Generate tests in Auto mode**. Once you are satisfied with the plan, instruct Codex to implement it. If still in the same session, you could now do `/approvals auto` to switch to Auto mode for execution. Alternatively, you could run a fresh non-interactive command using `codex exec` to generate tests. For example, from a shell you might run:
  ```bash
  codex --full-auto "Add RSpec tests for Order.calculate_total and Order.apply_coupon following our style guide (characteristic-based contexts, etc.). Use FactoryBot for data. Ensure happy path first, then edge cases."
  ```
  This one-liner uses `--full-auto` for demonstration (allowing file edits freely) – you could omit it if you prefer to stick to default Auto and have a chance to approve any extraordinary actions. Codex will then create a file like `spec/models/order_spec.rb` if it doesn't exist, populate it with `describe Order` and the contexts and examples. Because we emphasized the style guide in the prompt, Codex should:
  - Create multiple context levels if applicable.
  - Write a happy path `it` example first in each describe block, then negative cases.
  - Use `let` to set up data differences in contexts and define a `subject` at the top.

  As it runs in Auto mode, it will apply the changes directly to your files and typically show you a diff or summary of what it did. In interactive mode, you'd see the diff; in `codex exec`, since it's non-interactive, it will just apply changes (you can check `git diff` afterward to review).

- **Step 3: Run linters and tests with codex exec**. After generation, you want to verify style compliance and test correctness. Codex CLI's non-interactive mode is very handy for running commands and having the agent interpret results. For example:
  ```bash
  codex exec "bundle exec rubocop -D"
  ```
  This will have Codex run the RuboCop linter. By default `codex exec` runs in read-only mode, meaning it won't try to fix anything automatically (and it can't edit files in pure read-only). It will output the results. If there are offenses (particularly any `RSpecGuide/...` cop offenses), Codex will report them in its output. You can then feed those back into an interactive session or another `codex exec` to fix. For instance:
  ```bash
  codex "Fix the RuboCop offenses in spec/models/order_spec.rb. Follow rubocop-rspec-guide recommendations."
  ```
  In Auto mode, Codex would then edit the file to address the offenses (perhaps reordering contexts or extracting a duplicate let). Similarly, run the tests:
  ```bash
  codex exec "bundle exec rspec"
  ```
  If any tests fail, Codex will capture the failure messages. You can prompt it to analyze failures and apply fixes:
  ```bash
  codex "The test for expired coupon is failing with a nil error – update the code or test to handle nil coupon gracefully."
  ```
  It might then adjust the production code or the test based on what seems appropriate (here caution: if it starts editing app code, ensure that's intended!). Since Codex runs locally, you have your VCS to see any changes it makes. Iterate this way until rubocop returns 0 offenses and rspec is 100% passing. You can script these iterations in a runbook (see Appendix for an example).

- **Step 4: Use approval mode toggles for efficiency**: During the above process, you might temporarily escalate to Full Access if there are many repetitive changes. For example, if RuboCop flags the same issue in 10 files that Codex created, approving each edit can be tedious – you could do `/approvals full` and let it fix all in one sweep. After that, return to a safer mode. The CLI also supports a `--dangerously-bypass-approvals-and-sandbox` flag, but do not use it in normal circumstances, as it removes all safety checks.

- **Step 5: Integrate MCP or external tools if needed**: Codex CLI supports Model Context Protocol (MCP), which allows the agent to use external tools or APIs (like web search, or custom analysis tools) as part of its reasoning. For writing RSpec tests, this might not be necessary unless you want Codex to fetch additional info (maybe search an internal knowledge base or documentation for expected behavior). If you have internal APIs or scripts (for example, a script that lists all untested methods), you could register it as an MCP tool. This is an advanced use-case: you'd configure `~/.codex/config.toml` to point to your tool's endpoint. Codex can then call it when instructed (you'd see events like `mcp_tool_call` in verbose logs). For our purposes, it's likely overkill – the agent can work with just the repository code. But it's good to know that if something required external verification (like "verify in Jira if this bug has a test case"), an MCP integration could be set up to allow that query.

- **Step 6: Store prompt templates and runbooks in your repo**: Since you might not remember the exact phrasing to get the best results each time, it's useful to save the prompts that worked well. The Codex CLI allows custom prompt files or you can simply keep markdown files with instructions. For example, you might have a `docs/codex-runbooks/` directory (see Appendix) containing a file like `generate_rspec.md` which outlines the sequence: plan, generate, lint, test. You can open that while working with Codex or even copy commands from it. In interactive mode, you can also paste multi-line instructions from such a file. Codex CLI doesn't automatically ingest those runbook files (unless you copy or use them in a prompt), but they serve as documentation for your team. In the future, if Codex adds features to load context (similar to Claude's skills), you'll be ready.

- **Security and privacy**: Remember that Codex CLI operates entirely on your machine – all code stays local and only prompts/requests are sent to OpenAI's API. This makes it suitable for proprietary code. Still, treat the AI's suggestions as you would a junior developer's: review them. Ensure you run in a git branch so you can revert if the agent does something undesirable. Commit often, and use `git diff` to inspect changes after any large automated operation.

By using Codex CLI with the right mode at each stage and automating checks via `codex exec`, you can significantly speed up the creation of RSpec tests while maintaining adherence to your style guide. The agent becomes a collaborator that handles the boilerplate and rote enforcement, leaving you to oversee design and substance of the tests.

## 5. Instruction Guide for Humans Writing Tests Manually

Not everyone will use an AI agent for this task – human developers should also follow the style guide to write exemplary tests. Here's a practical step-by-step guide for a person to write RSpec tests in line with the guide, along with a review checklist:

### Step 5.1: Identify what needs to be tested
Start by determining the scope: Are you testing a model, a service object, a controller/endpoint, etc.? Locate the public methods or behaviors that are important. For instance, if working on a model `Order` with methods `calculate_total` and `apply_coupon`, decide to write a spec for each method (or a combined spec if appropriate under `describe Order`). The top-level describe should mention the class or module, and a nested describe (or context) can mention the method (e.g., `describe '#calculate_total' do ... end`). Clearly define the subject under test – e.g., `subject { order.calculate_total }` – at the appropriate level so it's obvious what the outcome of each `it` refers to. This makes the test's focus explicit.

### Step 5.2: Determine the independent characteristics for context structure
Think about all the factors that can change the behavior of the subject. Each factor will translate into a context. Ask yourself: "What conditions make a difference to the outcome?" These could be input types, attribute values, user roles, feature flags, external states, etc. List them out and identify which are independent and which depend on others. Structure your contexts accordingly:
- Use one context level per characteristic. For an independent factor like "user role", you might have `context 'when user is admin' do ... end` and `context 'when user is regular' do ... end` at the same level.
- If a characteristic only matters under certain higher-level conditions, nest it. For example, if and only if the user is an admin, perhaps a "subscription status" matters. Then put subscription contexts inside the admin context.
- Example: For `Order.apply_coupon`, relevant factors might be: coupon validity (valid vs expired vs invalid code) and perhaps order amount (above minimum vs below minimum for the coupon). "Coupon validity" is independent, so you'd have separate contexts for valid coupon and invalid/expired coupon. If "expired" and "invalid code" lead to the same behavior (both rejected), you might combine them into one context for simplicity, or have them as separate contexts if behaviors differ (one might produce a different error message than the other). Meanwhile, if the coupon has a minimum order amount condition, that is a second characteristic dependent on having a valid coupon. So you could nest: within the valid coupon context, have contexts for "when order meets minimum amount" and "when order is below minimum amount" to see if the discount applies or not.

### Step 5.3: Start with the happy path scenario
In each describe or context group of tests, begin by writing the scenario where everything is "as expected" (the normal case). This is the happy path. Writing it first sets the baseline behavior clearly. For `apply_coupon`, the happy path might be: `context "with a valid coupon"` and inside it `it "applies the discount to the order total"` (if that's the expected result). Write the minimal setup needed for this scenario: e.g., create an order and a coupon that is valid. Use FactoryBot factories to create these objects in a clean way (e.g. `let(:order) { create(:order, total: Money.new(1000)) }` and `let(:coupon) { create(:coupon, code: 'PROMO10', discount: 0.1) }`). The test might perform the action (`order.apply_coupon(coupon.code)`) and then expect the order's total or discount field to be updated appropriately. Ensure that the expectation is phrased as a behavior: e.g., `expect(order.total).to eq Money.new(900)` if a 10% discount applied, rather than checking some internal flag.

After the happy path, add one or more edge case contexts: for example, `context "with an expired coupon"` and `context "with an invalid coupon code"`. Each of those gets an `it` block describing the expected outcome (perhaps "does not apply any discount and returns an error message"). The `HappyPathFirst` rule ensures we not only include these cases but also order them after the happy scenario.

### Step 5.4: Provide unique setup per context, avoid repetition
Within each context, set up only the pieces that differ for that scenario. Use `let` blocks or `before` blocks to configure differences. Common setup that is needed for all contexts can live in a parent context or the top-level describe. For example, if all tests involve a user and an order, you might define `let(:user) { create(:user) }` at top-level, and then inside contexts override specific attributes if needed (or just rely on it). But if two sibling contexts end up with identical `let` definitions, that's a sign you should DRY it up by moving that `let` up one level. The style guide expects that each context reflects a meaningful difference from the others. If you find a context has no `let` or `before` and is just grouping one test, ask "Is this context adding value or can it be merged with the parent?" Conversely, if you have a context with no setup difference, it might violate the `ContextSetup` rule (which wants some setup inside each context). Make sure `subject` is set at the describe level (unless each context is testing a completely different method, which usually isn't the case). For example, do not write `subject { order.apply_coupon(code) }` inside every context – instead define it once at top if all contexts use the same subject.

Keep contexts focused: e.g., `context "with invalid coupon"` should only differ in the coupon's attributes. The order setup can remain shared unless the scenario calls for a different order state. Use `before` hooks for actions that need to happen in the context (e.g., calling the method under test if using a stateful expectation pattern, though often you can just call the method within the `it` block).

### Step 5.5: Write clear, behavior-oriented examples (`it` blocks)
Each `it` should complete the sentence formed by its context + description. For instance, `context "with an expired coupon"` + `it "does not apply any discount"` reads as a full specification: "with an expired coupon, it does not apply any discount." This makes tests readable. Avoid wording like "it works" or "it checks value" – be specific about the behavior. Also, avoid using multiple assertions in one `it` that are unrelated; typically one `it` = one primary expectation of behavior. If you have to verify several things to confirm one behavior (e.g., the status and the message of a result), you can use `aggregate_failures` to group them, but only if they logically belong together as one outcome.

Ensure you are testing the outcome or observable state. Do not reach into private methods or instance variables that aren't part of the public API. For example, test that `apply_coupon` returns false or an error object when invalid, rather than checking an internal `@error` variable was set. Likewise, avoid excessive mocking/stubbing of the subject's internals – if you find yourself stubbing the method you're testing, that's wrong. You might stub external collaborators or time (e.g., stub `Time.now` if not using time helpers, though using `travel_to` is better), but the core behavior should be executed for real.

### Step 5.6: DRY up repeated examples with shared examples (if needed)
After writing tests, scan if multiple contexts have identical `it` blocks. A common scenario: every context ends with something like `it "responds with status 200"` (for a request spec) or `it "does not raise an error"`. If this check truly applies in every case, you can factor it into a `shared_examples`. For instance, "`shared_examples 'a successful response' do ... end`" and then in each context do `it_behaves_like 'a successful response'`. The custom cop `RSpecGuide/InvariantExamples` will point these out by detecting if an example description repeats across all contexts. Using shared examples not only removes duplication but signals to readers that this expectation is a general contract across scenarios. Do ensure the shared example is defined before it's used (above in the file), and that it's named clearly.

### Step 5.7: Use FactoryBot and helpers for data setup
The guide encourages using FactoryBot's features to keep tests concise. For example, use `build_stubbed` for models in unit tests where you don't need them persisted (faster tests), and `create` for integration tests where the DB is involved. Use `attributes_for` to easily get a hash of attributes for creating records via POST in request specs. Traits are your friend: instead of manually overriding many fields for a given scenario, define a factory trait (e.g., `trait :expired do ... end` for coupons) and use `create(:coupon, :expired)`. This makes the test's intent clearer ("create an expired coupon" reads well). Also, be cautious with random data – if a factory uses Faker or randomness, consider if the randomness could cause flakiness. It's fine for non-deterministic values like names, but for things like generated tokens or timestamps, ensure consistency as needed (the `DynamicAttributes` cop will ensure you use `{ SecureRandom.hex }` instead of `SecureRandom.hex` so each created object gets a fresh token).

For time-dependent code, use time helpers to freeze or travel to a specific time so tests are deterministic. If your code uses `Time.now`, wrap it in a block or use `Time.current` with travel, otherwise tests might fail intermittently around midnight or daylight savings. Factories can use `created_at { 2.days.ago }` or similar to set up relative times.

### Step 5.8: Focus integration tests on the big picture
If you're writing higher-level specs (like request specs, feature specs), remember not to assert every nitty-gritty detail. Instead, assert the key outcomes and that the layers integrated correctly. For example, in a request spec for an order creation API, you'd check that the HTTP status is 201 Created and that an Order record was actually created in the DB, and maybe that the response JSON has the essential fields. You would not check every attribute or the exact JSON structure in multiple tests (that's better done with schema validation or snapshot tests, as the API guide suggests). Also avoid duplicating unit specs: if you have model tests for validations, your integration test can assume those validations work and just ensure that an invalid input yields a 422 status and error message, not re-test every validation rule. This keeps integration tests lean and focused on integration logic (like "does the controller correctly combine authentication, business logic, and serialization?").

### Step 5.9: Run RuboCop and RSpec to verify compliance and correctness
Finally, use automation to your advantage:
- Run `rubocop` with the style guide's rules enabled (see next section for configuration). This will catch common issues like missing multiple contexts, wrong ordering, etc. Fix any offenses it reports. Treat a RuboCop offense as a must-fix (the style guide rules are meant to be followed strictly, not optional).
- Run your test suite (`bundle exec rspec`). Ensure all tests pass. If a test fails, either the code under test has a bug or the test might be written incorrectly – debug which it is. It's not uncommon to discover a code issue while writing a test (that's one of the purposes of testing!). If so, fix the code or handle the case in code, then ensure the test passes. If the test expectation was wrong, correct the test.

After these steps, you should have well-structured, readable tests. As a quick gut-check, read the spec file top to bottom: it should tell a coherent story of the behavior of the SUT. If it's hard to follow or requires remembering a lot of context, consider refactoring using the guidelines (maybe you need to introduce an additional describe/context to break up a complex scenario, or rename some `let` to be clearer, etc.).

### Human Review Checklist
Before considering your test "done," go through this checklist (based on the guide's checklist) to review:

- [ ] **At least one happy path and one edge case are present.** Does your spec have at least two contexts in each describe? The style demands both positive and negative tests, structured as separate contexts.
- [ ] **Happy path is written before corner cases.** Simply check order: the first context or first tests should be the normal case.
- [ ] **Each context has a distinct setup.** No context is just a placeholder – each has a `let`, `before`, or something that differentiates it from the outer scope. Also, `subject` is defined at the top (describe level) and not re-defined in contexts (use variables instead to vary inputs).
- [ ] **No duplicate `let` or `before` in sibling contexts.** If two contexts in the same level had the same setup, you have likely copy-pasted – factor it out.
- [ ] **No identical examples across contexts.** If every context ends with `it "does X"` repeated, use a shared example instead.
- [ ] **Factories and randomness/time usage are correct.** All random or time-dependent attributes in factories are in blocks (e.g., `{ Time.now }`) so they're evaluated per usage. No test relies on wall-clock time or randomness that could flake.
- [ ] **Integration tests: not duplicating unit tests.** High-level specs aren't checking trivial details that lower-level tests cover, and they combine concerns in one scenario per layer.
- [ ] **Descriptions and language are clear.** Context descriptions start with "when/with/without/etc." appropriately, and `it` descriptions are concise and in present tense (e.g., `it "returns false"` not "return false"). Negatives are explicit (use "not" or "does not" in description for negative cases to be clear).
- [ ] **No anti-patterns present:** No use of `any_instance` (instead use proper dependency injection or instance doubles); no overly DRY setup that sacrifices clarity (it's okay to repeat a little in tests for readability as per rule 16); no sleeping in tests or dependency on test order, etc.

Following these steps and checklist will result in tests that are easier to understand and maintain, and that serve as reliable documentation for the system's behavior.

## 6. Acceptance Criteria and Automated Checks

To consider the agent-generated (or human-written) tests acceptable, they should meet certain criteria aligned with the style guide. These criteria can be verified through automated tools:

### Style Guide Compliance
The test code should trigger **zero offenses** when run against RuboCop with the RSpec Style Guide plugin. Specifically, all custom cops from the `rubocop-rspec-guide` gem should pass:

- **RSpecGuide/CharacteristicsAndContexts**: ensures at least two contexts (or context + at least one example) in each `describe`.
- **RSpecGuide/HappyPathFirst**: ensures no context for an error case comes before a context for success.
- **RSpecGuide/ContextSetup**: flags any context with no setup or with `subject` defined inside a context.
- **RSpecGuide/DuplicateLetValues** and **DuplicateBeforeHooks**: ensure no duplicates across siblings.
- **RSpecGuide/InvariantExamples**: flags identical `it` descriptions in all leaf contexts.
- **FactoryBotGuide/DynamicAttributesForTimeAndRandom**: flags misuse of `Time.now` or `Random` outside of blocks in factories.

In addition, enabling RuboCop RSpec's core cops like `RSpec/LeadingSubject`, `RSpec/ImplicitSubject` will ensure subjects are used properly (the provided config recommends enabling `RSpec/LeadingSubject` to enforce subject placement). The goal is **0 offenses** after auto-corrections. Any offense should be fixed by adjusting the code (the agent can do this in its cycle, or a human can manually).

### Functional Correctness
All tests should pass (green) when running `bundle exec rspec`. This is obvious but crucial – it's the definition of done for test writing. If tests don't pass, either the tests are wrong or the code under test has bugs. Both need addressing: we expect at the end not only that tests are pretty, but that they are testing real, passing behavior (unless we intentionally wrote a failing test to TDD a new feature, but in that case the feature implementation would be the next step until tests pass).

### Test Coverage of behaviors
Each important behavior has at least one example. While we don't measure this purely in terms of code coverage percentage, qualitatively, the key branches or outcomes of each method are covered by at least one test. The presence of contexts for various conditions indicates this. (An optional metric: ensure no `RSpecGuide/CharacteristicsAndContexts` offense, which indirectly means at least one alternative case is present).

### Structure and clarity
The tests should reflect the guide's structural patterns:
- Subject defined at top-level describe (or use of `described_class` if appropriate) – this can be checked by code review or RuboCop's `RSpec/LeadingSubject` cop.
- Contexts nested properly (no more than 3-4 levels deep ideally – RuboCop's `RSpec/NestedGroups` can enforce a max).
- Each example's description forming a clear spec sentence with its context (subjective, but reviewers will check language).

### No style regressions
If using a CI, you can integrate the RuboCop check so that any new offenses break the build. This ensures future changes also comply. Similarly, if desired, enable a tool like RSpec Stan style guide enforcement or run the custom cops in a pre-commit hook.

To automate these checks in an agent-driven cycle:
1. **Linters**: The agent after writing tests runs `rubocop` with the config. We can even programmatically have it parse the RuboCop JSON output to identify which rules failed and decide how to fix (e.g., if `HappyPathFirst` failed, it knows to reorder contexts).
2. **Tests execution**: The agent runs `rspec`. If failures occur, it can read the failure messages. We can give the agent a strategy: for example, if a failure is an expectation mismatch, consider if test expectation was wrong or code bug. Often, since we assume code is correct (if we're just writing tests after the code), a failure indicates the test might need adjustment. But if the test uncovered a real bug, a human might intervene to fix code or instruct the agent to implement a fix (if within scope).
3. **RuboCop configuration**: It's important that the project's `.rubocop.yml` is set up to include the guide's cops. Typically, you'd add the gem and either include the provided default config or explicitly enable each cop. Here is a snippet that should be present in your `.rubocop.yml` (either manually added or via `rubocop --auto-gen-config` after installing the gem):

```yaml
# .rubocop.yml - Enforce RSpec Style Guide rules
require:
  - rubocop-rspec
  - rubocop-factory_bot
  - rubocop-rspec-guide

# Enable RSpec Style Guide custom cops:
RSpecGuide/CharacteristicsAndContexts:
  Enabled: true
RSpecGuide/HappyPathFirst:
  Enabled: true
RSpecGuide/ContextSetup:
  Enabled: true
RSpecGuide/DuplicateLetValues:
  Enabled: true
  WarnOnPartialDuplicates: true
RSpecGuide/DuplicateBeforeHooks:
  Enabled: true
  WarnOnPartialDuplicates: true
RSpecGuide/InvariantExamples:
  Enabled: true
  MinLeafContexts: 3
FactoryBotGuide/DynamicAttributesForTimeAndRandom:
  Enabled: true

# (Plus any core RuboCop/RSpec cops you want to enforce, e.g., RSpec/LeadingSubject: Enabled: true)
```

(The above config is based on the official example config from the guide's repository.)

With this config, running `bundle exec rubocop` will apply all the style guide rules. The acceptance criteria is essentially that this returns "no offenses detected".

### Optional additional metrics
If you use a code coverage tool, you might check that the new tests actually execute the intended lines of code. However, hitting 100% coverage is not the primary goal here – it's more important to have the right tests. Still, a quick glance to ensure critical paths are not left untested is useful.

By embedding these criteria into the agent's workflow (i.e., have the agent run the linters and tests automatically), the agent effectively has an "acceptance test" for the tests themselves. It won't stop improving the output until those acceptance checks pass (or it runs out of tries). For a human, these criteria form the definition of done: all style checks pass and tests are green.

## 7. Typical Mistakes and How to Fix Them

Even with guidelines, certain common mistakes slip into RSpec tests. Here are some typical ones along with ways to correct them, each tied to the style rules or checklist:

- **Testing implementation details instead of behavior**: For example, a test might assert that a certain method was called (using `expect(obj).to receive(:internal_helper)`) rather than asserting the outcome of the behavior. This is against rule 1 (test behavior, not implementation).
  - **Fix**: Refocus the test on what the user or calling code would observe. Use public methods' return values or resulting state. If the internal call is truly important (like a third-party API call), consider using a fake or stub at a higher level or test via a side effect. The guide's example contrasts a bad test that expects a validator to be called vs a good test that checks for a validation error outcome. If you find `any_instance` or `allow_any_instance_of` in tests, that's a red flag – usually indicating an implementation focus. Replace that by setting up the object state or using dependency injection to provide a test double in a cleaner way (or better, avoid global stubs altogether).

- **Not writing any negative/edge case tests**: This often manifests as having a describe with only one context or only straight-line `it` examples covering the happy path. The style guide (`CharacteristicsAndContexts` rule) mandates at least one alternative scenario.
  - **Fix**: Identify at least one thing that could go wrong or vary – add a context for it. If the code truly has no branching or error possibility (rare), at minimum test an extreme input or a nil input. It's important for completeness and to satisfy the guide's requirement that tests also capture corner cases. For instance, if testing a parser that usually gets valid data, add a test for when it receives malformed data (even if it's expected to raise an error, test that it does so gracefully).

- **Putting error cases before happy path in file order**: Some developers might naturally list "when error" first. But the `HappyPathFirst` rule flags this.
  - **Fix**: Reorder the contexts so the normal case is defined before the exceptional ones. This improves readability: readers see the expected usage and result first, then the deviations. It's an easy mistake to fix – just cut-paste the blocks or rename them in an order-neutral way (you can also number contexts in descriptions if order alone isn't clear, but usually naming with "when/with" for happy and "when ... is invalid" for error will naturally sort, since "when" typically precedes "without" lexicographically, but best not rely on that).

- **Contexts with no setup (empty context or irrelevant context)**: If you have a `context 'when X' do ... end` that doesn't actually set up X differently, it's pointless. The `ContextSetup` cop will warn if a context has no `let`/`before`/subject inside.
  - **Fix**: Either provide the needed setup or collapse the context into its parent. Sometimes this happens when a context is written but the author accidentally put the setup outside of it. Ensure the code that differentiates the scenario is inside the context. Example:
    ```ruby
    context 'when user is admin' do
      # Oops, no difference in setup here
      it 'allows access'...
    end
    ```
    Fix by adding, say, `let(:user) { create(:user, :admin) }` inside that context. Also, avoid defining `subject` inside contexts (it should be at top-level), as that is also flagged as bad setup practice; if you did that, move the subject definition out and use `let` for contextual variants.

- **Defining the same `let` or `before` in every context**: This is a sign of copy-paste. For example, each context defines `let(:user) { create(:user) }` with the same value. That's inefficient and violates DRY, and the `DuplicateLetValues` cop will ERROR on exact duplicates across all siblings.
  - **Fix**: Move that `let` to the parent describe or a wrapping context so it's defined once. If it's duplicated in some but not all contexts, the cop will give a warning – consider if your context structure is right. Possibly you have one context that truly differs, and two that are the same, so maybe those two should be combined. In any case, eliminate partial duplication either by consolidation or introducing another layer of context that covers the common setup for those two. Similarly for `before` hooks: if the same `before { do_something }` is in all contexts, lift it up.

- **Repeating the same example in every context**: This is a classic scenario where shared examples should be used (`InvariantExamples` cop). For instance, each context might have `it 'responds with success status' do ... end`. Instead, define a shared example and include it.
  - **Fix**: abstract the repeated test. This not only removes duplication but signals that this check is a general requirement. If for some reason you don't want to use `shared_examples`, at least consider whether the test is adding value in every context or if it could be moved to a higher level. Sometimes, people repeat an example unnecessarily – e.g., checking something in every context when it could be checked once in the parent describe because it doesn't actually vary by context.

- **Using real time or random values incorrectly**: A common pitfall is doing something like `create(:user, token: SecureRandom.hex)` in a factory or let. This will produce the same token every time if defined outside a block, or produce a new token but maybe not seeded. Similarly, `Time.now` used in setup will freeze that time at test load.
  - **Fix**: Use `{ SecureRandom.hex }` in factories (the `DynamicAttributes` cop will enforce this). If you need random values in tests (like for sampling), consider seeding the RNG for consistency or using deterministic choices. For time, use `Time.current` and control it with `travel_to(Time.new(2025,1,1))` in a before block if the code under test uses current time. The style guide explicitly mentions stabilizing time for tests. If you see tests failing at midnight or on certain days, suspect time issues – the fix is to freeze time in tests or allow a tolerance.

- **Overusing subject or not naming things clearly**: Some testers love subject and end up with `is_expected.to ...` a lot. While this can be fine, overuse can harm clarity, especially if there are multiple subjects or implicit subjects. The guide suggests using explicit subject only where it really clarifies the focus.
  - **Fix**: If a test reads better by naming the object, do `expect(order.total).to eq(100)` instead of making `subject { order.total }` at top just to use `is_expected.to eq(100)`. Also avoid using the implicit subject (`subject { }` without name and then using `is_expected`) in complex specs – it can confuse readers. Name things with `let` for intermediate values. The cop `RSpec/NamedSubject` (enabled in the example config) will encourage giving a name to subject if used.

- **Writing overly DRY tests (to the point of obscurity)**: This can happen when trying to remove every bit of duplication. For example, using a `shared_context` for setup that is included everywhere, or computing expectations programmatically (like looping through a list of inputs in one example). While DRY is good, rule 16 says explicitness is favored over DRY in tests.
  - **Fix**: Don't hesitate to repeat a little code if it makes each test self-contained and clear. For instance, having two separate `it` examples with similar code can be more readable than one `it` that iterates and asserts multiple cases within it. The guide allows some repetition if it avoids indirection that the reader must mentally resolve.

- **Using deprecated or discouraged RSpec features**: e.g., `should` syntax instead of `expect`, or `allow_any_instance_of`. The checklist flags `any_instance` as an anti-pattern.
  - **Fix**: Use modern `expect` syntax and prefer injection or explicit stubs over `any_instance_of`. If you find yourself wanting to stub any instance of a class, consider refactoring code to inject a collaborator or use a singleton method stub on a specific instance.

- **Poor context naming/organization**: Sometimes tests have contexts like `context 'with inputs 1,2,3'` which is not very descriptive of the behavior. Or mixing multiple conditions in one context name ("when admin logs in with invalid password" – that's two factors, could be split for clarity).
  - **Fix**: Follow the language guidelines: use when/with/without appropriately. When for describing a state or action, with/without for presence/absence of a feature, but for an exception to a happy path, etc. Ensure each context name is focused on one thing. If you have 'and' in a context description, that's a hint you might need nesting (each 'and' clause could be its own nested context under the first condition).

Each of these mistakes corresponds to one or more style rules, and many are automatically detectable by the cops or checklist. Using the checklist in Section 5.9, a human reviewer can catch them, and using RuboCop with the custom cops, an automated process can catch many as well. The key to fixing any issue is almost always to simplify and clarify:
- Simplify expectations to the essence of the behavior.
- Clarify setup by structuring contexts properly.
- Remove any confusing or redundant parts.

When in doubt, refer back to the principles: Is this test clearly about behavior? Does its structure reduce cognitive load or add to it? Answering those will usually guide the correction.

## 8. Prompt Templates for Agents

Finally, here are some example prompt templates that can be used with Claude Code and Codex CLI to kickstart the RSpec test generation process, aligning with the style guide. These "battle-tested" prompts assume the agent already has some context about your code (or you point it to the relevant file).

### For Claude Code (in an IDE or Claude's chat):

You can instruct Claude to load the RSpec style skill and then give it a structured task. For example:

**Prompt (Claude Code - Generate Specs):**
(Assume the `rspec-style` skill is available)
"Use the RSpec Style Guide instructions. For the file `app/models/order.rb`, write an RSpec spec:
1. Identify the public methods to test and outline contexts based on independent characteristics (each level = one characteristic).
2. Start with the happy path example(s) for each method, then add at least one context for an edge case or failure for each.
3. In each context, include only the setup needed for that scenario (use `let`/`before` appropriately) – ensure contexts reflect their names. Subject should be the Order or its method result defined at top-level.
4. If any expectation is repeated in every context, factor it into a shared example and use `it_behaves_like`.
5. Use FactoryBot to create any Order or related objects; for time or random values, use `{ }` blocks in factories.
6. After writing the tests, run `rubocop` with our style rules and run the tests. Fix any style offenses or failing tests you encounter until all are clear.

Provide the final RSpec code with explanations for each context in comments."

This prompt explicitly steps Claude through the required tasks. The numbering helps it not to forget any part. Claude will produce `order_spec.rb` content accordingly, and possibly run the commands if you instruct it in the conversation (depending on whether you allow it to use the terminal – you might issue the `rubocop` command yourself or via Claude's terminal tool).

You can also create a **review prompt** for Claude Code to check an existing spec file:

**Prompt (Claude Code - Review Specs):**
"Review the file `spec/models/order_spec.rb` for compliance with our RSpec style guide. Check that:
- At least one happy path and one edge case are present (`CharacteristicsAndContexts`).
- Happy path is listed before corner cases (`HappyPathFirst`).
- Each context has unique setup and uses subject appropriately (`ContextSetup`).
- No duplicate lets or before hooks across sibling contexts (`DuplicateLetValues/BeforeHooks`).
- No identical examples in all contexts (`InvariantExamples` – use shared examples if needed).
- Factories use dynamic attributes for time/random (`DynamicAttributesForTimeAndRandom`).

List any issues found and suggest how to fix them. If the spec is perfect, say so."

Claude will then enumerate any problems (effectively performing a code review according to the checklist). This can be used after a human writes tests, as a double-check.

### For OpenAI Codex CLI:

When using Codex in the terminal, you usually provide a single query or run in interactive mode. Here are example commands:

**One-shot generation with codex:** You can run a single command that tells Codex exactly what to do. For example:

```bash
codex "Create an RSpec test file for the UserMailer (in app/mailers/user_mailer.rb) following our style guide. The UserMailer has a method 'welcome_email(user)' – test that it sends an email to the user's address (happy path), and test behavior if the user has no email (edge case). Use contexts for 'valid email' and 'missing email'. Ensure to use subject/let properly, and include both scenarios. After writing, run rubocop with rubocop-rspec-guide and run rspec, fixing any issues until tests pass with no offenses."
```

This prompt is quite detailed; it directs Codex to do the whole loop. Codex will likely produce the `user_mailer_spec.rb`, and potentially attempt to run rubocop/rspec (though in the one-shot mode it might not execute commands – you'd have to run them). It's often better to break it up into steps interactively, but this shows you can ask Codex to iterate internally.

**Step-by-step in interactive mode:** You can replicate a human-like approach:
- **Plan**: In Codex CLI, ask: "What contexts and examples should we have for X feature according to our RSpec style guide?" (Codex will list them).
- **Write tests**: Then say: "Okay, implement those in a spec file." It will do so.
- **Run rubocop**: You could then do `codex exec "bundle exec rubocop -D"` to get offenses.
- **Fix offenses**: Copy the offense list into the chat (or just say in chat: "Fix the RuboCop offenses above." Codex is usually aware of what it executed via `codex exec` if you use resume).
- **Run tests**: `codex exec "bundle exec rspec"` to see failures.
- **Fix failures**: Tell Codex to address the failures (it will have seen them).

This interactive loop aligns with how a developer would guide it.

**Template prompt for Codex CLI (review existing):** If you want Codex to review a spec, you can do:

```bash
codex "Review spec/models/order_spec.rb for adherence to our RSpec style guide and list any improvements."
```

Codex would then output something akin to a code review (similar to Claude, pointing out context ordering, etc.).

In all these prompts, mentioning the "RSpec style guide" or specific rule names helps the agent recall the guidelines. Since our custom cops have intuitive names, even Codex might pick up on them (especially if the rubocop config is present in the repo, Codex could read `.rubocop.yml` and see those cop names, informing its decisions).

**Note**: When actually using these prompts, ensure your AI agent has sufficient context:
- For Claude, loading the skill or having a CLAUDE.md with key points will help it follow through.
- For Codex, having the `.rubocop.yml` and perhaps a GUIDE.md excerpt in the repo might help if it scans files. You can also paste in short relevant excerpts if needed (Codex has a context window too, albeit large).

These templates serve as a starting point – you may tweak wording based on what yields the best results from the AI. The goal is to be clear about the structure you expect (contexts, happy vs sad paths, etc.) and to remind it to verify via rubocop/rspec.

## Appendix: Claude Skill Skeleton and Codex Runbook Examples

Finally, here are outlines for the skill and runbook mentioned, which you can include in your repository for easy reuse:

### Claude Skill: `skill-rspec-style/`

This skill encapsulates the style guide rules and workflow for Claude. It might contain the following files:

```
skill-rspec-style/
├── README.md                   # Explains the purpose of the skill: to help Claude write RSpec tests following our style guide.
├── INSTRUCTIONS.md              # Key rules and step-by-step algorithm distilled for the agent. (E.g., bullet points of do's and don'ts, similar to sections 1 and 2 above.)
├── CHECKLIST.md                 # The review checklist in bullet form, for Claude to self-check or for use in review prompts.
├── prompts/
│   ├── generate_spec.prompt.md  # A template prompt for generating specs (like the example in section 8 for Claude Code).
│   └── review_spec.prompt.md    # A template prompt for reviewing specs (as in section 8).
├── scripts/
│   ├── run_rubocop.sh           # Script to run RuboCop with the project's config (e.g., `bundle exec rubocop -D`).
│   └── run_rspec.sh             # Script to run the test suite (e.g., `bundle exec rspec`).
└── resources/
    └── links.md                 # (Optional) Links or references to the full guide or external docs for further reading.
```

**Note**: The exact structure for a Claude skill might evolve (Anthropic's docs should be consulted for required manifest files, etc.), but the above is a logical content layout. The key is that when this skill is loaded, Claude gains knowledge of the style rules and even tools to execute. The scripts allow Claude to call `run_rubocop.sh` or `run_rspec.sh` as tools, rather than formulating the commands from scratch, which can reduce errors. The prompts can be used via the `#use skill-rspec-style/prompts/generate_spec` directive in Claude (or you manually copy them).

By packaging this skill, you ensure consistency – every developer or every time you spin up Claude Code, it will apply the same standards.

### Codex Runbook: `docs/codex-runbooks/generate_rspec.md`

This runbook can guide someone (or even the agent, if it had the ability to read it) through the process in Codex CLI. For example, its content might be:

```markdown
# Runbook: Generate RSpec tests with Codex CLI

1. **Plan contexts and examples** – Start Codex (in Read-Only) and ask:
   > "List the public methods of `app/services/payment_processor.rb` and propose RSpec contexts and examples for each, following our RSpec style guide."

   Review the proposed plan, ensure it includes happy paths and edge cases.

2. **Enable style guide cops** – Ensure `.rubocop.yml` has `rubocop-rspec-guide` enabled (see `rubocop-rspec-guide` README for config). If not, you can have Codex add it:
   > "Create a .rubocop.yml with rubocop-rspec, rubocop-factory_bot, and rubocop-rspec-guide enabled (use the default config from the style guide)."

   (Codex will add the necessary config lines.)

3. **Generate spec file** – Switch Codex to Auto mode and instruct:
   > "Write the RSpec spec for `PaymentProcessor` according to the plan. Use contexts per characteristic, happy path first, etc. Use FactoryBot for data."

   Approve file creations/edits. Codex will create `spec/services/payment_processor_spec.rb` with content.

4. **Run linters and tests** – Use codex exec:
   - `codex exec "bundle exec rubocop -D"` to get style offenses. If any offenses, go back into Codex chat:
     > "Fix the RuboCop offenses in payment_processor_spec.rb."
   - `codex exec "bundle exec rspec"` to run tests. If failures, provide failures to Codex:
     > "Fix the failing test for PaymentProcessor (it says 'expected 200 got 500')."

   Iterate until 0 offenses and all tests green.

5. **Review final code** – (Optional) Ask Codex in Read-Only:
   > "Summarize how the tests adhere to the style guide and if any improvements can be made."
```

This runbook is meant for a developer to follow or adapt. It outlines how to use Codex's features stepwise to achieve the goal.

By having such runbooks and skills, your team can consistently generate and verify tests, whether via AI or manually, with the RSpec style guide as the unwavering standard.

---

## References

1. [GitHub - AlexeyMatskevich/rspec-guide](https://github.com/AlexeyMatskevich/rspec-guide)
2. [GitHub - AlexeyMatskevich/rubocop-rspec-guide](https://github.com/AlexeyMatskevich/rubocop-rspec-guide)
3. [Claude Code 2.0: Checkpoints, Subagents, and Autonomous Coding](https://skywork.ai/blog/claude-code-2-0-checkpoints-subagents-autonomous-coding/)
4. [Claude Skills: Customize AI for your workflows \ Anthropic](https://www.anthropic.com/news/skills)
5. [Claude Code Best Practices \ Anthropic](https://www.anthropic.com/engineering/claude-code-best-practices)
6. [How to Install OpenAI Codex CLI on macOS: Complete 2025 Guide | ITECS Blog](https://itecsonline.com/post/install-codex-macos)
7. [exec.md - openai/codex](https://github.com/openai/codex/blob/4a42c4e1420e24cd74528398f7892d68c1407b3a/docs/exec.md)
8. [README.md - openai/codex](https://github.com/openai/codex/blob/4a42c4e1420e24cd74528398f7892d68c1407b3a/README.md)
9. [guide.en.md - rspec-guide](https://github.com/AlexeyMatskevich/rspec-guide/blob/0a2d3c303ac1ddda90060a7983fe83f083bab8b6/guide.en.md)
10. [.rubocop.yml.example - rspec-guide](https://github.com/AlexeyMatskevich/rspec-guide/blob/0a2d3c303ac1ddda90060a7983fe83f083bab8b6/rubocop-configs/.rubocop.yml.example)