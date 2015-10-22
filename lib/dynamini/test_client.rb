module Dynamini
  require 'ostruct'

  # In-memory database client for test purposes.
  class TestClient

    attr_reader :hash_key, :data

    def initialize(hash_key)
      @data = {}
      @hash_key = hash_key
    end

    def update_item(args = {})
      table = args[:table_name]
      updates = flatten_attribute_updates(args).merge(
          hash_key => args[:key][hash_key].to_s
      )
      @data[table] ||= {}
      if @data[table][args[:key][hash_key].to_s].present?
        @data[table][args[:key][hash_key].to_s].merge!(updates)
      else
        @data[table][args[:key][hash_key].to_s] = updates
      end
    end

    def get_item(args = {})
      table = args[:table_name]
      @data[table] ||= {}
      attributes_hash = @data[table][args[:key][hash_key]]
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

    def delete_item(args = {})
      @data[args[:table_name]].delete(args[:key][hash_key])
    end

    def reset
      @data = {}
    end

    private

    def flatten_attribute_updates(args = {})
      attribute_hash = {}

      args[:attribute_updates].each do |k, v|
        if v[:action] == 'ADD' && @data[args[:table_name]][args[:key][hash_key]]
          # if record has been saved
          attribute_hash[k] = (v[:value] + @data[args[:table_name]][args[:key][hash_key]][k].to_f).to_s
        else
          attribute_hash[k] = v[:value].to_s
        end
      end
      attribute_hash
    end
  end
end
