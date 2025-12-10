#!/usr/bin/env bash
# Get list of changed files with their git status
# Usage: ./get-changed-files-with-status.sh [--branch|--staged|FILE_PATH]
#
# Discovery modes:
#   --branch    Files changed on current branch vs main/master
#   --staged    Staged files only
#   FILE_PATH   Single file (verifies existence)
#
# Output: NDJSON (newline-delimited JSON)
#   {"path":"app/models/user.rb","status":"M"}
#   {"path":"app/models/payment.rb","status":"A"}
#   {"path":"app/models/old.rb","status":"D"}
#
# Status codes: A=added, M=modified, D=deleted, R=renamed
# Exit codes: 0=success, 1=error

set -euo pipefail

discovery_mode="${1:-}"

# Convert git diff --name-status output to NDJSON
format_as_ndjson() {
  while IFS=$'\t' read -r status path; do
    # Handle renamed files (R100	old_path	new_path)
    if [[ "$status" =~ ^R ]]; then
      # For renames, use new path and treat as modified
      path=$(echo "$path" | cut -f2)
      status="M"
    fi
    # Extract first character for status (handles R100, etc.)
    status="${status:0:1}"
    echo "{\"path\":\"$path\",\"status\":\"$status\"}"
  done
}

case "$discovery_mode" in
  --branch)
    # Detect default branch (main or master)
    base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    git diff "$base"...HEAD --name-status | format_as_ndjson
    ;;
  --staged)
    git diff --cached --name-status | format_as_ndjson
    ;;
  "")
    echo "Error: discovery_mode required (--branch, --staged, or file path)" >&2
    exit 1
    ;;
  *)
    # Single file mode - verify exists, return as modified
    if [[ -f "$discovery_mode" ]]; then
      echo "{\"path\":\"$discovery_mode\",\"status\":\"M\"}"
    else
      echo "Error: File not found: $discovery_mode" >&2
      exit 1
    fi
    ;;
esac
