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
