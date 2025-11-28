#!/usr/bin/env bash
# Get list of changed files from git
# Usage: ./get-changed-files.sh [--branch|--staged|FILE_PATH]
#
# Modes:
#   --branch    Files changed on current branch vs main/master
#   --staged    Staged files only
#   FILE_PATH   Single file (verifies existence)
#
# Output: Newline-separated file paths (stdout)
# Exit codes: 0=success, 1=error

set -euo pipefail

mode="${1:-}"

case "$mode" in
  --branch)
    # Detect default branch (main or master)
    base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    git diff "$base"...HEAD --name-only
    ;;
  --staged)
    git diff --cached --name-only
    ;;
  "")
    echo "Error: Mode required (--branch, --staged, or file path)" >&2
    exit 1
    ;;
  *)
    # Single file mode - verify exists
    if [[ -f "$mode" ]]; then
      echo "$mode"
    else
      echo "Error: File not found: $mode" >&2
      exit 1
    fi
    ;;
esac
