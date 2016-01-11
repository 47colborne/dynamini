module Dynamini
  module Increment

    def increment!(attributes, opts = {})
      attributes.each do |attr, value|
        validate_incrementable_attribute(attr, value)
      end
      increment_to_dynamo(attributes, opts)
    end

    private

    def increment_updates(attributes, opts = {})
      updates = {}
      attributes.each do |attr,value|
        updates[attr] = { value: value, action: 'ADD' }
      end
      updates[:updated_at] = { value: Time.now.to_f, action: 'PUT' } unless opts[:skip_timestamps]
      updates[:created_at] = { value: Time.now.to_f, action: 'PUT' } unless @attributes[:created_at]
      updates.stringify_keys
    end

    def validate_incrementable_attribute(attribute, value)
      validate_new_increment_value(value)
      validate_current_increment_value(attribute  )
    end

    def validate_new_increment_value(value)
      unless value.is_a?(Integer) || value.is_a?(Float)
        fail StandardError, "You cannot increment an attribute by a
          non-numeric value: #{value}"
      end
    end

    def validate_current_increment_value(attribute)
      current_value = read_attribute(attribute)
      unless current_value.nil? || current_value.is_a?(Integer) || current_value.is_a?(Float) || current_value.is_a?(BigDecimal)
        fail StandardError, "Cannot increment a non-numeric non-nil value:
                              #{attribute} is currently #{current_value}, a #{current_value.class}."
      end
    end

  end
end
