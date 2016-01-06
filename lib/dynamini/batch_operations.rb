module Dynamini
  module BatchOperations
    BATCH_SIZE = 25

    def import(models)
      models.each_slice(25) do |batch|
        batch.each do |model|
          model.generate_timestamps!
        end
        dynamo_batch_save(batch)
      end
    end

    attr_writer :batch_write_queue

    def batch_write_queue
      @batch_write_queue ||= []
    end

    def batch_find(ids = [])
      return [] if ids.length < 1
      objects = []
      fail StandardError, 'Batch is limited to 100 items' if ids.length > 100
      key_structure = ids.map { |i| {hash_key => i.to_s} }
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