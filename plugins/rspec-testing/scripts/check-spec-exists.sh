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
#   app/controllers/foo_controller.rb  -> spec/requests/foo_spec.rb (preferred) + spec/controllers/foo_controller_spec.rb (legacy)
#   lib/bar/baz.rb          -> spec/lib/bar/baz_spec.rb

set -euo pipefail

while IFS= read -r file || [[ -n "$file" ]]; do
  # Controllers: prefer request specs for new work, but also report legacy controller specs.
  if [[ "$file" =~ ^app/controllers/(.+)\.rb$ ]]; then
    rel="${BASH_REMATCH[1]}"
    rel_dir="$(dirname "$rel")"
    filename="$(basename "$rel")"

    request_name="${filename%_controller}"
    if [[ "$rel_dir" == "." ]]; then
      preferred_spec_path="spec/requests/${request_name}_spec.rb"
    else
      preferred_spec_path="spec/requests/${rel_dir}/${request_name}_spec.rb"
    fi
    legacy_spec_path="spec/controllers/${rel}_spec.rb"

    if [[ -f "$preferred_spec_path" ]]; then
      preferred_exists="true"
    else
      preferred_exists="false"
    fi

    if [[ -f "$legacy_spec_path" ]]; then
      legacy_exists="true"
    else
      legacy_exists="false"
    fi

    # Back-compat fields: spec_path/spec_exists point at the preferred request spec.
    spec_path="$preferred_spec_path"
    spec_exists="$preferred_exists"

    echo "{\"file\":\"$file\",\"spec_exists\":$spec_exists,\"spec_path\":\"$spec_path\",\"preferred_spec_path\":\"$preferred_spec_path\",\"preferred_exists\":$preferred_exists,\"legacy_spec_path\":\"$legacy_spec_path\",\"legacy_exists\":$legacy_exists}"
    continue
  fi

  spec_path=""
  if [[ "$file" =~ ^app/(.+)\.rb$ ]]; then
    spec_path="spec/${BASH_REMATCH[1]}_spec.rb"
  elif [[ "$file" =~ ^lib/(.+)\.rb$ ]]; then
    spec_path="spec/lib/${BASH_REMATCH[1]}_spec.rb"
  fi

  if [[ -n "$spec_path" && -f "$spec_path" ]]; then
    spec_exists="true"
  else
    spec_exists="false"
  fi

  echo "{\"file\":\"$file\",\"spec_exists\":$spec_exists,\"spec_path\":\"$spec_path\"}"
done
