module Dynamini
  module Dirty

    def changes
      @changes.delete_if { |attr, _value| keys.include?(attr) }
          .stringify_keys
    end

    def changed
      changes.keys.map(&:to_s)
    end

    def new_record?
      @new_record
    end

    private

    def record_change(attribute, new_value, old_value)
      @changes[attribute] = [old_value, new_value]
    end

    def clear_changes
      @changes = Hash.new { |hash, key| hash[key] = Array.new(2) }
    end

    def was_method?(name)
      method_name = name.to_s
      read_method?(method_name) && method_name.end_with?('_was')
    end

    def __was(name)
      attr_name = name[0..-5].to_sym
      raise ArgumentError unless (@attributes[attr_name] || handles[attr_name])
      @changes[attr_name].compact.present? ? @changes[attr_name][0] : read_attribute(attr_name)
    end
  end
end