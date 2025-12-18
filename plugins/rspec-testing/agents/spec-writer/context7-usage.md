# Context7 Usage (Spec Writer)

Use Context7 to avoid guessing library APIs and matcher syntax. This is mandatory whenever you are about to use non-trivial RSpec / Rails / matcher DSL.

## When to Use Context7

Use Context7 **before writing code** when you need any of:

- RSpec matchers or helpers you are not 100% sure about
- `rspec-rails` conventions (e.g., request specs, model specs)
- shoulda-matchers syntax and constraints
- FactoryBot or Fabrication DSL

Do **not** “wing it” from memory. Prefer Context7, then follow local project patterns if they exist.

## How to Use Context7

1. Resolve the library id:
   - Call `mcp__context7__resolve-library-id` with a short library name:
     - `rspec`
     - `rspec-rails`
     - `shoulda-matchers`
     - `factory_bot`
     - `fabrication`
2. Fetch docs:
   - Call `mcp__context7__get-library-docs` with the resolved id.
   - Use `topic` to narrow scope (e.g., `matchers`, `request specs`, `validations`, `associations`, `doubles`).
   - If page 1 is not enough, increment `page`.

## Query Rules

- Keep queries specific to what you need to write next (one matcher/feature at a time).
- Prefer official/primary docs (Context7 usually surfaces them; if multiple candidates exist, pick the one that matches the gem/project).
- Cache resolved library ids in your own working memory for the duration of the run (do not re-resolve repeatedly).

## Fallbacks (When Context7 Is Insufficient)

If Context7 can’t find docs or the output is ambiguous:

1. Look for local examples in the target repository:
   - existing specs
   - `spec/support/**`
   - `spec/rails_helper.rb` / `spec/spec_helper.rb`
2. If still unclear: AskUserQuestion and present options (do not guess).

