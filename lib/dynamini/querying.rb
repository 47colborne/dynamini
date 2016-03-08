module Dynamini
  module Querying
    OPTIONAL_QUERY_PARAMS = [:limit, :scan_index_forward]

    def find(hash_value, range_value = nil)
      fail 'Range key cannot be blank.' if range_key && range_value.nil?
      response = client.get_item(table_name: table_name, key: create_key_hash(hash_value, range_value))
      raise 'Item not found.' unless response.item
      new(response.item.symbolize_keys, false)
    end

    def exists?(hash_value, range_value = nil)
      fail 'Range key cannot be blank.' if range_key && range_value.nil?

      r = client.get_item(table_name: table_name, key: create_key_hash(hash_value, range_value))
      r.item.present?
    end

    def find_or_new(hash_value, range_value = nil)
      validate_query_values(hash_value, range_value)


      r = client.get_item(table_name: table_name, key: create_key_hash(hash_value, range_value))
      if r.item
        new(r.item.symbolize_keys, false)
      else
        range_key ? new(hash_key => hash_value, range_key => range_value) : new(hash_key => hash_value)
      end
    end

    def query(args = {})
      fail ArgumentError, 'You must provide a :hash_key.' unless args[:hash_key]
      fail TypeError, 'Your range key must be handled as an integer, float, date, or time.' unless self.range_is_numeric?

      response = dynamo_query(args)
      objects = []
      response.items.each do |item|
        objects << new(item.symbolize_keys, false)
      end
      objects
    end

    protected

    def range_is_numeric?
      handles[@range_key] && [:integer, :time, :float, :date].include?(handles[@range_key][:format])
    end

    private

    def dynamo_query(args)
      expression_attribute_values = build_expression_attribute_values(args)
      key_condition_expression = build_key_condition_expression(args)
      query = set_extra_parameters(
          {
              table_name: table_name,
          key_condition_expression: key_condition_expression,
          expression_attribute_values: expression_attribute_values
      },
          args)
      client.query(query)
    end

    def build_expression_attribute_values(args)
      expression_values = {}
      expression_values[':h'] = args[:hash_key]
      expression_values[':s'] = args[:start] if args[:start]
      expression_values[':e'] = args[:end] if args[:end]
      expression_values
    end

    def build_key_condition_expression(args)
      expression = "#{current_index_hash_key(args)} = :h"
      if args[:start] && args[:end]
        expression += " AND #{current_index_range_key(args)} BETWEEN :s AND :e"
      elsif args[:start]
        expression += " AND #{current_index_range_key(args)} >= :s"
      elsif args[:end]
        expression += " AND #{current_index_range_key(args)} <= :e"
      end
      expression
    end

    def current_index_hash_key(args)
      args[:index_name] ? secondary_index[args[:index_name].to_s][:hash_key_name] : hash_key
    end

    def current_index_range_key(args)
      args[:index_name] ? secondary_index[args[:index_name].to_s][:range_key_name] : range_key
    end

    def set_extra_parameters(hash, args)
      extras = args.select { |k, v| OPTIONAL_QUERY_PARAMS.include? k }
      extras[:index_name] = args[:index_name].to_s if args[:index_name]
      hash.merge!(extras)
    end

    def validate_query_values(hash_value, range_value)
      fail 'Key cannot be blank.' if (hash_value.nil? || hash_value == '')
      fail 'Range key cannot be blank.' if range_key && range_value.nil?
    end
  end
end