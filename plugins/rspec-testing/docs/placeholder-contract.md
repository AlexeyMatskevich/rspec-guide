# Placeholder Contract (v2)

This document defines the **machine-readable markers** printed into spec skeletons by `spec_structure_generator.rb`.

Goal: enable deterministic mapping (without reading Ruby source code and without brittle Ruby parsing):

- `it` ↔ `behavior_id`
- leaf/terminal example ↔ characteristic branch path (`path`)
- side effect example ↔ `behavior_id` + same `path`
- method block boundaries ↔ stable replace/regenerate operations

---

## Marker Format

Markers are Ruby comments with a strict prefix:

```
# rspec-testing:<tag> key="value" key2="value2"
```

Rules:

- Keys are snake_case.
- Values are double-quoted strings.
- Inside values, `\"` escapes a quote and `\\` escapes a backslash.
- Unknown keys must be ignored by readers (forward-compatible).

---

## Method Boundaries

Every method `describe` block contains begin/end markers.

Example (instance method):

```ruby
describe "#process" do
  # rspec-testing:method_begin method="#process" method_id="PaymentProcessor#process"

  # ...

  # rspec-testing:method_end method="#process" method_id="PaymentProcessor#process"
end
```

Required attributes:

- `method` — exact RSpec descriptor used in `describe` (e.g. `#process`, `.process`)
- `method_id` — canonical method identifier:
  - instance method: `ClassName#method`
  - class method: `ClassName.method`

---

## Example Marker

Every generated `it` block includes an `example` marker **inside** the block (after `{EXPECTATION}`):

```ruby
it "returns completed status" do
  {EXPECTATION}
  # rspec-testing:example behavior_id="returns_completed" kind="terminal" path="1:payment_status=:completed"
end
```

Required attributes:

- `behavior_id` — from metadata `behaviors[].id`
- `kind` — `terminal` | `success` | `side_effect`
- `path` — canonical characteristic branch path (see below)

---

## Side Effect Example Marker

Side effect examples use the same `example` marker, with `kind="side_effect"`:

```ruby
it "sends confirmation email" do
  {EXPECTATION}
  # rspec-testing:example behavior_id="sends_confirmation_email" kind="side_effect" path="1:payment_status=:pending,2:gateway_result=true"
end
```

---

## Canonical `path`

`path` must be deterministic and canonical:

- Order is by characteristic `level` (1..N).
- Each segment is `level:characteristic=value`.
- Segments are comma-separated.
- `value` is the raw metadata value (not the human description). Canonical encoding:
  - `nil` → `nil`
  - booleans → `true` / `false`
  - symbols → `:symbol`
  - strings/numbers → Ruby literal via `inspect` (e.g. `"foo"`, `42`)

Examples:

- `path="1:authenticated=true"`
- `path="1:payment_status=:pending,2:gateway_result=true"`

If a method has no contexts/characteristics, `path` is an empty string.

---

## Reader Expectations (Implementer)

Given a spec skeleton file, the implementer should:

- Locate a method block using `method_begin` / `method_end` markers (prefer editing only that slice).
- For each `it` block, read the closest `rspec-testing:example` marker inside the block.
- Use `behavior_id`, `kind`, and `path` to select the correct setup/expectation content deterministically.

