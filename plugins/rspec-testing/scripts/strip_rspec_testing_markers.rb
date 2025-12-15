#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

MARKER_RE = /^\s*#\s*rspec-testing:\w+\b/.freeze

options = { spec: nil }

OptionParser.new do |opts|
  opts.banner = 'Usage: strip_rspec_testing_markers.rb --spec PATH'
  opts.on('--spec PATH', 'Path to spec file to modify in-place') { |v| options[:spec] = v }
end.parse!

if options[:spec].nil? || options[:spec].strip.empty?
  warn 'Error: --spec is required'
  exit 1
end

spec_path = options[:spec]

unless File.exist?(spec_path)
  warn "Error: Spec file not found: #{spec_path}"
  exit 1
end

lines = File.read(spec_path, mode: 'r:BOM|UTF-8').split("\n", -1)
filtered = lines.reject { |line| line.match?(MARKER_RE) }

File.write(spec_path, filtered.join("\n") + "\n")
puts 'OK'
