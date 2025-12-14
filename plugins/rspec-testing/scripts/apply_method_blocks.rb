#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'json'

class MarkerParseError < StandardError; end
class BlockParseError < StandardError; end
class ApplyError < StandardError; end
class ConflictError < ApplyError; end

module Marker
  METHOD_BEGIN_RE = /^\s*#\s*rspec-testing:method_begin\b/
  METHOD_END_RE = /^\s*#\s*rspec-testing:method_end\b/
  ATTR_RE = /(\w+)="((?:\\.|[^"\\])*)"/

  def self.extract_attrs(line)
    attrs = {}
    line.scan(ATTR_RE) do |key, raw|
      attrs[key] = unescape(raw)
    end
    attrs
  end

  def self.unescape(str)
    str.gsub('\\\\', '\\').gsub('\\"', '"')
  end
end

module Lines
  def self.read(path)
    File.read(path, mode: 'r:BOM|UTF-8').split("\n", -1)
  end

  def self.write(path, lines)
    File.write(path, lines.join("\n") + "\n")
  end

  def self.find_prev_nonblank(lines, from_index)
    i = from_index
    while i >= 0
      return i unless lines[i].strip.empty?
      i -= 1
    end
    nil
  end

  def self.find_next_nonblank(lines, from_index)
    i = from_index
    while i < lines.length
      return i unless lines[i].strip.empty?
      i += 1
    end
    nil
  end
end

class MethodBlocks
  # Extract method blocks from a text that contains method_begin/method_end markers.
  # For each method_id, returns:
  # - begin_idx, end_idx (marker lines, inclusive)
  # - open_idx, close_idx (describe line to the closing end line, inclusive)
  def self.extract(lines)
    blocks = {}
    i = 0
    while i < lines.length
      line = lines[i]
      unless line.match?(Marker::METHOD_BEGIN_RE)
        i += 1
        next
      end

      begin_attrs = Marker.extract_attrs(line)
      method_id = begin_attrs['method_id']
      raise BlockParseError, "method_begin missing method_id at line #{i + 1}" if method_id.nil? || method_id.strip.empty?
      raise BlockParseError, "Duplicate method_id in input: #{method_id}" if blocks.key?(method_id)

      begin_idx = i
      end_idx = find_matching_end(lines, begin_idx, method_id)

      open_idx = Lines.find_prev_nonblank(lines, begin_idx - 1)
      raise BlockParseError, "Cannot find describe line for #{method_id} before line #{begin_idx + 1}" if open_idx.nil?
      raise BlockParseError, "Expected describe line before method_begin for #{method_id} at line #{open_idx + 1}" unless lines[open_idx].lstrip.start_with?('describe ')

      close_idx = Lines.find_next_nonblank(lines, end_idx + 1)
      raise BlockParseError, "Cannot find closing end line for #{method_id} after line #{end_idx + 1}" if close_idx.nil?
      raise BlockParseError, "Expected closing 'end' after method_end for #{method_id} at line #{close_idx + 1}" unless lines[close_idx].strip == 'end'

      blocks[method_id] = {
        method_id: method_id,
        begin_idx: begin_idx,
        end_idx: end_idx,
        open_idx: open_idx,
        close_idx: close_idx
      }

      i = end_idx + 1
    end

    blocks
  end

  def self.find_matching_end(lines, begin_idx, method_id)
    j = begin_idx + 1
    while j < lines.length
      if lines[j].match?(Marker::METHOD_END_RE)
        end_attrs = Marker.extract_attrs(lines[j])
        end_method_id = end_attrs['method_id']
        raise BlockParseError, "method_end missing method_id at line #{j + 1}" if end_method_id.nil? || end_method_id.strip.empty?
        raise BlockParseError, "method_end method_id mismatch (begin=#{method_id}, end=#{end_method_id}) at line #{j + 1}" if end_method_id != method_id
        return j
      end
      j += 1
    end
    raise BlockParseError, "Missing method_end for #{method_id} (begin at line #{begin_idx + 1})"
  end
end

class ApplyMethodBlocks
  MODES = %w[insert replace upsert].freeze
  CONFLICT_POLICIES = %w[error overwrite skip].freeze

  def initialize(spec_path:, blocks_path:, mode:, conflict:, only_method_ids:, format:, in_place:)
    @spec_path = spec_path
    @blocks_path = blocks_path
    @mode = mode
    @conflict = conflict
    @only_method_ids = only_method_ids
    @format = format
    @in_place = in_place
  end

  def run
    spec_lines = Lines.read(@spec_path)
    blocks_lines = Lines.read(@blocks_path)

    spec_blocks = MethodBlocks.extract(spec_lines)
    source_blocks = MethodBlocks.extract(blocks_lines)

    selected_method_ids = if @only_method_ids.empty?
                            source_blocks.keys
                          else
                            @only_method_ids
                          end

    missing_in_source = selected_method_ids.reject { |id| source_blocks.key?(id) }
    raise ApplyError, "Requested method_id(s) not found in blocks input: #{missing_in_source.join(', ')}" unless missing_in_source.empty?

    operations = []

    selected_method_ids.each do |method_id|
      has_target = spec_blocks.key?(method_id)
      operation = decide_operation(method_id, has_target)
      operations << operation
    end

    result = {
      spec_path: @spec_path,
      blocks_path: @blocks_path,
      mode: @mode,
      conflict: @conflict,
      operations: []
    }

    # Apply in the order provided by blocks input (stable + deterministic)
    selected_method_ids.each do |method_id|
      op = operations.find { |o| o[:method_id] == method_id }
      action = op[:action]

      case action
      when 'skip'
        result[:operations] << op.merge(status: 'skipped')
      when 'insert'
        spec_lines = insert_block(spec_lines, spec_blocks, blocks_lines, source_blocks[method_id])
        spec_blocks = MethodBlocks.extract(spec_lines)
        result[:operations] << op.merge(status: 'inserted')
      when 'replace'
        spec_lines = replace_block_inner(spec_lines, blocks_lines, spec_blocks[method_id], source_blocks[method_id])
        spec_blocks = MethodBlocks.extract(spec_lines)
        result[:operations] << op.merge(status: 'replaced')
      else
        raise ApplyError, "Unknown action: #{action}"
      end
    end

    if @in_place
      Lines.write(@spec_path, spec_lines)
    else
      puts spec_lines.join("\n")
    end

    print_result(result)
    0
  rescue ConflictError => e
    warn "Conflict: #{e.message}"
    2
  rescue ApplyError, BlockParseError, MarkerParseError => e
    warn "Error: #{e.message}"
    1
  rescue StandardError => e
    warn "Error: #{e.class}: #{e.message}"
    1
  end

  private

  def decide_operation(method_id, has_target)
    case @mode
    when 'insert'
      if has_target
        case @conflict
        when 'overwrite' then { method_id: method_id, action: 'replace', reason: 'conflict_overwrite' }
        when 'skip' then { method_id: method_id, action: 'skip', reason: 'conflict_skip' }
        else
          raise ConflictError, "target spec already contains method_id=#{method_id}"
        end
      else
        { method_id: method_id, action: 'insert' }
      end
    when 'replace'
      raise ApplyError, "Missing target block for replace: method_id=#{method_id}" unless has_target
      { method_id: method_id, action: 'replace' }
    when 'upsert'
      { method_id: method_id, action: (has_target ? 'replace' : 'insert') }
    else
      raise ApplyError, "Unknown mode: #{@mode}"
    end
  end

  def insert_block(spec_lines, spec_blocks, blocks_lines, source_block)
    block_lines = blocks_lines[source_block[:open_idx]..source_block[:close_idx]]

    insertion_index = insertion_point(spec_lines, spec_blocks)

    new_lines = spec_lines.dup
    new_lines.insert(insertion_index, *([''] + block_lines))
    new_lines
  end

  def insertion_point(spec_lines, spec_blocks)
    if spec_blocks.empty?
      # Insert before the last `end` in the file (expected to be the top-level RSpec.describe end).
      last_end = spec_lines.rindex { |l| l.strip == 'end' }
      raise ApplyError, "Cannot find insertion point: no 'end' found in #{@spec_path}" if last_end.nil?
      last_end
    else
      # Insert after the last method block closing `end`.
      last_close = spec_blocks.values.map { |b| b[:close_idx] }.max
      last_close + 1
    end
  end

  def replace_block_inner(spec_lines, blocks_lines, target_block, source_block)
    target_begin = target_block[:begin_idx]
    target_end = target_block[:end_idx]
    source_inner = blocks_lines[source_block[:begin_idx]..source_block[:end_idx]]

    new_lines = spec_lines.dup
    new_lines[target_begin..target_end] = source_inner
    new_lines
  end

  def print_result(result)
    case @format
    when 'json'
      warn(JSON.pretty_generate(result))
    else
      result[:operations].each do |op|
        reason = op[:reason] ? " (#{op[:reason]})" : ''
        warn "#{op[:status]}: #{op[:method_id]}#{reason}"
      end
    end
  end
end

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
  opts.on('--mode MODE', ApplyMethodBlocks::MODES, 'Mode: insert, replace, upsert') { |v| options[:mode] = v }
  opts.on('--on-conflict POLICY', ApplyMethodBlocks::CONFLICT_POLICIES, 'Conflict policy for insert: error, overwrite, skip') { |v| options[:conflict] = v }
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

exit(
  ApplyMethodBlocks.new(
    spec_path: options[:spec],
    blocks_path: options[:blocks],
    mode: options[:mode],
    conflict: options[:conflict],
    only_method_ids: options[:only],
    format: options[:format],
    in_place: options[:in_place]
  ).run
)
