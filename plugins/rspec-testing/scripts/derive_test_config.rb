#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'yaml'

class DeriveTestConfigError < StandardError; end

PROJECT_TYPES = %w[rails web service library].freeze
OUTPUT_FORMATS = %w[json text].freeze
LOW_CONFIDENCE_CHOICES = %w[unit integration request].freeze

def load_plugin_config
  path = '.claude/rspec-testing-config.yml'
  return {} unless File.exist?(path)

  YAML.load_file(path) || {}
rescue Psych::Exception => e
  warn "Warning: Cannot parse #{path}: #{e.class}: #{e.message}"
  {}
end

def bool(value)
  value ? true : false
end

def compute_method_id(class_name, method_hash)
  name = method_hash['name']
  type = method_hash['type']
  raise DeriveTestConfigError, 'Method missing name/type' if name.to_s.strip.empty? || type.to_s.strip.empty?

  type == 'class' ? "#{class_name}.#{name}" : "#{class_name}##{name}"
end

def file_type_for(source_file, class_name)
  return 'controller' if source_file.match?(%r{\Aapp/controllers/}) || class_name.end_with?('Controller')
  return 'job' if source_file.match?(%r{\Aapp/jobs/}) || class_name.end_with?('Job')
  return 'worker' if source_file.match?(%r{\Aapp/workers/}) || class_name.end_with?('Worker')
  return 'service' if source_file.match?(%r{\Aapp/(services|interactors)/})
  return 'model' if source_file.match?(%r{\Aapp/models/})
  return 'lib' if source_file.match?(%r{\Alib/})

  'other'
end

def http_client_class?(name)
  return false if name.to_s.strip.empty?

  name.to_s.match?(/(HTTP|Net::HTTP|HTTParty|Faraday|RestClient|HTTPClient)/i)
end

def method_loc_from(metadata, method_name)
  list = metadata['methods_to_analyze']
  return nil unless list.is_a?(Array)

  entry = list.find { |m| m.is_a?(Hash) && m['name'].to_s == method_name.to_s }
  return nil unless entry.is_a?(Hash)

  lr = entry['line_range']
  return nil unless lr.is_a?(Array) && lr.length == 2

  start_line, end_line = lr
  return nil unless start_line.is_a?(Integer) && end_line.is_a?(Integer) && end_line >= start_line

  (end_line - start_line + 1)
end

def downgrade_confidence(current, target)
  order = { 'high' => 3, 'medium' => 2, 'low' => 1 }
  return current unless order.key?(current) && order.key?(target)

  order[target] < order[current] ? target : current
end

def decide_test_config(project_type:, file_type:, method:, metadata:, class_name:)
  method_name = method['name'].to_s
  method_id = compute_method_id(class_name, method)

  characteristics = method['characteristics'].is_a?(Array) ? method['characteristics'] : []
  side_effects = method['side_effects'].is_a?(Array) ? method['side_effects'] : []
  dependencies = method['dependencies'].is_a?(Array) ? method['dependencies'] : []

  side_effect_types = side_effects.map { |e| e.is_a?(Hash) ? e['type'] : nil }.compact.map(&:to_s)

  uses_db =
    characteristics.any? { |c| c.is_a?(Hash) && c.dig('setup', 'type').to_s == 'model' } ||
      side_effect_types.include?('cache')

  uses_external_http =
    side_effect_types.include?('external_api') ||
      characteristics.any? do |c|
        next false unless c.is_a?(Hash)
        next false unless c.dig('source', 'kind').to_s == 'external'

        http_client_class?(c.dig('source', 'class'))
      end

  uses_queue = (side_effect_types & %w[event webhook email]).any?

  is_pure = !uses_db && !uses_external_http && !uses_queue && side_effect_types.empty?

  complexity_zone = metadata.dig('complexity', 'zone').to_s
  loc = method_loc_from(metadata, method_name)

  base_test_level =
    if project_type == 'library'
      'unit'
    else
      case file_type
      when 'controller' then 'request'
      when 'job', 'worker' then 'integration'
      else 'unit'
      end
    end

  decision_trace = []
  decision_trace << "project_type: #{project_type}"
  decision_trace << "file_type: #{file_type}"
  decision_trace << "base_test_level: #{base_test_level}"
  decision_trace << "complexity.zone: #{complexity_zone}" unless complexity_zone.strip.empty?
  decision_trace << "loc: #{loc}" if loc
  decision_trace << "dependencies.count: #{dependencies.length}" unless dependencies.empty?
  decision_trace << "side_effects: #{side_effect_types.join(', ')}" unless side_effect_types.empty?
  decision_trace << 'uses_db: true (setup.type=model or side_effect cache)' if uses_db
  decision_trace << 'uses_external_http: true (side_effect external_api or HTTP client)' if uses_external_http
  decision_trace << 'uses_queue: true (event/webhook/email)' if uses_queue
  decision_trace << 'is_pure: true (no side effects, no db/http/queue)' if is_pure

  test_level = base_test_level

  if is_pure
    test_level = 'unit'
  elsif project_type != 'library'
    if file_type == 'controller'
      test_level = 'request'
    elsif uses_db
      should_integrate_db =
        (loc && loc > 20) ||
          %w[yellow red].include?(complexity_zone) ||
          dependencies.length > 1

      if should_integrate_db
        decision_trace << 'rule: uses_db + (loc>20 or zone>=yellow or deps>1) => integration'
        test_level = 'integration'
      else
        decision_trace << 'rule: uses_db + small/simple => unit (db stubbed)'
        test_level = 'unit'
      end
    end
  end

  isolation = { 'db' => 'none', 'external_http' => 'none', 'queue' => 'none' }

  if test_level == 'request'
    isolation['db'] = 'real'
  elsif uses_db
    isolation['db'] = test_level == 'integration' ? 'real' : 'stubbed'
  end

  isolation['external_http'] = uses_external_http ? 'stubbed' : 'none'
  isolation['queue'] = uses_queue ? 'stubbed' : 'none'

  confidence = 'high'
  confidence = downgrade_confidence(confidence, 'medium') if %w[yellow].include?(complexity_zone)
  confidence = downgrade_confidence(confidence, 'low') if %w[red].include?(complexity_zone)
  confidence = downgrade_confidence(confidence, 'medium') if uses_db && uses_external_http
  confidence = downgrade_confidence(confidence, 'medium') if loc && loc >= 15 && loc <= 25

  # Controller helper methods can look pure; request-vs-unit is ambiguous.
  confidence = downgrade_confidence(confidence, 'low') if file_type == 'controller' && is_pure

  {
    method_id: method_id,
    method_name: method_name,
    uses_db: bool(uses_db),
    uses_external_http: bool(uses_external_http),
    uses_queue: bool(uses_queue),
    is_pure: bool(is_pure),
    test_level: test_level,
    isolation: isolation,
    confidence: confidence,
    decision_trace: decision_trace
  }
end

def low_confidence_decision_payload(source_file:, class_name:, file_type:, low_methods:, recommended_action:)
  methods_summary =
    low_methods.map do |m|
      {
        method_id: m[:method_id],
        suggested_test_level: m[:test_level],
        signals: {
          uses_db: m[:uses_db],
          uses_external_http: m[:uses_external_http],
          uses_queue: m[:uses_queue],
          is_pure: m[:is_pure]
        },
        decision_trace: m[:decision_trace]
      }
    end

  choices = [
    {
      action: 'unit',
      label: 'Unit — faster, more stubs/mocks',
      flag: '--low-confidence=unit'
    },
    {
      action: 'integration',
      label: 'Integration — real DB, external HTTP stubbed',
      flag: '--low-confidence=integration'
    }
  ]

  if file_type == 'controller'
    choices << {
      action: 'request',
      label: 'Request — full endpoint (controller)',
      flag: '--low-confidence=request'
    }
  end

  {
    decision: 'test_level_low_confidence',
    title: 'Test level is unclear',
    question: [
      "For #{class_name} methods, test level is unclear.",
      "File: #{source_file}",
      '',
      'Choose default:'
    ].join("\n"),
    recommended_action: recommended_action,
    context: {
      file: source_file,
      class_name: class_name,
      file_type: file_type,
      methods: methods_summary
    },
    choices: choices
  }
end

options = {
  metadata: nil,
  project_type: nil,
  format: 'json',
  low_confidence: nil
}

OptionParser.new do |opts|
  opts.banner = 'Usage: derive_test_config.rb --metadata PATH [options]'

  opts.on('--metadata=PATH', String, 'Path to metadata YAML file') { |v| options[:metadata] = v }
  opts.on('--project-type=TYPE', PROJECT_TYPES, 'Override project type') { |v| options[:project_type] = v }
  opts.on('--format=FORMAT', OUTPUT_FORMATS, 'Output format') { |v| options[:format] = v }
  opts.on('--low-confidence=CHOICE', LOW_CONFIDENCE_CHOICES, 'Resolve low-confidence decision (unit|integration|request)') do |v|
    options[:low_confidence] = v
  end
end.parse!

unless options[:metadata]
  warn 'Error: --metadata is required'
  exit 1
end

metadata_path = options[:metadata]
unless File.exist?(metadata_path)
  warn "Error: Metadata file not found: #{metadata_path}"
  exit 1
end

metadata =
  begin
    YAML.load_file(metadata_path)
  rescue Psych::Exception => e
    warn "Error: Cannot parse metadata YAML: #{e.class}: #{e.message}"
    exit 1
  end

unless metadata.is_a?(Hash)
  warn 'Error: metadata must be a Hash'
  exit 1
end

config = load_plugin_config
project_type = options[:project_type] || config['project_type']
project_type = project_type.to_s

if project_type.strip.empty?
  warn 'Error: project_type is required (pass --project-type or set in .claude/rspec-testing-config.yml)'
  exit 1
end

unless PROJECT_TYPES.include?(project_type)
  warn "Error: project_type must be one of: #{PROJECT_TYPES.join(', ')}"
  exit 1
end

source_file = metadata['source_file'].to_s
class_name = metadata['class_name'].to_s
if source_file.strip.empty? || class_name.strip.empty?
  warn 'Error: metadata must include source_file and class_name'
  exit 1
end

methods = metadata['methods']
unless methods.is_a?(Array) && !methods.empty?
  warn 'Error: metadata must include methods[]'
  exit 1
end

file_type = file_type_for(source_file, class_name)

derived = []
low_conf = []

methods.each do |m|
  next unless m.is_a?(Hash)

  begin
    tc = decide_test_config(project_type: project_type, file_type: file_type, method: m, metadata: metadata, class_name: class_name)
    derived << tc
    low_conf << tc if tc[:confidence] == 'low'
  rescue DeriveTestConfigError => e
    payload = { status: 'error', error: 'invalid_method', message: e.message }
    puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
    exit 1
  end
end

if low_conf.any? && options[:low_confidence].nil?
  suggested = low_conf.map { |m| m[:test_level] }
  recommended_action = suggested.include?('integration') ? 'integration' : 'unit'

  payload = {
    status: 'needs_decision',
    decisions: [
      low_confidence_decision_payload(
        source_file: source_file,
        class_name: class_name,
        file_type: file_type,
        low_methods: low_conf,
        recommended_action: recommended_action
      )
    ]
  }

  puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
  exit 2
end

low_conf_choice = options[:low_confidence]

automation = metadata['automation']
automation = {} unless automation.is_a?(Hash)

methods.each do |m|
  next unless m.is_a?(Hash)

  method_id = compute_method_id(class_name, m)
  tc = derived.find { |d| d[:method_id] == method_id }
  next unless tc

  confidence = tc[:confidence]
  test_level = tc[:test_level]
  isolation = tc[:isolation].dup
  decision_trace = tc[:decision_trace].dup

  if confidence == 'low'
    override = low_conf_choice || test_level
    decision_trace << "user_override_low_confidence: #{override}" if low_conf_choice

    test_level = override
    confidence = 'high'

    uses_db = tc[:uses_db] == true
    uses_external_http = tc[:uses_external_http] == true
    uses_queue = tc[:uses_queue] == true

    isolation['db'] =
      case test_level
      when 'request'
        'real'
      when 'integration'
        uses_db ? 'real' : 'none'
      else
        uses_db ? 'stubbed' : 'none'
      end
    isolation['external_http'] = uses_external_http ? 'stubbed' : 'none'
    isolation['queue'] = uses_queue ? 'stubbed' : 'none'
  end

  m['test_config'] = {
    'test_level' => test_level,
    'isolation' => isolation,
    'confidence' => confidence,
    'decision_trace' => decision_trace
  }
end

automation['isolation_decider_completed'] = true
metadata['automation'] = automation

File.write(metadata_path, metadata.to_yaml)

payload = {
  status: 'success',
  metadata: metadata_path,
  updated_methods: methods.count { |m| m.is_a?(Hash) && m.key?('test_config') },
  low_confidence_methods: low_conf.map { |m| m[:method_id] }
}

puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
exit 0

