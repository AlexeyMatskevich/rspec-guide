#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'yaml'

ALLOWED_STAGES = %w[
  discovery-agent
  code-analyzer
  isolation-decider
  test-architect
  test-implementer
].freeze

def fail_with(errors)
  warn 'Metadata validation failed:'
  errors.each { |e| warn "- #{e}" }
  exit 1
end

def warn_with(warnings)
  return if warnings.empty?

  warn 'Metadata validation warnings:'
  warnings.each { |w| warn "- #{w}" }
end

def require_hash!(value, label, errors)
  return if value.is_a?(Hash)
  errors << "#{label} must be a Hash"
end

def require_array!(value, label, errors)
  return if value.is_a?(Array)
  errors << "#{label} must be an Array"
end

def require_string!(value, label, errors)
  return if value.is_a?(String) && !value.strip.empty?
  errors << "#{label} must be a non-empty String"
end

def require_bool!(value, label, errors)
  return if value == true || value == false
  errors << "#{label} must be boolean"
end

def require_int!(value, label, errors)
  return if value.is_a?(Integer)
  errors << "#{label} must be an Integer"
end

def require_in!(value, label, allowed, errors)
  return if allowed.include?(value)
  errors << "#{label} must be one of: #{allowed.join(', ')}"
end

def path_segments_for_context(characteristics, current_level, parent)
  level_chars = characteristics.select { |c| c['level'] == current_level }
  level_chars = filter_by_parent(level_chars, parent)

  contexts = []
  level_chars.each do |char|
    (char['values'] || []).each do |value_obj|
      terminal = value_obj['terminal'] == true
      node = { char: char, value: value_obj, terminal: terminal, children: [] }
      unless terminal
        next_parent = { char_name: char['name'], state: value_obj['value'] }
        node[:children] = path_segments_for_context(characteristics, current_level + 1, next_parent)
      end
      contexts << node
    end
  end

  contexts
end

def filter_by_parent(chars, parent)
  if parent.nil?
    chars.select { |c| c['depends_on'].nil? }
  else
    chars.select do |c|
      next false unless c['depends_on'] == parent[:char_name]
      when_parent = c['when_parent'] || []
      when_parent.include?(parent[:state])
    end
  end
end

def leaf_nodes(contexts)
  leaves = []
  contexts.each do |ctx|
    if ctx[:terminal] || ctx[:children].empty?
      leaves << ctx
    else
      leaves.concat(leaf_nodes(ctx[:children]))
    end
  end
  leaves
end

def estimate_leaf_contexts(characteristics)
  roots = path_segments_for_context(characteristics, 1, nil)
  leaf_nodes(roots).length
end

def validate_discovery_agent(metadata, errors, warnings)
  automation = metadata['automation'] || {}
  require_hash!(automation, 'automation', errors)
  require_bool!(automation['discovery_agent_completed'], 'automation.discovery_agent_completed', errors)

  require_string!(metadata['source_file'], 'source_file', errors)
  require_string!(metadata['class_name'], 'class_name', errors)
  require_string!(metadata['spec_path'], 'spec_path', errors)

  complexity = metadata['complexity']
  require_hash!(complexity, 'complexity', errors)
  if complexity.is_a?(Hash)
    require_string!(complexity['zone'], 'complexity.zone', errors)
  end

  methods_to_analyze = metadata['methods_to_analyze']
  require_array!(methods_to_analyze, 'methods_to_analyze', errors)
  return unless methods_to_analyze.is_a?(Array)

  if methods_to_analyze.empty?
    errors << 'methods_to_analyze must not be empty'
    return
  end

  methods_to_analyze.each_with_index do |m, idx|
    unless m.is_a?(Hash)
      errors << "methods_to_analyze[#{idx}] must be a Hash"
      next
    end
    require_string!(m['name'], "methods_to_analyze[#{idx}].name", errors)
    require_in!(m['method_mode'], "methods_to_analyze[#{idx}].method_mode", %w[new modified unchanged], errors)
    require_bool!(m['selected'], "methods_to_analyze[#{idx}].selected", errors)

    line_range = m['line_range']
    require_array!(line_range, "methods_to_analyze[#{idx}].line_range", errors)
    if line_range.is_a?(Array)
      if line_range.length != 2
        errors << "methods_to_analyze[#{idx}].line_range must be [start, end]"
      else
        require_int!(line_range[0], "methods_to_analyze[#{idx}].line_range[0]", errors)
        require_int!(line_range[1], "methods_to_analyze[#{idx}].line_range[1]", errors)
      end
    end
  end

  warnings << 'spec_path is under spec/controllers; prefer spec/requests for new Rails controllers tests' if metadata['spec_path'].to_s.start_with?('spec/controllers/')
end

def validate_code_analyzer(metadata, errors, warnings)
  automation = metadata['automation'] || {}
  require_hash!(automation, 'automation', errors)
  require_bool!(automation['code_analyzer_completed'], 'automation.code_analyzer_completed', errors)

  require_string!(metadata['slug'], 'slug', errors)
  require_string!(metadata['source_file'], 'source_file', errors)
  require_int!(metadata['source_mtime'], 'source_mtime', errors)
  require_string!(metadata['class_name'], 'class_name', errors)

  behaviors = metadata['behaviors']
  require_array!(behaviors, 'behaviors', errors)

  behavior_bank = {}
  if behaviors.is_a?(Array)
    behaviors.each_with_index do |b, idx|
      unless b.is_a?(Hash)
        errors << "behaviors[#{idx}] must be a Hash"
        next
      end

      require_string!(b['id'], "behaviors[#{idx}].id", errors)
      require_string!(b['description'], "behaviors[#{idx}].description", errors) if b['enabled'] != false

      id = b['id']
      next unless id.is_a?(String)

      if behavior_bank.key?(id)
        errors << "behaviors[].id must be unique; duplicate: #{id}"
      else
        behavior_bank[id] = b
      end
    end
  end

  methods = metadata['methods']
  require_array!(methods, 'methods', errors)
  return unless methods.is_a?(Array)

  if methods.empty?
    errors << 'methods must not be empty'
    return
  end

  selected_names = nil
  if metadata['methods_to_analyze'].is_a?(Array)
    selected_names = metadata['methods_to_analyze'].select { |m| m.is_a?(Hash) && m['selected'] == true }.map { |m| m['name'] }.compact
    selected_names = nil if selected_names.empty?
  end

  method_names = methods.map { |m| m.is_a?(Hash) ? m['name'] : nil }.compact
  if selected_names
    missing = selected_names - method_names
    extra = method_names - selected_names
    errors << "methods missing selected methods: #{missing.join(', ')}" unless missing.empty?
    errors << "methods contains unselected methods: #{extra.join(', ')}" unless extra.empty?
  end

  combinatorial_warnings = []

  methods.each_with_index do |m, idx|
    unless m.is_a?(Hash)
      errors << "methods[#{idx}] must be a Hash"
      next
    end

    require_string!(m['name'], "methods[#{idx}].name", errors)
    require_in!(m['type'], "methods[#{idx}].type", %w[instance class], errors)
    require_bool!(m['analyzed'], "methods[#{idx}].analyzed", errors)
    require_in!(m['method_mode'], "methods[#{idx}].method_mode", %w[new modified unchanged], errors)

    characteristics = m['characteristics']
    require_array!(characteristics, "methods[#{idx}].characteristics", errors)

    side_effects = m['side_effects'] || []
    require_array!(side_effects, "methods[#{idx}].side_effects", errors) unless m.key?('side_effects')

    side_effects_count = side_effects.is_a?(Array) ? side_effects.length : 0

    if characteristics.is_a?(Array)
      # Validate per-field schema for characteristics/values.
      characteristics.each_with_index do |c, cidx|
        unless c.is_a?(Hash)
          errors << "methods[#{idx}].characteristics[#{cidx}] must be a Hash"
          next
        end

        require_string!(c['name'], "methods[#{idx}].characteristics[#{cidx}].name", errors)
        require_string!(c['description'], "methods[#{idx}].characteristics[#{cidx}].description", errors)
        require_string!(c['type'], "methods[#{idx}].characteristics[#{cidx}].type", errors)
        require_int!(c['level'], "methods[#{idx}].characteristics[#{cidx}].level", errors)
        require_array!(c['values'], "methods[#{idx}].characteristics[#{cidx}].values", errors)

        source = c['source']
        require_hash!(source, "methods[#{idx}].characteristics[#{cidx}].source", errors)
        require_in!(source['kind'], "methods[#{idx}].characteristics[#{cidx}].source.kind", %w[internal external], errors) if source.is_a?(Hash)

        setup = c['setup']
        require_hash!(setup, "methods[#{idx}].characteristics[#{cidx}].setup", errors)
        require_in!(setup['type'], "methods[#{idx}].characteristics[#{cidx}].setup.type", %w[model data action], errors) if setup.is_a?(Hash)

        next unless c['values'].is_a?(Array)

        c['values'].each_with_index do |v, vidx|
          unless v.is_a?(Hash)
            errors << "methods[#{idx}].characteristics[#{cidx}].values[#{vidx}] must be a Hash"
            next
          end
          require_bool!(v['terminal'], "methods[#{idx}].characteristics[#{cidx}].values[#{vidx}].terminal", errors)
          require_string!(v['description'], "methods[#{idx}].characteristics[#{cidx}].values[#{vidx}].description", errors)
          if v['terminal'] == true
            require_string!(v['behavior_id'], "methods[#{idx}].characteristics[#{cidx}].values[#{vidx}].behavior_id", errors)
          end
          if v.key?('behavior_id') && v['behavior_id'].to_s.strip != ''
            bid = v['behavior_id'].to_s
            errors << "Unknown behavior_id '#{bid}' in methods[#{idx}].characteristics[#{cidx}].values[#{vidx}]" unless behavior_bank.key?(bid)
          end
        end
      end

      char_count = characteristics.length
      roots = path_segments_for_context(characteristics, 1, nil)
      leaves = leaf_nodes(roots)
      leaf_contexts = leaves.length
      estimated_examples = leaf_contexts * (1 + side_effects_count)

      # Strict leaf validation: every generated leaf context (terminal or success) must have behavior_id.
      leaves.each do |leaf|
        value_obj = leaf[:value] || {}
        behavior_id = value_obj['behavior_id']
        if behavior_id.nil? || behavior_id.to_s.strip.empty?
          errors << "Missing values[].behavior_id on leaf value (method '#{m['name']}')"
          break
        end
        bid = behavior_id.to_s
        errors << "Unknown behavior_id '#{bid}' on leaf value (method '#{m['name']}')" unless behavior_bank.key?(bid)
      end

      if char_count >= 5 || leaf_contexts >= 25 || estimated_examples >= 50
        combinatorial_warnings << "Potential combinatorial explosion for method '#{m['name']}': characteristics=#{char_count}, leaf_contexts≈#{leaf_contexts}, examples≈#{estimated_examples}"
      end
    end

    if side_effects.is_a?(Array)
      side_effects.each_with_index do |e, eidx|
        unless e.is_a?(Hash)
          errors << "methods[#{idx}].side_effects[#{eidx}] must be a Hash"
          next
        end

        require_string!(e['behavior_id'], "methods[#{idx}].side_effects[#{eidx}].behavior_id", errors)
        bid = e['behavior_id'].to_s
        errors << "Unknown behavior_id '#{bid}' in methods[#{idx}].side_effects[#{eidx}]" unless bid.strip.empty? || behavior_bank.key?(bid)
      end
    end
  end

  unless combinatorial_warnings.empty?
    warnings.concat(combinatorial_warnings)
    warnings << 'AskUserQuestion recommended: continue generation vs pause and reduce scope'
  end
end

def validate_isolation_decider(metadata, errors, warnings)
  automation = metadata['automation'] || {}
  require_hash!(automation, 'automation', errors)
  require_bool!(automation['code_analyzer_completed'], 'automation.code_analyzer_completed', errors)
  require_bool!(automation['isolation_decider_completed'], 'automation.isolation_decider_completed', errors)

  methods = metadata['methods']
  require_array!(methods, 'methods', errors)
  return unless methods.is_a?(Array)

  methods.each_with_index do |m, idx|
    next unless m.is_a?(Hash)
    test_config = m['test_config']
    require_hash!(test_config, "methods[#{idx}].test_config", errors)
    next unless test_config.is_a?(Hash)

    require_in!(test_config['test_level'], "methods[#{idx}].test_config.test_level", %w[unit integration request], errors)
    require_in!(test_config['confidence'], "methods[#{idx}].test_config.confidence", %w[high medium low], errors)

    isolation = test_config['isolation']
    require_hash!(isolation, "methods[#{idx}].test_config.isolation", errors)
    if isolation.is_a?(Hash)
      require_in!(isolation['db'], "methods[#{idx}].test_config.isolation.db", %w[real stubbed none], errors)
      require_in!(isolation['external_http'], "methods[#{idx}].test_config.isolation.external_http", %w[real stubbed none], errors)
      require_in!(isolation['queue'], "methods[#{idx}].test_config.isolation.queue", %w[real stubbed none], errors)
    end

    decision_trace = test_config['decision_trace']
    require_array!(decision_trace, "methods[#{idx}].test_config.decision_trace", errors)
  end
end

def validate_test_architect(metadata, errors, warnings)
  automation = metadata['automation'] || {}
  require_hash!(automation, 'automation', errors)
  require_bool!(automation['code_analyzer_completed'], 'automation.code_analyzer_completed', errors)
  require_bool!(automation['isolation_decider_completed'], 'automation.isolation_decider_completed', errors)
  require_bool!(automation['test_architect_completed'], 'automation.test_architect_completed', errors)

  require_string!(metadata['spec_file'], 'spec_file', errors)
  require_string!(metadata['spec_path'], 'spec_path', errors)

  if metadata['spec_file'].is_a?(String) && metadata['spec_path'].is_a?(String) && metadata['spec_file'] != metadata['spec_path']
    errors << "spec_file and spec_path must match (spec_file=#{metadata['spec_file']} spec_path=#{metadata['spec_path']})"
  end

  spec_file = metadata['spec_file']
  if spec_file.is_a?(String) && !spec_file.strip.empty?
    errors << "spec_file does not exist: #{spec_file}" unless File.exist?(spec_file)
  end
end

def validate_test_implementer(metadata, errors, warnings)
  automation = metadata['automation'] || {}
  require_hash!(automation, 'automation', errors)
  require_bool!(automation['test_implementer_completed'], 'automation.test_implementer_completed', errors)

  spec_file = metadata['spec_file'] || metadata['spec_path']
  require_string!(spec_file, 'spec_file/spec_path', errors)
  return unless spec_file.is_a?(String) && !spec_file.strip.empty?

  unless File.exist?(spec_file)
    errors << "spec_file does not exist: #{spec_file}"
    return
  end

  content = File.read(spec_file)
  remaining = %w[{COMMON_SETUP} {SETUP_CODE} {EXPECTATION}].select { |p| content.include?(p) }
  errors << "Spec still contains placeholders: #{remaining.join(', ')}" unless remaining.empty?
end

options = { stage: nil, metadata_path: nil }

OptionParser.new do |opts|
  opts.banner = 'Usage: validate_metadata_stage.rb --stage=STAGE --metadata=PATH'

  opts.on('--stage=STAGE', String, "Stage to validate (#{ALLOWED_STAGES.join(' | ')})") do |s|
    options[:stage] = s
  end

  opts.on('--metadata=PATH', String, 'Path to metadata YAML file') do |p|
    options[:metadata_path] = p
  end
end.parse!

unless options[:stage] && ALLOWED_STAGES.include?(options[:stage])
  warn "Error: --stage must be one of: #{ALLOWED_STAGES.join(', ')}"
  exit 1
end

unless options[:metadata_path]
  warn 'Error: --metadata is required'
  exit 1
end

metadata_path = options[:metadata_path]

unless File.exist?(metadata_path)
  warn "Error: Metadata file not found: #{metadata_path}"
  exit 1
end

metadata =
  begin
    YAML.load_file(metadata_path)
  rescue Psych::Exception => e
    warn "Error: Cannot parse YAML: #{e.class}: #{e.message}"
    exit 1
  end

errors = []
warnings = []

require_hash!(metadata, 'metadata', errors)
fail_with(errors) unless errors.empty?

case options[:stage]
when 'discovery-agent'
  validate_discovery_agent(metadata, errors, warnings)
when 'code-analyzer'
  validate_code_analyzer(metadata, errors, warnings)
when 'isolation-decider'
  validate_isolation_decider(metadata, errors, warnings)
when 'test-architect'
  validate_test_architect(metadata, errors, warnings)
when 'test-implementer'
  validate_test_implementer(metadata, errors, warnings)
end

fail_with(errors) unless errors.empty?

warn_with(warnings)

puts 'OK'
exit warnings.empty? ? 0 : 2
