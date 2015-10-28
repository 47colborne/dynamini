module Dynamini
  # Core db interface class.
  class Base
    include ActiveModel::Validations
    attr_reader :attributes

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
        time:     proc { |v| v.to_f },
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

      def exists?(key)
        r = client.get_item(table_name: table_name, key: { hash_key => key.to_s })
        r.item.present?
      end

      def find_or_new(key)
        fail 'Key cannot be blank.' if (key.nil? || key == '')
        r = client.get_item(table_name: table_name, key: { hash_key => key.to_s })
        if r.item
          new(r.item.symbolize_keys, false)
        else
          new(hash_key => key.to_s)
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
      @changed = Set.new
      @new_record = new_record
      @attributes = {}

      attributes.each do |k, v|
        write_attribute(k, v, new_record)
      end
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
      @changed.empty? || (valid? && trigger_save(options))
    end

    def save!(options = {})
      options[:validate] = true if options[:validate].nil?

      unless @changed.empty?
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

    def increment!(attribute_increments, opts = {})
      attribute_increments.each do |a, v|
        validate_incrementable_attribute(a, v)
      end
      increment_to_dynamo(attribute_increments, opts)
    end

    def delete
      delete_from_dynamo
      self
    end

    def changes
      @attributes.select { |attribute| @changed.include?(attribute.to_s) &&
          attribute != self.class.hash_key &&
          attribute != self.class.range_key
      }
    end

    def changed
      @changed.to_a
    end

    def new_record?
      @new_record
    end

    private

    def add_changed(attributes)
      @changed += attributes.keys.map(&:to_s)
    end

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

    def increment_to_dynamo(attribute_increments, opts = {})
      self.class.client.update_item(
          table_name: self.class.table_name,
          key: key,
          attribute_updates: increment_updates(attribute_increments, opts)
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

    def attribute_updates
      changes.reduce({}) do |updates, (key, value)|
        updates[key] = {value: value, action: 'PUT'} unless value.blank?
        updates
      end
    end

    def increment_updates(attribute_increments, opts = {})
      updates = {}
      attribute_increments.each do |k,v|
        updates[k] = { value: v, action: 'ADD' }
      end
      updates[:updated_at] = { value: Time.now.to_f, action: 'PUT' } unless opts[:skip_timestamps]
      updates[:created_at] = { value: Time.now.to_f, action: 'PUT' } unless attributes[:created_at]
      updates
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
      @changed = Set.new
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
        if @attributes.key?(column)
          v = read_attribute(column)
          if v.is_a? Array
            v.map{ |e| proc.call(e) }
          else
            proc.call(read_attribute(column))
          end
        else
          options[:default] || nil
        end
      end
    end

    def self.define_handled_setter(column, format_class)
      setter_symbol = (column.to_s + '=').to_sym
      proc = SETTER_PROCS[format_class]
      fail 'Unsupported data type: ' + format_class.to_s if proc.nil?
      define_method(setter_symbol) do |value|
        if value.is_a? Array
          write_attribute(column, value.map{ |e| proc.call(e) })
        else
          write_attribute(column, proc.call(value))
        end
      end
    end

    def respond_to_missing?(name, include_private = false)
      @attributes.keys.include?(name) || write_method?(name) || super
    end

    def write_attribute(attribute, new_value, record_change = true)
      old_value = @attributes[attribute]
      @attributes[attribute] = (new_value.nil? ? nil : new_value)
      record_change(attribute, new_value, old_value) if record_change
    end

    def record_change(attribute, new_value, old_value)
      @changed << attribute.to_s if new_value != old_value
    end

    def read_attribute(name)
      @attributes[name]
    end

    #### Default class macros

    handle :updated_at, :time
    handle :created_at, :time
  end
end
