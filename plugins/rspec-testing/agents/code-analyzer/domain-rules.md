# Domain-Specific Rules

Additional rules for specific file types. Load only when trigger condition matches.

---

## Controller Rules

**Trigger:** `IF source_file matches *_controller.rb`

Controllers have implicit behavior that differs from services/POROs.

### Implicit Render Patterns

| Pattern | Behavior Description |
|---------|---------------------|
| Empty action body | "renders {action_name} template" |
| `respond_to { \|f\| f.json {} }` | "renders JSON response" |
| `respond_to { \|f\| f.html {} }` | "renders HTML template" |
| No explicit `render` call | "renders default template" |

### Response Patterns

| Pattern | Behavior Description |
|---------|---------------------|
| `render json: data` | "returns JSON response" |
| `render :show` | "renders show template" |
| `head :no_content` | "returns 204 status" |
| `head :ok` | "returns 200 status" |
| `head :unprocessable_entity` | "returns 422 status" |
| `redirect_to path` | "redirects to {path}" |

### Guard Patterns (before_action)

| Pattern | Terminal Behavior |
|---------|-------------------|
| `before_action :authenticate!` | "raises if not authenticated" |
| `before_action -> { authorize :view? }` | "raises if not authorized" |
| `skip_before_action :auth, only: [:public]` | (skip for listed actions) |

### Rescue Handler Patterns

| Pattern | Terminal Behavior |
|---------|-------------------|
| `rescue_from ActiveRecord::RecordNotFound` | "returns 404 on not found" |
| `rescue StandardError => e; head :unprocessable_entity` | "returns 422 on error" |
| `rescue => e; render json: { error: e.message }` | "returns error JSON" |

### Success Flow Detection

For controllers, success flows are typically the successful responses. Each generates a leaf characteristic value with `behavior_id`:

| Action Type | Success Behavior |
|-------------|------------------|
| `index` | "returns {resources} collection" |
| `show` | "returns {resource}" |
| `create` | "creates {resource}" |
| `update` | "updates {resource}" |
| `destroy` | "deletes {resource}" |

### Side Effects in Controllers

Controllers may have implicit side effects via callbacks:

| Pattern | Side Effect Type |
|---------|-----------------|
| `after_action :track_event` | event |
| `after_action :send_notification` | webhook/email |
| `after_action :clear_cache` | cache |

### Example Analysis

```ruby
class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_payment, only: [:show, :update]

  def create
    @payment = Payment.new(payment_params)

    if @payment.save
      PaymentMailer.confirmation(@payment).deliver_later
      render json: @payment, status: :created
    else
      render json: @payment.errors, status: :unprocessable_entity
    end
  end
end
```

**Output:**

```yaml
behaviors:
  - id: raises_authentication_error
    description: "raises authentication error"
    type: terminal
    enabled: true
    used_by: 1
  - id: returns_422_with_errors
    description: "returns 422 with errors"
    type: terminal
    enabled: true
    used_by: 1
  - id: creates_payment
    description: "creates the payment"
    type: success
    enabled: true
    used_by: 1
  - id: sends_confirmation_email
    description: "sends confirmation email"
    type: side_effect
    subtype: email
    enabled: true
    used_by: 1

methods:
  - name: create
    type: instance
    side_effects:
      - type: email
        behavior_id: sends_confirmation_email
    characteristics:
      - name: authenticated
        description: "user is authenticated"
        type: boolean
        source:
          kind: internal
        values:
          - value: true
            description: "authenticated"
            terminal: false
          - value: false
            description: "not authenticated"
            terminal: true
            behavior_id: raises_authentication_error
        level: 1

      - name: payment_valid
        description: "payment is valid"
        type: boolean
        source:
          kind: internal
        values:
          - value: true
            description: "valid payment"
            terminal: false
            behavior_id: creates_payment  # leaf success flow
          - value: false
            description: "invalid payment"
            terminal: true
            behavior_id: returns_422_with_errors
        level: 2
        depends_on: authenticated
        when_parent: [true]
```

---

## Model Rules

**Trigger:** `IF source_file matches app/models/*.rb AND class inherits from ApplicationRecord`

(Reserved for future expansion)

### Callback Side Effects

| Callback | Side Effect Type |
|----------|-----------------|
| `after_create :send_welcome_email` | email |
| `after_save :publish_event` | event |
| `after_commit :clear_cache` | cache |

---

## Service Object Rules

**Trigger:** `IF source_file matches app/services/**/*.rb`

Default rules apply. Services are the primary use case for code-analyzer.

No special handling needed — standard characteristic extraction works well.
