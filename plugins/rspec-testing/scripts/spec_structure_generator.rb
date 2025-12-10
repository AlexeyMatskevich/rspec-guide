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
  # Binary: first state → 'with', second → 'but'
  # Enum/Range (3+): all use 'and'
  # Terminal states use same rules but generate no children

  def self.determine(characteristic, state, state_index, level)
    return 'when' if level == 1

    type = characteristic['type']
    values = characteristic['values'] || []

    case type
    when 'enum', 'sequential'
      'and'
    when 'boolean', 'presence'
      state_index.zero? ? 'with' : 'but'
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
  # For enum/range: keep original order (analyzer should order correctly)

  def self.order_values(characteristic)
    values = characteristic['values'] || []
    type = characteristic['type']

    case type
    when 'boolean', 'presence'
      order_binary_values(values)
    else
      values # Keep original order for enum/range/sequential
    end
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
    return '{BEHAVIOR_DESCRIPTION}' if behavior_id.nil?

    behavior = @behaviors[behavior_id]
    return '{BEHAVIOR_DESCRIPTION}' unless behavior

    # Skip disabled behaviors
    return nil if behavior['enabled'] == false

    behavior['description'] || '{BEHAVIOR_DESCRIPTION}'
  end

  # Check if behavior is enabled (default true if not specified)
  def enabled?(behavior_id)
    return true if behavior_id.nil?

    behavior = @behaviors[behavior_id]
    return true unless behavior

    behavior['enabled'] != false
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
      contexts: build_contexts(method['characteristics'] || [], 1, nil, side_effects)
    }
  end

  def resolve_behavior(behavior_id, fallback_description)
    if behavior_id
      @behavior_resolver.resolve(behavior_id)
    else
      fallback_description || '{BEHAVIOR_DESCRIPTION}'
    end
  end

  def resolve_side_effects(side_effects)
    side_effects.filter_map do |effect|
      behavior_id = effect['behavior_id']
      description = if behavior_id
                      @behavior_resolver.resolve(behavior_id)
                    else
                      effect['description'] || '{BEHAVIOR_DESCRIPTION}'
                    end

      # Skip if behavior is disabled (resolve returns nil)
      next nil if description.nil?

      {
        'type' => effect['type'],
        'description' => description
      }
    end
  end

  def resolve_leaf_behavior(value_obj)
    # Resolve behavior_id for any leaf value (terminal or non-terminal success)
    behavior_id = value_obj['behavior_id']
    if behavior_id
      @behavior_resolver.resolve(behavior_id)
    else
      # Fallback to inline behavior field (backwards compatibility)
      value_obj['behavior'] || '{BEHAVIOR_DESCRIPTION}'
    end
  end

  def build_contexts(characteristics, current_level, parent_context, side_effects = [])
    # Filter characteristics for current level
    level_chars = characteristics.select { |c| c['level'] == current_level }

    # Filter by parent dependency
    level_chars = filter_by_parent(level_chars, parent_context)

    contexts = []

    level_chars.each do |char|
      ordered_values = StateOrdering.order_values(char)

      ordered_values.each_with_index do |value_obj, index|
        context = build_single_context(char, value_obj, index, current_level, characteristics, side_effects)
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

  def build_single_context(char, value_obj, state_index, level, all_chars, side_effects = [])
    context_word = ContextWords.determine(char, value_obj['value'], state_index, level)
    description = DescriptionFormatter.format(char, value_obj)
    let_block = LetBlockGenerator.generate(char, value_obj)

    is_terminal = value_obj['terminal'] == true

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

      # Skip terminal if behavior is disabled (resolve returns nil)
      if behavior.nil?
        context[:skip_reason] = 'behavior disabled'
        context[:it_blocks] = []
      else
        context[:it_blocks] = [
          { description: behavior }
        ]
      end
    else
      # Non-terminal: recurse for children
      parent = { char_name: char['name'], state: value_obj['value'] }
      context[:children] = build_contexts(all_chars, level + 1, parent, side_effects)

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
            it_blocks << { description: effect['description'], side_effect: true }
          end

          # Add success behavior it block last
          it_blocks << { description: success_behavior }

          context[:it_blocks] = it_blocks
        end
      end
    end

    context
  end
end

# --- Code Generator ---

class SpecCodeGenerator
  def initialize(metadata, context_trees, structure_mode: :full)
    @metadata = metadata
    @context_trees = context_trees
    @structure_mode = structure_mode
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

    # Method descriptor: # for instance, . for class
    descriptor = method_type == 'class' ? ".#{method_name}" : "##{method_name}"

    lines = []
    lines << "#{indent}describe '#{descriptor}' do"

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

    # Generate contexts
    if method_tree[:contexts].empty?
      # No contexts (rare): generate side effects + placeholder behavior
      side_effects = method_tree[:side_effects] || []
      side_effects.each do |effect|
        lines << "#{indent}  it '#{effect['description']}' do"
        lines << "#{indent}    {EXPECTATION}"
        lines << "#{indent}  end"
        lines << ''
      end

      # Fallback: methods without characteristics need behavior from somewhere
      lines << "#{indent}  it '{BEHAVIOR_DESCRIPTION}' do"
      lines << "#{indent}    {EXPECTATION}"
      lines << "#{indent}  end"
    else
      method_tree[:contexts].each do |context|
        lines << generate_context(context, indent_level + 1)
      end
    end

    lines << "#{indent}end"
    lines.join("\n")
  end

  def generate_context(context, indent_level)
    indent = '  ' * indent_level

    # Skip contexts with disabled behaviors
    if context[:skip_reason]
      return "#{indent}# SKIPPED: #{context[:skip_reason]} - context '#{context[:word]} #{context[:description]}'"
    end

    lines = []
    lines << "#{indent}context '#{context[:word]} #{context[:description]}' do"

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
        lines << "#{indent}  it '#{it_block[:description]}' do"
        lines << "#{indent}    {EXPECTATION}"
        lines << "#{indent}  end"
      end
    end

    # Child contexts
    context[:children].each do |child|
      lines << ''
      lines << generate_context(child, indent_level + 1)
    end

    lines << "#{indent}end"
    lines.join("\n")
  end
end

# --- Main ---

def main
  options = { structure_mode: nil }

  OptionParser.new do |opts|
    opts.banner = 'Usage: spec_structure_generator.rb <metadata_path> [options]'

    opts.on('--structure-mode=MODE', %w[full blocks], 'Structure mode: full or blocks') do |m|
      options[:structure_mode] = m.to_sym
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
    warn 'Warning: No methods found in metadata'
    puts generate_minimal_spec(metadata)
    exit 2
  end

  # Determine structure_mode (required via CLI, default to :blocks for safety)
  structure_mode = options[:structure_mode] || :blocks

  # Initialize behavior resolver with behaviors bank
  behavior_resolver = BehaviorResolver.new(metadata['behaviors'])

  # Build context trees
  builder = ContextTreeBuilder.new(metadata['methods'], behavior_resolver)
  context_trees = builder.build

  # Generate code
  generator = SpecCodeGenerator.new(metadata, context_trees, structure_mode: structure_mode)
  puts generator.generate

  # Report warnings
  builder.warnings.each { |w| warn "Warning: #{w}" }

  exit builder.warnings.empty? ? 0 : 2
end

def generate_minimal_spec(metadata)
  class_name = metadata['class_name']

  <<~RUBY
    # frozen_string_literal: true

    RSpec.describe #{class_name} do
      it '{BEHAVIOR_DESCRIPTION}' do
        {EXPECTATION}
      end
    end
  RUBY
end

main if __FILE__ == $PROGRAM_NAME
