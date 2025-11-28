#!/usr/bin/env bash
# Check if spec file exists for each source file
# Usage: echo "app/services/foo.rb" | ./check-spec-exists.sh
#
# Input: Newline-separated file paths (stdin)
# Output: NDJSON with file path and spec status
#
# Mapping rules:
#   app/models/user.rb      -> spec/models/user_spec.rb
#   app/services/foo.rb     -> spec/services/foo_spec.rb
#   app/controllers/foo.rb  -> spec/controllers/foo_spec.rb OR spec/requests/foo_spec.rb
#   lib/bar/baz.rb          -> spec/lib/bar/baz_spec.rb

set -euo pipefail

while IFS= read -r file || [[ -n "$file" ]]; do
  spec_path=""

  if [[ "$file" =~ ^app/(.+)\.rb$ ]]; then
    spec_path="spec/${BASH_REMATCH[1]}_spec.rb"
  elif [[ "$file" =~ ^lib/(.+)\.rb$ ]]; then
    spec_path="spec/lib/${BASH_REMATCH[1]}_spec.rb"
  fi

  # Check if spec exists
  if [[ -n "$spec_path" && -f "$spec_path" ]]; then
    spec_exists="true"
  else
    spec_exists="false"
  fi

  # Output as JSON
  echo "{\"file\":\"$file\",\"spec_exists\":$spec_exists,\"spec_path\":\"$spec_path\"}"
done
