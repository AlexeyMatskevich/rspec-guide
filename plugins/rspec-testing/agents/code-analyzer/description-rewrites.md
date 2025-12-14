---
description: Rewrite patterns for values[].description to satisfy the description contract.
---

# Description Rewrites (values[].description)

This file helps you rewrite `methods[].characteristics[].values[].description` when validation fails.

## Core Rule

Treat `values[].description` as a **fragment**, not a full sentence.

- Do not start with reserved context words: `when`, `with`, `and`, `but`, `without`.
- For nested binary characteristics (level 2+), prefer noun/adjective phrases (avoid `has/have/is/are/was/were`).

## 1) Remove Context-Word Prefixes

Do not include reserved context words (`when/with/and/but/without`) in `values[].description`.

Examples:

- Bad: `"[with] subscription"` → Good: `"subscription"`
- Bad: `"[without] payment method"` → Good: `"payment method"`
- Bad: `"[when] user authenticated"` → Good: `"user authenticated"` (or `"user is authenticated"` for level 1)

## 2) Rewrite Clauses into Phrases (Level >= 2, Binary Types)

For nested binary contexts (level 2+), avoid clause verbs: `has/have/is/are/was/were`.

### `X has Y` → `Y in X`

- Bad: `"cart has items"` → Good: `"items in cart"`
- Bad: `"account has sufficient balance"` → Good: `"sufficient balance in account"` or `"sufficient account balance"`

### `X is empty` → `empty X` (or `no Y in X`)

- Bad: `"cart is empty"` → Good: `"empty cart"`
- Bad: `"email is missing"` → Good: `"missing email"` or `"no email"`

### `X is valid/invalid` → `valid/invalid X`

- Bad: `"payment is valid"` → Good: `"valid payment"`
- Bad: `"token is invalid"` → Good: `"invalid token"`

### `X is NOT Y` → Prefer a phrase

- Bad: `"user is not authenticated"` (level 2+) → Good: `"NOT authenticated user"` or `"NOT authenticated"`

For `presence` characteristics, prefer **positive noun phrases**:

- Bad (presence): `"NOT subscription"` → Good: `"subscription"`

## 3) Presence Characteristics: Use the Same Noun Phrase for Both Values

For `type: presence`, prefer the same noun phrase for both states:

```yaml
values:
  - value: present
    description: "subscription"
  - value: nil
    description: "subscription"
```

This yields consistent phrasing across both states.

Example:

- present: `"subscription"`
- nil: `"subscription"`

If you really need a negative wording (e.g., `"empty cart"`), use it explicitly.

## 4) Enum/Sequential/Range(>2): Prefer Value Words

For `enum/sequential/range(>2)`, avoid verb phrases in `values[].description`.

- Bad: `"paying by card"` → Good: `"card"`
- Bad: `"using PayPal"` → Good: `"PayPal"`
