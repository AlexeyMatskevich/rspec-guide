# Context Word Selection (Rule 20)

Detailed decision tree and examples for selecting context words.

## Decision Tree

```
Is this level 1 (root)?
├─ YES → 'when' (always)
└─ NO  → What type is the characteristic?
         ├─ boolean/presence
         │   ├─ First value (happy path) → 'with'
         │   └─ Second value (corner case) → 'but'
         │
         ├─ enum/sequential
         │   └─ All values → 'and'
         │
         └─ range
             ├─ 2 values → treat as binary ('with'/'but')
             └─ 3+ values → treat as enum ('and')
```

## Special Cases

### Explicit Negation: `NOT`

Use capitalized `NOT` when:
- State name contains negation: "not authenticated" → "when user NOT authenticated"
- Result is denial/rejection: `it 'does NOT charge the card'`

### Absence: `without`

Use when explicitly showing absence:
- `context 'without verified email'`
- `context 'without payment method'`

Alternative to `but` when emphasizing what's missing.

---

## Complete Examples

### Binary Characteristic (boolean/presence)

```yaml
- name: authenticated
  type: boolean
  values:
    - value: true
      description: "authenticated"
    - value: false
      description: "not authenticated"
  level: 1
```

**Level 1:**
```ruby
context 'when user authenticated' do    # First: 'when' (level 1)
  # ...
end

context 'when user NOT authenticated' do # Second: 'when' (level 1) + NOT emphasis
  # ...
end
```

**Level 2:**
```ruby
context 'with valid credentials' do      # First: 'with' (happy path)
  # ...
end

context 'but credentials expired' do     # Second: 'but' (contrast)
  # ...
end
```

### Enum Characteristic

```yaml
- name: payment_method
  type: enum
  values:
    - value: card
    - value: paypal
    - value: bank_transfer
  level: 2
```

```ruby
context 'when user authenticated' do
  context 'and payment method is card' do      # 'and' for all enum values
    # ...
  end

  context 'and payment method is paypal' do
    # ...
  end

  context 'and payment method is bank transfer' do
    # ...
  end
end
```

### Range Characteristic (2 values)

```yaml
- name: balance
  type: range
  values:
    - value: sufficient
    - value: insufficient
  level: 3
```

```ruby
context 'with balance sufficient' do      # First: 'with'
  it 'processes the payment'
end

context 'but balance insufficient' do     # Second: 'but'
  it 'returns insufficient funds error'
end
```

### Sequential Characteristic

```yaml
- name: order_status
  type: sequential
  values:
    - value: pending
    - value: processing
    - value: completed
    - value: cancelled
  level: 2
```

```ruby
context 'when order exists' do
  context 'and order status is pending' do     # 'and' for all
    # ...
  end

  context 'and order status is processing' do
    # ...
  end

  context 'and order status is completed' do
    it 'cannot be modified'  # Terminal state
  end

  context 'and order status is cancelled' do
    it 'cannot be processed'  # Terminal state
  end
end
```

---

## Word Sequence in Nested Contexts

Follow this sequence as you nest deeper:

```ruby
describe OrderService do
  describe '#process' do
    context 'when user authenticated' do           # Level 1: 'when'
      context 'with valid order' do                # Level 2: 'with'
        context 'and payment method is card' do    # Level 3: 'and'
          context 'with balance sufficient' do     # Level 4: 'with'
            it 'processes the order'
          end

          context 'but balance insufficient' do    # Level 4: 'but'
            it 'returns insufficient funds'
          end
        end
      end

      context 'but order invalid' do               # Level 2: 'but'
        it 'returns validation error'
      end
    end

    context 'when user NOT authenticated' do       # Level 1: 'when' + NOT
      it 'denies access'
    end
  end
end
```

---

## Common Mistakes

### Wrong: Using 'when' at nested levels

```ruby
# BAD
context 'when user authenticated' do
  context 'when payment valid' do  # Wrong! Not level 1
```

```ruby
# GOOD
context 'when user authenticated' do
  context 'with valid payment' do  # Correct: 'with' at level 2
```

### Wrong: Missing 'NOT' emphasis

```ruby
# BAD
context 'when user not authenticated' do  # 'not' should be capitalized
```

```ruby
# GOOD
context 'when user NOT authenticated' do  # Correct: NOT in caps
```

### Wrong: 'but' before 'with'

```ruby
# BAD
context 'but payment valid' do  # 'but' implies contrast, needs 'with' first
```

```ruby
# GOOD
context 'with payment valid' do   # Happy path first
  # ...
end

context 'but payment invalid' do  # Then contrast
  # ...
end
```
