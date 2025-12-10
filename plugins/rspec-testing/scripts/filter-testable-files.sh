#!/usr/bin/env bash
# Filter NDJSON file list to only testable Ruby files
# Usage: ./get-changed-files-with-status.sh --branch | ./filter-testable-files.sh
#
# Input: NDJSON with path and status
#   {"path":"app/models/user.rb","status":"M"}
#
# Includes: .rb files in app/, lib/
# Excludes: _spec.rb, db/migrate/, config/, bin/, vendor/
#
# Output: Filtered NDJSON (same format as input)

set -euo pipefail

while IFS= read -r line; do
  # Extract path from JSON (simple pattern match, no jq dependency)
  path=$(echo "$line" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')

  # Skip non-.rb files
  [[ "$path" != *.rb ]] && continue

  # Skip spec files
  [[ "$path" == *_spec.rb ]] && continue

  # Skip excluded directories
  [[ "$path" == db/migrate/* ]] && continue
  [[ "$path" == config/* ]] && continue
  [[ "$path" == bin/* ]] && continue
  [[ "$path" == script/* ]] && continue
  [[ "$path" == vendor/* ]] && continue

  # Pass through the full JSON object
  echo "$line"
done
