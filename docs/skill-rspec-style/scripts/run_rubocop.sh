#!/bin/bash

# RuboCop runner script for RSpec Style Guide validation
# This script runs RuboCop with all necessary flags for style guide compliance

# Note: We don't use 'set -e' here because we want to capture
# the exit code and provide helpful messages when offenses are found

echo "🔍 Running RuboCop with RSpec Style Guide rules..."
echo "================================================"

# Check if we're in a bundled environment
if [ -f "Gemfile" ]; then
    echo "📦 Using Bundler..."

    # Check if rubocop-rspec-guide is in Gemfile
    if ! grep -q "rubocop-rspec-guide" Gemfile Gemfile.lock 2>/dev/null; then
        echo "⚠️  Warning: rubocop-rspec-guide gem not found in Gemfile"
        echo "   Add to Gemfile: gem 'rubocop-rspec-guide', group: :development"
    fi

    # Run RuboCop with bundle exec and capture exit code
    bundle exec rubocop \
        --display-style-guide \
        --extra-details \
        --display-cop-names \
        --parallel \
        spec/
    EXIT_CODE=$?
else
    echo "📦 Running without Bundler..."
    rubocop \
        --display-style-guide \
        --extra-details \
        --display-cop-names \
        --parallel \
        spec/
    EXIT_CODE=$?
fi

echo ""
echo "================================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ RuboCop: No offenses detected!"
    echo "   All tests comply with the RSpec Style Guide"
else
    echo "❌ RuboCop found style violations"
    echo ""
    echo "To auto-fix safe issues, run:"
    echo "  bundle exec rubocop -a"
    echo ""
    echo "For unsafe auto-fixes (review carefully):"
    echo "  bundle exec rubocop -A"
fi

exit $EXIT_CODE