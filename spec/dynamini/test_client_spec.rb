require 'spec_helper'

describe Dynamini::TestClient do

  let(:table_name) { 'table' }

  describe '#update_item' do

    context 'with hash key ONLY' do
      it 'should be able to save a record' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: 'abc', :hash_key_name => "hash_key_value")
      end

      it 'should be able to update an existing record' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: 'def', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: 'def', :hash_key_name => "hash_key_value")
      end

    end

    context 'with Hash key and range key' do
      it 'should be able to save a record' do
        test_client = Dynamini::TestClient.new(:hash_key_name, :range_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value', range_key_name: 'range_key_value'}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']['range_key_value']).to eq({abc: 'abc', :hash_key_name => "hash_key_value", :range_key_name => "range_key_value"})
      end

      it 'should update an existing record' do
        test_client = Dynamini::TestClient.new(:hash_key_name, :range_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value', range_key_name: 'range_key_value'}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})

        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value', range_key_name: 'range_key_value'}, attribute_updates: {abc: {value: 'def', action: 'PUT'}})

        expect(test_client.data[table_name]['hash_key_value']['range_key_value']).to eq({abc: 'def', :hash_key_name => "hash_key_value", :range_key_name => "range_key_value"})
      end

    end

    context 'invalid args' do
      it 'should not try to add invalid args for a hash key only table' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {}, attribute_updates: {abc: {value: 'def', action: 'PUT'}})

        expect(test_client.data[table_name]).to eq({})
      end

      it 'should not try to add invalid args for a hash key and range key table' do
        test_client = Dynamini::TestClient.new(:hash_key_name, :range_key_name)
        test_client.update_item(table_name: table_name, key: {}, attribute_updates: {abc: {value: 'def', action: 'PUT'}})

        expect(test_client.data[table_name]).to eq({})
      end
    end
  end

  describe '#get_item' do
    context 'table with just a hash key' do
      let(:test_client) { Dynamini::TestClient.new(:hash_key_name) }

      it 'should return the item identified by the hash_key' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}, attribute_updates: {test_attr: {value: 'test', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}).item[:test_attr]).to eq('test')
      end

      it 'should returns nil if the item does not exist' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}).item).to eq(nil)
      end

      it 'should ignore any extra keys in the args' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}, attribute_updates: {test_attr: {value: 'test', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", :extra_key => "extra"}).item[:test_attr]).to eq('test')
      end
    end

    context 'table with hash and range key' do
      let(:test_client) { Dynamini::TestClient.new(:hash_key_name, :range_key_name) }

      it 'should return the item identified by the hash_key' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", test_client.range_key_attr => 'def'}, attribute_updates: {test_attr: {value: 'test_range', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", test_client.range_key_attr => 'def'}).item[:test_attr]).to eq('test_range')
      end

      it 'should returns nil if the item does not exist' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", test_client.range_key_attr => 'def'}).item).to eq(nil)
      end

      it 'should return nil when only supplied range key' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.range_key_attr => 'def'}).item).to eq(nil)
      end
    end
  end

  describe '#query' do

    let(:test_client) { Dynamini::TestClient.new(:hash_key_field, :range_key_field) }

    before do
      4.times do |i|
        test_client.update_item(table_name: table_name, key: {hash_key_field: 'foo', range_key_field: i + 1}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})
      end
    end

    context 'on table with integer hash_key' do
      it 'should return items correctly' do
        test_client.update_item(table_name: 'integer_table', key: {hash_key_field: 1, range_key_field: 1}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})
        response = test_client.query(
          table_name: 'integer_table',
          key_condition_expression: "hash_key_field = :h",
          expression_attribute_values: {
            ":h" => 1
          }
        )
        expect(response.items.length).to eq(1)
        expect(response.items.first[:range_key_field]).to eq(1)
        expect(response.items.first[:hash_key_field]).to eq(1)
      end
    end

    context 'with LE operator' do
      it 'should return all items with range key less than or equal to the provided value' do
        response = test_client.query(
            table_name: table_name,
            key_condition_expression: "hash_key_field = :h AND user_id <= :e",
            expression_attribute_values: {
                ":h" => 'foo',
                ":e" => 2
            }
        )
        expect(response.items.length).to eq(2)
        expect(response.items.first[:range_key_field]).to eq(1)
        expect(response.items.last[:range_key_field]).to eq(2)
      end
    end
    context 'with GE operator' do
      it 'should return all items with range key greater than or equal to the provided value' do
        response = test_client.query(
            table_name: table_name,
            key_condition_expression: "hash_key_field = :h AND user_id >= :s",
            expression_attribute_values: {
                ":h" => 'foo',
                ":s" => 2
            }
        )
        expect(response.items.length).to eq(3)
        expect(response.items.first[:range_key_field]).to eq(2)
        expect(response.items.last[:range_key_field]).to eq(4)
      end
    end
    context 'with BETWEEN operator' do
      it 'should return all items with range key between the provided values' do
        response = test_client.query(
            table_name: table_name,
            key_condition_expression: "hash_key_field = :h AND user_id BETWEEN :s AND :e",
            expression_attribute_values: {
                ":h" => 'foo',
                ":s" => 2,
                ":e" => 3
            }
        )
        expect(response.items.length).to eq(2)
        expect(response.items.first[:range_key_field]).to eq(2)
        expect(response.items.last[:range_key_field]).to eq(3)
      end
    end
    context 'with no operator' do
      it 'should return all items with range key between the provided values' do
        response = test_client.query(
            table_name: table_name,
            key_condition_expression: "hash_key_field = :h",
            expression_attribute_values: {
                ":h" => 'foo'
            }
        )
        expect(response.items.length).to eq(4)
        expect(response.items.first[:range_key_field]).to eq(1)
        expect(response.items.last[:range_key_field]).to eq(4)
      end
    end
  end

  describe '#batch_write_item' do
    let(:test_client) { Dynamini::TestClient.new(:id) }

    it 'should store all items in the table correctly' do
      item1 = {'foo' => 'bar', 'id' => 1}
      item2 = {'foo' => 'bar', 'id' => 2}
      put_requests = [{put_request: {item: item1}},
                      {put_request: {item: item2}}]

      request_options = {request_items: {table_name => put_requests}}

      test_client.batch_write_item(request_options)
      expect(test_client.data[table_name][1]).to eq(item1)
      expect(test_client.data[table_name][2]).to eq(item2)
    end
  end

  describe '#batch_get_item' do
    let(:test_client) { Dynamini::TestClient.new(:id) }

    before do
      test_client.data[table_name] = {}
      test_client.data[table_name]['foo'] = {id: 'foo', price: 1}
    end

    it 'should only return the items found' do
      keys = [{id: 'foo'}, {id: 'bar'}]
      request = {request_items: {table_name => {keys: keys}}}
      result = test_client.batch_get_item(request)
      expect(result.responses[table_name].length).to eq(1)
      expect(result.responses[table_name].first[:id]).to eq('foo')
    end
  end
end
