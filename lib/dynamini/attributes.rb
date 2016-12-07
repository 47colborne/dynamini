module Dynamini
  module Attributes

    ADDABLE_TYPES = [:set, :array, :integer, :float, :time, :date]
    DELETED_TOKEN = '__deleted__'

    attr_reader :attributes

    def assign_attributes(attributes)
      attributes.each do |key, value|
        write_attribute(key, value)
      end
      nil
    end

    def update_attribute(key, value, options = {})
      write_attribute(key, value)
      save!(options)
    end

    def update_attributes(attributes, options = {})
      assign_attributes(attributes)
      save!(options)
    end

    def add_to(attribute, value)
      complain_about(attribute) unless self.class.handles[attribute]
      old_value = read_attribute(attribute)
      add_value = self.class.attribute_callback(TypeHandler::SETTER_PROCS,  self.class.handles[attribute], value, true)
      if ADDABLE_TYPES.include? self.class.handles[attribute][:format]
        @attributes[attribute] ? @attributes[attribute] += add_value : @attributes[attribute] = add_value
      else
        complain_about(attribute)
      end
      record_change(attribute, old_value, add_value, 'ADD')
      self
    end

    def delete_attribute(attribute)
      if @attributes[attribute]
        old_value = read_attribute(attribute)
        record_change(attribute, old_value, DELETED_TOKEN, 'DELETE')
        @attributes.delete(attribute)
      end
    end

    def delete_attribute!(attribute)
      delete_attribute(attribute)
      save!
    end

    private

    def attribute_updates
      changes.reduce({}) do |updates, (key, value)|
        current_value = value[1]
        updates[key] = { action: value[2] || 'PUT' }
        binding.pry
        updates[key][:value] = current_value unless current_value == DELETED_TOKEN
        updates
      end
    end

    def method_missing(name, *args, &block)
      if write_method?(name)
        write_attribute(attribute_name(name), args.first)
      elsif was_method?(name)
        __was(name)
      elsif read_method?(name)
        read_attribute(name)
      else
        super
      end
    end

    def attribute_name(name)
      name[0..-2].to_sym
    end

    def read_method?(name)
      name =~ /^([a-zA-Z][-_\w]*)[^=?]*$/
    end

    def write_method?(name)
      name =~ /^([a-zA-Z][-_\w]*)=.*$/
    end

    def complain_about(attribute)
      raise ArgumentError, "#{attribute.capitalize} is not handled as an addable type. Addable types are set, array, integer, float, time, and date."
    end

    def respond_to_missing?(name, include_private = false)
      @attributes.keys.include?(name) || write_method?(name) || was_method?(name) || super
    end

    def write_attribute(attribute, new_value, change: true, **options)
      old_value = read_attribute(attribute)
      if (handle = self.class.handles[attribute.to_sym]) && !new_value.nil?
        new_value = self.class.attribute_callback(TypeHandler::SETTER_PROCS, handle, new_value, change)
      end
      @attributes[attribute] = new_value
      record_change(attribute, old_value, new_value, options[:action]) if change && new_value != old_value
    end

    def read_attribute(name)
      value = @attributes[name]
      if (handle = self.class.handles[name.to_sym])
        value = handle[:options][:default] if value.nil?
        value = self.class.attribute_callback(TypeHandler::GETTER_PROCS, handle, value, false) unless value.nil?
      end
      value
    end
  end
end
