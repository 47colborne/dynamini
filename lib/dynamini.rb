module Dynamini
  require 'active_model'
  require 'dynamini/base'
  require 'dynamini/configuration'

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



# Dynamini.configure do |config|
#   config.aws_region = 'eu-west-1'
#   config.access_key_id =
#   config.secret_access_key =
# end
