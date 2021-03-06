require 'bundler/setup'
Bundler.setup

require 'aws-sdk-dynamodb'
require 'pry'
require 'dynamini'
require 'dynamini/testing'

RSpec.configure do |config|
  # For running just wanted tests in guard
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.after(:each) { Dynamini::Base.client.reset }
end
