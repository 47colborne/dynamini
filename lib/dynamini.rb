module Dynamini
  require 'active_model'
  require 'dynamini/base'
  require 'dynamini/configuration'
  require 'dynamini/test_client'

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end