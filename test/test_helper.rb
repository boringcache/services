require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
  add_group 'Services', 'lib/boring_services/services'
  add_group 'Core', 'lib/boring_services'
end

begin
  require 'bundler/setup'
rescue StandardError => e
  warn "Skipping bundler/setup: #{e.message}" if ENV['VERBOSE']
end

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'boring_services'
require 'minitest/autorun'
