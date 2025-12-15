# Placeholder Contract (v2)

This document defines the **machine-readable markers** printed into spec skeletons by `spec_structure_generator.rb`.

Goal: enable deterministic mapping (without reading Ruby source code and without brittle Ruby parsing):

- `it` ↔ `behavior_id`
- leaf/terminal example ↔ characteristic branch path (`path`)
- side effect example ↔ `behavior_id` + same `path`
- method block boundaries ↔ stable replace/regenerate operations

**Important:** These markers are **temporary**. The final spec file produced by the pipeline must not contain any `# rspec-testing:*` lines (spec-writer strips them after placeholders are filled).

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

The generator emits `example` markers to link each example site to `behavior_id` + `kind` + `path`.

There are two valid “carriers” for the `example` marker:

1. **Inline carrier** — inside an `it` block (after `{EXPECTATION}`).
2. **Include-site carrier** — a comment line immediately **before** `it_behaves_like` / `include_examples`.

### Inline carrier (inside `it`)

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

### Include-site carrier (before `it_behaves_like`)

When the generator deduplicates repeated behaviors into `shared_examples`, leaf contexts may include the shared template via `it_behaves_like`.
In that case, the include-site marker keeps the **real** `path` for that specific occurrence:

```ruby
# rspec-testing:example behavior_id="returns_completed" kind="success" path="1:payment_status=:completed"
it_behaves_like "__rspec_testing__PaymentProcessor#process__returns_completed__success"
```

Rules:

- `path` is required for include-site carriers.
- Readers should treat the marker as applying to the immediately following `it_behaves_like` / `include_examples` line.

### Template marker (inside `shared_examples`)

Templates are marked by an additional attribute: `template="true"`.

For template markers, `path=""` is allowed because the real `path` is stored at include sites.

```ruby
shared_examples "__rspec_testing__PaymentProcessor#process__returns_completed__success" do
  it "returns completed status" do
    {EXPECTATION}
    # rspec-testing:example behavior_id="returns_completed" kind="success" path="" template="true"
  end
end
```

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

## Reader Expectations (spec-writer)

Given a spec skeleton file, spec-writer should:

- Locate a method block using `method_begin` / `method_end` markers (prefer editing only that slice).
- For each example site, read `rspec-testing:example` in one of two ways:
  - Inline: the closest marker inside the `it` block.
  - Include-site: the marker line directly above `it_behaves_like` / `include_examples`.
- Use `behavior_id`, `kind`, and `path` to select the correct setup/expectation content deterministically.
- If `shared_examples` templates are present, fill `{EXPECTATION}` in templates where `template="true"` exactly once per template name.
