module Dynamini
  module Adder

    ADDABLE_TYPES = [:set, :array, :integer, :float, :time, :date]

    def add_to(attribute, value)
      complain_about(attribute) unless handles[attribute]
      old_value = read_attribute(attribute)
      add_value = self.class.attribute_callback(TypeHandler::SETTER_PROCS, handles[attribute], value, true)
      if ADDABLE_TYPES.include? handles[attribute][:format]
        @attributes[attribute] ? @attributes[attribute] += add_value : @attributes[attribute] = add_value
      else
        complain_about(attribute)
      end
      record_change(attribute, old_value, add_value, 'ADD')
      self
    end

    private

    def complain_about(attribute)
      raise ArgumentError, "#{attribute.capitalize} is not handled as an addable type. Addable types are set, array, integer, float, time, and date."
    end
  end
end
