module Dynamini
  class ItemSplitter

    MAX_SIZE = 380_000

    class << self

      def split(attribute_updates)
        unprocessed_au = attribute_updates.map { |k, v| {k => v} }
        updates = []
        current_update_size = 0
        current_update = {}

        while unprocessed_au.length > 0 do
          size = au_size(unprocessed_au[0])
          if size > MAX_SIZE
            part_one, part_two = split_au(unprocessed_au[0])
            # replace huge attribute with two smaller ones
            unprocessed_au.shift
            unprocessed_au.unshift(part_one)
            unprocessed_au.unshift(part_two)
          else
            current_update_size += size
            if current_update_size > MAX_SIZE
              updates.push(current_update)
              current_update_size = 0
              current_update = []
            else
              current_update_size += size
              key, value = get_key_and_value(unprocessed_au[0])
              current_update[key] = value
              unprocessed_au.shift
            end
          end
        end

        updates.push(current_update) unless current_update.empty?
        updates
      end

      private

      def au_size(au)
        0 # FIXME
      end

      def split_au(au)
        # input: {"sec"=>{:action=>"PUT", :value=>"[1,2,3]"}
        attribute_name = au.keys[0]
        attribute_action = au.values[0][:action]
        attribute_value = au.values[0][:value]

        raise "#{attribute_name} is not enumerable and is too large to save." unless attribute_value.is_a?(Enumerable)

        part_one = {attribute_name => {action: attribute_action, value: attribute_value[0..attribute_value.length / 2]}}
        part_two = {attribute_name => {action: "ADD", value: attribute_value[attribute_value.length / 2..-1]}}
        [part_one, part_two]
      end

      def get_key_and_value(au)
        [au.keys[0], au.values[0]]
      end
    end
  end
end
