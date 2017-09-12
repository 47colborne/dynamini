require 'ostruct'

module Dynamini
  module BatchOperations

    def import(models, options = {})
      # Max batch size is 25, per Dynamo BatchWriteItem docs

      models.each_slice(25) do |batch|
        batch.each do |model|
          model.send(:generate_timestamps!) unless options[:skip_timestamps]
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

    def batch_delete(ids)
      requests = ids.map{|id| { delete_request: { key: { hash_key => id } } } }
      options = { request_items: { table_name => requests } }
      client.batch_write_item(options)
    end

    def scan(options = {})
      validate_scan_options(options)
      response = dynamo_scan(options)
      if options[:index_name]
        last_evaluated_key = response.last_evaluated_key[secondary_index[options[:index_name]][:hash_key_name].to_s]
      else
        last_evaluated_key = response.last_evaluated_key[hash_key.to_s]
      end
      OpenStruct.new(
        last_evaluated_key: last_evaluated_key,
        items: response.items.map { |i| new(i.symbolize_keys, false) }
      )
    end

    private

    def dynamo_batch_get(key_struct)
      client.batch_get_item(
        request_items: {
          table_name => {keys: key_struct}
        }
      )
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

    def dynamo_scan(options)
      client.scan({
        consistent_read:      options[:consistent_read],
        exclusive_start_key:  options[:exclusive_start_key],
        secondary_index_name: options[:index_name],
        limit:                options[:limit],
        segment:              options[:segment],
        total_segments:       options[:total_segments],
        table_name:           table_name
      }.select { |_, v| !v.nil? })
    end

    def validate_scan_options(options)
      if options[:total_segments] && !options[:segment]
        raise ArgumentError, 'Must specify segment if specifying total_segments'
      elsif options[:segment] && !options[:total_segments]
        raise ArgumentError, 'Must specify total_segments if specifying segment'
      elsif options[:index_name] && !self.secondary_index[options[:index_name]]
        raise ArgumentError, "Secondary index of #{options[:index_name]} does not exist"
      end
    end
  end
end
