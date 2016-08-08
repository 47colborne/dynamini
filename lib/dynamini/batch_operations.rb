require 'ostruct'

module Dynamini
  module BatchOperations

    def import(models)
      # Max batch size is 25, per Dynamo BatchWriteItem docs

      models.each_slice(25) do |batch|
        batch.each do |model|
          model.send(:generate_timestamps!)
        end
        dynamo_batch_save(batch)
      end
    end

    def batch_find(ids = [])
      return OpenStruct.new(found: [], not_found: []) if ids.length < 1
      objects = []
      key_structure = ids.map { |i| {hash_key => i} }
      key_structure.each_slice(100) do |keys|
        response = dynamo_batch_get(keys)
        response.responses[table_name].each do |item|
          objects << new(item.symbolize_keys, false)
        end
      end
      OpenStruct.new(found: objects, not_found: ids - objects.map(&hash_key))
    end

    def dynamo_batch_save(model_array)
      put_requests = model_array.map do |model|
        {
            put_request: {
                item: model.attributes.reject { |_k, v| v.blank? }.stringify_keys
            }
        }
      end
      request_options = {
          request_items: {table_name => put_requests}
      }
      client.batch_write_item(request_options)
    end

    def batch_delete(ids)
      requests = ids.map{|id| { delete_request: { key: { hash_key => id } } } }
      options = { request_items: { table_name => requests } }
      client.batch_write_item(options)
    end

    private

    def dynamo_batch_get(key_struct)
      client.batch_get_item(
          request_items: {
              table_name => {keys: key_struct}
          }
      )
    end
  end
end