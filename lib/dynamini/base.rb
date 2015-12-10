module Dynamini
  # Core db interface class.
  class Base
    include ActiveModel::Validations

    attr_reader :attributes

    class_attribute :handles

    self.handles = {
          created_at: { format: :time, options: {} },
          updated_at: { format: :time, options: {} }
        }

    BATCH_SIZE = 25

    GETTER_PROCS = {
        integer:  proc { |v| v.to_i },
        date:     proc { |v| v.is_a?(Date) ? v : Time.at(v).to_date },
        time:     proc { |v| Time.at(v.to_f) },
        float:    proc { |v| v.to_f },
        symbol:   proc { |v| v.to_sym },
        string:   proc { |v| v },
        boolean:  proc { |v| v }
    }

    SETTER_PROCS = {
        integer:  proc { |v| v.to_i },
        time:     proc { |v| (v.is_a?(Date) ? v.to_time : v).to_f },
        float:    proc { |v| v.to_f },
        symbol:   proc { |v| v.to_s },
        string:   proc { |v| v },
        boolean:  proc { |v| v },
        date:     proc { |v| v.to_time.to_f }
    }

    class << self
      attr_writer :batch_write_queue, :in_memory
      attr_reader :range_key

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

      def handle(column, format_class, options = {})
        self.handles = self.handles.merge(column => { format: format_class, options: options })

        define_handled_getter(column, format_class, options)
        define_handled_setter(column, format_class)
      end

      def hash_key
        @hash_key || :id
      end

      def in_memory
        @in_memory || false
      end

      def batch_write_queue
        @batch_write_queue ||= []
      end

      def client
        if in_memory
          @client ||= Dynamini::TestClient.new(hash_key, range_key)
        else
          @client ||= Aws::DynamoDB::Client.new(
              region: Dynamini.configuration.region,
              access_key_id: Dynamini.configuration.access_key_id,
              secret_access_key: Dynamini.configuration.secret_access_key
          )
        end
      end

      def create(attributes, options = {})
        model = new(attributes, true)
        model if model.save(options)
      end

      def create!(attributes, options = {})
        model = new(attributes, true)
        model if model.save!(options)
      end

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

      def batch_find(ids = [])
        return [] if ids.length < 1
        objects = []
        fail StandardError, 'Batch is limited to 100 items' if ids.length > 100
        key_structure = ids.map { |i| { hash_key => i.to_s } }
        response = dynamo_batch_get(key_structure)
        response.responses[table_name].each do |item|
          objects << new(item.symbolize_keys, false)
        end
        objects
      end

      def query(args = {})
        fail ArgumentError, 'You must provide a :hash_key.' unless args[:hash_key]
        fail TypeError, 'Your range key must be handled as an integer, float, date, or time.' unless self.range_is_numeric?

        response = self.dynamo_query(args)
        objects = []
        response.items.each do |item|
          objects << new(item.symbolize_keys, false)
        end
        objects
      end

      def enqueue_for_save(attributes, options = {})
        model = new(attributes, true)
        model.generate_timestamps! unless options[:skip_timestamps]
        if model.valid?
          batch_write_queue << model
          flush_queue! if batch_write_queue.length == BATCH_SIZE
          return true
        end
        false
      end

      def flush_queue!
        response = dynamo_batch_save(batch_write_queue)
        self.batch_write_queue = []
        response
      end

    end

    #### Instance Methods

    def initialize(attributes = {}, new_record = true)
      @new_record = new_record
      @attributes = {}
      clear_changes
      attributes.each do |k, v|
        write_attribute(k, v, new_record)
      end
    end

    def keys
      [self.class.hash_key, self.class.range_key]
    end

    def changes
      @changes.delete_if { |attr, value| keys.include?(attr) }
              .stringify_keys
    end

    def changed
      changes.keys.map(&:to_s)
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
      @changes.empty? || (valid? && trigger_save(options))
    end

    def save!(options = {})
      options[:validate] = true if options[:validate].nil?

      unless @changes.empty?
        if (options[:validate] && valid?) || !options[:validate]
          trigger_save(options)
        else
          raise StandardError, errors.full_messages
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

    def increment!(attributes, opts = {})
      attributes.each do |attr, value|
        validate_incrementable_attribute(attr, value)
      end
      increment_to_dynamo(attributes, opts)
    end

    def delete
      delete_from_dynamo
      self
    end


    def new_record?
      @new_record
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

    def save_to_dynamo
      self.class.client.update_item(
          table_name: self.class.table_name,
          key: key,
          attribute_updates: attribute_updates
      )
    end

    def touch_to_dynamo
      self.class.client.update_item(
          table_name: self.class.table_name,
          key: key,
          attribute_updates:
              { updated_at:
                   { value: Time.now.to_f,
                    action: 'PUT'
                   }
              }
      )
    end

    def delete_from_dynamo
      self.class.client.delete_item(table_name: self.class.table_name, key: key)
    end

    def increment_to_dynamo(attributes, opts = {})
      self.class.client.update_item(
          table_name: self.class.table_name,
          key: key,
          attribute_updates: increment_updates(attributes, opts)
      )
    end

    def self.dynamo_batch_get(key_struct)
      client.batch_get_item(
          request_items: {
              table_name => { keys: key_struct }
          }
      )
    end

    def self.dynamo_batch_save(model_array)
      put_requests = []
      model_array.each do |model|
        put_requests << { put_request: {
            item: model.attributes.reject{ |_k, v| v.blank? }.stringify_keys
        } }
      end
      request_options = { request_items: {
          "#{table_name}" => put_requests }
      }
      client.batch_write_item(request_options)
    end

    def self.dynamo_query(args)
      expression_attribute_values = self.build_expression_attribute_values(args)
      key_condition_expression = self.build_key_condition_expression(args)

      client.query(
          table_name: table_name,
          key_condition_expression: key_condition_expression,
          expression_attribute_values: expression_attribute_values
      )
    end

    def self.build_expression_attribute_values(args)
      expression_values = {}
      expression_values[':h'] = args[:hash_key]
      expression_values[':s'] = args[:start] if args[:start]
      expression_values[':e'] = args[:end] if args[:end]
      expression_values
    end

    def self.build_key_condition_expression(args)
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

    def key
      key_hash = { self.class.hash_key => @attributes[self.class.hash_key] }
      key_hash[self.class.range_key] = @attributes[self.class.range_key] if self.class.range_key
      key_hash
    end

    def self.create_key_hash(hash_value, range_value = nil)
      key_hash = { self.hash_key => hash_value }
      key_hash[self.range_key] = range_value if self.range_key
      key_hash
    end

    def self.build_range_expression(start_value, end_value)
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


    def attribute_updates
      changes.reduce({}) do |updates, (key, value)|
        current_value = value[1]
        updates[key] = {value: current_value, action: 'PUT'} unless current_value.blank?
        updates
      end
    end

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
      if value.is_a?(Integer) || value.is_a?(Float)
        current_value = read_attribute(attribute)
        unless current_value.nil? || current_value.is_a?(Integer) || current_value.is_a?(Float) || current_value.is_a?(BigDecimal)
          fail StandardError, "Cannot increment a non-numeric non-nil value:
                                #{attribute} is currently #{current_value}, a #{current_value.class}."
        end
      else
        fail StandardError, "You cannot increment an attribute by a
                              non-numeric value: #{value}"
      end
    end

    def clear_changes
      @changes = Hash.new { |hash, key| hash[key] = Array.new(2) }
    end

    def method_missing(name, *args, &block)
      if write_method?(name)
        attribute = name[0..-2].to_sym
        new_value = args.first
        write_attribute(attribute, new_value)
      elsif read_method?(name)
        read_attribute(name)
      else
        super
      end
    end

    def read_method?(name)
      name =~ /^([a-zA-Z][-_\w]*)[^=?]*$/
    end

    def write_method?(name)
      name =~ /^([a-zA-Z][-_\w]*)=.*$/
    end

    def self.define_handled_getter(column, format_class, options = {})
      proc = GETTER_PROCS[format_class]
      fail 'Unsupported data type: ' + format_class.to_s if proc.nil?

      define_method(column) do
        read_attribute(column)
      end
    end

    def self.define_handled_setter(column, format_class)
      method_name = (column.to_s + '=')
      proc = SETTER_PROCS[format_class]
      fail 'Unsupported data type: ' + format_class.to_s if proc.nil?
      define_method(method_name) do |value|
        write_attribute(column, value)
      end
    end

    def respond_to_missing?(name, include_private = false)
      @attributes.keys.include?(name) || write_method?(name) || super
    end

    def write_attribute(attribute, new_value, record_change = true)
      old_value = read_attribute(attribute)
      if (handle = handles[attribute.to_sym]) && !new_value.nil?
        new_value = attribute_callback(SETTER_PROCS, handle, new_value)
      end
      @attributes[attribute] = new_value
      record_change(attribute, new_value, old_value) if record_change
    end

    def record_change(attribute, new_value, old_value)
      @changes[attribute] = [old_value, new_value]
    end

    def read_attribute(name)
      value = @attributes[name]
      if (handle = handles[name.to_sym])
        value = handle[:options][:default] if value.nil?
        value = attribute_callback(GETTER_PROCS, handle, value) unless value.nil?
      end
      value
    end

    def attribute_callback(procs, handle, value)
      callback = procs[handle[:format]]
      value.is_a?(Array) ? value.map { |e| callback.call(e) } : callback.call(value)
    end

    def handles
      self.class.handles
    end

    def self.range_is_numeric?
      handles[@range_key] && [:integer, :time, :float, :date].include?(handles[@range_key][:format])
    end

  end
end
