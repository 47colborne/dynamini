module Dynamini
  module ClientInterface
    module ClassMethods
      def client
          @client ||= Aws::DynamoDB::Client.new(
              region: Dynamini.configuration.region,
              access_key_id: Dynamini.configuration.access_key_id,
              secret_access_key: Dynamini.configuration.secret_access_key
          )
      end
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

    def self.included(base)
      base.extend ClassMethods
    end
  end
end
