#!/usr/bin/env ruby
# frozen_string_literal: true

# spec_structure_generator.rb - Generate RSpec structure from metadata
#
# Transforms code-analyzer metadata into RSpec context hierarchy.
# Implements Rule 20 (context words) and terminal state handling.
#
# Behavior Bank Support:
#   - Reads `behaviors[]` array from metadata
#   - Resolves `behavior_id` references to descriptions
#   - Skips behaviors where `enabled: false`
#   - Falls back to inline `behavior` field for backwards compatibility
#
# Exit codes:
#   0 - Success
#   1 - Critical error (file not found, invalid YAML)
#   2 - Warning (empty characteristics, suspicious patterns)
#
# Usage:
#   ruby spec_structure_generator.rb <metadata_path> [--structure-mode=full|blocks]
#
# Output:
#   --structure-mode=full   → complete spec file skeleton (new spec file)
#   --structure-mode=blocks → describe/context blocks only (for insertion into existing spec)

require 'yaml'
require 'optparse'

# --- Configuration ---

NEGATIVE_PREFIXES = %w[not_ no_ invalid_ missing_ without_ un].freeze
POSITIVE_STATES = %w[true enabled authenticated active valid confirmed approved present].freeze

# --- Context Word Selection (Rule 20) ---

module ContextWords
  # Level 1 always uses 'when' (opens branch)
  # Binary: happy path (state_index 0) → 'with'
  #   - boolean/range(2): alternative → 'but'
  #   - presence: alternative → 'without' if description is absence-friendly, else 'but'
  # Enum/Range (3+): all use 'and'
  # Terminal states use same rules but generate no children

  ABSENCE_UNFRIENDLY_PATTERNS = [
    /\bnot\b/i,
    /\bwithout\b/i,
    /\bno\b/i,
    /\bempty\b/i,
    /\bmissing\b/i,
    /\binvalid\b/i,
    /\binsufficient\b/i,
    /\bblocked\b/i,
    /\bdenied\b/i,
    /\bfailed\b/i,
    /\berror\b/i
  ].freeze

  def self.absence_friendly_description?(text)
    str = text.to_s.strip
    return false if str.empty?

    ABSENCE_UNFRIENDLY_PATTERNS.none? { |re| str.match?(re) }
  end

  def self.determine(characteristic, _state_value, state_description, state_index, level)
    return 'when' if level == 1

    type = characteristic['type']
    values = characteristic['values'] || []

    case type
    when 'enum', 'sequential'
      'and'
    when 'boolean', 'presence'
      return 'with' if state_index.zero?

      if type == 'presence' && absence_friendly_description?(state_description)
        'without'
      else
        'but'
      end
    when 'range'
      values.length == 2 ? (state_index.zero? ? 'with' : 'but') : 'and'
    else
      '{CONTEXT_WORD}' # Placeholder for unknown types
    end
  end
end

# --- State Ordering (Happy Path First) ---

module StateOrdering
  # Reorder states so positive/happy path comes first
  # For boolean/presence: true/present first
  # For enum/range/sequential: keep original order (analyzer should order correctly)
  # Always place non-terminal values before terminal ones

  def self.order_values(characteristic)
    values = characteristic['values'] || []
    type = characteristic['type']

    non_terminal, terminal = values.partition { |v| v['terminal'] != true }

    ordered_non_terminal =
      if %w[boolean presence].include?(type)
        order_binary_values(non_terminal)
      else
        non_terminal # Keep original order for enum/range/sequential
      end

    ordered_non_terminal + terminal
  end

  def self.order_binary_values(values)
    return values if values.length != 2

    first_value = values[0]['value'].to_s

    # If first value is negative, swap
    if negative_value?(first_value)
      values.reverse
    else
      values
    end
  end

  def self.negative_value?(value)
    str = value.to_s.downcase
    NEGATIVE_PREFIXES.any? { |prefix| str.start_with?(prefix) } ||
      %w[false nil].include?(str)
  end
end

# --- Description Formatting ---

module DescriptionFormatter
  # Convert characteristic + value to readable context description
  # Binary: use value description directly
  # Enum/Range: "name is value"
  # Capitalize NOT for negative emphasis (Rule 19)

  def self.format(characteristic, value_obj)
    type = characteristic['type']
    description = value_obj['description'] || value_obj['value'].to_s

    # Capitalize NOT for emphasis
    description = emphasize_not(description)

    case type
    when 'boolean', 'presence'
      description
    else
      name = humanize(characteristic['name'])
      "#{name} is #{description}"
    end
  end

  def self.humanize(name)
    name.to_s.gsub('_', ' ')
  end

  def self.emphasize_not(text)
    text.gsub(/\bnot\b/i, 'NOT')
  end
end

# --- Let Block Generation (Shadowing Pattern) ---

module LetBlockGenerator
  # Generate let blocks for characteristic states
  # Binary: let(:name) { true/false }
  # Enum/Sequential: let(:name) { :value }
  # Range: skip (values need calculation)

  def self.generate(characteristic, value_obj)
    type = characteristic['type']
    name = characteristic['name']
    value = value_obj['value']

    case type
    when 'boolean'
      "let(:#{name}) { #{value} }"
    when 'presence'
      ruby_value = value == 'present' ? 'true' : 'nil'
      "let(:#{name}) { #{ruby_value} }"
    when 'enum', 'sequential'
      "let(:#{name}) { :#{value} }"
    when 'range'
      # Range needs threshold calculation - leave for implementer
      threshold = characteristic['threshold_value']
      operator = characteristic['threshold_operator']
      if threshold && operator
        "let(:#{name}) { {THRESHOLD_VALUE} }  # #{operator} #{threshold}"
      else
        "let(:#{name}) { {THRESHOLD_VALUE} }"
      end
    else
      nil
    end
  end
end

# --- Behavior Bank Resolver ---

class BehaviorResolver
  def initialize(behaviors)
    @behaviors = (behaviors || []).each_with_object({}) do |b, hash|
      hash[b['id']] = b
    end
  end

  # Resolve behavior_id to description, returns nil if disabled
  def resolve(behavior_id)
    if behavior_id.nil? || behavior_id.to_s.strip.empty?
      raise ArgumentError, 'Missing behavior_id in metadata'
    end

    behavior = @behaviors[behavior_id]
    raise ArgumentError, "Unknown behavior_id in metadata: #{behavior_id}" unless behavior

    # Skip disabled behaviors
    return nil if behavior['enabled'] == false

    description = behavior['description']
    raise ArgumentError, "Missing behavior description in behavior bank: #{behavior_id}" if description.nil? || description.to_s.strip.empty?

    description
  end

  # Check if behavior is enabled (default true if not specified)
  def enabled?(behavior_id)
    return true if behavior_id.nil?

    behavior = @behaviors[behavior_id]
    return true unless behavior

    behavior['enabled'] != false
  end
end

# --- Placeholder Contract (v2) Helpers ---

class PathFormatter
  def self.format(segments)
    return '' if segments.nil? || segments.empty?

    segments.map do |(level, characteristic, value)|
      "#{level}:#{characteristic}=#{encode_value(value)}"
    end.join(',')
  end

  def self.encode_value(value)
    case value
    when NilClass
      'nil'
    when TrueClass
      'true'
    when FalseClass
      'false'
    when Symbol
      ":#{value}"
    else
      value.inspect
    end
  end
end

class MarkerFormatter
  def self.format(tag, attrs = {})
    parts = attrs
              .sort_by { |k, _| k.to_s }
              .map { |k, v| "#{k}=\"#{escape_attr(v)}\"" }
              .join(' ')

    "# rspec-testing:#{tag} #{parts}".rstrip
  end

  def self.escape_attr(value)
    value.to_s.gsub('\\', '\\\\').gsub('"', '\\"')
  end
end

# --- Context Tree Builder ---

class ContextTreeBuilder
  def initialize(methods_data, behavior_resolver)
    @methods_data = methods_data
    @behavior_resolver = behavior_resolver
    @warnings = []
  end

  attr_reader :warnings

  def build
    @methods_data.map do |method|
      build_method_tree(method)
    end
  end

  private

  def build_method_tree(method)
    # Resolve side effects
    side_effects = resolve_side_effects(method['side_effects'] || [])

    {
      name: method['name'],
      type: method['type'],
      side_effects: side_effects,
      contexts: build_contexts(method['characteristics'] || [], 1, nil, side_effects, [])
    }
  end

  def resolve_side_effects(side_effects)
    side_effects.filter_map do |effect|
      behavior_id = effect['behavior_id']
      raise ArgumentError, "Missing side_effects[].behavior_id in metadata" if behavior_id.nil? || behavior_id.to_s.strip.empty?

      description = @behavior_resolver.resolve(behavior_id)

      # Skip if behavior is disabled (resolve returns nil)
      next nil if description.nil?

      {
        'type' => effect['type'],
        'description' => description,
        'behavior_id' => behavior_id
      }
    end
  end

  def resolve_leaf_behavior(value_obj)
    # Resolve behavior_id for any leaf value (terminal or non-terminal success)
    behavior_id = value_obj['behavior_id']
    raise ArgumentError, 'Missing values[].behavior_id on leaf value in metadata' if behavior_id.nil? || behavior_id.to_s.strip.empty?

    description = @behavior_resolver.resolve(behavior_id)

    # Skip if behavior is disabled (resolve returns nil)
    return nil if description.nil?

    { behavior_id: behavior_id, description: description }
  end

  def build_contexts(characteristics, current_level, parent_context, side_effects = [], path_segments = [])
    # Filter characteristics for current level
    level_chars = characteristics.select { |c| c['level'] == current_level }

    # Filter by parent dependency
    level_chars = filter_by_parent(level_chars, parent_context)

    contexts = []

    level_chars.each do |char|
      ordered_values = StateOrdering.order_values(char)

      ordered_values.each_with_index do |value_obj, index|
        context = build_single_context(
          char,
          value_obj,
          index,
          current_level,
          characteristics,
          side_effects,
          path_segments
        )
        contexts << context
      end
    end

    contexts
  end

  def filter_by_parent(chars, parent_context)
    if parent_context.nil?
      # Root level: no dependencies
      chars.select { |c| c['depends_on'].nil? }
    else
      chars.select do |c|
        next false unless c['depends_on'] == parent_context[:char_name]

        when_parent = c['when_parent'] || []
        when_parent.include?(parent_context[:state])
      end
    end
  end

  def build_single_context(char, value_obj, state_index, level, all_chars, side_effects = [], parent_path_segments = [])
    context_word = ContextWords.determine(char, value_obj['value'], value_obj['description'], state_index, level)
    description = DescriptionFormatter.format(char, value_obj)
    let_block = LetBlockGenerator.generate(char, value_obj)

    is_terminal = value_obj['terminal'] == true

    context_path_segments = parent_path_segments + [[level, char['name'], value_obj['value']]]
    context_path = PathFormatter.format(context_path_segments)

    context = {
      word: context_word,
      description: description,
      characteristic: char['name'],
      value: value_obj['value'],
      let_block: let_block,
      source_line: char['source_line'],
      terminal: is_terminal,
      children: []
    }

    if is_terminal
      # Terminal state: resolve behavior_id or use inline behavior
      behavior = resolve_leaf_behavior(value_obj)

      if behavior.nil?
        context[:skip_reason] = 'behavior disabled'
        context[:it_blocks] = []
      else
        context[:it_blocks] = [
          {
            description: behavior[:description],
            behavior_id: behavior[:behavior_id],
            kind: 'terminal',
            path: context_path
          }
        ]
      end
    else
      # Non-terminal: recurse for children
      parent = { char_name: char['name'], state: value_obj['value'] }
      context[:children] = build_contexts(all_chars, level + 1, parent, side_effects, context_path_segments)

      # Leaf context (no children): generate it blocks for side effects + success behavior
      if context[:children].empty?
        # Resolve success behavior from leaf value's behavior_id
        success_behavior = resolve_leaf_behavior(value_obj)

        # Skip if behavior is disabled
        if success_behavior.nil?
          context[:skip_reason] = 'behavior disabled'
          context[:it_blocks] = []
        else
          it_blocks = []

          # Add side effect it blocks first
          side_effects.each do |effect|
            it_blocks << {
              description: effect['description'],
              behavior_id: effect['behavior_id'],
              kind: 'side_effect',
              path: context_path
            }
          end

          # Add success behavior it block last
          it_blocks << {
            description: success_behavior[:description],
            behavior_id: success_behavior[:behavior_id],
            kind: 'success',
            path: context_path
          }

          context[:it_blocks] = it_blocks
        end
      end
    end

    context
  end
end

# --- Code Generator ---

class SpecCodeGenerator
  def initialize(metadata, context_trees, structure_mode: :full, shared_examples_threshold: 3)
    @metadata = metadata
    @context_trees = context_trees
    @structure_mode = structure_mode
    @shared_examples_threshold = shared_examples_threshold
  end

  def generate
    case @structure_mode
    when :full
      generate_full_spec
    when :blocks
      generate_blocks_only
    end
  end

  private

  def generate_full_spec
    class_name = @metadata['class_name']

    lines = []
    lines << '# frozen_string_literal: true'
    lines << ''
    lines << "RSpec.describe #{class_name} do"

    @context_trees.each do |method_tree|
      lines << generate_method_block(method_tree, 1)
    end

    lines << 'end'
    lines.join("\n")
  end

  def generate_blocks_only
    # Generate only method describe blocks for insertion
    @context_trees.map do |method_tree|
      generate_method_block(method_tree, 1)
    end.join("\n\n")
  end

  def generate_method_block(method_tree, indent_level)
    indent = '  ' * indent_level
    method_name = method_tree[:name]
    method_type = method_tree[:type]
    class_name = @metadata['class_name']

    # Method descriptor: # for instance, . for class
    descriptor = method_type == 'class' ? ".#{method_name}" : "##{method_name}"
    method_id = method_type == 'class' ? "#{class_name}.#{method_name}" : "#{class_name}##{method_name}"

    lines = []
    lines << "#{indent}describe '#{descriptor}' do"
    lines << "#{indent}  #{MarkerFormatter.format('method_begin', { method: descriptor, method_id: method_id })}"

    # Subject
    if method_type == 'instance'
      lines << "#{indent}  subject(:result) { instance.#{method_name} }  # TODO: Add parameters"
      lines << ''
      lines << "#{indent}  let(:instance) { described_class.new }"
    else
      lines << "#{indent}  subject(:result) { described_class.#{method_name} }  # TODO: Add parameters"
    end

    lines << ''
    lines << "#{indent}  {COMMON_SETUP}"
    lines << ''

    shared_examples_plan = build_shared_examples_plan(method_tree, method_id)
    unless shared_examples_plan[:templates].empty?
      shared_examples_plan[:templates].each do |template|
        lines << "#{indent}  shared_examples '#{escape_single_quotes(template[:name])}' do"
        lines << "#{indent}    it '#{escape_single_quotes(template[:description])}' do"
        lines << "#{indent}      {EXPECTATION}"
        lines << "#{indent}      #{MarkerFormatter.format('example', { behavior_id: template[:behavior_id], kind: template[:kind], path: '', template: true })}"
        lines << "#{indent}    end"
        lines << "#{indent}  end"
        lines << ''
      end
    end

    # Generate contexts
    if method_tree[:contexts].empty?
      raise ArgumentError, "No contexts generated for method #{method_id}; ensure metadata contains characteristics with leaf values that have behavior_id"
    else
      method_tree[:contexts].each do |context|
        lines << generate_context(context, indent_level + 1, shared_examples_by_key: shared_examples_plan[:names_by_key])
      end
    end

    lines << "#{indent}  #{MarkerFormatter.format('method_end', { method: descriptor, method_id: method_id })}"
    lines << "#{indent}end"
    lines.join("\n")
  end

  def generate_context(context, indent_level, shared_examples_by_key: nil)
    indent = '  ' * indent_level

    # Skip contexts with disabled behaviors
    if context[:skip_reason]
      return "#{indent}# SKIPPED: #{context[:skip_reason]} - context '#{escape_single_quotes(context[:word])} #{escape_single_quotes(context[:description])}'"
    end

    lines = []
    lines << "#{indent}context '#{escape_single_quotes(context[:word])} #{escape_single_quotes(context[:description])}' do"

    # Source location comment
    if context[:source_line]
      lines << "#{indent}  # Logic: #{context[:source_line]}"
    end

    # Let block for shadowing
    if context[:let_block]
      lines << "#{indent}  #{context[:let_block]}"
    end

    lines << "#{indent}  {SETUP_CODE}"
    lines << ''

    # It blocks (for leaf/terminal contexts)
    if context[:it_blocks] && !context[:it_blocks].empty?
      context[:it_blocks].each do |it_block|
        key = [it_block[:behavior_id], it_block[:kind]]
        shared_name = shared_examples_by_key && shared_examples_by_key[key]

        if shared_name
          lines << "#{indent}  #{MarkerFormatter.format('example', { behavior_id: it_block[:behavior_id], kind: it_block[:kind], path: it_block[:path] })}"
          lines << "#{indent}  it_behaves_like '#{escape_single_quotes(shared_name)}'"
        else
          lines << "#{indent}  it '#{escape_single_quotes(it_block[:description])}' do"
          lines << "#{indent}    {EXPECTATION}"
          lines << "#{indent}    #{MarkerFormatter.format('example', { behavior_id: it_block[:behavior_id], kind: it_block[:kind], path: it_block[:path] })}"
          lines << "#{indent}  end"
        end
      end
    end

    # Child contexts
    context[:children].each do |child|
      lines << ''
      lines << generate_context(child, indent_level + 1, shared_examples_by_key: shared_examples_by_key)
    end

    lines << "#{indent}end"
    lines.join("\n")
  end

  def escape_single_quotes(value)
    value.to_s.gsub("'", "\\\\'")
  end

  def build_shared_examples_plan(method_tree, method_id)
    threshold = @shared_examples_threshold.to_i
    return { templates: [], names_by_key: {} } if threshold <= 0

    it_blocks = []
    collect_it_blocks(method_tree[:contexts], it_blocks)

    counts = Hash.new(0)
    exemplar = {}

    it_blocks.each do |it_block|
      key = [it_block[:behavior_id], it_block[:kind]]
      counts[key] += 1
      exemplar[key] ||= it_block
    end

    dedup_keys =
      counts
        .select { |_key, count| count >= threshold }
        .keys
        .sort_by { |behavior_id, kind| [behavior_id.to_s, kind.to_s] }

    names_by_key = {}
    templates = []

    dedup_keys.each do |behavior_id, kind|
      name = "__rspec_testing__#{method_id}__#{behavior_id}__#{kind}"
      names_by_key[[behavior_id, kind]] = name

      templates << {
        name: name,
        description: exemplar[[behavior_id, kind]][:description],
        behavior_id: behavior_id,
        kind: kind
      }
    end

    { templates: templates, names_by_key: names_by_key }
  end

  def collect_it_blocks(contexts, acc)
    contexts.each do |context|
      (context[:it_blocks] || []).each { |it_block| acc << it_block }
      next if context[:children].nil? || context[:children].empty?

      collect_it_blocks(context[:children], acc)
    end
  end
end

# --- Main ---

def main
  options = { structure_mode: nil, shared_examples_threshold: 3 }

  OptionParser.new do |opts|
    opts.banner = 'Usage: spec_structure_generator.rb <metadata_path> [options]'

    opts.on('--structure-mode=MODE', %w[full blocks], 'Structure mode: full or blocks') do |m|
      options[:structure_mode] = m.to_sym
    end

    opts.on(
      '--shared-examples-threshold=N',
      Integer,
      'Deduplicate repeated (behavior_id, kind) into shared_examples when count >= N (default: 3)'
    ) do |n|
      if n < 2
        warn 'Error: --shared-examples-threshold must be >= 2'
        exit 1
      end
      options[:shared_examples_threshold] = n
    end
  end.parse!

  if ARGV.empty?
    warn 'Error: Missing metadata file argument'
    warn 'Usage: spec_structure_generator.rb <metadata_path> [--structure-mode=full|blocks]'
    exit 1
  end

  metadata_path = ARGV[0]

  unless File.exist?(metadata_path)
    warn "Error: Metadata file not found: #{metadata_path}"
    exit 1
  end

  # Parse metadata
  begin
    metadata = YAML.load_file(metadata_path)
  rescue Psych::SyntaxError => e
    warn "Error: Cannot parse metadata YAML: #{e.message}"
    exit 1
  end

  # Validate required fields
  unless metadata['class_name']
    warn 'Error: Missing class_name in metadata'
    exit 1
  end

  unless metadata['methods'] && !metadata['methods'].empty?
    warn 'Error: No methods found in metadata'
    exit 1
  end

  # Determine structure_mode (required via CLI, default to :blocks for safety)
  structure_mode = options[:structure_mode] || :blocks

  # Initialize behavior resolver with behaviors bank
  behavior_resolver = BehaviorResolver.new(metadata['behaviors'])

  # Build context trees
  begin
    builder = ContextTreeBuilder.new(metadata['methods'], behavior_resolver)
    context_trees = builder.build
  rescue ArgumentError => e
    warn "Error: Invalid metadata for structure generation: #{e.message}"
    exit 1
  end

  # Generate code
  begin
    generator = SpecCodeGenerator.new(
      metadata,
      context_trees,
      structure_mode: structure_mode,
      shared_examples_threshold: options[:shared_examples_threshold]
    )
    puts generator.generate
  rescue ArgumentError => e
    warn "Error: Cannot generate structure: #{e.message}"
    exit 1
  end

  # Report warnings
  builder.warnings.each { |w| warn "Warning: #{w}" }

  exit builder.warnings.empty? ? 0 : 2
end

main if __FILE__ == $PROGRAM_NAME
