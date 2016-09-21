module Dynamini
  module Adder
    def add_to(attribute, value)
      complain_about(attribute) unless handles[attribute]
      old_value = read_attribute(attribute)
      add_value = attribute_callback(Dynamini::TypeHandler::SETTER_PROCS, handles[attribute], value)
      case handles[attribute][:format]
        when :set, :array
          @attributes[attribute] += add_value
        when :integer, :float, :time, :date
          @attributes[attribute] += add_value
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
