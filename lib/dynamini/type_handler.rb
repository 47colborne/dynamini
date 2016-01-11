module Dynamini
  module TypeHandler
    module ClassMethods
      def handle(column, format_class, options = {})
        self.handles = self.handles.merge(column => { format: format_class, options: options })

        define_handled_getter(column, format_class, options)
        define_handled_setter(column, format_class)
      end

      def define_handled_getter(column, format_class, _options = {})
        proc = GETTER_PROCS[format_class]
        fail 'Unsupported data type: ' + format_class.to_s if proc.nil?

        define_method(column) do
          read_attribute(column)
        end
      end

      def define_handled_setter(column, format_class)
        method_name = (column.to_s + '=')
        proc = SETTER_PROCS[format_class]
        fail 'Unsupported data type: ' + format_class.to_s if proc.nil?
        define_method(method_name) do |value|
          write_attribute(column, value)
        end
      end
    end

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

    def handles
      self.class.handles
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end
end
