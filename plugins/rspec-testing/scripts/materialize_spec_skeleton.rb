#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'yaml'

require_relative 'spec_structure_generator'
require_relative 'lib/method_block_patcher'

class MaterializeError < StandardError; end

SUPPORTED_RAILS_RSPEC_GENERATORS = %w[
  rspec:channel
  rspec:controller
  rspec:helper
  rspec:job
  rspec:mailbox
  rspec:model
  rspec:request
].freeze

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

def controller_paths(source_file)
  m = source_file.match(%r{\Aapp/controllers/(.+)\.rb\z})
  return nil unless m

  rel = m[1]
  rel_dir = File.dirname(rel)
  filename = File.basename(rel)

  request_name = filename.sub(/_controller\z/, '')
  preferred_spec_path =
    if rel_dir == '.'
      "spec/requests/#{request_name}_spec.rb"
    else
      "spec/requests/#{rel_dir}/#{request_name}_spec.rb"
    end
  legacy_spec_path = "spec/controllers/#{rel}_spec.rb"

  {
    preferred_spec_path: preferred_spec_path,
    preferred_exists: File.exist?(preferred_spec_path),
    legacy_spec_path: legacy_spec_path,
    legacy_exists: File.exist?(legacy_spec_path)
  }
end

def rails_rspec_generator_for(source_file, controllers_mode)
  case source_file
  when %r{\Aapp/models/(.+)\.rb\z}
    { generator: 'rspec:model', name: Regexp.last_match(1) }
  when %r{\Aapp/controllers/(.+)_controller\.rb\z}
    name = Regexp.last_match(1)
    generator = controllers_mode == 'controller' ? 'rspec:controller' : 'rspec:request'
    { generator: generator, name: name }
  when %r{\Aapp/channels/(.+)_channel\.rb\z}
    { generator: 'rspec:channel', name: Regexp.last_match(1) }
  when %r{\Aapp/helpers/(.+)_helper\.rb\z}
    { generator: 'rspec:helper', name: Regexp.last_match(1) }
  when %r{\Aapp/jobs/(.+)\.rb\z}
    { generator: 'rspec:job', name: Regexp.last_match(1) }
  when %r{\Aapp/mailboxes/(.+)_mailbox\.rb\z}
    { generator: 'rspec:mailbox', name: Regexp.last_match(1) }
  else
    nil
  end
end

def run_rails_generator(generator:, name:)
  unless SUPPORTED_RAILS_RSPEC_GENERATORS.include?(generator)
    raise MaterializeError, "Unsupported rails rspec generator: #{generator}"
  end

  cmd = ['bundle', 'exec', 'rails', 'generate', generator, name]
  stdout, stderr, status = Open3.capture3(*cmd)

  {
    cmd: cmd.join(' '),
    status: status.exitstatus,
    ok: status.success?,
    stdout: stdout,
    stderr: stderr
  }
end

def find_generated_spec_path(output)
  candidates = []

  output.to_s.each_line do |line|
    next unless line.match?(/\b(create|skip|identical)\b/i)

    token = line.strip.split(/\s+/).last
    next unless token
    next unless token.end_with?('_spec.rb')
    next unless token.include?('/')

    candidates << token
  end

  candidates.last
end

def prune_to_wrapper!(spec_path)
  lines = RspecTesting::Lines.read(spec_path)
  block = RspecTesting::RSpecDescribeBlock.find_any(lines)
  raise MaterializeError, "Cannot find RSpec.describe block in generated spec: #{spec_path}" unless block

  open_idx = block[:open_idx]
  close_idx = block[:close_idx]

  prefix = lines[0..open_idx]
  closing_end = lines[close_idx]

  wrapper = prefix + [''] + [closing_end]
  RspecTesting::Lines.write(spec_path, wrapper)
end

def ensure_parent_dir(path)
  FileUtils.mkdir_p(File.dirname(path))
end

def manual_create_wrapper!(spec_path, helper:, describe_line:)
  ensure_parent_dir(spec_path)

  lines = []
  lines << '# frozen_string_literal: true'
  lines << ''
  if helper && !helper.to_s.strip.empty?
    lines << "require '#{helper}'"
    lines << ''
  end
  lines << describe_line
  lines << 'end'
  RspecTesting::Lines.write(spec_path, lines)
end

def generate_blocks_lines(metadata, shared_examples_threshold:)
  behavior_resolver = BehaviorResolver.new(metadata['behaviors'])
  builder = ContextTreeBuilder.new(metadata['methods'], behavior_resolver)
  context_trees = builder.build

  generator = SpecCodeGenerator.new(
    metadata,
    context_trees,
    structure_mode: :blocks,
    shared_examples_threshold: shared_examples_threshold
  )

  blocks_text = generator.generate
  [blocks_text.split("\n", -1), builder.warnings]
end

def compute_method_id(class_name, method_hash)
  name = method_hash['name']
  type = method_hash['type']
  raise MaterializeError, 'Method missing name/type' if name.to_s.strip.empty? || type.to_s.strip.empty?

  type == 'class' ? "#{class_name}.#{name}" : "#{class_name}##{name}"
end

def controllers_spec_policy_decision(source_file, controllers_info)
  preferred_spec_path = controllers_info[:preferred_spec_path]
  legacy_spec_path = controllers_info[:legacy_spec_path]

  {
    decision: 'controllers_spec_policy',
    title: 'Rails controller spec policy',
    question: [
      'Legacy controller spec detected, but request spec is missing.',
      'Choose where controller tests should be written for this file.'
    ].join("\n"),
    recommended_action: 'request',
    context: {
      file: source_file,
      preferred_spec_path: preferred_spec_path,
      preferred_exists: bool(controllers_info[:preferred_exists]),
      legacy_spec_path: legacy_spec_path,
      legacy_exists: bool(controllers_info[:legacy_exists])
    },
    choices: [
      {
        action: 'request',
        label: 'Create request spec (recommended)',
        flag: '--controllers-choice=request',
        effects: {
          use_spec_path: preferred_spec_path
        }
      },
      {
        action: 'controller',
        label: 'Update existing legacy controller spec (not recommended)',
        flag: '--controllers-choice=controller',
        effects: {
          use_spec_path: legacy_spec_path
        }
      }
    ]
  }
end

def controllers_dual_specs_decision(source_file, controllers_info)
  preferred_spec_path = controllers_info[:preferred_spec_path]
  legacy_spec_path = controllers_info[:legacy_spec_path]

  {
    decision: 'controllers_dual_specs',
    title: 'Rails controller: both request and legacy specs exist',
    question: [
      'Both a request spec and a legacy controller spec exist for this controller.',
      'Choose which spec file should be updated by the pipeline.'
    ].join("\n"),
    recommended_action: 'request',
    context: {
      file: source_file,
      preferred_spec_path: preferred_spec_path,
      preferred_exists: bool(controllers_info[:preferred_exists]),
      legacy_spec_path: legacy_spec_path,
      legacy_exists: bool(controllers_info[:legacy_exists])
    },
    choices: [
      {
        action: 'request',
        label: 'Update request spec (recommended)',
        flag: '--controllers-choice=request',
        effects: {
          use_spec_path: preferred_spec_path
        }
      },
      {
        action: 'controller',
        label: 'Update legacy controller spec (not recommended)',
        flag: '--controllers-choice=controller',
        effects: {
          use_spec_path: legacy_spec_path
        }
      }
    ]
  }
end

def controllers_legacy_cleanup_decision(source_file, controllers_info)
  preferred_spec_path = controllers_info[:preferred_spec_path]
  legacy_spec_path = controllers_info[:legacy_spec_path]

  {
    decision: 'controllers_legacy_cleanup',
    title: 'Rails controller: legacy controller spec cleanup',
    question: [
      'A legacy controller spec exists under spec/controllers.',
      'Do you want to delete it after updating the request spec?'
    ].join("\n"),
    recommended_action: 'delete',
    context: {
      file: source_file,
      request_spec_path: preferred_spec_path,
      legacy_spec_path: legacy_spec_path
    },
    choices: [
      {
        action: 'keep',
        label: 'Keep legacy controller spec (no deletion)',
        flag: '--controllers-legacy=keep',
        effects: {
          delete_paths: []
        }
      },
      {
        action: 'delete',
        label: 'Delete legacy controller spec (recommended)',
        flag: '--controllers-legacy=delete',
        effects: {
          delete_paths: [legacy_spec_path]
        }
      }
    ]
  }
end

def new_method_conflict_decision(spec_path, method_id, detected_by:)
  {
    decision: 'new_method_conflict',
    title: 'Conflict: method_mode=new but spec already contains the block',
    question: [
      "Metadata marks this method as new, but the spec already contains a describe block for method_id=#{method_id}.",
      'Choose whether to overwrite the existing block or skip this method.'
    ].join("\n"),
    recommended_action: 'skip',
    context: {
      spec_path: spec_path,
      method_id: method_id,
      detected_by: detected_by
    },
    choices: [
      {
        action: 'overwrite',
        label: 'Overwrite existing method block',
        flag: "--new-conflict=#{method_id}=overwrite",
        effects: {
          patch_action: 'replace'
        }
      },
      {
        action: 'skip',
        label: 'Skip this method (leave existing block unchanged)',
        flag: "--new-conflict=#{method_id}=skip",
        effects: {
          patch_action: 'skip'
        }
      }
    ]
  }
end

options = {
  metadata: nil,
  spec: nil,
  project_type: nil,
  controllers_policy: nil,
  controllers_choice: nil,
  controllers_legacy: nil,
  new_conflicts: {},
  default_new_conflict: 'ask',
  format: 'json',
  only: [],
  shared_examples_threshold: 3
}

OptionParser.new do |opts|
  opts.banner = 'Usage: materialize_spec_skeleton.rb --metadata PATH [options]'

  opts.on('--metadata=PATH', String, 'Path to metadata YAML file') { |v| options[:metadata] = v }
  opts.on('--spec=PATH', String, 'Override target spec path (default: metadata spec_path)') { |v| options[:spec] = v }
  opts.on('--project-type=TYPE', %w[rails web service library], 'Override project type') { |v| options[:project_type] = v }
  opts.on('--controllers-policy=POLICY', %w[request controller ask], 'Override rails.controllers.spec_policy') { |v| options[:controllers_policy] = v }
  opts.on('--controllers-choice=CHOICE', %w[request controller], 'Resolve controllers ask-policy for this run') { |v| options[:controllers_choice] = v }
  opts.on('--controllers-legacy=ACTION', %w[keep delete], 'For request specs: keep or delete legacy spec/controllers/*_spec.rb') do |v|
    options[:controllers_legacy] = v
  end
  opts.on('--on-new-conflict=ACTION', %w[ask overwrite skip], 'Default action if method_mode=new but block exists') { |v| options[:default_new_conflict] = v }
  opts.on('--new-conflict=METHOD_ID=ACTION', String, 'Per-method conflict action for new methods (repeatable)') do |v|
    mid, action = v.split('=', 2)
    if mid.to_s.strip.empty? || action.to_s.strip.empty?
      raise OptionParser::InvalidArgument, '--new-conflict must be METHOD_ID=ACTION'
    end
    unless %w[overwrite skip].include?(action)
      raise OptionParser::InvalidArgument, '--new-conflict ACTION must be overwrite or skip'
    end
    options[:new_conflicts][mid] = action
  end
  opts.on('--only=METHOD_ID', String, 'Only patch this method_id (repeatable)') { |v| options[:only] << v }
  opts.on('--format=FORMAT', %w[json text], 'Output format') { |v| options[:format] = v }
  opts.on('--shared-examples-threshold=N', Integer, 'Deduplicate into shared_examples when count >= N (default: 3)') do |n|
    raise OptionParser::InvalidArgument, '--shared-examples-threshold must be >= 2' if n < 2
    options[:shared_examples_threshold] = n
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
controllers_policy = options[:controllers_policy] || config.dig('rails', 'controllers', 'spec_policy')
controllers_policy ||= 'request'

source_file = metadata['source_file'].to_s
class_name = metadata['class_name'].to_s
spec_path = options[:spec] || metadata['spec_path'].to_s

if source_file.strip.empty? || spec_path.strip.empty?
  warn 'Error: metadata must include source_file and spec_path'
  exit 1
end

if class_name.strip.empty?
  warn 'Error: metadata must include class_name'
  exit 1
end

if project_type.to_s.strip.empty?
  warn 'Error: project_type is required (pass --project-type or set in .claude/rspec-testing-config.yml)'
  exit 1
end

controllers_info = nil
controllers_mode = nil
if project_type == 'rails'
  controllers_info = controller_paths(source_file)
  if controllers_info
    if controllers_policy == 'ask' && options[:controllers_choice].nil?
      if controllers_info[:legacy_exists] && !controllers_info[:preferred_exists]
        payload = {
          status: 'needs_decision',
          decisions: [controllers_spec_policy_decision(source_file, controllers_info)]
        }
        puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
        exit 2
      end

      if controllers_info[:legacy_exists] && controllers_info[:preferred_exists]
        payload = {
          status: 'needs_decision',
          decisions: [controllers_dual_specs_decision(source_file, controllers_info)]
        }
        puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
        exit 2
      end
    end

    controllers_mode = options[:controllers_choice] || controllers_policy
    controllers_mode = 'request' unless %w[request controller].include?(controllers_mode)
    spec_path = controllers_mode == 'controller' && controllers_info[:legacy_exists] ? controllers_info[:legacy_spec_path] : controllers_info[:preferred_spec_path]
  end
end

created = false
created_by = nil
rails_generator = nil
rails_generator_output = nil

methods = metadata['methods']
unless methods.is_a?(Array) && !methods.empty?
  warn 'Error: metadata must include methods[]'
  exit 1
end

selected_method_ids = []
methods.each do |m|
  next unless m.is_a?(Hash)
  selected_method_ids << compute_method_id(class_name, m)
end
selected_method_ids &= options[:only] unless options[:only].empty?

decisions = []

# Rails controllers: if writing request specs and a legacy controller spec exists, ask whether to delete it.
if project_type == 'rails' && controllers_info && controllers_mode == 'request' && controllers_info[:legacy_exists] && options[:controllers_legacy].nil?
  decisions << controllers_legacy_cleanup_decision(source_file, controllers_info)
end

# Decide all new-method conflicts up-front (do not modify files until decisions resolved).
if File.exist?(spec_path)
  spec_lines_for_conflicts = RspecTesting::Lines.read(spec_path)

  begin
    marker_blocks = RspecTesting::MethodBlocks.extract(spec_lines_for_conflicts)
    descriptors_by_method_id = {}
    methods.each do |m|
      next unless m.is_a?(Hash)
      method_id = compute_method_id(class_name, m)
      next unless selected_method_ids.include?(method_id)
      next unless m['method_mode'].to_s == 'new'

      name = m['name'].to_s
      type = m['type'].to_s
      descriptor = type == 'class' ? ".#{name}" : "##{name}"
      descriptors_by_method_id[method_id] = descriptor
    end

    describe_blocks = RspecTesting::DescribeMethodBlocks.extract(spec_lines_for_conflicts, descriptors_by_method_id)
    existing_new_method_ids = (marker_blocks.keys & descriptors_by_method_id.keys) | (describe_blocks.keys & descriptors_by_method_id.keys)

    existing_new_method_ids.each do |method_id|
      action = options[:new_conflicts][method_id] || options[:default_new_conflict]
      next unless action == 'ask'

      detected_by =
        if marker_blocks.key?(method_id)
          'markers'
        elsif describe_blocks.key?(method_id)
          'describe'
        else
          'unknown'
        end
      decisions << new_method_conflict_decision(spec_path, method_id, detected_by: detected_by)
    end
  rescue RspecTesting::BlockParseError => e
    payload = { status: 'error', error: 'cannot_scan_spec_for_conflicts', message: e.message }
    puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
    exit 1
  end
end

unless decisions.empty?
  payload = { status: 'needs_decision', decisions: decisions }
  puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
  exit 2
end

# Create base spec file if needed (after all decisions).
unless File.exist?(spec_path)
  created = true

  helper = config.dig('rspec', 'helper')
  helper ||= (project_type == 'rails' ? 'rails_helper' : 'spec_helper')

  if project_type == 'rails'
    controllers_mode = if controllers_info
                         options[:controllers_choice] || controllers_policy
                       else
                         controllers_policy
                       end
    controllers_mode = 'request' unless %w[request controller].include?(controllers_mode)

    gen = rails_rspec_generator_for(source_file, controllers_mode)
    if gen
      rails_generator = gen[:generator]
      rails_generator_output = run_rails_generator(generator: gen[:generator], name: gen[:name])
      unless rails_generator_output[:ok]
        payload = {
          status: 'error',
          error: 'rails_generator_failed',
          cmd: rails_generator_output[:cmd],
          exit_status: rails_generator_output[:status],
          stdout: rails_generator_output[:stdout],
          stderr: rails_generator_output[:stderr]
        }
        puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
        exit 1
      end

      generated_path = find_generated_spec_path(rails_generator_output[:stdout].to_s + "\n" + rails_generator_output[:stderr].to_s)
      if generated_path && File.exist?(generated_path) && !File.exist?(spec_path)
        spec_path = generated_path
      end

      unless File.exist?(spec_path)
        payload = {
          status: 'error',
          error: 'rails_generator_did_not_create_spec',
          expected_spec_path: spec_path,
          cmd: rails_generator_output[:cmd],
          stdout: rails_generator_output[:stdout],
          stderr: rails_generator_output[:stderr]
        }
        puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
        exit 1
      end

      created_by = 'rails_generator'
      prune_to_wrapper!(spec_path)
    else
      created_by = 'manual_wrapper'
      manual_create_wrapper!(spec_path, helper: helper, describe_line: "RSpec.describe #{class_name} do")
    end
  else
    created_by = 'manual_wrapper'
    manual_create_wrapper!(spec_path, helper: helper, describe_line: "RSpec.describe #{class_name} do")
  end
end

blocks_lines, generator_warnings =
  begin
    generate_blocks_lines(metadata, shared_examples_threshold: options[:shared_examples_threshold])
  rescue ArgumentError, MaterializeError => e
    payload = { status: 'error', error: 'cannot_generate_blocks', message: e.message }
    puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
    exit 1
  end

spec_lines = RspecTesting::Lines.read(spec_path)

operations = []
patched_lines = spec_lines.dup

methods.each do |m|
  next unless m.is_a?(Hash)

  method_id = compute_method_id(class_name, m)
  next unless selected_method_ids.include?(method_id)

  method_mode = m['method_mode'].to_s
  mode = method_mode == 'new' ? 'insert' : 'upsert'

  conflict_action = options[:new_conflicts][method_id] || options[:default_new_conflict]
  conflict_policy = case conflict_action
                    when 'overwrite' then 'overwrite'
                    when 'skip' then 'skip'
                    else 'error'
                    end

  patcher = RspecTesting::MethodBlockPatcher.new(
    spec_lines: patched_lines,
    blocks_lines: blocks_lines,
    mode: mode,
    conflict: conflict_policy,
    only_method_ids: [method_id],
    class_name: class_name
  )

  begin
    patched_lines, result = patcher.run
    operations.concat(result[:operations])
  rescue RspecTesting::ConflictError => e
    payload = { status: 'error', error: 'unexpected_conflict_after_decisions', message: e.message }
    puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
    exit 1
  rescue RspecTesting::ApplyError, RspecTesting::BlockParseError => e
    payload = { status: 'error', error: 'patch_failed', message: e.message }
    puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
    exit 1
  end
end

RspecTesting::Lines.write(spec_path, patched_lines)

# Rails controllers: optionally delete legacy controller spec after writing request spec.
deleted_legacy_controller_spec = nil
if project_type == 'rails' && controllers_info && controllers_mode == 'request' && options[:controllers_legacy] == 'delete'
  legacy = controllers_info[:legacy_spec_path]
  if legacy && File.exist?(legacy) && legacy != spec_path
    FileUtils.rm_f(legacy)
    deleted_legacy_controller_spec = legacy
  end
end

outline =
  begin
    SpecOutlineGenerator.new(spec_path, only_method_ids: selected_method_ids).generate
  rescue ArgumentError => e
    "Error: Cannot outline spec: #{e.message}"
  end

payload = {
  status: 'success',
  spec_path: spec_path,
  created: bool(created),
  created_by: created_by,
  rails_generator: rails_generator,
  deleted_legacy_controller_spec: deleted_legacy_controller_spec,
  operations: operations,
  outline: outline
}
payload[:warnings] = generator_warnings unless generator_warnings.empty?
payload[:rails_generator_output] = rails_generator_output if rails_generator_output && !rails_generator_output[:stdout].to_s.strip.empty?

puts(options[:format] == 'json' ? JSON.pretty_generate(payload) : payload.inspect)
exit 0
