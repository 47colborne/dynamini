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
            unprocessed_au.shift
            unprocessed_au.unshift(part_two)
            unprocessed_au.unshift(part_one)
          else
            current_update_size += size
            if current_update_size > MAX_SIZE
              updates.push(current_update)
              current_update_size = 0
              current_update = {}
            else
              current_update_size += size
              key, value = key_and_value(unprocessed_au[0])
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
        au.to_s.bytesize
      end

      def split_au(au)
        attribute_name = au.keys[0]
        attribute_action = au.values[0][:action]
        attribute_value = au.values[0][:value]

        raise "#{attribute_name} is too large to save and is not splittable (not enumerable)." unless attribute_value.is_a?(Enumerable)

        part_one = {attribute_name => {action: attribute_action, value: attribute_value[0..(attribute_value.length / 2) - 1]}}
        part_two = {attribute_name => {action: "ADD", value: attribute_value[attribute_value.length / 2..-1]}}
        [part_one, part_two]
      end

      def key_and_value(au)
        [au.keys[0], au.values[0]]
      end
    end
  end
end
