#!/usr/bin/env bash
# Filter file list to only testable Ruby files
# Usage: cat files.txt | ./filter-testable-files.sh
#
# Includes: .rb files in app/, lib/
# Excludes: _spec.rb, db/migrate/, config/, bin/, vendor/
#
# Output: Filtered file paths (stdout)

set -euo pipefail

grep '\.rb$' \
  | grep -v '_spec\.rb$' \
  | grep -v '^db/migrate/' \
  | grep -v '^config/' \
  | grep -v '^bin/' \
  | grep -v '^script/' \
  | grep -v '^vendor/' \
  || true  # Don't fail if no matches
