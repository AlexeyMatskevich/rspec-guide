# `/rspec-init` Contract

This document defines what `/rspec-init` creates and the meaning of fields in `.claude/rspec-testing-config.yml`.

## Artifacts

`/rspec-init` must create:

- `.claude/rspec-testing-config.yml` — plugin configuration (YAML)
- `{metadata_path}/` — directory for pipeline artifacts (written by agents)

## Config Schema (`.claude/rspec-testing-config.yml`)

All paths are **project-root relative** (no absolute `/home/...` paths).

### Top-Level

| Field | Type | Meaning |
| --- | --- | --- |
| `ruby_version` | string | Detected Ruby version (informational). |
| `project_type` | string | One of: `library`, `rails`, `web`, `service`. |
| `factory_gem` | string | One of: `factory_bot`, `fabrication`, `none`. |
| `linter` | string | One of: `rubocop`, `standardrb`, `none`. |
| `metadata_path` | string | Base directory for metadata/artifacts (e.g. `tmp` or `.claude/metadata`). |
| `initialized_at` | string | Timestamp string (informational). |

### `rspec`

| Field | Type | Meaning |
| --- | --- | --- |
| `rspec.version` | string | Detected RSpec version (informational). |
| `rspec.helper` | string | One of: `rails_helper`, `spec_helper`. |

### `directories`

| Field | Type | Meaning |
| --- | --- | --- |
| `directories.spec` | string | Specs root directory (usually `spec`). |
| `directories.factories` | string | Factories directory (usually `spec/factories`). |
| `directories.support` | string | Support directory (usually `spec/support`). |

### `rails.controllers`

Applies only when `project_type: rails`.

| Field | Type | Meaning |
| --- | --- | --- |
| `rails.controllers.spec_policy` | string | One of: `request`, `controller`, `ask`. |

**Semantics**:

- `request` — controller tests are written as request specs under `spec/requests/**`. If legacy controller specs under `spec/controllers/**` exist, the pipeline treats them as migration targets (architect deletes them as part of migration).
- `controller` — if a legacy `spec/controllers/**` exists for a controller file, update it; otherwise create a request spec.
- `ask` — if a legacy controller spec exists but a request spec does not, ask the user per-controller whether to migrate to request spec or keep updating the controller spec.

## Output Payload (command result)

`/rspec-init` returns a small YAML payload with detected values and the config file path.
It must include the chosen controllers policy (for Rails projects) so downstream orchestration can be deterministic.
