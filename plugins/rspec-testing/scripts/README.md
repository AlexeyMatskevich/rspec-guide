# RSpec Testing Plugin — Shell Scripts

Deterministic shell scripts for routine operations. Agents call these to avoid spending tokens on algorithmic tasks.

## Scripts

### get-changed-files.sh

Get list of changed files from git.

```bash
# Branch mode (vs main/master)
./get-changed-files.sh --branch

# Staged files only
./get-changed-files.sh --staged

# Single file (verifies existence)
./get-changed-files.sh app/services/foo.rb
```

### filter-testable-files.sh

Filter file list to only testable Ruby files.

```bash
# Pipe from get-changed-files
./get-changed-files.sh --branch | ./filter-testable-files.sh
```

**Includes:** `.rb` files in `app/`, `lib/`

**Excludes:** `_spec.rb`, `db/migrate/`, `config/`, `bin/`, `vendor/`

### check-spec-exists.sh

Check if spec file exists for each source file.

```bash
echo "app/services/foo.rb" | ./check-spec-exists.sh
# Output: {"file":"app/services/foo.rb","spec_exists":false,"spec_path":"spec/services/foo_spec.rb"}
```

Rails controllers emit additional fields to support request-spec preference + legacy detection:

```bash
echo "app/controllers/api/v1/users_controller.rb" | ./check-spec-exists.sh
# Output:
# {"file":"app/controllers/api/v1/users_controller.rb","spec_exists":false,"spec_path":"spec/requests/api/v1/users_spec.rb","preferred_spec_path":"spec/requests/api/v1/users_spec.rb","preferred_exists":false,"legacy_spec_path":"spec/controllers/api/v1/users_controller_spec.rb","legacy_exists":true}
```

- `spec_path` / `spec_exists` point to the **preferred request spec** (back-compat).
- `preferred_*` describe the request spec path and existence.
- `legacy_*` describe the controller spec path and existence.

### validate_yaml.rb

Validate that YAML parses.

```bash
ruby validate_yaml.rb tmp/rspec_metadata/app_services_payment.yml
echo "foo: bar" | ruby validate_yaml.rb --stdin
```

Exit codes: 0 OK, 1 invalid YAML.

### validate_metadata_stage.rb

Validate metadata invariants for a pipeline stage.

```bash
ruby validate_metadata_stage.rb --stage=code-analyzer --metadata tmp/rspec_metadata/app_services_payment.yml
```

Exit codes:

- `0` OK
- `1` invalid (fail-fast)
- `2` warnings (e.g., combinatorial explosion → AskUserQuestion recommended)

### derive_test_config.rb

Derive `methods[].test_config` (test level + isolation knobs) deterministically from metadata.

```bash
ruby derive_test_config.rb \
  --metadata tmp/rspec_metadata/app_services_payment.yml \
  --project-type rails \
  --format json
```

**Outputs** (JSON):

- `status: success` — metadata updated in-place (`methods[].test_config`, `automation.isolation_decider_completed: true`)
- `status: needs_decision` (exit code `2`) — user choice required for low-confidence methods:
  - `decisions[]` contains one decision with choices:
    - `--low-confidence=unit`
    - `--low-confidence=integration`
    - `--low-confidence=request` (controllers only)

Re-run once with the chosen flag:

```bash
ruby derive_test_config.rb \
  --metadata tmp/rspec_metadata/app_services_payment.yml \
  --project-type rails \
  --format json \
  --low-confidence=integration
```

Exit codes: `0` success, `1` error, `2` needs decision.

### strip_rspec_testing_markers.rb

Remove all temporary `# rspec-testing:*` markers from a spec file.

```bash
ruby strip_rspec_testing_markers.rb --spec spec/services/payment_processor_spec.rb
```

Exit codes: 0 OK, 1 error.

## Composition Example

Full discovery pipeline:

```bash
./get-changed-files.sh --branch \
  | ./filter-testable-files.sh \
  | ./check-spec-exists.sh
```

Output (NDJSON):
```json
{"file":"app/models/payment.rb","spec_exists":true,"spec_path":"spec/models/payment_spec.rb"}
{"file":"app/services/payment_processor.rb","spec_exists":false,"spec_path":"spec/services/payment_processor_spec.rb"}
```

## Conventions

- **Input:** stdin or arguments
- **Output:** JSON/NDJSON for structured data, plain text for simple lists
- **Exit codes:** 0=success, 1=error
- **Composable:** Works with pipes (`|`)
- **No AI judgment:** Pure algorithmic operations only

## spec_structure_generator.rb (contract)

Builds RSpec context/it skeletons from metadata.

**Usage:**
```bash
ruby plugins/rspec-testing/scripts/spec_structure_generator.rb \
  {metadata_path} --structure-mode={full|blocks|outline} \
  [--shared-examples-threshold=3]
```

Outline from an existing (patched/edited) spec file:

```bash
ruby plugins/rspec-testing/scripts/spec_structure_generator.rb \
  --outline-spec {spec_path} \
  [--only {method_id}]
```

**Inputs:** metadata file with `methods[].characteristics[]`, `behaviors[]`, `methods[].side_effects[]`.

**Rules:**
- Leaf = value with `behavior_id` (terminal or success). Intermediate values have no `behavior_id`.
- Stop branching on `terminal: true`.
- Order values per characteristic: non-terminal first, terminal last; for boolean/presence put true/present first; enum/range/sequential keep incoming order.
- Context words: level 1 → `when`; binary happy → `with`; boolean/range(2) alternatives → `but`; presence alternatives → `without` if description is absence-friendly, else `but`; enum/sequential/range(>2) → `and`.
- In leaf contexts: side-effect `it` blocks first, then success/terminal `it` from leaf `behavior_id`.
- Prints machine-readable markers in the skeleton (see `plugins/rspec-testing/docs/placeholder-contract.md`).
- May deduplicate repeated `(behavior_id, kind)` within a single method into `shared_examples` + `it_behaves_like` when count >= threshold (default: 3):
  - Template marker: `# rspec-testing:example ... template="true" path=""` inside `shared_examples`
  - Include-site marker: `# rspec-testing:example ... path="..."` directly above `it_behaves_like`
- Outline mode prints a condensed preview (only `RSpec.describe` / `describe` / `context` / `it` / `end` lines).

Exit codes: 0 success, 1 error, 2 warning (output still readable).

## materialize_spec_skeleton.rb (contract)

Materialize a spec skeleton file from metadata:

- For **Rails** projects: uses `bundle exec rails generate rspec:*` for supported file types to create the base spec file when missing, then prunes it to a clean wrapper.
- For **non-Rails** (or unsupported types): creates a minimal wrapper file.
- Patches method blocks deterministically (insert/upsert based on `method_mode`), including rspec-testing markers for placeholder mapping.
- Returns a condensed outline for approval.

**Usage:**

```bash
ruby plugins/rspec-testing/scripts/materialize_spec_skeleton.rb \
  --metadata {metadata_path}/rspec_metadata/{slug}.yml
```

**Decisions (exit code `2`):**

- The script returns `status: needs_decision` with `decisions[]` (one or more items).
- Controllers:
  - ask-policy (legacy exists, request missing): re-run with `--controllers-choice=request` or `--controllers-choice=controller`
  - ask-policy (both request + legacy exist): re-run with `--controllers-choice=request` or `--controllers-choice=controller`
  - legacy cleanup (request spec path selected and legacy exists): re-run with `--controllers-legacy=keep` or `--controllers-legacy=delete`
- New method conflict(s): re-run with one flag per conflict:
  - `--new-conflict="{method_id}=overwrite"` or `--new-conflict="{method_id}=skip"`

Exit codes: 0 success, 1 error, 2 needs decision.

## apply_method_blocks.rb (contract)

Apply generated method blocks (from `--structure-mode=blocks`) to an existing spec file using `method_begin` / `method_end` markers.

**Usage:**

```bash
ruby plugins/rspec-testing/scripts/apply_method_blocks.rb \
  --spec {spec_file_path} \
  --blocks {blocks_file_path} \
  --mode {insert|replace|upsert}
```

**Requirements:**

- Blocks input must contain method markers:
  - `# rspec-testing:method_begin ... method_id="..."`
  - `# rspec-testing:method_end ... method_id="..."`
- Target spec file may have markers (skeleton) OR be marker-free (final form).
- Replacement preserves the existing `describe ... do` line and its closing `end`.
  - If target has markers: boundaries come from `method_begin`/`method_end`.
  - If target has no markers: boundaries are inferred from the `describe '#method' do` / `describe '.method' do` block.
- Insert is deterministic:
  - If spec already has method blocks → insert after the last existing method block
  - Otherwise → insert before the last `end` in the file (expected top-level `RSpec.describe` end)

**Conflict handling (insert mode):**

- Default: conflict is an error (exit code `2`)
- Optional: `--on-conflict overwrite` or `--on-conflict skip`

Exit codes: 0 success, 1 error, 2 conflict (needs decision).
