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

    def mark(attr)
      if @changes[attr][0..1] == [nil, nil]
        val = @attributes[attr]
        @changes[attr][0..1] = [val, val]
      end
    end

    private

    def record_change(attribute, old_value, new_value, action)
      action ||= 'PUT'
      @changes[attribute] = [old_value, new_value, action]
    end

    def clear_change(attribute)
      @changes.delete(attribute)
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
