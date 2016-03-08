module Dynamini
  require 'ostruct'

  # In-memory database client for test purposes.
  class TestClient

    attr_reader :hash_key_attr, :data, :range_key_attr, :secondary_index

    def initialize(hash_key_attr, range_key_attr = nil, secondary_index=nil)
      @data = {}
      @hash_key_attr = hash_key_attr
      @range_key_attr = range_key_attr
      @secondary_index = secondary_index
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

      primary_index_insertion(hash_key_value, range_key_value, updates, table) if hash_key_value

    end

    def primary_index_insertion(hash_key_value, range_key_value, updates, table)
      if range_key_value
        primary_with_range_insertion(hash_key_value, range_key_value, updates, table)
      else
        primary_only_hash_insertion(hash_key_value, updates, table)
      end
    end

    def primary_with_range_insertion(hash_key_value, range_key_value, updates, table)
      updates.merge!(range_key_attr => range_key_value)
      if table[hash_key_value] && table[hash_key_value][range_key_value]
        table[hash_key_value][range_key_value].merge! updates
      else
        table[hash_key_value] ||= {}
        table[hash_key_value][range_key_value] = updates
      end
    end

    def primary_only_hash_insertion(hash_key_value, updates, table)
      table[hash_key_value] ? table[hash_key_value].merge!(updates) : table[hash_key_value] = updates
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

    # TODO add range key support
    def batch_write_item(request_options)
      request_options[:request_items].each do |table_name, put_requests|
        put_requests.each do |request_hash|
          item = request_hash[:put_request][:item]
          key = item[hash_key_attr.to_s]
          get_table(table_name)[key] = item
        end
      end
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
      start_val, end_val = range_key_limits(tokens)

      if args[:index_name]
        secondary_index_query(args)
      else
        hash_key = hash_key_value(args).is_a?(Integer) ? tokens[2].to_i : tokens[2]

        parent = get_table(args[:table_name])[hash_key]
        return OpenStruct.new(items: []) unless parent
        selected = apply_filter_options(parent, args, start_val, end_val)

        OpenStruct.new(items: selected)
      end
    end

    def range_key_limits(tokens)
      case tokens[5]
        when ">=" then [tokens[6], nil]
        when "<=" then [nil, tokens[6]]
        when "BETWEEN" then [tokens[6], tokens[8]]
        else [nil, nil]
      end
    end

    def apply_filter_options(parent, args, start_val, end_val)
      records = parent.values
      records = records.select { |record| record[@range_key_attr] >= start_val.to_f } if start_val
      records = records.select { |record| record[@range_key_attr] <= end_val.to_f } if end_val
      records = records.sort! { |a, b| b[@range_key_attr] <=> a[@range_key_attr] } if args[:scan_index_forward] == false
      records = records[0...args[:limit]] if args[:limit]
      records
    end


    def secondary_index_query(args = {})
      index = secondary_index[args[:index_name]]
      table = get_table(args[:table_name])

      tokens = args[:key_condition_expression].split(/\s+/)
      start_val, end_val = range_key_limits(tokens)

      records = @range_key_attr ? get_values(table) : table.values
      selected = sort_records(records, index, args, start_val, end_val)
      OpenStruct.new(items: selected)
    end

    def sort_records(records, index, args, start_val, end_val)
      records = records.select { |record| record[get_secondary_hash_key(index)] == hash_key_value(args) }
      records = records.select { |record| record[get_secondary_range_key(index)] >= start_val.to_f } if start_val
      records = records.select { |record| record[get_secondary_range_key(index)] <= end_val.to_f } if end_val
      records = records.sort { |a, b| a[get_secondary_range_key(index)] <=> b[get_secondary_range_key(index)] }
      records = records.reverse if args[:scan_index_forward] == false
      records = records[0...args[:limit]] if args[:limit]
      records
    end

    def get_secondary_hash_key(index)
      index[:hash_key_name] == @hash_key_attr ? index[:hash_key_name] : index[:hash_key_name].to_s
    end

    def get_secondary_range_key(index)
      index[:range_key_name] == @range_key_attr ? index[:range_key_name] : index[:range_key_name].to_s
    end

    def reset
      @data = {}
    end

    private

    def hash_key_value(args)
      args[:expression_attribute_values][":h"]
    end

    def get_values(table, records=[])
      table.values.each { |value| records += value.values }
      records
    end

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
