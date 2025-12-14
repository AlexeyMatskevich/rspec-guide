---
description: Shared output-validation protocol for rspec-testing metadata/spec artifacts.
---

# Shared Metadata Self-Check (Output Validation)

Use this as the **last step** of any agent that writes metadata and/or spec artifacts.

## Goal

- Keep the pipeline fail-fast (no orchestrator retries).
- Let the agent correct its **own output** deterministically before returning `status: success`.
- Keep validation logic in `plugins/rspec-testing/scripts/`, not in generators.

## How to Run

1. Validate YAML parses:

```bash
ruby ../scripts/validate_yaml.rb "{metadata_file}"
```

2. Validate stage invariants:

```bash
ruby ../scripts/validate_metadata_stage.rb \
  --stage "{stage}" \
  --metadata "{metadata_file}"
```

Where:

- `{stage}` is one of: `discovery-agent`, `code-analyzer`, `isolation-decider`, `test-architect`, `test-implementer`
- `{metadata_file}` is: `{metadata_path}/rspec_metadata/{slug}.yml`

## Self-Check Loop (Max 2 Passes)

- If validator exits `0`: OK → finish.
- If validator exits `1`: fix output (metadata/spec) and retry (max 2 total attempts).
- If still failing after 2 attempts: return `status: error` and include the validator output.
- If validator exits `2` (warnings):
  - Use AskUserQuestion:
    - “Proceed anyway”
    - “Pause and reduce scope”
  - If user chooses pause: return `status: error` and include the warning list.

## TodoWrite Placement

Add a final step like:

- `[Phase X] Self-check output (validate_metadata_stage)`

This step must be the last one before returning success.

