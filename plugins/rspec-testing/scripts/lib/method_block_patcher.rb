#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ripper'

module RspecTesting
  class MarkerParseError < StandardError; end
  class BlockParseError < StandardError; end
  class ApplyError < StandardError; end
  class ConflictError < ApplyError; end

  module Marker
    METHOD_BEGIN_RE = /^\s*#\s*rspec-testing:method_begin\b/.freeze
    METHOD_END_RE = /^\s*#\s*rspec-testing:method_end\b/.freeze
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
    DESCRIBE_START_RE = /\A\s*describe(?:\s+|\s*\()/.freeze

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

        descriptor = begin_attrs['method']
        open_idx = find_describe_start(lines, begin_idx, descriptor)
        raise BlockParseError, "Cannot find describe line for #{method_id} before line #{begin_idx + 1}" if open_idx.nil?

        describe_indent = lines[open_idx][/^\s*/].length
        close_idx = find_closing_end(lines, end_idx + 1, describe_indent)
        raise BlockParseError, "Cannot find closing end line for #{method_id} after line #{end_idx + 1}" if close_idx.nil?

        blocks[method_id] = {
          method_id: method_id,
          descriptor: begin_attrs['method'],
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
          if end_method_id != method_id
            raise BlockParseError,
                  "method_end method_id mismatch (begin=#{method_id}, end=#{end_method_id}) at line #{j + 1}"
          end
          return j
        end
        j += 1
      end
      raise BlockParseError, "Missing method_end for #{method_id} (begin at line #{begin_idx + 1})"
    end

    def self.find_describe_start(lines, marker_idx, descriptor)
      marker_indent = lines[marker_idx][/^\s*/].length
      descriptor_re =
        if descriptor.nil? || descriptor.to_s.strip.empty?
          nil
        else
          /['"]#{Regexp.escape(descriptor)}['"]/
        end

      marker_idx.downto(0) do |i|
        line = lines[i]
        next unless line.match?(DESCRIBE_START_RE)
        next unless line[/^\s*/].length < marker_indent
        next if descriptor_re && !line.match?(descriptor_re)

        return i
      end

      nil
    end

    def self.find_closing_end(lines, from_idx, describe_indent)
      from_idx.upto(lines.length - 1) do |i|
        line = lines[i]
        next unless line.strip == 'end'

        return i if line[/^\s*/].length == describe_indent
      end

      nil
    end
  end

  module RubyBlocks
    OPENING_KEYWORDS = %w[do def class module if unless case begin while until for].freeze

    def self.find_block_end_line(code, start_line)
      tokens = Ripper.lex(code)
      started = false
      depth = 0

      tokens.each do |((line, _col), type, token, _state)|
        next if line < start_line

        case type
        when :on_kw
          if !started
            next unless token == 'do'
            started = true
            depth = 1
            next
          end

          if OPENING_KEYWORDS.include?(token)
            depth += 1
          elsif token == 'end'
            depth -= 1
            return line if depth.zero?
          end
        when :on_lbrace
          if !started
            started = true
            depth = 1
            next
          end
          depth += 1
        when :on_rbrace
          next unless started
          depth -= 1
          return line if depth.zero?
        end
      end

      raise BlockParseError, "Cannot find matching end for block starting at line #{start_line}"
    end
  end

  class DescribeMethodBlocks
    def self.extract(lines, descriptors_by_method_id)
      blocks = {}
      return blocks if descriptors_by_method_id.empty?

      code = lines.join("\n")

      descriptors_by_method_id.each do |method_id, descriptor|
        next if descriptor.nil? || descriptor.to_s.strip.empty?

        matches = find_describe_line_indexes(lines, descriptor)
        next if matches.empty?

        if matches.length > 1
          raise BlockParseError,
                "Multiple describe blocks found for method_id=#{method_id} (descriptor=#{descriptor})"
        end

        open_idx = matches.first
        end_line = RubyBlocks.find_block_end_line(code, open_idx + 1)
        close_idx = end_line - 1

        blocks[method_id] = {
          method_id: method_id,
          descriptor: descriptor,
          open_idx: open_idx,
          close_idx: close_idx
        }
      end

      blocks
    end

    def self.find_describe_line_indexes(lines, descriptor)
      re = describe_line_re(descriptor)
      lines.each_index.select { |idx| lines[idx].match?(re) }
    end

    def self.describe_line_re(descriptor)
      /\A\s*describe(?:\s+|\s*\()\s*['"]#{Regexp.escape(descriptor)}['"]\s*\)?\s*(do\b|\{)/
    end
  end

  class RSpecDescribeBlock
    def self.find(lines, class_name)
      return nil if class_name.nil? || class_name.to_s.strip.empty?

      re = /\A\s*RSpec\.describe\s+#{Regexp.escape(class_name)}\b/
      open_indexes = lines.each_index.select { |idx| lines[idx].match?(re) }
      return nil if open_indexes.empty?

      if open_indexes.length > 1
        raise BlockParseError, "Multiple RSpec.describe blocks found for class_name=#{class_name}"
      end

      open_idx = open_indexes.first
      code = lines.join("\n")
      end_line = RubyBlocks.find_block_end_line(code, open_idx + 1)
      close_idx = end_line - 1

      { open_idx: open_idx, close_idx: close_idx }
    end

    def self.find_any(lines)
      open_idx = lines.each_index.find { |idx| lines[idx].match?(/\A\s*RSpec\.describe\b/) }
      return nil if open_idx.nil?

      code = lines.join("\n")
      end_line = RubyBlocks.find_block_end_line(code, open_idx + 1)
      close_idx = end_line - 1

      { open_idx: open_idx, close_idx: close_idx }
    end
  end

  class MethodBlockPatcher
    MODES = %w[insert replace upsert].freeze
    CONFLICT_POLICIES = %w[error overwrite skip].freeze

    def initialize(spec_lines:, blocks_lines:, mode:, conflict:, only_method_ids:, class_name: nil)
      @spec_lines = spec_lines
      @blocks_lines = blocks_lines
      @mode = mode
      @conflict = conflict
      @only_method_ids = only_method_ids
      @class_name = class_name
    end

    def run
      source_blocks = MethodBlocks.extract(@blocks_lines)
      spec_blocks = build_target_blocks(@spec_lines, source_blocks)

      selected_method_ids = if @only_method_ids.empty?
                              source_blocks.keys
                            else
                              @only_method_ids
                            end

      missing_in_source = selected_method_ids.reject { |id| source_blocks.key?(id) }
      unless missing_in_source.empty?
        raise ApplyError, "Requested method_id(s) not found in blocks input: #{missing_in_source.join(', ')}"
      end

      operations = []
      selected_method_ids.each do |method_id|
        has_target = spec_blocks.key?(method_id)
        operations << decide_operation(method_id, has_target)
      end

      result = {
        mode: @mode,
        conflict: @conflict,
        operations: []
      }

      new_lines = @spec_lines.dup

      # Apply in the order provided by blocks input (stable + deterministic)
      selected_method_ids.each do |method_id|
        op = operations.find { |o| o[:method_id] == method_id }
        action = op[:action]

        case action
        when 'skip'
          result[:operations] << op.merge(status: 'skipped')
        when 'insert'
          new_lines = insert_block(new_lines, spec_blocks, @blocks_lines, source_blocks[method_id])
          spec_blocks = build_target_blocks(new_lines, source_blocks)
          result[:operations] << op.merge(status: 'inserted')
        when 'replace'
          new_lines = replace_block_body(new_lines, @blocks_lines, spec_blocks[method_id], source_blocks[method_id])
          spec_blocks = build_target_blocks(new_lines, source_blocks)
          result[:operations] << op.merge(status: 'replaced')
        else
          raise ApplyError, "Unknown action: #{action}"
        end
      end

      [new_lines, result]
    end

    private

    def build_target_blocks(spec_lines, source_blocks)
      marker_blocks = MethodBlocks.extract(spec_lines)
      descriptors_by_method_id = source_blocks.each_with_object({}) do |(method_id, block), acc|
        acc[method_id] = block[:descriptor]
      end
      describe_blocks = DescribeMethodBlocks.extract(spec_lines, descriptors_by_method_id)

      # Prefer marker-based blocks when both exist.
      describe_blocks.merge(marker_blocks)
    end

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
      method_block_closes = spec_blocks.values.map { |b| b[:close_idx] }.compact
      return method_block_closes.max + 1 unless method_block_closes.empty?

      rspec_block = RSpecDescribeBlock.find(spec_lines, @class_name)
      rspec_block ||= RSpecDescribeBlock.find_any(spec_lines)
      return rspec_block[:close_idx] if rspec_block

      # Last resort: insert before the last `end` in the file.
      last_end = spec_lines.rindex { |l| l.strip == 'end' }
      raise ApplyError, "Cannot find insertion point: no 'end' found" if last_end.nil?
      last_end
    end

    # Replace the inside of a method describe block, preserving the existing `describe ... do` line and its closing `end`.
    def replace_block_body(spec_lines, blocks_lines, target_block, source_block)
      target_open = target_block[:open_idx]
      target_close = target_block[:close_idx]
      raise ApplyError, 'Target block missing open_idx/close_idx' if target_open.nil? || target_close.nil?

      source_open = source_block[:open_idx]
      source_close = source_block[:close_idx]
      raise ApplyError, 'Source block missing open_idx/close_idx' if source_open.nil? || source_close.nil?

      source_body = blocks_lines[(source_open + 1)..(source_close - 1)] || []

      new_lines = spec_lines.dup
      insertion_start = target_open + 1
      insertion_end = target_close - 1

      if insertion_start <= insertion_end
        new_lines[insertion_start..insertion_end] = source_body
      else
        new_lines.insert(target_close, *source_body)
      end
      new_lines
    end
  end
end
