module Dynamini
  require 'ostruct'

  class TestClient

    attr_reader :hash_key

    def initialize(hash_key)
      @data = {}
      @hash_key = hash_key
    end

    def update_item(args = {})
      table = args[:table_name]
      @data[table] ||= {}
      @data[table][args[:key][hash_key]] = flatten_attribute_updates(args[:attribute_updates])
      @data[table][args[:key][hash_key]][hash_key] = args[:key][hash_key]
    end

    def get_item(args = {})
      attributes_hash = @data[args[:table_name]][args[:key][hash_key]]
      item = attributes_hash.nil? ? nil : attributes_hash
      OpenStruct.new(item: item)
    end

    def batch_get_item(args = {})
      responses = {}

      args[:request_items].each do |k, v|
        responses[k] = []
        v[:keys].each do |key_hash|
          item = @data[k][key_hash.values.first]
          responses[k] << item
        end
      end

      OpenStruct.new(responses: responses)
    end

    def batch_write_item(request_options)
      request_options[:request_items].each do |k, v|
        @data[k] ||= {}
        v.each do |request_hash|
          item = request_hash[:put_request][:item]
          key = item[hash_key]
          @data[k][key] = item
        end
      end
    end

    def reset
      @data = {}
    end

    private

    def flatten_attribute_updates(attribute_updates)
      attribute_hash = {}

      attribute_updates.each do |k, v|
        attribute_hash[k] = v[:value]
      end
      attribute_hash
    end

  end
end