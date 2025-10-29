# Table of Contents

## Philosophy and Foundations
- [What You Can Learn from Tests](#what-you-can-learn-from-tests)
- [About RSpec](#about-rspec)
  - [How RSpec, BDD and TDD are Related](#how-rspec-bdd-and-tdd-are-related)
  - [Why We Need BDD in Practice](#why-we-need-bdd-in-practice)
  - [From Natural Language to Formal Gherkin Syntax](#from-natural-language-to-formal-gherkin-syntax)
  - [Testing Pyramid and Level Selection](#testing-pyramid-and-level-selection)
- [Glossary](#glossary)
  - [Core Concepts](#core-concepts)
  - [Types of Testing](#types-of-testing)
  - [Design Principles](#design-principles)
  - [Characteristics and States](#characteristics-and-states)
- [Why We Write Tests This Way: Cognitive Load](#why-we-write-tests-this-way-cognitive-load)
  - [Three Types of Cognitive Load in Tests](#three-types-of-cognitive-load-in-tests)
  - [How Rules Reduce Cognitive Load](#how-rules-reduce-cognitive-load)
  - [How Tests Reveal Design Problems](#how-tests-reveal-design-problems)

## Quick Reference
- [All Rules in One List](#all-rules-in-one-list)
- [Quick Diagnostics: "Why Does My Test Smell?"](#quick-diagnostics-why-does-my-test-smell)

## RSpec Style Guide

### Behavior and Test Structure
- [1. Test behavior, not implementation](#1-test-behavior-not-implementation)
- [2. Verify what the test actually tests](#2-verify-what-the-test-actually-tests)
- [3. Each example (`it`) describes one observable behavior](#3-each-example-it-describes-one-observable-behavior)
  - [3.1. Exception for interface testing](#31-exception-for-interface-testing)
  - [3.2. Working with large interfaces](#32-working-with-large-interfaces)
- [4. Identify behavior characteristics and their states](#4-identify-behavior-characteristics-and-their-states)
- [5. Build `context` hierarchy by characteristic dependencies](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases)
- [6. Final context audit: two types of duplicates](#6-final-context-audit-two-types-of-duplicates)
- [7. Place happy path before corner cases](#7-place-happy-path-before-corner-cases)
- [8. Write positive and negative tests](#8-write-positive-and-negative-tests)
- [9. Each context should reflect the difference from the outer scope](#9-each-context-should-reflect-the-difference-from-the-outer-scope)

### Syntax and Readability
- [10. Specify `subject` to explicitly designate what is being tested](#10-specify-subject-to-explicitly-designate-what-is-being-tested)
- [11. Each test should be divided into 3 phases](#11-each-test-should-be-divided-into-3-phases-in-strict-order)

### Context and Data Preparation
- [FactoryBot and Data Preparation](#factorybot-and-data-preparation)
  - [12. Use FactoryBot capabilities](#12-use-factorybot-capabilities-to-hide-test-data-details)
  - [13. Use `attributes_for` to generate parameters](#13-use-attributes_for-to-generate-parameters-that-are-not-important-details-in-behavior-testing)
  - [14. In unit tests use `build_stubbed`](#14-in-unit-tests-except-models-use-build_stubbed)
  - [Choosing FactoryBot Method: Decision Tree](#choosing-factorybot-method-decision-tree)
- [15. Don't program in tests](#15-dont-program-in-tests)
- [16. Explicitness over DRY](#16-explicitness-over-dry)

### Specification Language
- [17. Description should form a valid sentence](#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english)
- [18. Description should be understandable to anyone](#18-description-of-contexts-context-and-test-cases-it-together-including-it-should-be-written-so-that-anyone-understands)
- [19. Grammar of describe/context/it formulations](#19-grammar-of-describecontextit-formulations)
- [20. Context language: when / with / and / without / but / NOT](#20-context-language-when--with--and--without--but--not)
- [21. Study Rubocop rules on naming](#21-study-rubocop-rules-on-naming-in-detail)

### Tools and Support
- [22. Don't use `any_instance`](#22-dont-use-any_instance)
- [23. Use `:aggregate_failures` only when describing one rule](#23-use-aggregate_failures-only-when-describing-one-rule)
  - [Decision Guide: one `it` or multiple?](#decision-guide-one-it-or-multiple)
  - [Testing Patterns: before/after](#testing-patterns-beforeafter)
- [24. Prefer verifying doubles](#24-prefer-verifying-doubles-instance_double-class_double-object_double)
- [25. Use shared examples to declare contracts](#25-use-shared-examples-to-declare-contracts)
- [26. Prefer Request specs over controller specs](#26-prefer-request-specs-over-controller-specs)
- [27. Stabilize time with `ActiveSupport::Testing::TimeHelpers`](#27-stabilize-time-with-activesupporttestingtimehelpers)
- [28. Make test failure output readable](#28-make-test-failure-output-readable)

## Specialized Topics
- [API Contract Testing: RSpec Applicability Boundaries](#api-contract-testing-rspec-applicability-boundaries)
  - [Complete API Contracts Guide](guide.api.en.md)
- [External Services](#external-services)
- [Time Nuances Between Ruby and PostgreSQL](#time-nuances-between-ruby-and-postgresql)

## Practical Guides
- [Migration from Implementation-Focused to Behavior-Focused Tests](#migration-from-implementation-focused-to-behavior-focused-tests)
- [Refactoring Deep Context Hierarchies](#refactoring-deep-context-hierarchies)
- [Introducing Characteristic-Based Structure into Existing Tests](#introducing-characteristic-based-structure-into-existing-tests)

# What You Can Learn from Tests

- **Better Specs** — style and formulations: learn to write readable `describe/context/it`, choose matchers and avoid anti-patterns. <https://www.betterspecs.org>
- **Testing for Beginners** — introductory book: understand what to test, how to think in scenarios and parse red tests. <http://testing-for-beginners.rubymonstas.org/index.html>
- **Pluralsight: RSpec Ruby Application Testing** — hands-on course: build BDD cycle step by step, reinforce `describe/context/it` structure and three test phases. <https://www.pluralsight.com/courses/rspec-ruby-application-testing>
- **Everyday Rails Testing with RSpec** — practices and tools: from factory_bot to VCR/WebMock, plus daily patterns for maintaining baseline coverage. <https://leanpub.com/everydayrailsrspec>

These materials provide the foundation. Below is the RSpec/BDD philosophy that underpins the rules in the next section.

# About RSpec

RSpec is a testing library for Ruby with a DSL tailored for describing behavior, not internal implementation.

```ruby
describe "my app" do
  it "works" do
    expect(MyApp.working).to eq(true)
  end
end
```

Official tagline from <https://rspec.info/>:

```
Behaviour Driven Development for Ruby.
Making TDD Productive and Fun.
```

Key idea: RSpec is a BDD tool for Ruby. It makes TDD practice productive and more "human" through language close to business formulations.

## How RSpec, BDD and TDD are Related

TDD (test-driven development) is a short Red -> Green -> Refactor cycle:

- write a test that captures desired behavior;
- write minimal code to make the test pass;
- refactor while keeping green state.

BDD (behaviour-driven development) grew out of TDD and shifts focus to [domain](#domain) behavior and business communication language. Tests become readable specifications, not just code checks.

RSpec embodies BDD in the Ruby ecosystem: `describe/context/it` help formulate behavior uniformly and understandably.

## Why We Need BDD in Practice

- Common language with business: formulate [domain](#domain) rules in "human" phrases without knowing implementation.
- Executable documentation: tests are verifiable behavior specifications.
- Fast problem localization: failed test clearly shows which rule is violated.
- Free refactoring: focus on what the system does, not how it's built.

**Domain** — a set of rules and concepts that business wants to see in the system (e.g., billing). In code, we implement precisely these behavior rules.

## From Natural Language to Formal Gherkin Syntax

BDD often relies on Gherkin — a formal but readable syntax for describing stories and scenarios. It captures three key phases: Given (initial context), When (action), Then (result).

Example story and scenarios:

```
As a store owner
In order to keep track of stock
I want to add items back to stock when they're returned.

Scenario 1: Refunded items should be returned to stock
  Given that a customer previously bought a black sweater from me
  And I have three black sweaters in stock
  When they return the black sweater for a refund
  Then I should have four black sweaters in stock

Scenario 2: Replaced items should be returned to stock
  Given that a customer previously bought a blue garment from me
  And I have two blue garments in stock
  And three black garments in stock
  When they return the blue garment for a replacement in black
  Then I should have three blue garments in stock
  And two black garments in stock
```

### Gherkin Language — Cheat Sheet

| Keyword (EN) | Short Description |
| --- | --- |
| Story / Feature | Specification heading, formulates value. |
| As a | Stakeholder role. |
| In order to | Role's goal. |
| I want to | Brief desired outcome. |
| Scenario | Specific story scenario. |
| Given | Initial context (repeated with And). |
| When | Action triggering the scenario. |
| Then | Observable result (can add And/But). |
| And / But | Context clarification or exceptions. |

### How This Relates to RSpec

RSpec doesn't require Gherkin and doesn't execute `.feature` files, but follows the same semantic phases:

- **Given** -> context preparation (`let`, `before`, helper methods).
- **When** -> action being tested (method call, HTTP request, command).
- **Then** -> expected result (`expect` assertions).
- **Feature / Story** -> top-level `describe`, setting behavior scope.
- **Scenario** -> `it`, specific behavior example.
- **And / But** -> context clarification through nested `context`.

This isn't a mechanical one-to-one correspondence, but this lens helps write tests as readable [domain](#domain) specifications. The rules in the next section are built on this foundation.

## Testing Pyramid and Level Selection

BDD puts behavior first, but checks themselves live at different levels. Keep the pyramid in mind: fast unit tests at the base, service/integration in the middle, end-to-end and contract at the top. Proper level selection helps avoid testing implementation.

| Level | Question | Observation | Typical Tools |
| --- | --- | --- | --- |
| Unit (model, service, object) | How does a small piece of logic behave? | Return value, dependency calls (via doubles) | `expect`, doubles, pure Ruby |
| Integration / service | How do multiple components interact? | Service response, [domain](#domain) model change, side effects | Request/feature specs, ActiveJob, mailers |
| Request / API contracts | What does the client see (frontend, external service)? | HTTP status, response body, headers | Request specs, pact/contract tests |
| System (E2E) | Does the user story work end-to-end? | UI reactions, end-to-end flow | Capybara, Cypress, etc. |

**Note:** For API contract testing (field structure, types, required fields) see [guide.api.en.md](guide.api.en.md) — RSpec isn't the best tool for this task.

There are no iron rules, but there are guidelines:

- Check at the level where behavior is naturally observable. Request spec checks status/response, not database contents — otherwise you're testing controller implementation, not API contract (see rule 1).
- If one check requires complex context preparation or slow dependencies, consider moving part of the logic to a lower [pyramid](#testing-pyramid-and-level-selection) level.
- Single side effect (record created, email sent) is better extracted to a separate unit/service test. In BDD contracts, capture only what matters to the consumer.
- `:aggregate_failures` (rule 23) applies only when talking about one behavior and wanting to see all violations at once — it's not a way to check half the [pyramid](#testing-pyramid-and-level-selection) in one `it`.

With the [pyramid](#testing-pyramid-and-level-selection) in mind, it's easier to decide what counts as happy path, what as corner case, and which test level is responsible for confirming each rule.

## Glossary

### Core Concepts

#### Behavior

An observable change in system state or its reaction to external influence that can be described in one sentence in natural language.

Behavior in the context of BDD and RSpec is not every attribute or object method, but a business rule or action result that matters to stakeholders.

**Examples of behaviors:**
- "Creates an order in the database"
- "Sends confirmation email"
- "Provides full user profile from session"
- "Blocks access for unauthorized user"
- "Calculates total cost with discount"

**NOT separate behaviors:**
- Each individual attribute of a configuration object (e.g., `name`, `email`, `phone` are parts of User object interface)
- Each field in API response structure (all fields together form the response contract)
- Each value object getter (getters together form the public interface)

**Rule:** If you can't describe a check as an independent action or result in natural language, it's likely part of a larger behavior.

#### Domain

The subject area or business domain for which the application is developed. The concept originates from Domain-Driven Design (DDD).

In the context of testing and architecture:
- **Domain rules** — business rules and domain logic that we verify in tests
- **Domain model** — a set of entities and their behavior reflecting domain rules
- **Domain language** — ubiquitous language used by both developers and business specialists to describe rules
- **Domain layer** — architectural layer containing business logic, isolated from infrastructure details (DB, HTTP, external services)
- **Domain objects** — objects expressing domain concepts: entities, value objects, services
- **Business domain** — specific area of responsibility (e.g., "payments domain", "authentication domain")

**In tests:** We formulate domain rules using domain language instead of technical terms. At the integration level, details within one business domain are combined, while their combinatorics are tested in unit tests (see [Rule 5](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases)).

### Types of Testing

Depending on what exactly we're checking, tests are divided into two main types:

#### Behavioral Testing

Checking business logic through observable side effects or system reactions. Each action causes an independent effect that matters to the business.

**Examples:**
- Checking that a method creates a database record
- Checking that a service sends an email
- Checking that order status changed after payment
- Checking that the system logs an event

**Distinctive features:**
- Each effect is a separate business logic rule
- Effects are independent of each other
- Each effect can be described in a separate sentence: "the system does X"

#### Interface Testing

Checking a set of object attributes in a specific state. All checked attributes are derived from one source/state and represent a single behavior: "object provides correct interface".

**Application examples:**
- Value objects with multiple attributes (Money, Address, Coordinate)
- Configuration objects (Settings, Config, Preferences)
- Read-only interfaces built from a single source
- Presenter/Decorator objects providing derived attributes

**Distinctive features:**
- Attributes are connected by a common data source
- Source change affects all attributes at once
- Attributes form a holistic object contract
- Described as "object provides interface X"

**Rule of thumb:** If you're checking multiple attributes that are all derived from one source/state and don't include independent business effects, it's interface testing — combine checks in one `it` with `:aggregate_failures`.

**Important:** Interface testing applies to [domain](#domain) objects. For HTTP API interfaces, use specialized contract fixation tools (see "API Contract Testing: RSpec Applicability Boundaries" section).

### Design Principles

These principles from object-oriented design directly affect code testability. Tests honestly show violations of these principles through their complexity.

#### Do One Thing

Principle from "Clean Code" (Robert Martin): a function/method/class should have one responsibility and do only one thing at one level of abstraction.

**Signal in tests:**
- **At method level:** Deep context nesting (5+ levels), dozens of characteristic combinations for one method
- **At class level:** Too many `describe` blocks (10+ public methods) — class does too many different things

**Typical violations:**
- Mixing abstraction levels (high-level business logic + low-level details in one method)
- Multiple responsibility (method OR class solves several independent tasks)
- Unclear layer boundaries (controller contains business logic, model builds complex SQL queries AND processes data)

**Solution for Rails:** Controller → coordination, Service Object → business logic, Model → data operations

**See also:** [Rule 5](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases)

#### Single Responsibility Principle

A class should have only one reason to change. Part of SOLID principles.

**Signal in tests:** Complex factories with dozens of required fields, impossible to test one aspect of behavior in isolation.

**Typical violation:** God Object — a class that knows or does too much. ActiveRecord model with business logic, validation, calculations, integrations, etc.

**See also:** [Rules 12-14](#12-use-factorybot-capabilities-to-hide-test-data-details)

#### Encapsulation

Hiding internal implementation details behind a public interface. An object manages its own state and doesn't expose internals.

**Signal in tests:** Tests check internal method calls (`receive`), need to know DB schema details to create test data, impossible to create object through public API.

**Typical violations:**
- Direct work with object internal fields
- Public methods that are actually utility methods (should be private)
- Implementation details leaking through API

**See also:** [Rule 1](#1-test-behavior-not-implementation), [Rule 15](#15-dont-program-in-tests)

#### Dependency Injection

Dependencies are passed to an object from outside (through constructor, setter, method parameter), not created inside the object.

**Signal in tests:** Need `any_instance_of` for mocks, impossible to test class in isolation, have to mock global objects.

**Typical violation:** Class creates dependencies inside itself: `service = SomeService.new` in a method instead of `def initialize(service)`.

**Solution:** Pass dependencies through constructor. This makes code testable and flexible.

**See also:** [Rule 22](#22-dont-use-any_instance)

#### Tight Coupling

Situation when classes/modules depend too strongly on each other, know about each other's internal details.

**Signal in tests:** Need to create many related objects to test one class, changing one class breaks tests of other classes, impossible to use `build_stubbed`.

**Typical violation:** Class directly accesses fields of another class, rigidly depends on specific implementation instead of interface.

**Solution:** Depend on abstractions/interfaces, not concrete implementations (Dependency Inversion from SOLID).

**See also:** [Rules 13-14](#13-use-attributes_for-to-generate-parameters-that-are-not-important-details-in-behavior-testing), [Rule 22](#22-dont-use-any_instance)

#### Leaky Abstraction

When lower-level details "leak" through upper-level interface. The abstraction user is forced to know implementation details.

**Signal in tests:** Have to know DB schema details to work with [domain](#domain) model, business logic mixed with SQL, public API doesn't express business operations.

**Typical violation:** ActiveRecord model with public methods like `update_column`, business service that requires knowledge of DB structure.

**Solution:** Clearly separate layers (domain → persistence), [domain](#domain) layer shouldn't know about storage details.

**See also:** [Rule 15](#15-dont-program-in-tests)

**Key idea:** If tests are complex — the problem is in code design. Don't complicate tests, simplify code. Tests are honest feedback about architecture quality.

### Characteristics and States

#### Characteristic

A [domain](#domain) aspect that affects behavior outcome (user role, payment method, order status).

*How to find:* ask "if I change this characteristic, will the expected result change?", and make sure you're talking about a business fact, not a technical detail.

#### State

A specific variant of a characteristic value important for the rule (subscription active, balance below limit).

*How to identify:* group possible values into [domain](#domain) ranges and formulate them as short statements.

*Types of states:*
- binary (yes/no: card linked ↔ not linked);
- multiple (enum: role = admin / manager / guest);
- ranges (number/date: balance ≥ cost / balance < cost).

#### Context

A `context` block capturing one or several characteristic states. Context is responsible for the "Given" part of the specification.

**Types of contexts:**
- **Positive context** — state is met (usually part of happy path).
- **Negative context** — state is violated or negated (often part of corner case).
- **Nested context** — refines outer context, adding a new characteristic state or refining the current one.

#### Case

A minimal scenario (`it` block) testing specific behavior on a selected set of states.

**Types of cases:**
- **Happy path case** — main flow: expected success without exceptions.
- **Corner case** — deviation from main flow: edge values, errors, exceptional situations.
- **Positive test** — example confirms behavior (often coincides with happy path).
- **Negative test** — example shows refusal or protection from incorrect behavior (often coincides with corner case).

*Important:* happy/corner describe case type, while positive/negative describe test result. With multiple states, several happy path cases are possible without negative tests on this characteristic.

| Case Type       | Context Types Inside                   | Test Result                 |
| --------------- | -------------------------------------- | --------------------------- |
| Happy path case | Positive contexts                      | Positive test               |
| Corner case     | Negative or refining contexts          | Negative test / protection  |

The table reflects typical relationships, but exceptions are possible — for example, enum characteristic can include several happy path cases without negative tests, or corner case can end with positive result (e.g., graceful degradation).

#### State Assignment

A declaration (`let`/`before`) that makes the context formulation true. It's placed directly under the corresponding `context`, so the connection between description and context preparation reads without file searching (see point 11).

#### Flaky test

A test that behaves unpredictably: sometimes green, sometimes red with unchanged code. Most often related to unstable time, global state, random order, or dependencies on external services.

# RSpec style guide

## Why We Write Tests This Way: Cognitive Load

All rules in this guide are united by one goal: **reduce cognitive load when reading, understanding, and changing tests**.

**Cognitive load** is the amount of mental effort required to perform a task. In the context of tests, this means:
- How much information needs to be kept in memory to understand what the test checks?
- How much time is required to find the right test when it fails?
- How easy is it to change a test when requirements change?

### Three Types of Cognitive Load in Tests

1. **Intrinsic load** — complexity of the domain itself. This is inevitable: if a business rule is complex, the test will reflect this complexity.

2. **Extraneous load** — artificial complexity due to poor code organization. Examples:
   - Test checks implementation instead of behavior → reader needs to "execute code mentally"
   - Characteristic states hidden in private methods → need to search for definitions
   - Multiple behaviors in one `it` → unclear which rule is violated on failure

3. **Germane load** — effort to build a mental model. Good tests help build this model quickly:
   - Explicit `context` structure shows characteristic dependencies
   - `it` description formulates business rule in natural language
   - Three-phase structure (Given-When-Then) simplifies reading

### How Rules Reduce Cognitive Load

Each rule in this guide attacks extraneous load and strengthens germane load:

- **[Rule 1](#1-test-behavior-not-implementation)** (behavior, not implementation) — eliminates the need to understand code's internal structure
- **[Rule 5](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path--corner-cases)** (context hierarchy) — makes characteristic dependencies visible immediately
- **[Rule 10](#10-specify-subject-to-explicitly-designate-what-is-being-tested)** (subject) — explicitly shows what's being tested, no need to search for object in expectations
- **[Rule 11](#11-each-test-should-be-divided-into-3-phases-in-strict-order)** (three-phase structure) — creates a predictable reading pattern
- **[Rules 12-13](#12-use-factorybot-capabilities-to-hide-test-data-details)** (factories) — hide technical details, leave only business characteristics
- **[Rule 16](#16-explicitness-over-dry)** (explicitness over DRY) — tests remain documentation, not a puzzle of abstractions
- **Rules 17-21** ([Specification Language](#specification-language)) — clear formulations in natural language turn tests into readable documentation
- **[Rule 23](#23-use-aggregate_failures-only-when-describing-one-rule)** (aggregate_failures) — shows all violations at once, saving debugging cycles
- **[Rule 28](#28-make-test-failure-output-readable)** (readable failure output) — using proper matchers gives clear and relevant output on failure

When you follow these rules, your tests become **executable documentation**: colleagues can quickly understand business rules, new developers easily grasp the [domain](#domain), and requirement changes don't turn into rewriting half the test suite.

**Golden rule:** If when reading a test you have a question "what does this mean?" or "where does this come from?", extraneous cognitive load is too high. Simplify.

## Tests as Code Quality Indicator

The second key idea of this guide: **test complexity and problems reflect problems in tested code**. Tests are not just correctness checks, but a **design quality detector**.

### How Tests Reveal Design Problems

Well-designed code is easy to test. If tests become complex, fragile, or confusing — it's a signal about problems in architecture and code design itself.

**Typical signals of bad design through tests:**

1. **Complex data preparation (Given)** → code depends on too many details, encapsulation principle violated
2. **Deep context nesting (5+ levels)** → method violates [Do One Thing](#design-principles), does too much
3. **Implementation tests (`receive`, `allow` for internal methods)** → fragile abstractions, unclear responsibility boundaries
4. **Frequent test changes during refactoring** → code depends on implementation details, not contracts
5. **Impossible to test behavior without mocks** → too tight coupling
6. **Complex factories with dozens of required fields** → God Object, Single Responsibility violation

### Tests as Design Improvement Tool

BDD and TDD are not only about correctness, but also about **design through tests**:

- **Test-First forces thinking about interface** — you write test before code, so you first define convenient public API
- **Complex test = signal to simplify code** — if test is hard to write, code is too complex or incorrectly structured
- **Refactoring becomes safe** — good tests (on behavior) allow changing implementation without fear

**Feedback rule:** When you encounter complexity in tests, the first question should not be "how to work around this in tests?", but **"what's wrong with code design?"**.

### Examples of Signals and Solutions

| Signal in Tests | Problem in Code | Solution |
|-----------------|-----------------|---------|
| Need to mock 5+ dependencies | Too many responsibilities in one class | Split into several classes with clear boundaries |
| Deep `context` nesting | Method does too much (Do One Thing violation) | Extract subtasks into separate methods/services |
| Tests break during refactoring | Tests tied to implementation, not behavior | Rewrite tests to check observable behavior |
| Hard to create object for test | God Object or complex dependencies | Apply Dependency Injection, simplify constructor |
| Need private methods in setup | Hidden complexity or leaky abstractions | Extract logic to public interface or separate class |

**Golden rule:** If a test is complex, don't complicate tests — simplify code. Tests should remain simple and declarative. Their complexity is honest feedback about design quality.

---

## Quick Reference

This section contains a compact summary of all rules, decision trees, and common anti-patterns for quick reference.

### All Rules in One List

**Behavior and Test Structure:**

1. **[Test behavior, not implementation](#1-test-behavior-not-implementation)** — Check observable results, not internal details (methods, instance variables).
2. **[Verify what the test actually tests](#2-verify-what-the-test-actually-tests)** — Ensure the test fails when the rule is violated (test-first practice).
3. **[One `it` — one behavior](#3-each-example-it-describes-one-observable-behavior)** — Each example describes one observable rule; use `:aggregate_failures` only for interface testing.
4. **[Identify characteristics](#4-identify-behavior-characteristics-and-their-states)** — Characteristic = condition affecting behavior; each characteristic = separate `context`.
5. **[Hierarchy by dependencies](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases)** — Happy path first, corner cases nested; one characteristic = one `context` level.
6. **[Final context audit](#6-final-context-audit-two-types-of-duplicates)** — Check for description duplicates (merge) and state duplicates (separate).
7. **[Happy path before corner cases](#7-place-happy-path-before-corner-cases)** — Reader sees main scenario first, then exceptions.
8. **[Positive and negative tests](#8-write-positive-and-negative-tests)** — Check both successful result and failure (when applicable).
9. **[Context differences](#9-each-context-should-reflect-the-difference-from-the-outer-scope)** — Each nested `context` should add a new characteristic or refinement.

**Syntax and Readability:**

10. **[Specify `subject`](#10-specify-subject-to-explicitly-designate-what-is-being-tested)** — Explicitly designate what is being tested for clarity.
11. **[Three test phases](#11-each-test-should-be-divided-into-3-phases-in-strict-order)** — Preparation (`let`/`before`) → Action (explicit call) → Verification (`expect`).
12. **[Use FactoryBot](#12-use-factorybot-capabilities-to-hide-test-data-details)** — Hide data details important only for validity, not for behavior.
13. **[`attributes_for` for parameters](#13-use-attributes_for-to-generate-parameters-that-are-not-important-details-in-behavior-testing)** — Generate parameter hashes instead of full objects when object isn't needed.
14. **[`build_stubbed` in units](#14-in-unit-tests-except-models-use-build_stubbed)** — Faster than `build`/`create`; stubbed objects don't touch DB.
15. **[Don't program in tests](#15-dont-program-in-tests)** — Avoid loops, conditionals, complex logic; tests should be declarative.
16. **[Explicitness over DRY](#16-explicitness-over-dry)** — Duplicate code if it makes the test clearer.

**Specification Language:**

17. **[Valid sentence](#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english)** — `describe` + `context` + `it` form a grammatically correct English sentence.
18. **[Understandable to anyone](#18-description-of-contexts-context-and-test-cases-it-together-including-it-should-be-written-so-that-anyone-understands)** — Descriptions should be understandable without programming knowledge (business language).
19. **[Grammar](#19-grammar-of-describecontextit-formulations)** — `describe` (noun/method), `context` (when/with/and), `it` (verb in 3rd person).
20. **[Context language](#20-context-language-when--with--and--without--but--not)** — Use when/with/and/without/but/NOT to connect characteristics.
21. **[Rubocop naming](#21-study-rubocop-rules-on-naming-in-detail)** — Study [RSpec Style Guide](https://rspec.rubystyle.guide/#naming) for details.

**Tools and Support:**

22. **[Don't use `any_instance`](#22-dont-use-any_instance)** — Use dependency injection instead of global mocks.
23. **[`:aggregate_failures` only for interfaces](#23-use-aggregate_failures-only-when-describing-one-rule)** — One rule = one `it`; object interface = can combine with aggregate_failures.
24. **[Verifying doubles](#24-prefer-verifying-doubles-instance_double-class_double-object_double)** — Prefer `instance_double`/`class_double` over `double` for contract verification.
25. **[Shared examples for contracts](#25-use-shared-examples-to-declare-contracts)** — Declare repeating contracts through shared examples.
26. **[Request specs instead of controller specs](#26-prefer-request-specs-over-controller-specs)** — Request specs check HTTP contract, controller specs are deprecated.
27. **[Stabilize time with TimeHelpers](#27-stabilize-time-with-activesupporttestingtimehelpers)** — Use `freeze_time` and `travel_to` for predictable time tests.
28. **[Make test failure output readable](#28-make-test-failure-output-readable)** — Structural matchers instead of string comparisons for clear errors.

### Quick Diagnostics: "Why Does My Test Smell?"

**If the test is hard to read:**
- ✅ Check: are loops/conditionals used? → See [Rule 15](#15-dont-program-in-tests)
- ✅ Check: do describe/context/it form a sentence? → See [Rule 17](#17-description-of-contexts-context-and-test-cases-it-together-including-it-should-form-a-valid-sentence-in-english)
- ✅ Check: are data details hidden in factories? → See [Rule 12](#12-use-factorybot-capabilities-to-hide-test-data-details)

**If the test runs slowly:**
- ✅ Check: are you using `create` in unit tests? → Replace with `build_stubbed` ([Rule 14](#14-in-unit-tests-except-models-use-build_stubbed))
- ✅ Check: are there unnecessary HTTP requests? → See [External Services](#external-services) section
- ✅ Check: are unnecessary associations created? → Use traits selectively ([Rule 12](#12-use-factorybot-capabilities-to-hide-test-data-details))

**If the test is flaky (fails unpredictably):**
- ✅ Check: is time fixed? → See [Rule 27](#27-stabilize-time-with-activesupporttestingtimehelpers) and [Time Nuances](#time-nuances-between-ruby-and-postgresql) section
- ✅ Check: does it depend on record order? → See [Rule 1](#1-test-behavior-not-implementation) (use `match_array`)
- ✅ Check: are there race conditions? → Isolate tests

**If the test fails during refactoring:**
- ✅ Check: are you testing implementation? → See [Rule 1](#1-test-behavior-not-implementation)
- ✅ Check: is there coupling to details? → Hide details in factories ([Rule 12](#12-use-factorybot-capabilities-to-hide-test-data-details))

**If the test doesn't fail when it should:**
- ✅ Check: is test-first approach working? → See [Rule 2](#2-verify-what-the-test-actually-tests)
- ✅ Check: are all expectations executed? → Add explicit `expect`

---

## Behavior and Test Structure

### 1. Test behavior, not implementation

If your test doesn't describe [behavior](#behavior), it's not a test. Why? Without behavior description, implementation coupling emerges—when someone looks at tests after you, they won't understand anything and the tests will be useless.

###### below, `some_action` in examples is pseudocode that we're testing and whose behavior we're describing

```ruby
# atrocious
describe "#some_action" do
  # ... create user, but don't connect context preparation with description
  it "true" do          # "true"? What's true? Why true? Under what conditions? Reader is confused...
    expect(some_action).to be(true)
  end
end
```

```ruby
# good
describe "#some_action" do
  # ... create user and explicitly set the characteristic we mention in `it`
  it "allows unlocking the user" do         # Aha! Now it's clear: true means "unlocking is allowed"
    expect(some_action).to be(true)
  end
end
```

What's wrong in the bad example:

- The `it` description doesn't tell about behavior; it's unclear what the expected `true` means.
- The context in the comment isn't connected with the example formulation, so the specification doesn't read as a behavior rule.

Or, for example, use `match_array` or `contain_exactly` when writing expectations for arrays where element order doesn't matter.

```ruby
# bad
expect(some_action).to eq [1, 2, 3] # pass
```

```ruby
# good
expect(some_action).to match_array [2, 3, 1] # pass
expect(some_action).to contain_exactly(1, 2, 3) # pass
```

What's wrong in the bad example:

- The `eq` comparison ties the test to element order and leads to false failures.
- The specification describes implementation, not the rule.

Imagine `some_action` always returned `[1, 2, 3]` and your tests passed, then you made some changes to the code, updated the database, etc. That is, for some reason the array order changed, for example, it became `[2, 1, 3]`, and a dozen of your tests started failing. And all this happened because of your implementation coupling! Don't do this, test specific behavior. If it's data selection, check the fact of correct data selection.

In general, every time you work with any collection (arrays, hashes, ActiveRecord::Relation...) and use `eq`, it's a bell that you're doing something wrong. Perhaps there's a helper from the `RSpec Expectations` library suitable for defining your expectation, or perhaps you're testing the wrong thing (not your code's behavior) or even implementing the wrong thing.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Behavior description in natural language (`"allows unlocking the user"`) creates a mental model without needing to read code
- The right matcher (`match_array` instead of `eq`) immediately shows intent: "checking composition, not order"
- When a test with clear description fails, it's immediately clear which business rule is violated—no need to analyze implementation

**What this says about code design:**

If it's hard to write a test for **behavior** and you have to test **implementation** — it's a signal about [encapsulation](#design-principles) violation:

- Public API doesn't express business operations, only technical details → [leaky abstraction](#design-principles)
- Need to check internal method calls (`receive`) → internal logic isn't hidden behind public interface
- Tests break during refactoring even when behavior doesn't change → code depends on implementation details, not contracts

**Solution:** Public API should express business operations. If API is good, behavior test writes naturally, without mocking internal calls.

**See also:**
- [Rule 2: Verify what the test actually tests](#2-verify-what-the-test-actually-tests) — ensure the test really checks behavior
- [Rule 3: One `it` — one behavior](#3-each-example-it-describes-one-observable-behavior) — how to properly separate behaviors
- [Rule 22: Don't use `any_instance`](#22-dont-use-any_instance) — avoid implementation mocks

### 2. Verify what the test actually tests

After writing a test, ensure it actually catches bugs — break the code and verify the test fails. This is the second most important rule after "test behavior": without verifying test functionality, you risk getting a false-positive test that always passes regardless of code correctness.

#### Problem: code-first instead of test-first

In an ideal TDD (test-driven development) world, the "Red → Green → Refactor" cycle guarantees the test first fails (Red), then passes after implementation (Green). But in real commercial development, most teams don't follow strict TDD—code is written first, then tests. This leads to the risk of "fitting the test to implementation": the test is written to check current implementation but doesn't catch errors.

**Typical scenario:**

1. You wrote code
2. Wrote a test that passes
3. Committed
4. A week later someone breaks the code
5. Test is still green—because it never checked correct behavior

#### Contrived example

**Note:** An experienced reader will find the problem in this example obvious, but it's hard for the guide author to come up with a truly practical example. Such situations are very tricky and easily arise everywhere in real code, often in more complex contexts where the error isn't as noticeable.

```ruby
# code
class NotificationService
  def notify_user(user, message)
    UserMailer.notification(user.email, message).deliver_later
  end
end
```

```ruby
# bad
describe NotificationService do
  let(:user) { double(email: 'user@example.com') }
  let(:mailer) { double(deliver_later: true) }

  before do
    allow(UserMailer).to receive(:notification).and_return(mailer)
  end

  it 'sends notification to user' do
    service.notify_user(user, 'Hello')
    expect(UserMailer).to have_received(:notification)
  end
end
```

**What's wrong:**

- Test only checks the fact of `notification` call, but doesn't check arguments
- If code breaks and starts passing `nil` instead of email or wrong message—test stays green
- It seems everything is covered, but in fact the critical part (passing correct data) isn't checked

#### Practical checklist

After writing each test, perform "manual Red":

1. ✅ Test passes (Green)
2. 🔨 Break the code in one of the ways:
   - Return wrong value (`return 0`, `return nil`, `return "wrong"`)
   - Comment out key logic line
   - Change condition (`if` → `unless`, `>` → `<`)
   - Pass wrong arguments to method calls
3. ❌ Test should fail (Red)
4. 🔄 Restore code to original state
5. ✅ Test passes again (Green)

If at step 3 the test stayed green—rewrite the test, it doesn't check real behavior.

**Golden rule:** A test that never failed proves nothing. Break the code and ensure the test catches the breakage—only then do you have a guarantee it works.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- False-positive tests create an illusion of coverage and make the team constantly doubt: "does this test actually check anything?"
- Test verification through "manual Red" gives confidence—no need to keep in mind the question "does this test even work?"
- The team can trust the test suite and not spend mental effort on test distrust

**See also:** [Rule 23: aggregate_failures](#23-use-aggregate_failures-only-when-describing-one-rule) — allows seeing all violations at once when checking test for Red

### 3. Each example (`it`) describes one observable behavior

**Navigation within the rule:**
- [3.1. Exception for interface testing](#31-exception-for-interface-testing)
- [3.2. Working with large interfaces](#32-working-with-large-interfaces)

The description in `it` should be unique and tell about one business truth. If two examples name the same thing, we're checking implementation in different ways. This is a smell: either need to identify a separate [behavior](#behavior), or redistribute checks across the [testing pyramid](#testing-pyramid-and-level-selection).

- One `it` = one specification situation = one key observation.
- We choose observation at the contract level (HTTP status, response body, return value), not internal side effects, unless the team agreed otherwise.
- When you need to check several consequences of one rule, separate them into different `it`. Use `:aggregate_failures` only when really talking about one behavior (see point 23).

A test is a short statement about behavior, not a mini-program. The more precise the `it` formulation, the easier to read the specification as documentation.

```ruby
# bad
it "processes signup successfully" do
  expect { post_signup }.to change(User, :count).by(1)
  expect(ActionMailer::Base.deliveries.count).to eq(1)
end
```

```ruby
# good
it "creates new user account" do
  expect { post_signup }.to change(User, :count).by(1)
end

it "sends welcome email" do
  expect { post_signup }.to change { ActionMailer::Base.deliveries.count }.by(1)
end
```

What's wrong in the bad example:

- Two different behaviors are hidden in one `it`, so when it fails it's unclear which rule is violated.
- Information in RSpec report loses connection with behavior description, and the test stops being a specification.
- Information in RSpec report has to be analyzed, and you also have to look at the test to figure out what behavior was expected, due to missing description in the report.

Request spec example. We want to ensure authorization is successful, and choose observation at API level, not DB:

```ruby
# bad
it "creates a session" do
  post "/sessions", params: creds
  expect(Session.count).to eq 1
end
```

```ruby
# good
it "returns an access token" do
  post "/sessions", params: creds
  expect(response).to have_http_status(:created)
  expect(response.parsed_body.fetch("token")).to be_present
end
```

What's wrong in the bad example:

- Check accesses database directly and fixes controller implementation instead of public API contract.
- Such test failure only hints "record wasn't created", not that client received wrong response.

> Don't compare JSON entirely as string: see section 28 ("Make test failure output readable") — it shows how structural diff helps see discrepancy immediately.

If many `expect` appear in `it`, it's usually a signal: we're trying to fix side effects instead of behavior. Typical example — user registration and sending welcome email. In request-spec we check API status/response, and the fact of sending email we drop to unit/service test level (or return to the [pyramid](#testing-pyramid-and-level-selection) and write a separate scenario if email is an independent rule). Don't turn behavior specification into a small program: loops, conditional operators and calculations in tests are a direct sign we stopped describing rules and started rewriting implementation.

**Why not combining many expectations in one `it`:**

Although this speeds up tests (data created once, on first failure others are skipped), it leads to problems:

1. Less readable results and the test itself
2. Unclear which expectation corresponds to `it` description
3. Lack of isolation between expectations
4. **Main point:** it's a smell of bad code design — if test checks several different things, code does several different things, violating "Do One Thing" principle (Clean Code, Robert Martin)

If tests became "too smart", probably the tested code is too. Split code into simple parts, write unit tests for each, then a simple integration test for their composition.

#### 3.1. Exception for interface testing

When testing objects that provide a set of related attributes (see [Interface Testing](#interface-testing) in glossary), multiple expectations in one `it` with `:aggregate_failures` are acceptable and preferable, as they represent a single behavior: "object provides correct interface in given state".

**When interface testing is applicable:**

- Value objects with multiple attributes (Money, Address, Coordinate)
- Configuration objects (Settings, Config, Preferences)
- Read-only interfaces built from a single data source
- Presenter/Decorator objects providing derived attributes

**Rule of thumb:** If you're checking multiple attributes that are all derived from one source/state and don't include independent business effects, combine them in one `it` with `:aggregate_failures`.

For more on when `:aggregate_failures` is acceptable and what alternatives exist, see [rule 23](#23-use-aggregate_failures-only-when-describing-one-rule).

**Examples of good names for interface tests:**

- ✅ `'exposes product catalog interface'` — explicitly indicates interface check
- ✅ `'returns complete order summary'` — shows that full data set is checked
- ✅ `'builds user profile from session data'` — describes source and what's built
- ✅ `'provides shipping address details'` — clear description of provided interface

**Avoid:**

- ❌ `'works correctly'` — too general, doesn't describe what's checked
- ❌ `'returns correct values'` — unclear which values exactly
- ❌ `'has valid attributes'` — vague, doesn't indicate interface

```ruby
# bad: over-splitting interface into separate tests
describe ProductPresenter do
  let(:product) { create(:product, name: 'Laptop', price: 999.99, stock: 5, sku: 'LPT-001') }
  subject(:presenter) { described_class.new(product) }

  it('returns product name') { expect(presenter.display_name).to eq('Laptop') }
  it('returns formatted price') { expect(presenter.formatted_price).to eq('$999.99') }
  # ... 2 more checks for availability and SKU
end
```

```ruby
# good: interface testing with aggregate_failures
describe ProductPresenter do
  let(:product) { create(:product, name: 'Laptop', price: 999.99, stock: 5, sku: 'LPT-001') }
  subject(:presenter) { described_class.new(product) }

  it 'exposes product display interface', :aggregate_failures do
    expect(presenter.display_name).to eq('Laptop')
    expect(presenter.formatted_price).to eq('$999.99')
    # ... 2 more checks for availability and SKU
  end

  # Separate tests for independent behavior
  context 'when product is out of stock' do
    let(:product) { create(:product, stock: 0) }
    it('indicates unavailability') { expect(presenter.availability).to eq('Out of Stock') }
  end
end
```

What's wrong in the bad example:

- Four separate tests check parts of one interface that presenter provides based on one `product` object.
- When data source (product) changes, all four tests have to be updated, though they describe a single behavior.
- Each test name doesn't convey that all attributes are related and form a holistic presenter interface.

What the good example provides:

- One test with `:aggregate_failures` explicitly shows: "presenter provides complete display interface".
- All attributes are checked together because they're derived from one source and represent a single behavior.
- Separate context for `out of stock` checks independent behavior (availability logic change), not just another attribute.

**Important:** Don't confuse [interface testing](#interface-testing) with checking independent side effects. If each expectation describes an independent business rule (record creation + email sending), separate them into different `it` per main rule 3.

#### 3.2. Working with large interfaces

When an object provides 10+ attributes, a test with multiple `expect` becomes bulky and hard to maintain. Use appropriate tools depending on object type.

**See also:** [API Contract Testing](guide.api.en.md) — for HTTP API use specialized tools instead of multiple `expect`.

**For [domain](#domain) objects (value objects, presenters, config):**

Use `have_attributes` — it's more compact and readable than a list of separate `expect`.

```ruby
# bad: long list of expect
describe UserProfile do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  subject(:profile) { described_class.new(user) }

  it 'exposes user profile', :aggregate_failures do
    expect(profile.first_name).to eq('John')
    expect(profile.last_name).to eq('Doe')
    expect(profile.full_name).to eq('John Doe')
    # ... 7 more similar checks for email, phone, city, country, account_type, verified, created_at
  end
end

# good: compact via have_attributes
describe UserProfile do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  subject(:profile) { described_class.new(user) }

  it 'exposes user profile' do
    expect(profile).to have_attributes(
      first_name: 'John',
      last_name: 'Doe',
      full_name: 'John Doe'
      # ... other attributes: email, phone, city, country, account_type, verified
    )
  end
end
```

**Advantages of `have_attributes`:**

- Compact notation — entire check in one place
- Automatic `:aggregate_failures` — shows all mismatches at once
- Readable output on test failure

**For JSON API with large nested structures:**

When API response contains dozens of fields and nested objects, checking the entire structure inline becomes unreadable. Use **decomposition via `let`** to manage complexity.

```ruby
# bad: entire structure in one place — hard to read and maintain
describe 'GET /api/orders/:id' do
  let(:order) { create(:order) }

  it 'returns order with items and customer' do
    get "/api/orders/#{order.id}"

    expect(response.parsed_body).to eq({
      'id' => order.id,
      'status' => 'pending',
      'total' => 1049.99,
      'customer' => {
        'id' => order.customer.id,
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'shipping_address' => {
          'street' => '123 Main St',
          'city' => 'Springfield',
          'postal_code' => '12345',
          'country' => 'USA'
        },
        'billing_address' => {
          'street' => '456 Oak Ave',
          'city' => 'Springfield',
          'postal_code' => '12345',
          'country' => 'USA'
        }
      },
      'items' => [
        {
          'id' => order.items[0].id,
          'product_name' => 'Laptop',
          'quantity' => 1,
          'price' => 999.99,
          'subtotal' => 999.99
        },
        {
          'id' => order.items[1].id,
          'product_name' => 'Mouse',
          'quantity' => 2,
          'price' => 25.0,
          'subtotal' => 50.0
        }
        # ... 5 more items
      ],
      'created_at' => order.created_at.iso8601,
      'updated_at' => order.updated_at.iso8601,
      'metadata' => {
        'source' => 'web',
        'ip' => '192.168.1.1'
        # ... 10 more metadata fields
      }
    })
  end
end
```

```ruby
# good: decomposition via let — separating data and expectations
describe 'GET /api/orders/:id' do
  let(:order) { create(:order, customer: customer, items: [laptop_item, mouse_item]) }
  let(:customer) { create(:customer) }
  let(:laptop_item) { create(:order_item, product_name: 'Laptop', price: 999.99, quantity: 1) }
  let(:mouse_item) { create(:order_item, product_name: 'Mouse', price: 25.0, quantity: 2) }

  # Expectations separated from data and structured
  let(:expected_address) do
    {
      'street' => '123 Main St',
      'city' => 'Springfield',
      'postal_code' => '12345',
      'country' => 'USA'
    }
  end

  let(:expected_customer) do
    {
      'id' => customer.id,
      'name' => 'John Doe',
      'email' => 'john@example.com',
      'shipping_address' => expected_address,
      'billing_address' => expected_address
    }
  end

  let(:expected_items) do
    [
      {
        'id' => laptop_item.id,
        'product_name' => 'Laptop',
        'quantity' => 1,
        'price' => 999.99,
        'subtotal' => 999.99
      },
      {
        'id' => mouse_item.id,
        'product_name' => 'Mouse',
        'quantity' => 2,
        'price' => 25.0,
        'subtotal' => 50.0
      }
      # ... other items can be added similarly
    ]
  end

  let(:expected_response) do
    {
      'id' => order.id,
      'status' => 'pending',
      'total' => 1049.99,
      'customer' => expected_customer,
      'items' => expected_items,
      'created_at' => order.created_at.iso8601,
      'updated_at' => order.updated_at.iso8601
      # metadata can also be extracted to separate let if needed
    }
  end

  it 'returns complete order details' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body).to match(expected_response)
  end
end
```

**Advantages of decomposition:**

- Nested structure becomes flat and readable
- Separation of data (fixtures) and expectations — easier to understand what we're testing
- Easy to reuse parts (e.g., `expected_address` for shipping and billing)
- When structure changes, it's clear which block to update
- Hierarchy is preserved: `expected_response` → `expected_customer` → `expected_address`

**When to use decomposition via `let`:**

- Checking **behavior** — key fields important for business logic
- Medium complexity structure (5-20 fields with 2-3 nesting levels)
- Need flexibility for dynamic values (`order.id`, `customer.email`)

**When NOT to use:**

- Checking **API contract** — all fields, types, required fields, nesting
- Huge structure (50+ fields, deep nesting)
- Full schema fixation important for external consumers

**For fixing full API structure use specialized tools:**

- **JSON Schema validation** (thoughtbot/json_matchers) — structure and type validation
- **rspec-openapi** — automatic OpenAPI generation from Request specs
- **Snapshot testing** — fixing reference response

For details see ["API Contract Testing: RSpec Applicability Boundaries"](#api-contract-testing-rspec-applicability-boundaries) section.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- One `it` = one behavior → when test fails, it's immediately clear which rule is violated
- Unique descriptions → can find needed test by name without reading code
- Separating behaviors into different `it` → easy to change or remove one rule without touching others

**See also:**
- [Rule 1: Test behavior](#1-test-behavior-not-implementation) — what counts as behavior
- [Rule 23: `:aggregate_failures`](#23-use-aggregate_failures-only-when-describing-one-rule) — when checks can be combined
- [Section 3.1: Interface testing](#31-exception-for-interface-testing) — exceptions for interfaces

### 4. Identify behavior characteristics and their states

**[Characteristic](#characteristics-and-states)** — a domain aspect that affects the outcome of tested behavior (user role, payment method, order status).

**[Characteristic state](#characteristics-and-states)** — a specific variant of this characteristic important for the rule (subscription active, balance less than limit, status = shipped).

How to understand you found a characteristic:

- ask the question: "if I change this characteristic, will the example expectation change?";
- characteristic describes a business fact, not implementation (`user has subscription`, not `premium_flag`);
- characteristic is formulated as an entity with clarification (`user role`, `card balance`).

How to select states:

- list all variants that business distinguishes (role = admin / customer; status = draft / paid / cancelled);
- group numeric values into ranges that affect the decision (balance ≥ cost, balance < cost);
- express each state as a separate `context` with clear formulation.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Explicit characteristic identification → tests read as business rules, not technical checks
- Each state in its own `context` → no need to keep in mind "under what conditions does this work?"
- Characteristics formulated in [domain](#domain) language → developer and business speak the same language

**See also:**
- [Rule 5: Context hierarchy](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases) — how to build hierarchy from characteristics
- [Rule 9: Context differences](#9-each-context-should-reflect-the-difference-from-the-outer-scope) — each context adds a characteristic
- [Glossary: Characteristics and States](#characteristics-and-states) — term definitions

### 5. Build `context` hierarchy by characteristic dependencies (happy path → corner cases)

**Navigation within the rule:**
- [Basic hierarchies: dependent characteristics](#basic-hierarchies-dependent-characteristics)
- [Complex hierarchies: independent characteristics](#complex-hierarchies-independent-characteristics)

Characteristics can be:

- **basic** — without them others don't make sense (no card → no balance);
- **refining** — refine basic characteristic (card balance when card exists);
- **independent** — don't affect each other (user role and beta test flag).

Algorithm:

1. Write out characteristics and states.
2. Mark dependencies: characteristic B depends on A if its state is meaningful only at specific state of A.
3. Build hierarchy table.
4. For each branch create nested `context` from basic to refining, ordering states: first happy path (normal scenario), then corner cases (deviations).

#### Basic hierarchies: dependent characteristics

**Dependent characteristics (binary characteristic)**

| Characteristic | States we test | Depends on |
| --- | --- | --- |
| Card attachment | has card / has NO card | — |
| Card balance | balance ≥ price / balance < price | Card attachment (has card) |

```ruby
describe '#purchase' do
  context 'when user has a payment card' do               # happy path: card attached
    context 'and card balance covers the price' do        # happy path: balance sufficient
      it 'charges the card'
    end

    context 'but card balance does NOT cover the price' do # corner case: not enough money
      it 'rejects the purchase'
    end
  end

  context 'when user has NO payment card' do              # corner case: no card
    it 'rejects the purchase'
  end
end
```

> ```ruby
> # bad
> describe '#purchase' do
>   context 'but card balance does NOT cover the price' do
>     it 'rejects the purchase'
>   end
>
>   context 'when user has a payment card' do
>     context 'and card balance covers the price' do
>       it 'charges the card'
>     end
>   end
> end
> ```
>
> What's wrong:
>
> - Branch `but ...` is detached from basic `when user has a payment card`, so happy path and corner case swap places.
> - Reader has to keep dependency in mind that nesting previously showed: specification becomes hard to read.

#### Complex hierarchies: independent characteristics

**Independent characteristics (enum + binary characteristic)**

| Characteristic | States we test | Depends on |
| --- | --- | --- |
| User role | admin / customer | — |
| Beta access flag | enabled / disabled | — |

```ruby
describe '#feature_access' do
  context 'when user role is admin' do        # happy path: full access
    it('grants access to admin tools') { ... }

    context 'and beta feature is enabled' do  # happy path: bonus access
      it('grants access to beta tools') { ... }
    end

    context 'but beta feature is disabled' do # corner case for admin
      it('falls back to standard tools') { ... }
    end
  end

  context 'when user role is customer' do     # corner case: limited rights
    it('denies access to admin tools') { ... }

    context 'and beta feature is enabled' do  # corner case: partial mitigation
      it('grants access to beta tools') { ... }
    end

    context 'but beta feature is disabled' do # strictest corner case
      it('denies access to beta tools') { ... }
    end
  end
end
```

Order of independent characteristics can be changed (first flag, then role), but happy path should stay on top, and deviations should be grouped below at corresponding nesting level.

**Combining independent characteristics at integration level:**

According to the [testing pyramid](#testing-pyramid-and-level-selection), different test levels have different responsibilities:

- **Unit tests** (models, services) — check **all combinations** of characteristics in detail
- **Integration/Request specs** — check **happy path + critical corner cases**, combining many independent preconditions into a single context

**In Request specs apply the same hierarchy principles:**

```ruby
# bad: duplicating detailed testing of all combinations (this is unit tests' task)
describe 'POST /api/payments' do
  context 'when user is authenticated' do
    context 'when card is verified' do
      context 'when balance is sufficient' do
        it 'processes payment successfully'
      end

      context 'when balance is insufficient' do
        it 'rejects payment with insufficient funds error'
      end
    end

    context 'when card is not verified' do
      it 'rejects payment with verification error'
    end
  end

  context 'when user is not authenticated' do
    it 'returns 401 Unauthorized'
  end
end

# good: combining independent conditions within domain, preserving layer hierarchy
describe 'POST /api/payments' do
  context 'when user is authenticated' do
    context 'with valid payment prerequisites' do
      let(:user) { create(:user, :authenticated, :with_verified_card, :with_sufficient_balance) }

      it 'processes payment successfully' do
        post "/api/payments", params: { amount: 100 }
        expect(response).to have_http_status(:created)
      end
    end

    context 'when card is not verified' do
      let(:user) { create(:user, :authenticated, :with_unverified_card) }

      it 'returns 422 Unprocessable Entity' do
        post "/api/payments", params: { amount: 100 }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  context 'when user is not authenticated' do
    let(:user) { create(:user) }

    it 'returns 401 Unauthorized' do
      post "/api/payments", params: { amount: 100 }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

**Combination philosophy:**

**Combine details within one business [domain](#domain).** At integration level, many conditions related to one area of responsibility (verified card + sufficient balance = payment prerequisites) are combined into a single state. We check that API works in the normal case, not the combinatorics of all possible violations within the [domain](#domain).

**Combination marker:** if a separate unit test exists for the [domain](#domain) (e.g., `PaymentService`), then in request spec the details of this [domain](#domain) can be combined into a single context.

**Typical layer structure for an application:**

```ruby
context 'when user is authenticated' do          # Authentication layer
  context 'when user is authorized' do           # Authorization layer (role, subscription plan)
    context 'with valid domain prerequisites' do # Specific business domain
      # happy path
    end

    context 'when domain prerequisite violated' do
      # corner case within domain
    end
  end

  context 'when user is not authorized' do
    # corner case authorization layer
  end
end

context 'when user is not authenticated' do
  # corner case authentication layer
end
```

Each nesting level = transition to next [domain](#domain)/responsibility layer.

**Testing reverse cases:**

For corner cases, it's usually enough to check **one** critical scenario at each hierarchy level — not all possible violations. Reasons:

- All corner cases within [domain](#domain) are handled **similarly** (e.g., return validation error in HTTP response the same way)
- Only **content** changes (error text), not system behavior
- Checking all combinations = **duplicating unit tests** at integration level
- This doesn't add reliability, only slows tests, creates duplication and complicates maintenance and test changes as system evolves

Detailed testing of all boundary conditions and their combinations stays at lower [pyramid](#testing-pyramid-and-level-selection) levels in unit tests.

**Otherwise apply the same principles:** characteristic dependency hierarchy, happy path before corner cases.

**See also:**
- [Testing Pyramid](#testing-pyramid-and-level-selection) — responsibility separation by levels
- [Rule 26: Request specs](#26-prefer-request-specs-over-controller-specs) — what to check at HTTP contract level

**When nesting becomes too deep:**

If context hierarchy goes deeper than 3-4 levels, this is **almost always a signal of [Do One Thing](#design-principles) principle violation** in tested code. The problem is not in tests — the problem is in code design.

**Typical causes of deep nesting:**

1. **Mixing abstraction levels** — method simultaneously works with business logic and low-level details
   - *Solution:* Extract low-level logic into separate methods/services
   - *Example:* Data parsing → separate method, validation → separate method, saving → separate method

2. **Multiple responsibility** — method solves several independent tasks
   - *Solution:* Split into several methods, each doing one thing
   - *Example:* `process_payment` + `update_order_status` + `update_inventory` instead of one giant method

3. **Unclear layer boundaries** — high-level logic combined with low-level implementation
   - *Solution:* Clearly separate layers (controller → service → repository)
   - *Example:* Controller shouldn't know about SQL query details

**Practical rule:** If testing a method requires 5+ `context` levels, it's a signal to refactor **code**, not complicate tests. Tests honestly show the method tries to do too much.

**In tests you can temporarily:**
- Use `shared_examples` for repeating checks (reduces visible duplication)
- Split into several `describe` blocks for independent aspects

**But the right solution:** Code refactoring according to Do One Thing.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Context hierarchy visualizes characteristic dependencies — no need to keep conditions in mind
- Happy path on top → reader immediately understands main scenario without digging into deviations
- Symmetrical structure (all characteristic states at same level) simplifies navigation: "where's test for case X?" → "at same level as Y and Z"
- When adding new state, it's immediately clear where to place it — structure is self-documenting

**See also:**
- [Rule 4: Identify characteristics](#4-identify-behavior-characteristics-and-their-states) — how to define characteristics
- [Rule 6: Final context audit](#6-final-context-audit-two-types-of-duplicates) — checking for duplicates
- [Rule 7: Happy path before corner cases](#7-place-happy-path-before-corner-cases) — placement order
- [Rule 10: Specify subject](#10-specify-subject-to-explicitly-designate-what-is-being-tested) — explicit `subject` combined with clear context hierarchy makes test maximally readable

### 6. Final context audit: two types of duplicates

**Navigation within the rule:**
- [6.1. `let`/`before` duplicates reveal missing states](#61-letbefore-duplicates-reveal-missing-states)
- [6.2. `it` duplicates with identical expectations reveal invariant contracts](#62-it-duplicates-with-identical-expectations-reveal-invariant-contracts)

Every time you finish working on tests, ensure that `describe/context` structure really corresponds to [characteristics](#characteristic) and their [states](#state) from glossary (see point 5). Final audit includes two types of checks: `let`/`before` duplicates reveal missing characteristic states, and `it` duplicates with identical expectations reveal invariant interface contracts.

#### 6.1. `let`/`before` duplicates reveal missing states

Repeating `let` or `before` at the same level is an alarm signal: some state isn't extracted into explicit context, and a test for it is easy to lose.

Checklist after writing:

- Go through each nesting level and write out all `let`/`before`. If neighboring branches repeat identical values, the characteristic needs to be lifted higher or extracted into separate context.
- Try lifting common `let` one level up. If tests break after this, you discovered hidden state—add a context and example for it.
- Cross-check structure with initial list of characteristics and their states. If some state never appeared anywhere, scenario for it is missing.
- Look at `before` blocks. Repeating data preparation is a frequent sign you left only happy path and forgot about alternative context branch.

```ruby
# bad: duplicating let in each context
describe Billing::DiscountEvaluator do
  subject(:discount) { described_class.call(order) }

  let(:order) { build(:order, segment: segment, loyalty_status: loyalty_status) }

  context 'when segment is b2c' do
    let(:segment) { :b2c }

    context 'with gold loyalty' do
      let(:loyalty_status) { :gold }

      it 'returns 0.15' do
        expect(discount).to eq(0.15)
      end
    end

    context 'with silver loyalty' do
      let(:loyalty_status) { :silver }

      it 'returns 0.10' do
        expect(discount).to eq(0.10)
      end
    end

    context 'with no loyalty' do
      let(:loyalty_status) { :none }

      it 'returns 0' do
        expect(discount).to eq(0)
      end
    end
  end

  context 'when segment is b2b' do
    let(:segment) { :b2b }

    context 'with gold loyalty' do
      let(:loyalty_status) { :gold }

      it 'returns 0.12' do
        expect(discount).to eq(0.12)
      end
    end

    context 'with silver loyalty' do
      let(:loyalty_status) { :silver }

      it 'returns 0.05' do
        expect(discount).to eq(0.05)
      end
    end

    context 'with no loyalty' do
      let(:loyalty_status) { :none }

      it 'returns 0' do
        expect(discount).to eq(0)
      end
    end
  end
end
```

```ruby
# good
describe Billing::DiscountEvaluator do
  subject(:discount) { described_class.call(order) }

  let(:order) { build(:order, segment: segment, currency: currency, loyalty_status: loyalty_status) }

  context 'when segment is b2c' do
    let(:segment) { :b2c }

    context 'with USD currency' do
      let(:currency) { :usd }

      context 'and loyalty is gold' do
        let(:loyalty_status) { :gold }
        it('returns 0.15') { ... }
      end

      context 'and loyalty is silver' do
        let(:loyalty_status) { :silver }
        it('returns 0.10') { ... }
      end
    end
  end

  context 'when segment is b2b' do
    let(:segment) { :b2b }

    context 'with USD currency' do
      let(:currency) { :usd }

      context 'and loyalty is gold' do
        let(:loyalty_status) { :gold }
        it('returns 0.11') { ... }
      end

      context 'and loyalty is silver' do
        let(:loyalty_status) { :silver }
        it('returns 0.06') { ... }
      end
    end

    context 'with EUR currency' do
      let(:currency) { :eur }

      context 'and loyalty is gold' do
        let(:loyalty_status) { :gold }
        it('returns 0.12') { ... }
      end

      context 'and loyalty is silver' do
        let(:loyalty_status) { :silver }
        it('returns 0.05') { ... }
      end
    end
  end
end
```

What's wrong in the bad example:

- By description everything looks like correct hierarchy from point 4, but `currency` in each branch is set manually, meaning characteristic factually "lives" not where it's described.
- For state `currency: :usd` in segment `:b2b` example is missing—defect will pass by because tests read as complete specification.

Now:

- Currency takes its place in hierarchy, `let` duplicates disappeared, and structure repeats real characteristic dependencies (see point 5).
- Each combination `segment → currency → loyalty_status` from domain model has an example, and separate corner case fixes negative behavior.
- Context formulations form readable sentences, and happy path stands above corner case (see point 7), so scenarios read quickly.
- When new state appears, checklist will work automatically: you'll either add context or notice that returning to common `let` breaks the test.

#### 6.2. `it` duplicates with identical expectations reveal invariant contracts

After building symmetrical context tree (point 5) and eliminating `let`/`before` duplicates (point 6.1), review all leaf contexts. If several `it` repeat with identical expectations in all or most leaf contexts—these are interface invariants: rules that don't depend on characteristic states and should always hold.

Checklist after writing:

1. Review all leaf contexts and write out all `it`.
2. Find expectations that repeat verbatim or with minimal variations.
3. If expectation is present in all leaf contexts, regardless of characteristics—it's an interface invariant.
4. Extract invariant expectations into `shared_examples` and connect them via `it_behaves_like` (see point 25.2).

For example see point 22.2—class `BookingSearchValidator`, where checks `respond_to(:valid?)`, `respond_to(:errors)`, `respond_to(:normalized_params)` repeated in all four leaf contexts regardless of `client_type` and `region`. These are interface invariants that were extracted into `shared_examples 'a booking search validator'`.

Such final pass forces keeping tests at behavioral contract level, not a set of random happy paths.

### 7. Place happy path before corner cases

Within each `describe`, reader expects to see normal behavior first, then exceptions.

```ruby
# bad
describe '#enroll' do
  context 'when enrollment is rejected because email is invalid' do
    it('shows a validation error') { ... }
  end

  context 'when enrollment is rejected because plan is sold out' do
    it('puts the user on the waitlist') { ... }
  end

  context 'when enrollment is accepted' do # happy path lost at bottom
    it('activates the membership') { ... }
  end
end
```

```ruby
# good
describe '#enroll' do
  context 'when enrollment is accepted' do
    it('activates the membership') { ... }
  end

  context 'when enrollment is rejected because email is invalid' do
    it('shows a validation error') { ... }
  end

  context 'when enrollment is rejected because plan is sold out' do
    it('puts the user on the waitlist') { ... }
  end
end
```

What's wrong in the bad example:

- Happy path is hidden at bottom of branch, causing reader to spend more time understanding normal behavior.
- When new corner cases appear, order will mix even more, and RSpec report will stop reading top to bottom.

Instruction: when adding new examples, check that happy path blocks remain first at their nesting level. Corner cases should be below and either start with `but`/`without`, or explicitly describe deviation.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Happy path on top → reader immediately understands main system operation scenario
- Predictable order (success → deviations) → no need to jump around file searching "how should it work normally?"
- RSpec report reads top to bottom as a story: first norm, then exceptions

**See also:**
- [Rule 5: Context hierarchy](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases) — dependent characteristics
- [Rule 8: Positive and negative tests](#8-write-positive-and-negative-tests) — check both cases

### 8. Write positive and negative tests

Each context branch describes a specific combination of characteristic states. For these combinations we need at minimum one example confirming behavior and one example showing refusal—this way we protect from regressions in both directions.

```ruby
# bad
describe "#some_action" do
  # ... basic characteristic setup: user, role, blocking date
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  context "when user is blocked by admin" do # positive context for `blocked` characteristic state
    # ... setting state `blocked = true`
    let(:blocked) { true }

    context "and blocking duration is over a month" do # positive context for `blocked_at` characteristic state
      # ... setting refining characteristic `blocked_at`
      let(:blocked_at) { 2.month.ago }

      it "allows unlocking the user" do
        expect(some_action).to be(true) # positive test for combination of `blocked`, `blocked_at` characteristic states
      end
    end
  end
end
```

```ruby
# good
describe "#some_action" do
  # ... basic characteristic setup: user, role, blocking date
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }

  context "when user is blocked by admin" do # positive context for `blocked` characteristic state
    # ... setting `blocked` characteristic state
    let(:blocked) { true }

    # Level 2 context for `blocked_at` characteristic state
    context "and blocking duration is over a month" do # positive context for `blocked_at` characteristic state
      # ... refining characteristic `blocked_at` state
      let(:blocked_at) { 2.month.ago }
      it("allows unlocking the user") { ... }
    end

    context "but blocking duration is under a month" do # negative context for `blocked_at` characteristic state
      # ... refining characteristic `blocked_at` state
      let(:blocked_at) { 1.month.ago }
      it("does NOT allow unlocking the user") { ... }
    end
  end

  context "when user is NOT blocked by admin" do # negative context for `blocked` characteristic state
    # ... setting `blocked` characteristic state
    let(:blocked) { false }
    it("does NOT allow unlocking the user") { ... }
  end
end
```

What's wrong in the bad example:

- Characteristic `blocked` is checked only on positive state—protection from reverse scenario is absent.
- Refining context doesn't show alternative `blocked_at` state, so negative test for state combination is missing.
If only positive tests are present, such tests can't be relied upon later,
because they won't reflect behavior regression fact during future code changes,
since they won't check the reverse case.

### 9. Each context should reflect the difference from the outer scope

Can also say it this way: if you have a context where between `context "..." do` and `it` is empty, it's purely
syntactic context. It's either not needed at all or doesn't contain setup corresponding to context description.

Rule can be formulated differently: setup that makes context true should be right after the `context "..." do` line.
Don't make reader search throughout entire test where exactly context is prepared for described state.

```ruby
# There are users and a some_action method that determines if user can be unlocked.
# Users have states `blocked`, `blocked_at`.
```

```ruby
# very bad
describe "#some_action" do
  let(:user) { build :user }
  let(:blocked_user) { build :user, blocked: true }
  let(:old_blocked_user) { build :user, blocked: true, blocked_at: 2.month.ago }

  it "does NOT allow unlocking the user" do
    expect(user.some_action).to be(false)
  end

  context "when user is blocked by admin" do # there's context
    # no setup that makes it different from outer block
    it "allows unlocking the user" do
      expect(blocked_user.some_action).to be(true)
    end

    context "and blocking duration is over a month" do
      # What distinguishes this context from outer? In large test finding setup will be impossible.
      # Save your and others' effort—place block that prepares context right under declaration: that's where it's expected.
      it "allows unlocking the user" do
        expect(old_blocked_user.some_action).to be(true)
      end
    end
  end
end
```

```ruby
# good
describe "#some_action" do
  let(:blocked) { false } # base state of `blocked` characteristic
  let(:blocked_at) { nil } # base state of `blocked_at` characteristic
  let(:user) { build :user, blocked: blocked, blocked_at: blocked_at }
  subject(:result) { user.some_action }

  it "does NOT allow unlocking the user" do
    expect(result).to be(false)
  end

  context "when user is blocked by admin" do
    let(:blocked) { true } # this context setup—in its place, immediately noticeable

    context "and blocking duration is over a month" do
      let(:blocked_at) { 2.month.ago } # nested context setup—right here, under declaration

      it "allows unlocking the user" do
        expect(result).to be(true)
      end
    end

    context "but blocking duration is under a month" do
      let(:blocked_at) { 1.month.ago } # negative state of `blocked_at` characteristic

      it "does NOT allow unlocking the user" do
        expect(result).to be(false)
      end
    end
  end
end
```

What's wrong in the bad example:

- Context `when user is blocked by admin` doesn't set distinguishing conditions—`let` setup is far away and doesn't read together with description.
- Inner `context` doesn't prepare `blocked_at`, so it's hard to understand which characteristic state is checked.

Additionally, required state can be set by calculation—for example, located inside `before`.

## Syntax and Readability

Good test style is not only behavior, but also obviousness of what you're reading: explicit `subject`, predictable constructs and minimal eye searching.

### 10. Specify `subject` to explicitly designate what is being tested

When `subject` is explicitly declared, reader immediately sees what exactly is checked and doesn't spend time searching for test object in expectations.

`subject` is especially useful:

- When same result is checked in multiple `it` within different contexts
- When action requires preparation or method call with parameters
- When need to name checked result via named `subject(:result)`

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Explicit `subject` → immediately see what's tested, no need to search for object in each `expect`
- Named `subject(:result)` → descriptive name replaces repeating method calls
- Test structure becomes predictable → less time for understanding

**See also:** [Rule 5: Context hierarchy](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases) — explicit `subject` is especially useful combined with clear context hierarchy by characteristics

## Context and Data Preparation

Smooth tests are built on repeatable setup: clear Given/When/Then phases, factories that hide routine, and explicit dependencies. This section gathers environment preparation practices before checks.

### 11. Each test should be divided into 3 phases in strict order

`let` and `let!` prepare data that makes context true (Given), `before` brings system to needed state or invokes action (When), and expectations inside `it` fix result (Then). Don't mix these roles.

1. Data preparation for context (usually via `let` or factories)
2. Transferring data to needed state/invoking action (more often `before`, sometimes directly in `it`)
3. Result expectation (Then)

```ruby
# very bad
describe "#block" do
  before do
    user = create :user
    admin = create :admin
    admin.block(user)
  end

  it "true" do
    expect(User.find(1).blocked).to be(true)
  end
end
```

```ruby
# good
describe "#block" do
  # Phase 1: data preparation
  let(:user) { create :user }
  let(:admin) { create :admin }

  # Phase 2: action
  before { admin.block(user) }

  # Phase 3: result check
  it "marks the user as blocked" do
    expect(user.blocked).to be(true)
  end
end
```

Variant with action inside example:

```ruby
# okay
describe "#block" do
  # Phase 1
  let(:user) { create :user }
  let(:admin) { create :admin }

  it "marks the user as blocked" do
    # Phase 2
    admin.block(user)

    # Phase 3
    expect(user.blocked).to be(true)
  end
end
```

What's wrong in the bad example:

- Given/When/Then phases are mixed inside `before`, so it's unclear where preparation ends and check begins.
- Test accesses `User.find(1)` instead of context preparation via `let`, so example depends on global state.

Even if action is performed directly in `it`, keep structure explicit and return calculations to `before` when possible.

- `let` is lazy: value calculated on first access. If context state should appear before `it` execution, use `before` or `let!` to explicitly fix order and not violate rule 8 phases.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Predictable structure (Given → When → Then) → reader knows where to look for preparation, action, check
- No need to "execute code mentally" to understand execution order
- When changing test, immediately clear which section to add code to

## FactoryBot and Data Preparation

FactoryBot helps describe [characteristics](#characteristic) of [domain](#domain) objects through traits and parameterized hashes, so we use it so tests speak about [behavior](#behavior), not technical attributes.

### 12. Use FactoryBot capabilities to hide test data details

If project has FactoryBot, use it so tests remain readable and fix only [characteristics](#characteristic) and their [states](#state).

- Default factory should create "average" object suitable for happy path. Everything not participating in context description, hide inside factory.
- In repeating scenarios, arrange states through traits: `:blocked`, `:with_verified_email`, `:expired`. Traits can be freely combined (`create(:user, :blocked, :verified)`), getting needed states without copy-paste. Context doesn't need to list auxiliary fields, enough to mention characteristic.
- Avoid manually passing dozens of attributes to `create`. If many explicit values required, perhaps factory should be refined or new characteristic extracted.

```ruby
# bad
describe '#unlock' do
  let(:user) do
    create(:user,
           blocked: true,
           blocked_at: 2.months.ago,
           email_confirmed: true
           # ... 2 more attributes: last_sign_in_at, otp_required
    )
  end

  it 'allows unlocking the user' do
    expect(UserUnlocker.call(user)).to be_allowed
  end
end
```

```ruby
# good
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'secret123' }

    trait :blocked do
      blocked { true }
      blocked_at { 2.months.ago }
    end

    trait :verified do
      email_confirmed { true }
    end
  end
end

describe '#unlock' do
  let(:user) { create(:user, :blocked, :verified) }

  it 'allows unlocking the user' do
    expect(UserUnlocker.call(user)).to be_allowed
  end
end
```

- Traits document characteristic states and eliminate bulky setup blocks.
- Reader sees only important characteristics (`:blocked`, `:verified`) and quickly relates them to context description.
- Default attribute changes happen in factory, so tests don't "clutter" with technical data details.
- What's wrong in the bad example: factory is used as `create` with all attributes, so test doesn't show which states are important; any auxiliary field change requires changing test, not factory.

Such discipline makes tests cleaner, easier to maintain and better emphasizes business behavior.

Additionally: good overview of trait techniques from Thoughtbot — [Remove duplication with FactoryBot's traits](https://thoughtbot.com/blog/remove-duplication-with-factorybots-traits).

### 13. Use `attributes_for` to generate parameters that are not important details in behavior testing

When testing behavior, often the fact of action execution matters (order creation, profile update), not specific values of most attributes. `attributes_for` allows generating valid parameter hash from factory, avoiding duplication between factory and test.

**Key principle:** Use `attributes_for` when specific attribute values aren't important for understanding tested behavior. If attribute is critical for test—override it explicitly.

**Using attributes_for:**

**Main use case: Request specs**

Request specs are the most frequent place to apply `attributes_for`, since API endpoints accept parameter hashes.

```ruby
# bad
describe 'POST /api/orders' do
  let(:order_params) do
    {
      customer_email: 'user@example.com',
      total: 150.0
      # ... 2 more fields: currency, status
    }
  end

  before { post '/api/orders', params: order_params }

  it('creates new order') { expect(response).to have_http_status(:created) }
  it('returns order id') { expect(response.parsed_body['id']).to be_present }
end
```

```ruby
# good
describe 'POST /api/orders' do
  let(:order_params) { attributes_for(:order) }
  before { post '/api/orders', params: order_params }

  it('creates new order') { expect(response).to have_http_status(:created) }
  it('returns order id') { expect(response.parsed_body['id']).to be_present }
end
```

**What's wrong in the bad example:**

- Values `customer_email`, `total`, `currency`, `status` aren't important for understanding test "API creates order"
- Duplication: same attributes already defined in `factory :order`
- Reader forced to analyze each attribute though they don't affect tested behavior
- When default values change in factory, need to change test too

**Now:**

- Reader immediately sees: "standard order parameters used"
- No need to analyze insignificant details
- No duplication between factory and test
- Default value changes in factory automatically apply to test

**Overriding critical attributes**

If specific attribute value is **important for tested behavior**, override it explicitly:

```ruby
# good: explicitly show we're testing b2b segment
describe 'POST /api/orders' do
  let(:order_params) { attributes_for(:order, segment: 'b2b', discount: 0.15) }
  before { post '/api/orders', params: order_params }

  it('applies b2b pricing') { expect(Order.last.pricing_tier).to eq('corporate') }
  it('applies 15% discount') { expect(Order.last.final_total).to eq(order_params[:total] * 0.85) }
end
```

Here `segment: 'b2b'` and `discount: 0.15` are critical behavior details, so they're explicitly overridden.

**Combining with traits**

```ruby
# good: trait documents state
describe 'POST /api/orders' do
  let(:order_params) { attributes_for(:order, :international, :with_insurance) }

  before { post '/api/orders', params: order_params }

  it('includes customs declaration') { expect(Order.last.customs_required?).to be true }
end
```

Traits `:international` and `:with_insurance` clearly show order characteristics without need to list dozens of attributes.

**Other use cases**

`attributes_for` is useful everywhere code works with parameter hashes:

**Form Objects:**

```ruby
describe OrderForm do
  let(:form_params) { attributes_for(:order) }
  let(:form) { described_class.new(form_params) }

  it('validates successfully') { expect(form).to be_valid }
end
```

**Service Objects:**

```ruby
describe OrderCreationService do
  let(:order_params) { attributes_for(:order) }

  it('creates order record') { expect { described_class.call(order_params) }.to change(Order, :count).by(1) }
end
```

**When NOT to use `attributes_for`**

❌ **DO NOT USE when:**

**API interface differs from model interface** — request parameters have different names or structure:

```ruby
# bad: attributes_for returns model attributes, but API expects different names
describe 'POST /api/orders' do
  let(:order_params) { attributes_for(:order) }
  # factory returns: { customer_email: '...', total_cents: 15000 }
  # but API expects:  { email: '...', amount: 150.0 }

  before { post '/api/orders', params: order_params }

  it('creates new order') { expect(response).to have_http_status(:created) } # will fail: wrong parameters
end
```

```ruby
# good: explicitly form parameters according to API contract
describe 'POST /api/orders' do
  let(:order_params) do
    {
      email: 'user@example.com',      # API uses 'email', model uses 'customer_email'
      amount: 150.0                    # API uses 'amount' in rubles, model uses 'total_cents'
    }
  end

  before { post '/api/orders', params: order_params }

  it('creates new order') { expect(response).to have_http_status(:created) }
  it('maps API params to model attributes') { expect(Order.last).to have_attributes(...) }
end
```

**Golden rule:** If to understand test reader must open factory—critical parameters are better written explicitly in test. Use `attributes_for` to reduce duplication, but not at expense of readability.

**See also:** [Rule 14: build_stubbed in unit tests](#14-in-unit-tests-except-models-use-build_stubbed) — for tests where objects needed (not parameter hashes), use `build_stubbed`

### 14. In unit tests (except models) use `build_stubbed`

Unit specs of services, policies, presenters and form objects shouldn't depend on database. `build_stubbed` creates ActiveRecord object without `INSERT`/`UPDATE`, but with filled `id`, `created_at`, `updated_at` and `save` prohibition. This makes tests faster and emphasizes that code works with ready context, not building database integration.

- `build_stubbed` eliminates unnecessary round-trips to DB and speeds up unit test suite.
- Object can't be accidentally saved: if code tries to call `save`/`reload`, test will fail and show you're crossing level boundary (meaning integration test needed).
- Stubbed instances are more convenient to substitute in doubles: they have `id`, pre-filled attributes and disabled callbacks, so test remains predictable.

When not to use `build_stubbed`:

- model or scope test where need to check real DB interaction;
- code that relies on callbacks/triggers or reads changes after `save`;
- feature where validation/uniqueness/foreign key are checked by DB itself (then use `create`).

```ruby
# bad
describe Orders::PriceCalculator do
  let(:order) { create(:order, items_count: 3, total_cents: 100_00) }
  let(:discount) { create(:discount, percent: 10) }

  it 'applies discount to order total' do
    result = described_class.new(order, discount).calculate
    expect(result).to eq(90_00)
  end
end
```

```ruby
# good
describe Orders::PriceCalculator do
  let(:order) { build_stubbed(:order, items_count: 3, total_cents: 100_00) }
  let(:discount) { build_stubbed(:discount, percent: 10) }

  it 'applies discount to order total' do
    result = described_class.new(order, discount).calculate
    expect(result).to eq(90_00)
  end
end
```

What's wrong in the bad example:

- `create` performs database write for data that service only uses; tests slow down unnecessarily.
- If implementation calls `save`/`reload`, test won't see it because object already lives in DB—we're unknowingly checking integration scenario.

What the good example provides:

- `build_stubbed` creates full object without DB access, so unit specs run faster and stay isolated.
- Attempt to save object from tested code will end with error, signaling scenario crossed level boundary and integration test needed.

If test unexpectedly requires `save` or DB reading, you're testing higher level behavior—move example to integration layer or change data preparation strategy.

**See also:** [Rule 13: attributes_for for parameters](#13-use-attributes_for-to-generate-parameters-that-are-not-important-details-in-behavior-testing) — when parameter hashes needed (not objects), use `attributes_for`

**How FactoryBot reduces cognitive load:**
- **Traits** — trait name describes model [state](#state) (`:blocked`, `:verified`) → reader sees [characteristic](#characteristic) without diving into implementation details
- **Technical details** hidden in factory → no need to keep in mind "why are all these fields here?"
- **attributes_for** focuses on tested [behavior](#behavior) → no need to analyze insignificant parameters
- **build_stubbed** explicitly signals "this is unit test" → isolation level immediately clear
- **[Characteristic](#characteristic) centralization** → all technical implementation details of characteristic are in factory, changes require edits in one place, not dozens of tests
- **Default attribute changes** don't break tests → less mental load during refactoring

**What this says about code design:**

If factories become complex—it's a signal about [Single Responsibility](#design-principles) and [Tight Coupling](#design-principles) violations:

- Dozens of required attributes in factory → [God Object](#design-principles) (model does too much)
- Complex callbacks and field dependencies → business logic leaked into ActiveRecord model, should be in services
- Constantly requires `create`, can't use `build_stubbed` → code too dependent on persistence
- Need to create many related objects → [tight coupling](#design-principles), model depends on too many details

**Solution:** Model should be simple data structure. Extract business logic to services, reduce coupling via Dependency Injection.

### Choosing FactoryBot Method: Decision Tree

After studying rules 12-14, here's the final FactoryBot method selection scheme:

```
┌─────────────────────────────────────────────────────────────┐
│ Do you need an object to check behavior?                    │
└─────────────┬───────────────────────────────────────────────┘
              │
              ├─── NO (only parameters for API/controller)
              │    └─→ attributes_for(:user)
              │       # Returns { name: "...", email: "..." }
              │
              └─── YES (need object)
                   │
                   ├─── Should object be saved in DB?
                   │    │
                   │    ├─── YES (need persistence, associations, callbacks)
                   │    │    │
                   │    │    ├─── Need related objects?
                   │    │    │    ├─── YES → create(:order, :with_items)
                   │    │    │    │         # Use traits
                   │    │    │    │
                   │    │    │    └─── NO → create(:user)
                   │    │    │              # Simple creation
                   │    │    │
                   │    │    └─→ Always create() when DB needed
                   │    │
                   │    └─── NO (only in memory, DB not needed)
                   │         │
                   │         ├─── Testing this object's BEHAVIOR?
                   │         │    (validations, model methods, business logic)
                   │         │    │
                   │         │    └─→ build(:user)
                   │         │        # new_record? = true
                   │         │        # Validations work correctly
                   │         │
                   │         └─── Object needed only as DATA?
                   │              (passing to other service/method)
                   │              │
                   │              └─→ build_stubbed(:user)
                   │                  # Faster, id stubbed
                   │                  # persisted? = true
```

### 15. Don't program in tests

Test is behavior specification, not place for writing mini-frameworks. When instead of declarative `let`, factories and helper methods, private utilities with direct DB work appear, test stops being readable and reliable.

```ruby
# terrible
describe SomeService do
  it 'stores report' do
    result = described_class.call(raw_payload)

    expect(result).to be_success
    expect(find_report(result.id)).to have_attributes(status: 'done', rows: 3)
  end

  private

  def raw_payload
    DB[:reports].insert(name: 'daily', data: '{"rows":[1,2,3]}')
    DB[:reports].where(name: 'daily').first
  end

  def find_report(id)
    DB[:reports].where(id: id).first
  end
end
```

```ruby
# good
describe SomeService do
  let(:report) { create(:report, :daily, :with_rows) }
  subject(:result) { described_class.call(report.payload) }

  it 'stores report' do
    expect(result).to be_success
    expect(report.reload).to have_attributes(status: 'done', rows_count: 3)
  end
end
```

What's wrong in the bad example:

- Private methods hide how states are set: reader needs to "execute" code mentally to understand characteristics.
- Direct DB work bypasses factories/fixtures and creates hard binding to schema.
- When table structure changes, tests break silently or give unreadable errors.
- If such style seems convenient, it's alarm signal: such writing gravitates toward assert-style-DSL like minitest. In RSpec we describe behavior, not rewrite test framework code.

What the good example provides:

- `let` with factory explicitly describes characteristic (`report` with status and data), not SQL workarounds.
- When schema changes, adapt factory—tests remain declarative and follow characteristic glossary.

This rule closely relates to points 1, 7 and 8: we describe behavior, check both rule sides and keep context preparation near its description.

**What this says about code design:**

If tests require complex preparation (direct DB work, private helpers, workarounds)—it's signal about [encapsulation](#design-principles) and [leaky abstraction](#design-principles) violations:

- Can't create object via public API → creation logic too complex or hidden
- Need to know DB schema details for test data → [domain](#domain) layer not isolated from persistence
- Private helpers to bypass public API → possibly [God Object](#design-principles) (too many responsibilities)
- Direct DB work in service layer tests → layer boundaries violated

**Solution:** Object should be easy to create via public API (factories, constructors). If workarounds needed—refactor code, separate responsibilities.

### 16. Explicitness over DRY

In BDD tests it's important to immediately see WHAT is checked. Readability and specification clarity are more important than eliminating code duplication. If extracting method or variable makes test less obvious—leave duplication.

Tests are system behavior documentation. When reader opens spec file, they should immediately understand context and tested behavior, without jumping through auxiliary method definitions.

Of course, this doesn't mean rejecting `let`, factories or shared contexts—they actually help declaratively describe characteristics. But if abstraction hides important check detail, better write explicitly.

**Important:** This point requires choosing golden mean. One can always debate where boundary lies between useful abstraction and excessive explicitness. There's no universal rule—decision depends on context, [domain](#domain) complexity and team agreements.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- **Unified RSpec DSL** — everyone knows this testing language, no need to learn new "dialect" each time
- **Programming in tests** creates own mini-language → team has to learn custom API of each spec file
- **Ecosystem integration** — RSpec DSL gives clear output on failure, custom code produces vague errors
- **Syntax consistency** — `let`, factories, matchers work predictably, private methods with DB logic violate expectations

## Specification Language

Rules from this section directly reduce [cognitive load](#why-we-write-tests-this-way-cognitive-load) when reading and maintaining tests. When specification descriptions form understandable sentences in natural language, tests turn into readable documentation: developer immediately understands what behavior is checked without diving into implementation details.

**How this works:**
- Understandable language reduces extraneous load—no need to spend mental effort deciphering abbreviations, technical terms or unclear formulations
- Readable descriptions free resources for understanding business rules (germane load)
- Unified formulation style creates predictability—familiar structure allows finding needed tests faster
- When failed test reads as a sentence, it's immediately clear which rule is violated

**See also:** [Cognitive Load](#why-we-write-tests-this-way-cognitive-load)

### 17. Description of contexts `context` and test cases `it` together (including `it`) should form a valid sentence in English

Write specification descriptions (`describe`/`context`/`it`) in English: this way RSpec reports remain readable in CI, and team uses unified behavior description language.
For example, we'll leave only test descriptions, without example of creating test data and context changes.

```ruby
# atrocious
describe "#some_action" do
  context "blocked" do # what's blocked, when, by whom? what does this even mean?
    context "month ago" do # month ago what? blocked? exactly?
      it("true") { test } # what does true mean? how is it evaluated?
    end
  end
end
# when you run the test it returns this incomprehensible description
# #some_action user blocked month ago /it/ true
```

```ruby
# perfect
describe "#some_action" do
  context "when user is blocked by admin" do # here it's clear who did what and to whom
    context "and blocking duration is over a month" do # and here it's clear this continues the sentence started in previous context
      it("allows unlocking the user") { test } # aha, now it's completely clear why this method is needed, what's its value
      # it determines "can the user be unlocked?"
    end
  end
end
# #some_action when user is blocked by admin and blocking duration is over a month /it/ allows unlocking the user
```

What's wrong in the bad example:

- Contexts don't form a complete sentence: unclear who's blocked and what `month ago` means.
- Description `it("true")` doesn't tell about behavior, so RSpec report carries no meaning.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Sentence reads naturally → no need to mentally reconstruct meaning from fragmentary words
- RSpec report immediately shows which business rule is violated—no need to open code
- With many tests, understandable names work as table of contents—quickly find what you need

### 18. Description of contexts `context` and test cases `it` together (including `it`) should be written so that anyone understands

This means behavior description should be absolutely unambiguous and require no specific programming knowledge.
You should be able to simply give all test descriptions to any person, so they in turn can read them and understand the business.

```ruby
when user is blocked by admin and blocking duration is over a month /it/ allows unlocking the user
when user is blocked by admin but blocking duration is under a month /it/ does NOT allow unlocking the user
```

quite understandable description that clearly shows you can't unblock user who was blocked less than a month ago.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Descriptions without technical jargon are understandable to all team members—not only developers, but also business analysts
- Managers and product owners can read test reports as specification → team speaks same language
- New developers understand [domain](#domain) faster by reading tests as business rules documentation
- When test fails, its description immediately explains what broke in business terms, without needing to know code

### 19. Grammar of describe/context/it formulations

We describe stable system behavior, so formulations should sound like domain rules, not instructions to tester.

1. **Present Simple.** Behavior is always considered correct, so we talk about it in present tense: `it 'returns the summary'`. Present simple tense makes phrase universal and removes sense of temporariness.
2. **Active voice in `it`, third person.** Subject of sentence is system object. Use action verbs for behavior: `order generates invoice`, `service authenticates user`. For resulting state use state verbs: `order has parent`, `result is valid`, `record belongs to user`. This way reader understands what's being tested, and sentence stays short.
3. **Passive voice and state verbs for contexts.** Context sets characteristic state, so we use form `is/are + V3` or short constructions with static verb: `when user is blocked`, `when account has balance`. This way we fix state fact, not action that led to it.
4. **Zero conditional for context and result link.** In `context/it` pair both parts stay in Present Simple: `when payment is confirmed, it issues receipt`. Such structure reads as business rule "if … then …" without time shifts.
5. **Without modal verbs and extra words.** Avoid `should`, `can`, `must` and introductory constructions (`it should`, `it is expected that`). What remains is behavior declaration—it's shorter and fits better in reports.
6. **Explicit negation `NOT`.** Highlight negative scenarios with caps: in contexts—`when user is NOT verified`, in examples—`it 'does NOT unlock user'`. This way in report it's immediately visible that negative case fails.

Minimal template: describe object and characteristic in `describe`, context—through `context` in passive voice, expected reaction—through `it` in active Present Simple.

```ruby
describe OrderMailer do
  context 'when invoice is generated' do
    it 'sends the invoice email'
  end
end
```

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Unified grammar creates predictability—familiar structure allows reading tests like formulas
- Present Simple turns test into [domain](#domain) rule declaration, not description of step sequence
- Active voice in `it` makes action subject obvious—no need to mentally flip sentence
- Absence of modal verbs (`should`, `can`) makes formulation shorter and removes uncertainty
- `NOT` in caps immediately highlights negative scenarios—in long report you see what exactly failed

### 20. Context language: when / with / and / without / but / NOT

Follow Gherkin logic so branch reads as sequence of context clarifications. Each conjunction responds to state type and nesting level.

- **`when …`** — opens branch and describes base characteristic state. At this level often no `it` because branch clarifies further. Example: `context 'when user has a payment card' do … end`.
- **`with …`** — introduces first clarifying positive state and continues happy path: `context 'with verified email'`.
- **`and …`** — adds another positive state in same direction. Can use several in a row while branch remains part of happy path: `context 'and balance covers the price'`.
- **`without …`** — use for binary characteristics when explicitly showing both polarities. Happy path described by positive state, so `without …` branch immediately contains test demonstrating alternative outcome: `context 'without verified email' do … end`.
- **`but …`** — emphasizes happy path contrast. Often applied when happy path based on default state (separate `with` context not needed). Context `but …` must contain test showing how behavior changes when base context stops holding: `context 'but balance does NOT cover the price'`.
- **`NOT`** — use in caps inside context or `it` name to emphasize binary characteristic negative state or highlight negative test: `context 'when user does NOT have a payment card'`, `it 'does NOT charge the card'`.
- If `when`/`with`/`and`/`without`/`but` appears in `it` description, you lost corresponding context. Extract this state into `context`, otherwise example will mix Given and Then and violate rules 1–7. Exception—negative formulations with `does NOT`, where `NOT` emphasizes result, not context.

Recommended sequence within branch: `when` → `with` → `and` (as needed) → `but`/`without` → `it`. As soon as context fully prepared, add example: happy path or corner case.

```ruby
describe '#charge' do
  context 'when user has a payment card' do                      # base characteristic
    context 'with verified email' do                            # happy path clarification
      context 'and balance covers the price' do                 # another happy path state
        it 'charges the card'                                   # happy path case
      end

      context 'but balance does NOT cover the price' do         # corner case: contrast
        it 'does NOT charge the card'                           # negative test
      end
    end

    context 'without verified email' do                         # corner case: required state absence
      it 'does NOT charge the card'
    end
  end

  context 'when user does NOT have a payment card' do           # another branch for binary characteristic
    it 'does NOT charge the card'
  end
end
```

Make sure happy path branch goes first at its level, and contexts with `without`/`but` logically reference it: "when everything's good → what happens; but if base context breaks → how result changes".

Sometimes happy path builds on default value, and additional `with` context not needed—example can be placed directly under `when`. Corner case still unfolds via `but` or `without` at same level.

```ruby
describe '#authenticate' do
  context 'when account exists' do                        # base branch
    it 'signs the user in'                                # happy path directly under when

    context 'but account is blocked' do                   # corner case at same level
      it 'denies the sign-in'
    end
  end

  context 'when account does NOT exist' do                # contrast at context level
    it 'denies the sign-in'
  end
end
```

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- Unified conjunction system (`when`/`with`/`and`/`but`/`without`) creates test grammar—reader predicts structure
- Sequence "base characteristic → clarification → contrast" corresponds to [domain](#domain) reasoning logic
- Happy path goes first → first understand norm, then corner cases become obvious deviations
- Prohibition of `when`/`with` in `it` means context always explicitly isolated—no need to keep conditions in mind
- Gherkin logic (Given → When → Then) distributed across hierarchy levels, not mixed in one place

### 21. Study Rubocop rules on naming in detail <https://rspec.rubystyle.guide/#naming>

## Tools and Test Support

### 22. Don't use [any_instance](https://rspec.info/features/3-13/rspec-mocks/old-syntax/any-instance/), allow_any_instance_of, expect_any_instance_of

In most cases this is a "smell" that you're not following `dependency inversion principle`,
or that your class doesn't follow `single responsibility` and combines code for two actors
that in turn depend on each other unidirectionally.
Thus, your class can be split into two smaller classes, for which in turn you can cover their behavior in separate tests.
To be fair, following this rule is not very easy when you've accumulated giant technical debt, so this rule may have exceptions.

For more on why not to use it, read here <https://rspec.info/features/3-13/rspec-mocks/working-with-legacy-code/any-instance/>.

```ruby
# bad: allow_any_instance_of globally mocks all instances
describe HighLevelClass do
   before do
      allow_any_instance_of(LowLevelClass).to receive(:foo).and_return({some_key: :some_value})
   end

   it "returns the processed value" do
      expect(HighLevelClass.new.some_method).to eq(:some_expected_value)
   end
end

# good: dependency injection via constructor
describe HighLevelClass do
   let(:low_level_dependency) { instance_double(LowLevelClass) }
   subject(:instance) { described_class.new(low_level_dependency) }

   before do
      allow(low_level_dependency).to receive(:foo).and_return({some_key: :some_value})
      # now we simply allow returning needed value to one instance double
      # and there will be check that such method really exists in this class
   end

   it "returns the processed value" do
      expect(instance.some_method).to eq(:some_expected_value)
   end
end
```

What's wrong in the bad example:

- `allow_any_instance_of` globally substitutes method `foo` and affects all class instances, causing test to stop being isolated.
- Class doesn't accept dependency explicitly, so have to punch mock through global setting instead of injecting it via constructor.

**What this says about code design:**

If you need `any_instance_of`—it's **always** signal about [Dependency Injection](#design-principles) and [Tight Coupling](#design-principles) violation:

- Class creates dependencies inside itself (`SomeClass.new` in method) instead of accepting them via constructor
- Class depends on concrete implementations, not abstractions → Dependency Inversion (SOLID) violation
- Can't test class in isolation—can't pass mock via constructor
- Class tightly coupled with dependency implementation details

**Solution:** Use [Dependency Injection](#design-principles)—pass dependencies via constructor. If need `any_instance_of`, problem is in code—refactor.

### 23. Use `:aggregate_failures` only when describing one rule

**Navigation within the rule:**
- [Practical problem: incomplete context when debugging](#practical-problem-incomplete-context-when-debugging)
- [Usage guide](#usage-guide)
- [Decision guide: one `it` or multiple?](#decision-guide-one-it-or-multiple)
- [Testing patterns: before/after](#testing-patterns-beforeafter)

By default one `it` contains one check. `:aggregate_failures` is useful when we're talking about one behavior and want to see all violations at once, instead of fixing only first failed expectation.

**Key principle:** Use `:aggregate_failures` only if all expectations describe the same business outcome and depend on one set of prepared context states. Don't apply flag to hide different behaviors in one `it`—this violates rule 3.

**Note:** For HTTP API more appropriate tools exist than multiple `expect`. See [API Contract Testing](guide.api.en.md).

#### Practical problem: incomplete context when debugging

**Why `:aggregate_failures` is needed**

Without `:aggregate_failures` RSpec stops at first failed expectation. This creates expensive debugging cycle, especially in following scenarios:

**Scenario 1: [Flaky tests](#characteristics-and-states) that fail only in CI**

Imagine: you have API endpoint test that sometimes fails only in CI environment (timing issues, race conditions, database peculiarities). Can't reproduce locally, and each CI debugging iteration takes 10-15 minutes.

```ruby
# without aggregate_failures
it 'returns order details' do
  get "/api/orders/#{order.id}"

  expect(response).to have_http_status(:ok)           # ✅ passed
  expect(response.content_type).to match(/json/)      # ✅ passed
  expect(response.parsed_body['id']).to eq(order.id)  # ❌ FAILURE: nil instead of order.id
  # Test stops here. You don't know about other fields
  expect(response.parsed_body['status']).to eq('pending')
  expect(response.parsed_body['total']).to eq(150.0)
  expect(response.parsed_body['customer_email']).to be_present
end
```

**What happens:**

1. CI fails: "expected order.id, got nil"
2. Seeing only one error, you assume: "probably problem with ID in route". Fix `order.id` retrieval logic, push, wait 15 minutes
3. CI fails again: "expected 'pending', got nil"—turns out `status` is also `nil`. Now think: "maybe problem in scope for status?"
4. Fix scope, push, wait another 15 minutes
5. CI fails: "expected 150.0, got nil"—and `total` is also broken. Finally understand: entire serializer doesn't work!
6. **Total: 45+ minutes wasted + 2 wrong fixes due to incomplete context**

**Incomplete context problem:** Seeing only first failure, you don't understand problem scale. Instead of immediately seeing "entire `parsed_body` empty → serializer broken", you solve local problems (`id`, then `status`, then `total`) that are actually symptoms of one global cause. Incomplete context leads to wrong diagnosis and inefficient fixes. As they say, knowledge is power.

```ruby
# with aggregate_failures
it 'returns order details', :aggregate_failures do
  get "/api/orders/#{order.id}"

  expect(response).to have_http_status(:ok)
  expect(response.content_type).to match(/json/)
  expect(response.parsed_body['id']).to eq(order.id)
  expect(response.parsed_body['status']).to eq('pending')
  expect(response.parsed_body['total']).to eq(150.0)
  expect(response.parsed_body['customer_email']).to be_present
end
```

**Output with aggregate_failures shows EVERYTHING at once:**

```ruby
Failures:

  1) GET /api/orders/:id returns order details
     Got 4 failures:

     1.1) Failure/Error: expect(response.parsed_body['id']).to eq(order.id)
            expected: 123
                 got: nil

     1.2) Failure/Error: expect(response.parsed_body['status']).to eq('pending')
            expected: "pending"
                 got: nil

     1.3) Failure/Error: expect(response.parsed_body['total']).to eq(150.0)
            expected: 150.0
                 got: nil

     1.4) Failure/Error: expect(response.parsed_body['customer_email']).to be_present
            expected present value
                 got: nil
```

You **immediately see** problem is global—serializer doesn't work at all, `parsed_body` empty. Fix in one go, push, wait 15 minutes—done. **Savings: 30+ minutes.**

**Scenario 2: Tests that can't run locally**

Sometimes tests depend on environment difficult to set up locally:

- Integration with external service (staging environment)
- Specific infrastructure (Kubernetes, special network settings)
- Access to certain data or credentials only available in CI

In such cases each test run is commit + push + CI wait. If test checks 6 object attributes and all broken, without `:aggregate_failures` you'll make 6 iterations instead of one.

Similar problem arises with long integration tests, though these are rare.

**Rule:** If test checks attributes of one result (object, HTTP response, calculation result) and you can't quickly iterate (CI-only, [flaky](#characteristics-and-states)), use `:aggregate_failures`. This saves team time and nerves.

#### Usage guide

**When to use `:aggregate_failures`**

✅ **USE when:**

1. **Checking attributes of one created/retrieved object**—attributes derived from one source and form holistic interface (see rule 2.1 [Interface Testing](#interface-testing)):

   ```ruby
   # okay: aggregate_failures shows all mismatches at once
   it 'exposes user profile attributes', :aggregate_failures do
     expect(profile.full_name).to eq('John Doe')
     expect(profile.email).to eq('john@example.com')
     expect(profile.account_type).to eq('premium')
   end

   # perfect: have_attributes gives same effect + more compact
   it 'exposes user profile attributes' do
     expect(profile).to have_attributes(
       full_name: 'John Doe',
       email: 'john@example.com',
       account_type: 'premium'
     )
   end
   ```

   **Prefer `have_attributes`** when checking object attributes—it automatically shows all mismatches and makes code more readable (see rule 3.1).

2. **Testing object interface/contract in given state**—all checks relate to unified representation:

   ```ruby
   # okay
   it 'provides shipping address details', :aggregate_failures do
     expect(address.street).to eq('123 Main St')
     expect(address.city).to eq('Springfield')
     expect(address.postal_code).to eq('12345')
     expect(address.country).to eq('USA')
   end

   # perfect
   it 'provides shipping address details' do
     expect(address).to have_attributes(
       street: '123 Main St',
       city: 'Springfield',
       postal_code: '12345',
       country: 'USA'
     )
   end
   ```

3. **Checking HTTP response structure**—status, headers and main body fields as unified contract:

   ```ruby
   it 'returns successful response with order data', :aggregate_failures do
     post '/orders', params: order_params
     expect(response).to have_http_status(:created)
     expect(response.content_type).to match(/json/)
     expect(response.parsed_body).to include('id', 'status', 'total')
   end
   ```

4. **Checking related values derived from one source**—calculated or derived attributes:

   ```ruby
   it 'calculates order totals correctly', :aggregate_failures do
     expect(order.subtotal).to eq(100.0)
     expect(order.tax).to eq(8.0)
     expect(order.total).to eq(108.0)
   end
   ```

❌ **DO NOT USE when:**

1. **Testing different behaviors**—each action causes independent business effect:

   ```ruby
   # bad: two independent behaviors
   it 'creates order and sends confirmation', :aggregate_failures do
     expect { place_order }.to change(Order, :count).by(1)
     expect { place_order }.to have_enqueued_job(OrderConfirmationJob)
   end

   # good: separated into individual tests
   it 'creates an order' do
     expect { place_order }.to change(Order, :count).by(1)
   end

   it 'enqueues confirmation email' do
     expect { place_order }.to have_enqueued_job(OrderConfirmationJob)
   end
   ```

2. **Testing different actors**—each actor represents separate rule:

   ```ruby
   # bad: two actors with different logic
   it 'hides notifications', :aggregate_failures do
     expect(admin_notifications).to be_hidden
     expect(user_notifications).not_to be_hidden
   end

   # good: separate contexts for each actor
   context 'for admin' do
     it 'hides admin notifications' do
       expect(admin_notifications).to be_hidden
     end
   end

   context 'for regular user' do
     it 'does NOT hide user notifications' do
       expect(user_notifications).not_to be_hidden
     end
   end
   ```

#### Additional recommendations

- **Keep description specific:** Even with flag, `it` name should clearly indicate what's checked. Avoid general formulations (`'works correctly'`, `'returns data'`).
- **Limit number of expectations:** If test has more than 10-15 expectations, perhaps you're checking too much—consider splitting into several tests or extracting part of logic.
- **Context preparation doesn't justify mixing behaviors:** Even if setup expensive, better optimize factories or extract common context to `before` than hide independent rules in one `it`.

#### Decision guide: one `it` or multiple?

When unclear whether to combine checks in one test or separate into multiple, use these control questions:

#### 1. "Can these checks be described in one sentence for non-technical person?"

**If NO** (need different sentences) → Separate into individual `it`.

Example: "System creates order" and "system sends confirmation"—need two sentences, these are two different actions from business perspective.

**If YES** (one sentence describes everything) → Consider one `it` with `:aggregate_failures`.

Example: "User profile contains name, email and account type"—one sentence describes unified profile data representation.

#### 2. "Does each expectation test independent code execution path?"

**If YES** → Separate into individual `it`.

Example: Checking record creation (`expect { ... }.to change(Order, :count)`) and checking email sending (`expect { ... }.to have_enqueued_job`) execute different logic branches.

**If NO** → One `it` with `:aggregate_failures`.

Example: All presenter attributes calculated from one `product` object—no branching, only data transformation.

#### 3. "Am I checking different parts of public interface?"

**If YES, different parts** → Separate into individual `it`.

Example: `#create_order` and `#send_confirmation`—these are different methods, each representing separate behavior.

**If NO, one interface** → One `it` with `:aggregate_failures`.

Example: All checks relate to attributes of one `#summary` method—this is unified object interface in given state.

#### Application examples

**Question 1: Can this be described in one sentence?**

"Creates order" + "Sends email" → NO, need two different sentences → Separate

```ruby
# bad
it 'processes order', :aggregate_failures do
  expect { place_order }.to change(Order, :count).by(1)
  expect { place_order }.to have_enqueued_job(OrderConfirmationJob)
end
```

```ruby
# good
it 'creates an order' do
  expect { place_order }.to change(Order, :count).by(1)
end

it 'enqueues confirmation email' do
  expect { place_order }.to have_enqueued_job(OrderConfirmationJob)
end
```

**But if it's interface:**

"Product provides its catalog interface (name + price + availability)" → YES, one sentence describes everything → Combine

```ruby
# okay
it 'exposes catalog interface', :aggregate_failures do
  expect(product.name).to eq('Laptop')
  expect(product.price).to eq(999.99)
  expect(product.availability).to eq('In Stock')
end
```

```ruby
# perfect
it 'exposes catalog interface' do
  expect(product).to have_attributes(
    name: 'Laptop',
    price: 999.99,
    availability: 'In Stock'
  )
end
```

**Golden rule:** If in doubt—separate. Better to have more precise tests than one ambiguous.

#### Testing patterns: before/after

This section shows typical anti-patterns and their correct versions.

[Continuing with examples 1-3 from the pattern section, translated similarly...]

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):**
- See all violations at once → full problem context, correct diagnosis first time
- Save debugging cycles (especially in CI) → less frustration and context switching
- `:aggregate_failures` flag explicitly signals "this checks one rule with multiple aspects"

**See also:** [Rule 2: Verify what test tests](#2-verify-what-the-test-actually-tests)—use `:aggregate_failures` when checking test for Red to immediately see all violations

### 24. Prefer verifying doubles (`instance_double`, `class_double`, `object_double`)

`double` creates "anonymous" double without interface check. It allows mocking non-existent methods and missing regression when contract changes. `instance_double`, `class_double` and `object_double` check real object interfaces and protect from false green tests.

```ruby
# bad
let(:gateway) { double('PaymentGateway', charge: true) }

it 'charges the card' do
  service = Checkout.new(gateway: gateway)
  service.call(order)
  expect(gateway).to have_received(:charge).with(order.total_cents)
end
```

```ruby
# good
let(:gateway) { instance_double(PaymentGateway, charge: true) }

it 'charges the card' do
  service = Checkout.new(gateway: gateway)
  service.call(order)
  expect(gateway).to have_received(:charge).with(order.total_cents)
end
```

What's wrong in the bad example:

- `double` accepts any methods, so typo or interface change go unnoticed.
- Test stays green even when contract doesn't match real `PaymentGateway`, and regression reaches production.

- `instance_double(SomeClass)` checks `SomeClass` instance methods.
- `class_double(SomeClass)`—class methods themselves (e.g., `.find`, `.call`).
- `object_double(existing_object)`—fixes specific object interface (convenient for dependencies built in test).

**When verifying double can't be used:**

- Class or module created dynamically and not yet loaded when test executes (`require` missing).
- Interface formed via `method_missing`/`respond_to_missing?`, and specification has no signatures to check (e.g., `OpenStruct`, `Hashie::Mash`).
- You're mocking external service without Ruby class (SOAP/XML API), and emulation happens via `Struct.new` or on-the-fly wrapper.

In these rare situations:

- Document reason (`let(:gateway) { double('LegacyGateway') } # no real class, method set at runtime`).
- Limit contract with explicit `allow(...).to receive(:method)` and add integration test that checks real interaction.

In all other cases choose verifying doubles—it's cheap way to catch typo before running application.

### 25. Use shared examples to declare contracts

**Navigation within the rule:**
- [25.1. For common behavior of different objects](#251-for-common-behavior-of-different-objects)
- [25.2. For invariant expectations within one test](#252-for-invariant-expectations-within-one-test)

`shared_examples` serve to declare contracts—expectations that repeat in different places. They're not about DRY for reducing code lines—we don't "program" tests (see point 15), they describe rules. If expectation repeats, extract exactly its description and observable consequences.

Two usage scenarios for shared examples exist:

#### 25.1. For common behavior of different objects

When several classes implement one contract (e.g., include common module), use shared examples to check common behavior.

- Name `shared_examples` through behavior using formula: **`'a/an + [adjective] + noun [+ clarification]'`**. Examples: `'an enumerable resource'`, `'a pageable API'`, `'a collection of orders'`. This way RSpec output shows which rule is described.
  - Correctness check: substitute in sentence **"it behaves like [your_name]"**. If sounds like natural English sentence—name fits.
  - Exception: abstract nouns can be used without article (`'sortability'`, `'enumerability'`).
- Apply `it_behaves_like`/`it_should_behave_like` where object really implements contract: for example, class includes module with common methods (`Enumerable`, your `Paginatable` mixin).
- Inside shared examples work only with public interface, expecting same behavior that separate test would check.

```ruby
# shared_examples: spec/support/shared_examples/paginatable.rb
RSpec.shared_examples 'a pageable API' do
  it('returns the second page') { expect(resource.paginate(page: 2).current_page).to eq 2 }
  it('limits page size') { expect(resource.paginate(page: 1, per_page: 5).items.count).to eq 5 }
end

# usage
describe OrdersQuery do
  subject(:resource) { described_class.new(scope: Order.all) }

  it_behaves_like 'a pageable API'
end

describe UsersQuery do
  subject(:resource) { described_class.new(scope: User.active) }

  it_behaves_like 'a pageable API'
end
```

- Shared example formulates "what it means to be pageable", without ridiculous "general behaviour".
- Each class including `Paginatable` module connects shared example and proves contract is fulfilled.
- If need to add new characteristic (e.g., sorting), expand shared example—all clients automatically check updated contract.

#### 25.2. For invariant expectations within one test

When you check object with multiple characteristics and discover expectations that repeat in all leaf contexts (regardless of characteristic states)—these are interface invariants. They should always hold, regardless of input data.

- Invariant expectations are identified during final audit stage (see point 6.2).
- Extract repeating `it` into `shared_examples` and connect them in root `describe` or in each leaf context via `it_behaves_like`.
- Name through contract: `'valid booking search params'`, `'serializable to JSON'`, `'responds to required methods'`.

Example: class `BookingSearchValidator` checks hotel search parameters. Regardless of client type (b2c/b2b) and search region (domestic/international), it should always return structure with fields `valid?`, `errors`, `normalized_params`.

```ruby
# bad: repeating it in all leaf contexts
describe BookingSearchValidator do
  subject(:validator) { described_class.new(params, client_type: client_type, region: region) }

  context 'when client is b2c' do
    let(:client_type) { :b2c }

    context 'and region is domestic' do
      let(:region) { :domestic }
      let(:params) { ... } # domestic search parameters

      it('validates check_in date') { expect(validator.valid?).to be true }
      # ... same three it 'responds to' for valid?, errors, normalized_params
    end

    context 'and region is international' do
      let(:region) { :international }
      let(:params) { ... } # international search parameters

      it('validates international booking rules') { expect(validator.valid?).to be true }
      # ... same three it 'responds to' for valid?, errors, normalized_params
    end
  end

  context 'when client is b2b' do
    let(:client_type) { :b2b }

    context 'and region is domestic' do
      let(:region) { :domestic }
      let(:params) { ... } # domestic search parameters

      it('applies b2b pricing rules') { expect(validator.normalized_params[:pricing_tier]).to eq('corporate') }
      # ... same three it 'responds to' for valid?, errors, normalized_params
    end

    context 'and region is international' do
      let(:region) { :international }
      let(:params) { ... } # international search parameters

      it('applies international b2b rules') { expect(validator.normalized_params[:requires_passport]).to be true }
      # ... same three it 'responds to' for valid?, errors, normalized_params
    end
  end
end
```

```ruby
# good: invariant extracted to shared_examples
RSpec.shared_examples 'a booking search validator' do
  it('responds to valid?') { expect(validator).to respond_to(:valid?) }
  it('responds to errors') { expect(validator).to respond_to(:errors) }
  it('responds to normalized_params') { expect(validator).to respond_to(:normalized_params) }
end

describe BookingSearchValidator do
  subject(:validator) { described_class.new(params, client_type: client_type, region: region) }

  context 'when client is b2c' do
    let(:client_type) { :b2c }

    context 'and region is domestic' do
      let(:region) { :domestic }
      let(:params) { { check_in: '2025-11-01', check_out: '2025-11-03', guests: 2 } }

      it_behaves_like 'a booking search validator'

      it 'validates check_in date' do
        expect(validator.valid?).to be true
      end
    end

    context 'and region is international' do
      let(:region) { :international }
      let(:params) { { check_in: '2025-12-01', check_out: '2025-12-05', guests: 1 } }

      it_behaves_like 'a booking search validator'

      it 'validates international booking rules' do
        expect(validator.valid?).to be true
      end
    end
  end

  context 'when client is b2b' do
    let(:client_type) { :b2b }

    context 'and region is domestic' do
      let(:region) { :domestic }
      let(:params) { { check_in: '2025-11-10', check_out: '2025-11-15', guests: 5 } }

      it_behaves_like 'a booking search validator'

      it 'applies b2b pricing rules' do
        expect(validator.normalized_params[:pricing_tier]).to eq('corporate')
      end
    end

    context 'and region is international' do
      let(:region) { :international }
      let(:params) { { check_in: '2026-01-01', check_out: '2026-01-10', guests: 3 } }

      it_behaves_like 'a booking search validator'

      it 'applies international b2b rules' do
        expect(validator.normalized_params[:requires_passport]).to be true
      end
    end
  end
end
```

- Three `respond_to` checks repeated in all four leaf contexts—this is interface invariant.
- Shared example `'a booking search validator'` declares mandatory validation result contract.
- Each leaf context now contains only checks specific to its characteristics (b2c/b2b, domestic/international).
- When adding new method to validator interface (e.g., `warnings`), enough to expand shared example, and all contexts automatically check new contract.

Using shared examples doesn't cancel requirement to write meaningful contexts and `it`. They help avoid contract duplication but don't substitute understandable specifications.

### 26. Prefer Request specs over controller specs

Controller specs are considered deprecated: Rails core and RSpec core teams officially recommend writing Request specs, starting with RSpec 3.5 and Rails 5.0 release ([details](https://rspec.info/blog/2016/07/rspec-3-5-has-been-released/#rails-support-for-rails-5)). Request specs check HTTP contract, meaning they stay closer to observable behavior and don't depend on internal controller filters.

- For new tests choose Request specs; only they cover Rack → controller → middleware stack entirely and show what client will see.
- If have to maintain legacy controller specs, mark them as legacy (e.g., `describe SomeController, :legacy`) and plan migration. When making improvements, expand by [pyramid](#testing-pyramid-and-level-selection): behavior—in Request spec, small logic extract to service/model and cover with units.
- Don't duplicate checks: if action already described at Request spec level, controller spec only repeats implementation and will break during route or filter refactoring.

### 27. Stabilize time with `ActiveSupport::Testing::TimeHelpers`

Rails provides module [`ActiveSupport::Testing::TimeHelpers`](https://api.rubyonrails.org/v5.2.3/classes/ActiveSupport/Testing/TimeHelpers.html) that should be included in tests instead of manual time management. Its key methods (`freeze_time`, `travel_to`, `travel`, `travel_back`) freeze `Time.zone` and clear delayed jobs, helping avoid flaky tests.

- If calling `freeze_time` or `travel_to` without block (e.g., in `before`), must add `after { travel_back }`. These methods automatically roll back time only in block form (`freeze_time { example.run }`, `travel_to(time) { ... }`), where module calls `travel_back` in `ensure`. Manual `Time.now` change without rollback leaves global state and leads to floating failures.
- In Rails tests rely on `Time.zone.now`/`Time.current` and methods `5.minutes`/`2.days` so calculations account for application time zone. `Time.now` and `Date.today` ignore zone—easier to get inconsistency with `created_at`.
- When working with ActiveJob/ActionMailer don't forget `freeze_time` fixes timers. If example runs job with `wait_until`, return time in `after`, otherwise subsequent tests will wait for "past".

In sum: "froze—rolled back". Any deviation leads to random, hard to reproduce bugs.

### 28. Make test failure output readable

Before fixing example, imagine it failed: text team will see should instantly explain expected and actual behavior. If have to read dozens of lines of scattered output, test requires rework.

**How this reduces [cognitive load](#why-we-write-tests-this-way-cognitive-load):** Properly selected matchers and test structure create output that immediately shows problem essence—no need to spend time deciphering what went wrong.

```ruby
# bad
it 'returns response payload' do
  expect(response.body).to eq(
    "{\"meta\":{\"status\":\"ok\",\"total\":3},\"data\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"},{\"id\":3,\"name\":\"Carol\"}],\"errors\":[]}"
  )
end

# expected output on failure:
# expected: "{\"meta\":{\"status\":\"ok\",\"total\":3},\"data\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"},{\"id\":3,\"name\":\"Carol\"}],\"errors\":[]}"
#      got: "{\"meta\":{\"status\":\"ok\",\"total\":2},\"data\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":3,\"name\":\"Carol\"}],\"errors\":[\"missing Bob\"]}"
# (Compared using ==)
#
# Here two multi-line strings without formatting; to notice discrepancy, need to manually search for differences in quotes.
```

```ruby
# good
describe 'GET /users' do
  subject(:payload) { JSON.parse(response.body, symbolize_names: true) }

  it 'returns metadata and users' do
    expect(payload.fetch(:meta)).to include(status: 'ok', total: 3)
    expect(payload.fetch(:data)).to match_array([
      include(id: 1, name: 'Alice'),
      include(id: 2, name: 'Bob'),
      include(id: 3, name: 'Carol')
    ])
    expect(payload.fetch(:errors)).to be_empty
  end
end

# Failure will show structural diff, e.g.:
# expected collection contained: [{:id=>1, :name=>"Alice"}, {:id=>2, :name=>"Bob"}, {:id=>3, :name=>"Carol"}]
# actual collection contained:   [{:id=>1, :name=>"Alice"}, {:id=>3, :name=>"Carol"}]
# the missing elements were:     [{:id=>2, :name=>"Bob"}]
# the extra elements were:       []
# => visible that user Bob is missing and meta-information violated.
```

What's wrong in the bad example:

- String comparison hides response structure, and finding differences turns into manual diff by eye.
- Error message doesn't explain discrepancy meaning—need to parse JSON yourself.

**How to improve output readability:**

- Use structural expectations (`match_array`, `include`, `have_attributes`) so RSpec shows subject diff.
- Format complex data before comparison (`JSON.parse`, `hash.deep_symbolize_keys`). Raw strings or SQL dumps in failure are almost useless.
- If matcher doesn't give sufficient clarity, write helper that returns compact discrepancy description (but don't turn into mini-program—see [rule 15](#15-dont-program-in-tests)).

**See also:** [Rule 23](#23-use-aggregate_failures-only-when-describing-one-rule)—aggregate_failures helps see all problems at once, improving debugging readability.

## API Contract Testing: RSpec Applicability Boundaries

Detailed breakdown moved to separate document `guide.api.en.md` to keep main guide compact.

- Use RSpec Request specs for behavior: HTTP statuses, key fields and side effects.
- For JSON response structure connect specialized tools (JSON Schema, rswag, Pact)—they publish contracts and don't break when implementation changes.
- Don't try storing contract in dozens of `expect`: keep it in one place, and in RSpec check only observable rules.

[Complete guide with anti-patterns, tools and practical pipeline →](./guide.api.en.md)

## Migrating Legacy Tests

If you have existing test suite that doesn't follow this guide's rules, here are strategies for gradual improvement without complete rewrite.

### Migration from Implementation-Focused to Behavior-Focused Tests

**Problem:** Tests check internal implementation (method calls, internal states) instead of observable behavior.

**Gradual migration strategy:**

1. **Don't rewrite everything at once**—start with files that change most often or break most frequently
2. **With each code change:**
   - Find tests checking `receive`, `allow`, internal private methods
   - Ask: "What observable behavior does this test check?"
   - Rewrite check via public interface and expected result
3. **Mark legacy tests:** Use RSpec metadata capabilities—add custom tag (e.g., `:legacy`) to old tests to track migration progress
4. **Measure progress:** Periodically check number of tests with `:legacy` tag

**Refactoring example:**

```ruby
# before: checking implementation
it 'calls notification service' do
  expect(NotificationService).to receive(:send_email).with(user.email)
  subject.process_order(order)
end

# after: checking behavior
it 'sends confirmation email to user' do
  expect { subject.process_order(order) }
    .to change { ActionMailer::Base.deliveries.count }.by(1)

  email = ActionMailer::Base.deliveries.last
  expect(email.to).to include(user.email)
  expect(email.subject).to include('Order Confirmation')
end
```

### Refactoring Deep Context Hierarchies

**Problem:** Contexts nested 5+ levels deep, hard to read and understand dependencies.

**Strategy:**

1. **Identify characteristics:**
   - Write out all conditions from nested `context`
   - Determine which are real [characteristics](#characteristic) and which are technical details
2. **Simplify conditions via combination:**
   - Combine independent conditions into one state (see [valid combination methods](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases))
   - Separate dependent characteristics by happy path vs corner cases principle
3. **Use shared_examples for repeating checks:**
   - If same behavior checked in different context branches, extract to `shared_examples`
4. **Refactor code if tests show problem:**
   - Deep nesting often signals method does too much ([Do One Thing](#design-principles))
   - Consider extracting logic to separate methods/services (see [Rule 5](#5-build-context-hierarchy-by-characteristic-dependencies-happy-path-before-corner-cases))

**Example:**

```ruby
# before: 6 nesting levels
describe '#process_payment' do
  context 'when user is authenticated' do
    context 'when user has payment card' do
      context 'when card is verified' do
        context 'when balance is sufficient' do
          context 'when transaction is not duplicate' do
            context 'when fraud check passes' do
              it 'processes payment' # lost in conditions
            end
          end
        end
      end
    end
  end
end

# after: split into logical groups
describe '#process_payment' do
  context 'when all payment prerequisites are met' do
    let(:user) { create(:user, :authenticated, :with_verified_card) }
    let(:card) { user.payment_card }
    before { card.update(balance: 1000) }

    it 'processes payment successfully' do
      # focus on happy path
    end
  end

  context 'when payment is blocked' do
    # separate describe for fraud/duplicate checks
  end

  context 'when payment fails' do
    # separate describe for failure cases
  end
end
```

### Introducing Characteristic-Based Structure into Existing Tests

**Problem:** Tests organized chaotically, without explicit characteristic and state identification.

**Strategy:**

1. **Start with one example file:**
   - Choose spec file of medium complexity (not too simple, not too complex)
   - Apply rules 4-5 from this guide
   - Show team difference in readability
2. **Use as template:**
   - When writing new tests follow example structure
   - Gradually refactor existing files when making changes
3. **Focus on problem areas:**
   - Files with frequent flaky tests
   - Files hard for new developers to understand
   - Files that break with every requirement change
4. **Document team patterns:**
   - Create internal wiki with good test examples from your codebase
   - Add comment templates for typical scenarios

**Key rule:** Don't demand immediate migration of all tests—this leads to team resistance. Instead make gradual improvements with each code touch, and in few months test suite will naturally improve.

## External Services

- **HTTP requests.** Real calls in tests prohibited: enable WebMock (or analog) and explicitly allow only hosts you emulate. Any attempt to access external internet should end with clear error.
- **Contract fixation.** If protocol stable, use VCR—it fixes responses and prevents flakes. When more important to document format and semantics, connect contract tests: Pact for consumer ↔ provider scenarios, `rspec-openapi` or RSwag for actual OpenAPI specification. In contract fix only public fields, otherwise you get implementation test.
- **Queues and background jobs.** In specs check enqueueing fact (`expect { ... }.to have_enqueued_job`) and argument correctness. Extract job's business logic to separate unit test: there run `perform`/`perform_now` and ensure behavior matches [domain](#domain) rules.

## Time Nuances Between Ruby and PostgreSQL

- `Date#wday` returns 0 for Sunday, while `EXTRACT(DOW FROM ...)` in PostgreSQL gives 0 on Sundays and 1 on Mondays. Combining Ruby and SQL checks in tests, explicitly fix expected weekday and don't compare numbers "as is".
- `Date.current.beginning_of_week` obeys `Rails.application.config.beginning_of_week`, while `date_trunc('week', ...)` in PostgreSQL by ISO always starts from Monday. If application works with calendar, add tests checking correct "first day of week" via public interface, otherwise easy to get [flaky test](#characteristics-and-states) when changing setting.
- `Date.parse` and `Time.parse` ignore `Time.zone`, while ActiveRecord saves `timestamp` in UTC. In tests where zone matters, use `Time.zone.parse`, `Time.zone.local` and `in_time_zone`, and extract expectations to `Time.zone.at`/`change`.
- Transitions through midnight and DST: PostgreSQL calculates intervals with UTC values, while Ruby with `travel_to` can hit "non-existent" hour. To avoid catching floating failures, fix time in middle of day (`travel_to(Time.zone.parse('2024-03-25 12:00'))`) and write separate examples for transitions if business process touches edge points.

