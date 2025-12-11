# Library/CLI/Service Heuristics for Isolation Decider

## Scope
Applied when `project_type == "library"` or generic service with no Rails stack.

## Defaults
- `test_level = unit`
- Isolation: `db: none`, `external_http: stubbed` (only if present), `queue: none`

## Escalation
- If method interacts with filesystem/network or persistent store (detected via side_effects): keep `unit` but mark `external_http: stubbed`.
- If multiple domain dependencies and side effects combined, set `confidence: medium` and optionally ask user if low.

## Confidence
- Mostly high by default; drop to medium if side effects present; ask only on low (rare in library mode).
