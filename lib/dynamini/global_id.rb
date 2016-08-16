module Dynamini
  module GlobalId

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def deserialize_id(id)
        if self.range_key
          raise 'Dynamini::GlobalId.deserialize_id requires range key. please define .deserialize_id'
        end

        return id
      end

      def find(id)
        hash_value, range_value = *deserialize_id(id)

        fail 'Range key cannot be blank.' if range_key && range_value.nil?
        response = client.get_item(
          table_name: self.table_name,
          key: self.create_key_hash(hash_value, range_value)
        )
        raise 'Item not found.' unless response.item
        new(response.item.symbolize_keys, false)
      end
    end

    def serialize_id
      if self.class.range_key
        raise 'Dynamini::GlobalId#serialize_id requires range key. please define #serialize_id'
      end

      attributes[self.class.hash_key]
    end

    def id
      serialize_id
    end

  end
end
