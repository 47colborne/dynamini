module Dynamini
  require 'ostruct'

  # In-memory database client for test purposes.
  class TestClient

    attr_reader :hash_key_attr, :data, :range_key_attr

    def initialize(hash_key_attr, range_key_attr = nil)
      @data = {}
      @hash_key_attr = hash_key_attr
      @range_key_attr = range_key_attr
    end

    def get_table(table_name)
      @data[table_name] ||= {}
    end

    def update_item(args = {})
      table = get_table(args[:table_name])

      keys = args[:key]

      hash_key_value = keys[hash_key_attr]
      range_key_value = keys[range_key_attr]

      updates = flatten_attribute_updates(args).merge(
          hash_key_attr => hash_key_value
      )

      if hash_key_value
        if range_key_value
          updates.merge!(range_key_attr => range_key_value)
          if table[hash_key_value] && table[hash_key_value][range_key_value]
            table[hash_key_value][range_key_value].merge! updates
          else
            table[hash_key_value] ||= {}
            table[hash_key_value][range_key_value] = updates
          end

        else
          if table[hash_key_value]
            table[hash_key_value].merge!(updates)
          else
            table[hash_key_value] = updates
          end
        end
      end

    end

    def get_item(args = {})
      table = get_table(args[:table_name])

      hash_key_value = args[:key][hash_key_attr]
      range_key_value = args[:key][range_key_attr]

      attributes_hash = table[hash_key_value]
      attributes_hash = attributes_hash[range_key_value] if attributes_hash && range_key_value

      OpenStruct.new(item: attributes_hash)
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
          key = item[hash_key_attr]
          @data[k][key] = item
        end
      end
    end

    def delete_item(args = {})
      @data[args[:table_name]].delete(args[:key][hash_key_attr])
    end

    def reset
      @data = {}
    end

    private

    def flatten_attribute_updates(args = {})
      attribute_hash = {}

      hash_key_value = args[:key][hash_key_attr]
      range_key_value = args[:key][range_key_attr]

      if args[:attribute_updates]
        args[:attribute_updates].each do |k, v|

          if v[:action] == 'ADD' && @data[args[:table_name]][hash_key_value]
            # if record has been saved
            data = @data[args[:table_name]][hash_key_value]
            data = (data[range_key_value] ||= {}) if range_key_value

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
