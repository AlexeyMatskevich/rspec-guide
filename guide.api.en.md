# API Contract Testing: RSpec Applicability Boundaries

## Table of Contents

- [Philosophy: use the right tool for the right purpose](#philosophy-use-the-right-tool-for-the-right-purpose)
- [Anti-patterns of JSON API testing](#anti-patterns-of-json-api-testing-in-rspec)
  - [Over-splitting](#anti-pattern-1-over-splitting)
  - [Excessive detail](#anti-pattern-2-excessive-detail-checking-entire-hash)
- [When RSpec fits for API tests](#when-rspec-fits-for-api-tests)
- [Tools for API contract testing](#tools-for-api-contract-testing)
  - [JSON Schema validation](#1-json-schema-validation-thoughtbotjson_matchers)
  - [rspec-openapi](#2-rspec-openapi--automatic-openapi-specification-generation)
  - [RSwag](#3-rswag--dsl-for-describing-and-testing-openapi)
  - [Snapshot testing](#4-snapshot-testing--fixing-reference-responses)
- [Recommended approach](#recommended-approach-combination-of-tools)
- [Quick tool selection](#quick-tool-selection)
- [Golden rule](#golden-rule)
- [Glossary](#glossary)

---

RSpec is created for describing and checking **behavior**—business rules expressed through actions and their observable consequences. When it comes to fixing **[API contract](#api-contract)** (response structure, field types, required attributes), RSpec becomes unsuitable tool: attempting to describe contract through множество `expect` turns specification into fragile set of implementation checks.

## Philosophy: use the right tool for the right purpose

- **RSpec for behavior:** Check business logic (order creation, authorization), HTTP statuses, key response fields.
- **Specialized tools for contracts:** Fix complete API structure, field types, nesting, requiredness.

This separation provides:

- Readable RSpec tests focused on business rules
- Automatic up-to-date API documentation
- Protection from breaking changes in contract
- Independent evolution of behavior and contract

## Anti-patterns of JSON API testing in RSpec

### Anti-pattern 1: Over-splitting

Checking each field with separate test creates redundancy and hides that all fields are parts of unified contract.

```ruby
# bad: each field — separate test
describe 'GET /api/orders/:id' do
  let(:order) { create(:order, total: 150.0, status: 'pending') }

  it 'returns order ID' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['id']).to eq(order.id)
  end

  it 'returns order total' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['total']).to eq(150.0)
  end

  it 'returns order status' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['status']).to eq('pending')
  end

  it 'returns customer email' do
    get "/api/orders/#{order.id}"
    expect(response.parsed_body['customer_email']).to be_present
  end
  # ... 10 more tests for other fields
end
```

**Problems:**

- 10+ tests describe one thing: "API returns order"
- Every contract change breaks множество tests
- Unclear which fields are critical for business, which are technical details
- Repeated HTTP requests slow down tests

**Solution:** See [JSON Schema validation](#1-json-schema-validation-thoughtbotjson_matchers) or [Snapshot testing](#4-snapshot-testing--fixing-reference-responses).

### Anti-pattern 2: Excessive detail (checking entire hash)

Comparing full response via `eq` fixes implementation and makes tests fragile.

```ruby
# bad: checking entire structure byte-by-byte
describe 'GET /api/orders/:id' do
  it 'returns order details' do
    get "/api/orders/#{order.id}"

    expect(response.parsed_body).to eq({
      'id' => order.id,
      'total' => 150.0,
      'status' => 'pending',
      'customer_email' => 'user@example.com',
      'items_count' => 3,
      'shipping_address' => {
        'street' => '123 Main St',
        'city' => 'Springfield',
        'postal_code' => '12345'
      },
      'created_at' => order.created_at.iso8601(3),
      'updated_at' => order.updated_at.iso8601(3),
      'discount_amount' => nil,
      'tax_amount' => 12.0,
      'notes' => nil
    })
  end
end
```

**Problems:**

- Test fails when adding any new field to serializer
- Technical timestamp fields are checked, not important for business logic
- Unclear what exactly is critical: `total`, `status` or all fields are equal
- Hash key order can cause false failures

**Solution:** See [aggregate_failures in guide.en.md](guide.en.md#23-use-aggregate_failures-only-when-describing-one-rule) for business checks, [JSON Schema](#1-json-schema-validation-thoughtbotjson_matchers) for contract.

## When RSpec fits for API tests

✅ **Use RSpec request specs when:**

1. **Checking business behavior through API:**

   ```ruby
   it 'creates order with valid payment' do
     post '/orders', params: { product_id: 1, quantity: 2 }
     expect(response).to have_http_status(:created)
     expect(Order.last).to have_attributes(status: 'pending', total: 200.0)
   end
   ```

2. **Testing HTTP statuses and basic structure:**

   ```ruby
   it 'returns successful response with order data', :aggregate_failures do
     get "/orders/#{order.id}"
     expect(response).to have_http_status(:ok)
     expect(response.content_type).to match(/json/)
     expect(response.parsed_body).to include('id', 'status', 'total')
   end
   ```

3. **Checking key fields important for business logic:**

   ```ruby
   it 'includes essential order fields', :aggregate_failures do
     get "/orders/#{order.id}"
     expect(response.parsed_body).to include(
       'id' => order.id,
       'status' => 'pending',
       'total' => a_kind_of(Numeric)
     )
   end
   ```

   **See also:** [Rule 3.2 "Working with large interfaces"](guide.en.md#32-working-with-large-interfaces) — using `have_attributes` and structural matchers.

❌ **Avoid RSpec for:**

- Complete response structure fixation (field schemas, types, nesting)
- Comparing huge JSON via `eq` or string comparison
- Documenting API contract for external consumers
- Checking all possible response fields "just in case"

## Tools for API contract testing

### 1. JSON Schema validation (thoughtbot/json_matchers)

**What it is:** Gem for validating JSON responses against [JSON Schema](#glossary) directly in RSpec tests.

**When to use:** Intermediate solution between manual checks and full-fledged contract tests. Suitable for projects needing structure validation without documentation generation.

**Installation:**

```ruby
# Gemfile
group :test do
  gem 'json_matchers'
end
```

**Usage:**

```json
# spec/support/api/schemas/order.json
{
  "type": "object",
  "required": ["id", "status", "total"],
  "properties": {
    "id": { "type": "integer" },
    "status": { "type": "string", "enum": ["pending", "paid", "shipped"] },
    "total": { "type": "number", "minimum": 0 },
    "customer_email": { "type": "string", "format": "email" }
  },
  "additionalProperties": false
}
```

```ruby
# spec/requests/orders_spec.rb
RSpec.describe 'Orders API', type: :request do
  it 'matches order schema' do
    get "/api/orders/#{order.id}"
    expect(response).to match_response_schema('order')
  end
end
```

**Advantages:**

- Works with existing request specs
- Schema in separate file — can be reused
- `additionalProperties: false` catches field addition without schema update

**Disadvantages:**

- Doesn't generate documentation automatically
- Schemas need manual maintenance

### 2. rspec-openapi — automatic OpenAPI specification generation

**What it is:** Gem that generates [OpenAPI](#glossary) 3.0 specification from regular RSpec request specs during test execution.

**Philosophy:** **[Code-first](#glossary) approach** — source of truth is your API code and behavior. OpenAPI documentation is generated automatically from actual requests and responses during test execution.

**When to use:** You want to use RSpec for its direct purpose (behavior testing) and automatically get up-to-date OpenAPI documentation.

**Installation:**

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-openapi'
end
```

**Configuration:**

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.openapi_root = Rails.root.join('doc', 'openapi.yaml')
  config.openapi_specs = {
    'api/v1/openapi.yaml' => {
      info: {
        title: 'My API',
        version: 'v1'
      },
      servers: [{ url: 'https://api.example.com' }]
    }
  }
end
```

**Usage:**

```ruby
# spec/requests/orders_spec.rb
RSpec.describe 'Orders API', type: :request do
  # Regular RSpec test focused on behavior
  it 'creates order with valid payment' do
    post '/api/orders', params: { product_id: 1, quantity: 2 }
    expect(response).to have_http_status(:created)
    expect(Order.last.status).to eq('pending')
  end

  # rspec-openapi automatically captures:
  # - path POST /api/orders
  # - request body structure
  # - response structure with code 201
end
```

Running with OpenAPI generation:

```bash
OPENAPI=1 rspec spec/requests
```

**Adding metadata for better documentation:**

```ruby
describe 'GET /api/orders/:id', openapi: {
  summary: 'Get order details',
  tags: ['Orders'],
  security: [{ bearer_auth: [] }]
} do
  it 'returns order with items' do
    get "/api/orders/#{order.id}", headers: auth_headers
    expect(response).to have_http_status(:ok)
  end
end
```

**Advantages:**

- Minimal intrusion into existing tests
- Automatic documentation update when API changes
- Preserves manual edits in OpenAPI file when merging
- RSpec tests remain simple and readable

**Disadvantages:**

- Limited control over generated schema
- Doesn't validate responses against schema during tests (only generates)

### 3. RSwag — DSL for describing and testing OpenAPI

**What it is:** Gem providing DSL over RSpec for explicit API description and Swagger/[OpenAPI](#glossary) documentation generation + built-in Swagger UI.

**Philosophy:** **[Spec-first](#glossary) approach** — source of truth is OpenAPI specification, though it's written as Ruby code in tests. You explicitly describe API schema (essentially writing OpenAPI documentation in Ruby syntax), and RSwag converts these Ruby hashes/arrays to JSON/YAML OpenAPI format.

**When to use:** You want to explicitly describe API contract in tests and get response validation against schema + live documentation. Suitable for APIs where specification is primary (API developed to match contract).

**Installation:**

```ruby
# Gemfile
gem 'rswag-api'
gem 'rswag-ui'

group :development, :test do
  gem 'rswag-specs'
end
```

```bash
rails g rswag:api:install
rails g rswag:ui:install
RAILS_ENV=test rails g rswag:specs:install
```

```ruby
# spec/requests/orders_spec.rb
require 'swagger_helper'

RSpec.describe 'Orders API' do
  path '/api/orders' do
    post 'Creates an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :order, in: :body, schema: {
        type: :object,
        properties: {
          product_id: { type: :integer },
          quantity: { type: :integer, minimum: 1 }
        },
        required: ['product_id', 'quantity']
      }

      response '201', 'order created' do
        let(:order) { { product_id: 1, quantity: 2 } }

        schema type: :object,
          properties: {
            id: { type: :integer },
            status: { type: :string },
            total: { type: :number }
          },
          required: ['id', 'status', 'total']

        run_test!
      end

      response '422', 'invalid request' do
        let(:order) { { product_id: 1 } }
        run_test!
      end
    end
  end
end
```

Generating documentation:

```bash
rails rswag:specs:swaggerize
```

Documentation available at: `http://localhost:3000/api-docs`

**Advantages:**

- Explicit contract description in tests
- Response validation against schema during test execution
- Automatic Swagger UI generation
- Full schema control

**Disadvantages:**

- More verbose syntax compared to regular request specs
- Requires migrating existing tests to DSL
- Mixes contract description and behavior testing

### 4. Snapshot testing — fixing reference responses

**What it is:** Approach from frontend world (Jest) where test fixes output "snapshot" ([snapshot](#glossary)) on first run and compares with it on subsequent runs.

**Where it's from:** In frontend world (React, Vue) snapshot testing is used to fix component rendering. Developer runs tests, they create snapshot (HTML output), and on subsequent runs any render change causes test failure. If change expected — developer updates snapshot, if not — catches regression.

**How it works with API:** Same principle applicable to OpenAPI specifications or JSON responses:

1. First test run generates reference (OpenAPI spec or JSON snapshot)
2. Subsequent runs compare current output with reference
3. On API change test fails, showing diff
4. Developer either fixes regression or updates reference

**Advantages combined with rspec-openapi:**

When you use `rspec-openapi`, you:

- Write regular RSpec request specs focused on **behavior** (is order created correctly, does right status come)
- Automatically get OpenAPI specification fixing **contract** (response structure, field types)
- Can organize snapshot testing of this OpenAPI spec

**Catching two birds:**

1. RSpec used for direct purpose — behavior testing
2. OpenAPI spec as snapshot catches unexpected contract changes

**Tools for snapshot testing in Ruby:**

```ruby
# Gemfile
group :test do
  gem 'rspec-snapshot'  # General snapshot testing
  # or
  gem 'rspec-request_snapshot'  # Specialized for request specs
end
```

**Usage example:**

```ruby
RSpec.describe 'Orders API', type: :request do
  it 'returns order details' do
    get "/api/orders/#{order.id}"
    expect(response.body).to match_snapshot('order_details')
  end
end
```

On first run creates file `spec/__snapshots__/orders_api_spec.rb/order_details.json`. On subsequent runs current response is compared with this file.

**Snapshot testing OpenAPI with rspec-openapi:**

After generating OpenAPI via `OPENAPI=1 rspec`, file `doc/openapi.yaml` can be versioned in git. On API change:

- CI checks if file changed
- If yes — requires explicit commit of update (= acknowledge breaking change)
- If change unexpected — regression caught

**When to use snapshot testing:**

- For stable APIs with rare changes
- When important to catch unexpected contract changes
- Combined with rspec-openapi for automatic contract control

**When not to use:**

- For APIs that change frequently (constant snapshot updates)
- Instead of meaningful behavior checks
- For critical business rules (better explicit expectations)

## Recommended approach: combination of tools

✅ **Best practice:**

1. **RSpec request specs** — for behavior testing:

   ```ruby
   it 'creates order and charges customer' do
     post '/orders', params: order_params
     expect(response).to have_http_status(:created)
     expect(Order.last.status).to eq('pending')
     expect(customer.reload.balance).to eq(0)
   end
   ```

2. **rspec-openapi** — for automatic contract fixation:

   ```ruby
   # Same test above, run with OPENAPI=1,
   # automatically updates doc/openapi.yaml
   ```

3. **JSON Schema / thoughtbot/json_matchers** — for critical endpoints:

   ```ruby
   it 'returns valid payment confirmation' do
     post '/payments', params: payment_params
     expect(response).to match_response_schema('payment_confirmation')
   end
   ```

4. **RSwag** — if need live documentation and explicit control:

   ```ruby
   # For public APIs where documentation = contract with clients
   path '/api/v2/orders' do
     post 'Creates order' do
       # ... detailed schema description
     end
   end
   ```

5. **Snapshot testing** — for catching contract regressions:

   ```bash
   # CI checks that doc/openapi.yaml didn't change without explicit commit
   git diff --exit-code doc/openapi.yaml
   ```

## Quick tool selection

| Situation | Recommended tool | Why |
|-----------|------------------|-----|
| Testing business logic through API | **RSpec request specs** | Behavior checking — RSpec's direct purpose |
| Code-first: want documentation from code | **rspec-openapi** | Code — source of truth, OpenAPI generated automatically |
| Spec-first: developing API to match contract | **RSwag** | Spec — source of truth, tests validate compliance |
| Need response structure validation | **json_matchers** | Lightweight solution for JSON Schema checking |
| Need to catch unexpected changes | **Snapshot testing** | Auto-fixing reference, git diff shows changes |
| Checking HTTP statuses and key fields | **RSpec + structural matchers** | `include`, `match_array` instead of `eq` |

**Optimal:** Combination of RSpec (behavior) + rspec-openapi (contract) + json_matchers (critical endpoints).

---

## Quick Reference: Problem Diagnostics

### If need to fix response structure:

**Using code-first approach (code first, then specification)?**
→ [rspec-openapi](#2-rspec-openapi--automatic-openapi-specification-generation)

**Using spec-first approach (specification first, then code)?**
→ [RSwag](#3-rswag--dsl-for-describing-and-testing-openapi)

**Need lightweight validation without full OpenAPI specification?**
→ [json_matchers](#1-json-schema-validation-thoughtbotjson_matchers)

### If API tests break too often:

**Checking each field with separate test?**
→ This is [Anti-pattern 1: Over-splitting](#anti-pattern-1-over-splitting)

**Using `eq` for entire hash?**
→ This is [Anti-pattern 2: Excessive detail](#anti-pattern-2-excessive-detail-checking-entire-hash)

**Mixing behavior and structure checks in one test?**
→ See [Golden rule](#golden-rule)

### If API used by external clients:

**Need live documentation that's always up-to-date?**
→ [RSwag](#3-rswag--dsl-for-describing-and-testing-openapi) or [rspec-openapi](#2-rspec-openapi--automatic-openapi-specification-generation)

**Need to catch breaking changes before deploy?**
→ [Snapshot testing](#4-snapshot-testing--fixing-reference-responses) + any schema validation tool

---

## Golden rule

**Don't mix behavior and contract checking in one test.**

- RSpec = behavior (what system does)
- OpenAPI/JSON Schema/Snapshots = contract (what interface looks like)

If test reads as "checks that system creates order" — this is RSpec.
If test reads as "checks that response contains all fields from schema" — this is contract test.

---

## Glossary

### API contract

Formal description of API request and response structure: which fields are required, their types, format, nesting. Contract doesn't describe business logic, only data structure.

### Code-first

Approach where API code is written first, and documentation (OpenAPI) is generated from it automatically. Code is source of truth.

### Spec-first

Approach where API specification (OpenAPI) is created first, and code is written according to it. Specification is source of truth.

### OpenAPI (Swagger)

Standard for describing REST API in JSON/YAML format. Includes endpoints, parameters, data schemas, response examples.

### JSON Schema

Standard for describing JSON document structure: field types, requiredness, formats, validation.

### Snapshot testing

Testing technique where first execution result is saved as reference, and subsequent runs are compared with it.

---

**See also in main guide:**
- [Rule 27: Stabilize time](guide.en.md#27-stabilize-time-with-activesupporttestingtimehelpers) — time management in tests
- [Rule 28: Make test failure output readable](guide.en.md#28-make-test-failure-output-readable) — examples of readable JSON response formatting
