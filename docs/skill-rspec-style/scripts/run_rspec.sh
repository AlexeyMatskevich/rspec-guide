#!/bin/bash

# RSpec runner script for test execution
# This script runs RSpec with helpful formatting and options

# Note: We don't use 'set -e' here because we want to capture
# the exit code and provide helpful messages on failure

echo "🧪 Running RSpec tests..."
echo "========================="
echo ""

# Default options for better output
RSPEC_OPTIONS="--format documentation --color"

# Add coverage if SimpleCov is available
if [ -f ".simplecov" ] || grep -q "simplecov" Gemfile 2>/dev/null; then
    echo "📊 Coverage reporting enabled"
    export COVERAGE=true
fi

# Check if we're in a bundled environment
if [ -f "Gemfile" ]; then
    echo "📦 Using Bundler..."
    echo ""

    # Run RSpec with bundle exec and capture exit code
    bundle exec rspec $RSPEC_OPTIONS "$@"
    EXIT_CODE=$?
else
    echo "📦 Running without Bundler..."
    echo ""

    rspec $RSPEC_OPTIONS "$@"
    EXIT_CODE=$?
fi

echo ""
echo "========================="

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"

    # Show coverage summary if available
    if [ -d "coverage" ]; then
        echo ""
        echo "📊 Coverage report available at: coverage/index.html"
    fi
else
    echo "❌ Some tests failed"
    echo ""
    echo "To run a specific test file:"
    echo "  bundle exec rspec spec/path/to/file_spec.rb"
    echo ""
    echo "To run tests matching a pattern:"
    echo "  bundle exec rspec -e 'pattern'"
    echo ""
    echo "For faster feedback during development:"
    echo "  bundle exec rspec --fail-fast"
fi

exit $EXIT_CODE