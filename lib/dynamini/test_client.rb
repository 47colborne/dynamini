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

    # No range key support - use query instead.
    def batch_get_item(args = {})
      responses = {}

      args[:request_items].each do |table_name, get_request|
        responses[table_name] = []
        get_request[:keys].each do |key_hash|
          item = get_table(table_name)[key_hash.values.first]
          responses[table_name] << item unless item.nil?
        end
      end

      OpenStruct.new(responses: responses)
    end

    def delete_item(args = {})
      get_table(args[:table_name]).delete(args[:key][hash_key_attr])
    end

    def query(args = {})
      # Possible key condition structures:
      # "foo = val"
      # "foo = val AND bar <= val2"
      # "foo = val AND bar >= val2"
      # "foo = val AND bar BETWEEN val2 AND val3"

      args[:expression_attribute_values].each do |symbol, value|
        args[:key_condition_expression].gsub!(symbol, value.to_s)
      end

      tokens = args[:key_condition_expression].split(/\s+/)
      hash_key = tokens[2]
      case tokens[5]
        when ">="
          start_val = tokens[6]
          end_val = nil
        when "<="
          start_val = nil
          end_val = tokens[6]
        when "BETWEEN"
          start_val = tokens[6]
          end_val = tokens[8]
        else
          start_val = nil
          end_val = nil
      end
      parent = get_table(args[:table_name])[hash_key]
      return OpenStruct.new(items:[]) unless parent

      selected = parent.values
      selected = selected.select{ |item| item[@range_key_attr] >= start_val.to_f } if start_val
      selected = selected.select{ |item| item[@range_key_attr] <= end_val.to_f } if end_val

      OpenStruct.new(items: selected)
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
          table = get_table(args[:table_name])

          if v[:action] == 'ADD' && table[hash_key_value]
            # if record has been saved
            data = table[hash_key_value]
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
