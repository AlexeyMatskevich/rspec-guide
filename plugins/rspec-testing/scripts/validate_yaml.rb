#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'yaml'

def read_stdin
  $stdin.read
end

def validate_yaml_string(yaml_string, label:)
  YAML.load(yaml_string)
  nil
rescue Psych::Exception => e
  "#{label}: #{e.class}: #{e.message}"
end

def validate_yaml_file(path)
  yaml_string = File.read(path)
  validate_yaml_string(yaml_string, label: path)
rescue Errno::ENOENT
  "#{path}: file not found"
rescue Errno::EACCES
  "#{path}: permission denied"
end

options = { stdin: false }

OptionParser.new do |opts|
  opts.banner = 'Usage: validate_yaml.rb [--stdin] [FILE ...]'

  opts.on('--stdin', 'Read YAML from stdin (in addition to any FILE arguments)') do
    options[:stdin] = true
  end
end.parse!

errors = []

if options[:stdin]
  err = validate_yaml_string(read_stdin, label: '(stdin)')
  errors << err if err
end

ARGV.each do |path|
  err = validate_yaml_file(path)
  errors << err if err
end

if errors.empty?
  puts 'OK'
  exit 0
else
  warn "YAML validation failed (#{errors.length}):"
  errors.each { |e| warn "- #{e}" }
  exit 1
end

