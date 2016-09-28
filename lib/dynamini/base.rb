require_relative 'batch_operations'
require_relative 'querying'
require_relative 'client_interface'
require_relative 'dirty'
require_relative 'increment'
require_relative 'type_handler'
require_relative 'adder'
require_relative 'errors'

module Dynamini
  # Core db interface class.
  class Base
    include ActiveModel::Validations
    extend ActiveModel::Callbacks
    extend Dynamini::BatchOperations
    extend Dynamini::Querying
    include Dynamini::ClientInterface
    include Dynamini::Dirty
    include Dynamini::Increment
    include Dynamini::TypeHandler
    include Dynamini::Adder

    attr_reader :attributes
    class_attribute :handles

    self.handles = {
        created_at: {format: :time, options: {}},
        updated_at: {format: :time, options: {}}
    }

    define_model_callbacks :save

    class << self

      attr_reader :range_key, :secondary_index

      def table_name
        @table_name ||= name.demodulize.tableize
      end

      def set_table_name(name)
        @table_name = name
      end

      def set_hash_key(key)
        @hash_key = key
      end

      def set_range_key(key)
        @range_key = key
      end

      def set_secondary_index(index_name, args)
        @secondary_index ||= {}
        @secondary_index[index_name.to_s] = {hash_key_name: args[:hash_key] || hash_key, range_key_name: args[:range_key]}
      end

      def hash_key
        @hash_key || :id
      end

      def create(attributes, options = {})
        model = new(attributes, true)
        model if model.save(options)
      end

      def create!(attributes, options = {})
        model = new(attributes, true)
        model if model.save!(options)
      end
    end

    #### Instance Methods

    def initialize(attributes = {}, new_record = true)
      @new_record = new_record
      @attributes = {}
      clear_changes
      attributes.each do |k, v|
        write_attribute(k, v, change: new_record)
      end
    end

    def keys
      [self.class.hash_key, self.class.range_key]
    end

    def ==(other)
      hash_key == other.hash_key if other.is_a?(self.class)
    end

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

    def save(options = {})
      run_callbacks :save do
        @changes.empty? || (valid? && trigger_save(options))
      end
    end

    def save!(options = {})
      run_callbacks :save do
        options[:validate] = true if options[:validate].nil?

        unless @changes.empty?
          if (options[:validate] && valid?) || !options[:validate]
            trigger_save(options)
          else
            raise StandardError, errors.full_messages
          end
        end
      end
    end

    def touch(options = {validate: true})
      raise RuntimeError, 'Cannot touch a new record.' if new_record?
      if (options[:validate] && valid?) || !options[:validate]
        trigger_touch
      else
        raise StandardError, errors.full_messages
      end
    end

    def delete
      delete_from_dynamo
      self
    end

    private

    def trigger_save(options = {})
      generate_timestamps! unless options[:skip_timestamps]
      save_to_dynamo
      clear_changes
      @new_record = false
      true
    end

    def trigger_touch
      generate_timestamps!
      touch_to_dynamo
      true
    end

    def generate_timestamps!
      self.updated_at = Time.now.to_f
      self.created_at = Time.now.to_f if new_record?
    end

    def key
      key_hash = {self.class.hash_key => @attributes[self.class.hash_key]}
      key_hash[self.class.range_key] = @attributes[self.class.range_key] if self.class.range_key
      key_hash
    end

    def self.create_key_hash(hash_value, range_value = nil)
      key_hash = {self.hash_key => hash_value}
      key_hash[self.range_key] = range_value if self.range_key
      key_hash
    end

    def attribute_updates
      changes.reduce({}) do |updates, (key, value)|
        current_value = value[1]
        updates[key] = { value: current_value, action: value[2] || 'PUT' }
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

    def respond_to_missing?(name, include_private = false)
      @attributes.keys.include?(name) || write_method?(name) || was_method?(name) || super
    end

    def write_attribute(attribute, new_value, change: true, **options)
      old_value = read_attribute(attribute)
      if (handle = handles[attribute.to_sym]) && !new_value.nil?
        new_value = attribute_callback(SETTER_PROCS, handle, new_value)
      end
      @attributes[attribute] = new_value
      record_change(attribute, old_value, new_value, options[:action]) if change && new_value != old_value
    end

    def read_attribute(name)
      value = @attributes[name]
      if (handle = handles[name.to_sym])
        value = handle[:options][:default] if value.nil?
        value = attribute_callback(GETTER_PROCS, handle, value) unless value.nil?
      end
      value
    end
  end
end
