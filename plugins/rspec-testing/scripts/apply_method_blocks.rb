#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'json'

require_relative 'lib/method_block_patcher'

options = {
  mode: 'upsert',
  conflict: 'error',
  only: [],
  format: 'text',
  in_place: true
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: apply_method_blocks.rb --spec SPEC --blocks BLOCKS [options]'

  opts.on('--spec PATH', 'Path to target spec file') { |v| options[:spec] = v }
  opts.on('--blocks PATH', 'Path to blocks file (generator --structure-mode=blocks output)') { |v| options[:blocks] = v }
  opts.on('--mode MODE', RspecTesting::MethodBlockPatcher::MODES, 'Mode: insert, replace, upsert') { |v| options[:mode] = v }
  opts.on('--on-conflict POLICY', RspecTesting::MethodBlockPatcher::CONFLICT_POLICIES, 'Conflict policy for insert: error, overwrite, skip') { |v| options[:conflict] = v }
  opts.on('--only METHOD_ID', 'Apply only for this method_id (repeatable)') { |v| options[:only] << v }
  opts.on('--format FORMAT', %w[text json], 'Output format: text or json (printed to stderr)') { |v| options[:format] = v }
  opts.on('--stdout', 'Write patched spec to stdout instead of in-place') { options[:in_place] = false }
end

parser.parse!

if options[:spec].nil? || options[:blocks].nil?
  warn 'Error: --spec and --blocks are required'
  warn parser
  exit 1
end

begin
  spec_lines = RspecTesting::Lines.read(options[:spec])
  blocks_lines = RspecTesting::Lines.read(options[:blocks])

  patcher = RspecTesting::MethodBlockPatcher.new(
    spec_lines: spec_lines,
    blocks_lines: blocks_lines,
    mode: options[:mode],
    conflict: options[:conflict],
    only_method_ids: options[:only],
    class_name: nil
  )

  new_lines, result = patcher.run

  if options[:in_place]
    RspecTesting::Lines.write(options[:spec], new_lines)
  else
    puts new_lines.join("\n")
  end

  case options[:format]
  when 'json'
    warn(JSON.pretty_generate(result.merge(spec_path: options[:spec], blocks_path: options[:blocks])))
  else
    result[:operations].each do |op|
      reason = op[:reason] ? " (#{op[:reason]})" : ''
      warn "#{op[:status]}: #{op[:method_id]}#{reason}"
    end
  end

  exit 0
rescue RspecTesting::ConflictError => e
  warn "Conflict: #{e.message}"
  exit 2
rescue RspecTesting::ApplyError, RspecTesting::BlockParseError, RspecTesting::MarkerParseError => e
  warn "Error: #{e.message}"
  exit 1
rescue StandardError => e
  warn "Error: #{e.class}: #{e.message}"
  exit 1
end
