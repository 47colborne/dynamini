module Dynamini
  require 'ostruct'

  # In-memory database client for test purposes.
  class TestClient

    attr_reader :hash_key, :data, :range_key

    def initialize(hash_key, range_key=nil)
      @data = {}
      @hash_key = hash_key
      @range_key = range_key
    end

    def update_item(args = {})
      table = args[:table_name]
      arg_keys = args[:key]
      arg_hash_key_str = arg_keys[hash_key]
      arg_range_key_str = arg_keys[range_key]

      updates = flatten_attribute_updates(args).merge(
          hash_key => arg_hash_key_str
      )

      @data[table] ||= {}

      #existing record for hash && range
      if @data[table][arg_hash_key_str].present? && arg_keys[hash_key].present? && @range_key.present? && arg_keys[range_key].present?
        updates.merge!(range_key => arg_range_key_str)

        @data[table][arg_hash_key_str][arg_range_key_str].merge! updates

      #new record for hash & range ONLY
      elsif arg_keys[hash_key].present? && arg_keys[range_key].present?
        updates.merge!(range_key => arg_range_key_str)

        @data[table][arg_hash_key_str] ||= {}
        @data[table][arg_hash_key_str][arg_range_key_str] = updates

      #existing record for hash ONLY
      elsif @data[table][arg_hash_key_str].present?
        @data[table][arg_hash_key_str].merge!(updates)

      #new record for hash ONLY
      elsif arg_keys[hash_key].present?
        @data[table][arg_hash_key_str] = updates
      end

    end

    def get_item(args = {})
      table = args[:table_name]
      hash_key_value = args[:key][hash_key]
      range_key_value = args[:key][range_key]

      @data[table] ||= {}

      if hash_key_value && range_key_value
        attributes_hash = @data[table][hash_key_value]
        attributes_hash = attributes_hash[range_key_value] if attributes_hash
      else
        attributes_hash = @data[table][hash_key_value]
      end

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

      hash_key_value = args[:key][hash_key]
      range_key_value = args[:key][range_key]

      if args[:attribute_updates]
        args[:attribute_updates].each do |k, v|

          if v[:action] == 'ADD' && @data[args[:table_name]][hash_key_value]
            # if record has been saved
            data = @data[args[:table_name]][hash_key_value]
            data = data[range_key_value] if range_key_value
            attribute_hash[k] = (v[:value] + data[k].to_f)
          else
            attribute_hash[k] = v[:value]
          end
        end
      end

      attribute_hash
    end
  end
end
