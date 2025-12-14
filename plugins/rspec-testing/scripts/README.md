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
  {metadata_path} --structure-mode={full|blocks} \
  [--shared-examples-threshold=3]
```

**Inputs:** metadata file with `methods[].characteristics[]`, `behaviors[]`, `methods[].side_effects[]`.

**Rules:**
- Leaf = value with `behavior_id` (terminal or success). Intermediate values have no `behavior_id`.
- Stop branching on `terminal: true`.
- Order values per characteristic: non-terminal first, terminal last; for boolean/presence put true/present first; enum/range/sequential keep incoming order.
- Context words: level 1 → `when`; boolean/presence happy → `with`, alternatives → `but`/`without`; enum/sequential → `and`; range (2 values) → `with`/`but`.
- In leaf contexts: side-effect `it` blocks first, then success/terminal `it` from leaf `behavior_id`.
- Prints machine-readable markers in the skeleton (see `plugins/rspec-testing/docs/placeholder-contract.md`).
- May deduplicate repeated `(behavior_id, kind)` within a single method into `shared_examples` + `it_behaves_like` when count >= threshold (default: 3):
  - Template marker: `# rspec-testing:example ... template="true" path=""` inside `shared_examples`
  - Include-site marker: `# rspec-testing:example ... path="..."` directly above `it_behaves_like`

Exit codes: 0 success, 1 error, 2 warning (output still readable).

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

- Both inputs must contain method markers:
  - `# rspec-testing:method_begin ... method_id="..."`
  - `# rspec-testing:method_end ... method_id="..."`
- Replacement happens **strictly within** `method_begin`/`method_end` (describe header and closing `end` remain intact).
- Insert is deterministic:
  - If spec already has method blocks → insert after the last existing method block
  - Otherwise → insert before the last `end` in the file (expected top-level `RSpec.describe` end)

**Conflict handling (insert mode):**

- Default: conflict is an error (exit code `2`)
- Optional: `--on-conflict overwrite` or `--on-conflict skip`

Exit codes: 0 success, 1 error, 2 conflict (needs decision).
