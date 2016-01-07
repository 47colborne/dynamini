module Dynamini
  module Querying

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
      fail 'Key cannot be blank.' if (hash_value.nil? || hash_value == '')
      fail 'Range key cannot be blank.' if range_key && range_value.nil?

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

    private

    def dynamo_query(args)
      expression_attribute_values = build_expression_attribute_values(args)
      key_condition_expression = build_key_condition_expression(args)

      client.query(
          table_name: table_name,
          key_condition_expression: key_condition_expression,
          expression_attribute_values: expression_attribute_values
      )
    end

    def build_expression_attribute_values(args)
      expression_values = {}
      expression_values[':h'] = args[:hash_key]
      expression_values[':s'] = args[:start] if args[:start]
      expression_values[':e'] = args[:end] if args[:end]
      expression_values
    end

    def build_key_condition_expression(args)
      expression = "#{hash_key} = :h"
      if args[:start] && args[:end]
        expression += " AND #{range_key} BETWEEN :s AND :e"
      elsif args[:start]
        expression += " AND #{range_key} >= :s"
      elsif args[:end]
        expression += " AND #{range_key} <= :e"
      end
      expression
    end

    #FIXME unused method
    def build_range_expression(start_value, end_value)
      operator = (
      if start_value && end_value
        'BETWEEN'
      elsif start_value
        'GE'
      elsif end_value
        'LE'
      end
      )
      attribute_value_list = []

      if handle = handles[range_key.to_sym]
        attribute_value_list << attribute_callback(SETTER_PROCS, handle, start_value) if start_value
        attribute_value_list << attribute_callback(SETTER_PROCS, handle, end_value) if end_value
      else
        attribute_value_list << start_value if start_value
        attribute_value_list << end_value if end_value
      end

      {attribute_value_list: attribute_value_list, comparison_operator: operator}
    end


  end
end