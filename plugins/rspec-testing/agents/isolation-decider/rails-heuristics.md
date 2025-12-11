# Rails/Web/Service Heuristics for Isolation Decider

## Scope
Applied when `project_type in ["rails", "web", "service"]`.

## File-Type Hints
- `app/controllers/**` or class ending in `Controller` → request candidate.
- `app/jobs/**`, `app/workers/**` → integration (queue mocked).
- `app/services/**`, `app/interactors/**` → default unit → escalate on signals.
- `app/models/**` → default unit → escalate if heavy DB.
- `lib/**` → treat as library (mostly unit).

## Signals and Overrides

### DB Usage
- `setup.type: model` OR side_effect `cache` → uses_db = true.
- Escalate to integration when:
  - `loc > 20` OR
  - `complexity.zone in [yellow, red]` OR
  - >1 domain dependency (fan_out > 1).
- Else keep unit with `db: stubbed`.

### External HTTP
- side_effect `external_api` → always stub external calls.
- Does not force integration; combine with DB rule above.

### Queue/Async
- side_effect `event` / `webhook` / `email` → queue: stubbed.
- Does not force integration.

### Controllers
- For public actions (`index/show/create/update/destroy`): `test_level = request`, `db: real`, `external_http: stubbed`, `queue: stubbed`.
- Private helpers can follow service rules (DB/HTTP/queue heuristics).

### Pure Methods
- No side_effects, no DB/HTTP → `unit`, `db: none`, `external_http: none`, `queue: none`.

### Confidence
- Start high; drop to medium on mixed signals; low on red zone or conflicts (e.g., controller helper that looks pure).
