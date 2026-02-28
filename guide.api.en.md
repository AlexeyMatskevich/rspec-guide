# API Contract Testing: RSpec Applicability Boundaries

## Table of Contents

- [Philosophy](#philosophy)
- [Anti-patterns of JSON API testing](#anti-patterns-of-json-api-testing-in-rspec)
  - [Over-splitting](#anti-pattern-1-over-splitting)
  - [Excessive detail](#anti-pattern-2-excessive-detail-checking-entire-hash)
- [When RSpec fits for API tests](#when-rspec-fits-for-api-tests)
- [Tools for API contract testing](#tools-for-api-contract-testing)
  - [JSON Schema validation](#json-schema-validation-thoughtbotjson_matchers)
  - [rspec-openapi](#rspec-openapi)
  - [RSwag](#rswag)
  - [Snapshot testing](#snapshot-testing)
- [Quick tool selection](#quick-tool-selection)
- [Golden rule](#golden-rule)
- [Glossary](#glossary)

RSpec is designed for describing and checking **behavior** — business rules expressed through actions and their observable consequences. When it comes to pinning down an **[API contract](#api-contract)** (response structure, field types, required attributes), RSpec becomes unsuitable: attempting to describe a contract through many `expect` statements turns the specification into a fragile set of implementation checks.

## Philosophy

RSpec checks behavior: business logic (order creation, authorization), HTTP statuses, key response fields. Specialized tools pin down the contract: complete API structure, field types, nesting, required fields.

When behavior and contract are separated, RSpec tests read as a business rules specification, API documentation updates automatically, and breaking changes in the contract are caught before deploy. Behavior and contract evolve independently.

## Anti-patterns of JSON API testing in RSpec

### Anti-pattern 1: Over-splitting

Checking each field with a separate test creates redundancy and hides the fact that all fields are parts of a unified contract.

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
- Every contract change breaks many tests
- Unclear which fields are critical for business and which are technical details
- Repeated HTTP requests slow down tests

**Solution:** See [JSON Schema validation](#json-schema-validation-thoughtbotjson_matchers) or [Snapshot testing](#snapshot-testing).

### Anti-pattern 2: Excessive detail (checking entire hash)

Comparing the full response via `eq` locks in the implementation and makes tests fragile.

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
- Technical timestamp fields irrelevant to business logic are checked
- Unclear what exactly is critical: `total`, `status`, or are all fields equal
- Hash key order can cause false failures

**Solution:** See [aggregate_failures in guide.en.md](guide.en.md#11-aggregate_failures-for-interface-tests) for business checks, [JSON Schema](#json-schema-validation-thoughtbotjson_matchers) for contract.

## When RSpec fits for API tests

RSpec request specs are appropriate when checking behavior, not structure.

Checking business behavior through API:

```ruby
it 'creates order with valid payment' do
  post '/orders', params: { product_id: 1, quantity: 2 }
  expect(response).to have_http_status(:created)
  expect(Order.last).to have_attributes(status: 'pending', total: 200.0)
end
```

Testing HTTP statuses and basic structure:

```ruby
it 'returns successful response with order data', :aggregate_failures do
  get "/orders/#{order.id}"
  expect(response).to have_http_status(:ok)
  expect(response.content_type).to match(/json/)
  expect(response.parsed_body).to include('id', 'status', 'total')
end
```

Checking key fields important for business logic:

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

**See also:** [Rule 11 "aggregate_failures for interface tests"](guide.en.md#11-aggregate_failures-for-interface-tests) — using `have_attributes` and structural matchers.

RSpec is not suitable for locking down the complete response structure (field schemas, types, nesting), comparing large JSON via `eq` or string comparison, documenting API contracts for external consumers, or checking all possible response fields "just in case". For that, use the tools below.

## Tools for API contract testing

Tool choice depends on what exactly you need: structure validation without documentation, documentation from code, development to match a contract, or regression protection.

### JSON Schema validation (thoughtbot/json_matchers)

If you need response structure validation without generating documentation, `json_matchers` fits. The gem adds an RSpec matcher for checking JSON responses against a [JSON Schema](#json-schema) that you describe in a separate file.

```ruby
# Gemfile
group :test do
  gem 'json_matchers'
end
```

The schema describes the contract — field types, required fields, allowed values:

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

One line in the test checks the entire contract:

```ruby
# spec/requests/orders_spec.rb
RSpec.describe 'Orders API', type: :request do
  it 'matches order schema' do
    get "/api/orders/#{order.id}"
    expect(response).to match_response_schema('order')
  end
end
```

Works with existing request specs, the schema in a separate file is reusable, and `additionalProperties: false` catches field addition without schema update. The trade-off — schemas don't generate documentation and require manual maintenance.

### rspec-openapi

If you want to write regular RSpec tests and automatically get up-to-date documentation — this is the [code-first](#code-first) approach. The `rspec-openapi` gem generates an [OpenAPI](#openapi-swagger) 3.0 specification from actual requests and responses during test runs. Code is the source of truth; documentation follows it.

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-openapi'
end
```

Configuration:

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

Tests stay focused on behavior — the gem extracts the contract from actual requests:

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

For better documentation you can add metadata:

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

The main advantage is minimal intrusion into existing tests: documentation updates automatically, and manual edits in the OpenAPI file are preserved on merge. The limitation — the gem doesn't validate responses against the schema (only generates), and control over the output is limited.

### RSwag

If the contract is primary and the API is developed to match a specification — this is the [spec-first](#spec-first) approach. RSwag provides a DSL over RSpec for explicitly describing the [OpenAPI](#openapi-swagger) contract in tests. Essentially you write OpenAPI documentation in Ruby syntax, and RSwag converts it to JSON/YAML and serves Swagger UI.

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

RSwag gives full control: explicit contract description, response validation against schema during test runs, automatic Swagger UI generation. The price — more verbose syntax, the need to migrate existing tests to the DSL, and mixing contract description with behavior testing in the same file.

### Snapshot testing

Snapshot testing is an approach from the frontend world. In React and Vue it's used to capture component rendering: on the first run Jest creates a snapshot of the HTML output, on subsequent runs it compares current output with the reference. If the change is expected — the developer updates the [snapshot](#glossary), if not — catches regression.

The same principle applies to API responses and OpenAPI specifications:

1. First test run generates a reference (OpenAPI spec or JSON snapshot)
2. Subsequent runs compare current output with the reference
3. On API change the test fails, showing a diff
4. Developer either fixes regression or updates the reference

Combined with `rspec-openapi` this works as follows: you write regular RSpec tests focused on behavior, automatically get an OpenAPI specification that captures the contract, and organize snapshot testing of that spec. RSpec is used for its direct purpose — behavior testing, while the OpenAPI spec as a snapshot catches unexpected contract changes.

Tools for snapshot testing in Ruby:

```ruby
# Gemfile
group :test do
  gem 'rspec-snapshot'  # General snapshot testing
  # or
  gem 'rspec-request_snapshot'  # Specialized for request specs
end
```

Usage example:

```ruby
RSpec.describe 'Orders API', type: :request do
  it 'returns order details' do
    get "/api/orders/#{order.id}"
    expect(response.body).to match_snapshot('order_details')
  end
end
```

On the first run it creates file `spec/__snapshots__/orders_api_spec.rb/order_details.json`. On subsequent runs the current response is compared with this file.

Snapshot testing OpenAPI via `rspec-openapi` is even simpler: after generating via `OPENAPI=1 rspec`, the file `doc/openapi.yaml` is versioned in git. CI checks if the file changed and requires an explicit commit of the update — an acknowledged breaking change. An unexpected change is caught as a regression.

Snapshot testing works well for stable APIs with rare changes and for automatic contract control combined with `rspec-openapi`. It doesn't work well for APIs that change frequently (constant snapshot updates slow things down), and it doesn't replace meaningful behavior checks or explicit expectations for critical business rules.

## Quick tool selection

| Situation | Recommended tool | Why |
|-----------|------------------|-----|
| Testing business logic through API | **RSpec request specs** | Behavior checking — RSpec's direct purpose |
| Code-first: want documentation from code | **rspec-openapi** | Code — source of truth, OpenAPI generated automatically |
| Spec-first: developing API to match contract | **RSwag** | Spec — source of truth, tests validate compliance |
| Need response structure validation | **json_matchers** | Lightweight solution for JSON Schema checking |
| Need to catch unexpected changes | **Snapshot testing** | Auto-fixing reference, git diff shows changes |
| Checking HTTP statuses and key fields | **RSpec + structural matchers** | `include`, `match_array` instead of `eq` |

## Golden rule

Don't mix behavior and contract checking in one test.

- RSpec = behavior (what system does)
- OpenAPI/JSON Schema/Snapshots = contract (what interface looks like)

If a test reads as "checks that the system creates an order" — this is RSpec.
If a test reads as "checks that the response contains all fields from the schema" — this is a contract test.

## Glossary

### API contract

Formal description of API request and response structure: which fields are required, their types, formats, and nesting. A contract doesn't describe business logic, only data structure.

### Code-first

Approach where API code is written first, and documentation (OpenAPI) is generated from it automatically. Code is the source of truth.

### Spec-first

Approach where API specification (OpenAPI) is created first, and code is written according to it. Specification is the source of truth.

### OpenAPI (Swagger)

Standard for describing REST API in JSON/YAML format. Includes endpoints, parameters, data schemas, response examples.

### JSON Schema

Standard for describing JSON document structure: field types, required fields, formats, validation.

### Snapshot testing

Testing technique where the first execution result is saved as a reference, and subsequent runs are compared with it.

**See also in main guide:**
- [Rule 16: Stabilize time](guide.en.md#16-stabilize-time) — time management in tests
- [Rule 17: Make failure output readable](guide.en.md#17-make-failure-output-readable) — examples of readable JSON response formatting
