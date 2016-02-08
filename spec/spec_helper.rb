require 'bundler/setup'
Bundler.setup

require 'aws-sdk'
require 'pry'
require 'fuubar'
require 'dynamini'
require 'dynamini/testing'

RSpec.configure do |config|
  # For running just wanted tests in guard
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.after(:each) { Dynamini::Base.client.reset }
end