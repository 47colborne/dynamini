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

      it 'ADDs integers' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: 1, action: 'PUT'}})
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: 1, action: 'ADD'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: 2, hash_key_name: 'hash_key_value')
      end

      it 'should be able to add to an existing set' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: Set.new([1]), action: 'PUT'}})
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: {abc: {value: Set.new([2]), action: 'ADD'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: Set.new([1, 2]), hash_key_name: 'hash_key_value')
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

      it 'should return nil if the item does not exist' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}).item).to eq(nil)
      end

      it 'should ignore any extra keys in the args' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}, attribute_updates: {test_attr: {value: 'test', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", :extra_key => "extra"}).item[:test_attr]).to eq('test')
      end

      it 'should return new (cloned) arrays if arrays are present in the model attributes' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => "abc"}, attribute_updates: {ary: {value: ['a','b','c'], action: 'PUT'}})
        retrieved = test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", :extra_key => "extra"}).item
        retrieved[:ary] = ['a','b','c','d']
        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key_attr => "abc", :extra_key => "extra"}).item[:ary]).to eq(['a','b','c'])
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

    context 'hash key is not handled' do
      let(:test_client) { Dynamini::TestClient.new(:hash_key_name) }
      context 'getting a record by integer when hash key is string' do
        it 'should not find the item' do
          test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => '123'}, attribute_updates: {test_attr: {value: 'test', action: 'PUT'}})
          expect(test_client.get_item(table_name: table_name, key: {test_client.range_key_attr => 123}).item).to eq(nil)
        end
      end

      context 'getting a record by string when hash key is integer' do
        it 'should not find the item' do
          test_client.update_item(table_name: table_name, key: {test_client.hash_key_attr => 123}, attribute_updates: {test_attr: {value: 'test', action: 'PUT'}})
          expect(test_client.get_item(table_name: table_name, key: {test_client.range_key_attr => '123'}).item).to eq(nil)
        end
      end
    end
  end

  describe '#query' do

    let(:test_client) { Dynamini::TestClient.new(:hash_key_field, :range_key_field, {'secondary_index' => {hash_key_name: 'abc', range_key_name: :secondary_range_key }})}

    before do
      4.times do |i|
        test_client.update_item(table_name: table_name, key: {hash_key_field: 'foo', range_key_field: i + 1}, attribute_updates: {'abc' => {value: 'abc', action: 'PUT'}, 'secondary_range_key' => {value: 10 - i, action: 'PUT'}})
      end
    end

    context 'on table with integer hash_key' do
      it 'should return items correctly' do
        test_client.update_item(table_name: 'integer_table', key: {hash_key_field: 1, range_key_field: 1}, attribute_updates: {abc: {value: 'abc', action: 'PUT'}})
        response = test_client.query(
          table_name: 'integer_table',
          key_condition_expression: "#H = :h",
          expression_attribute_names: {'#H' => 'hash_key_field'},
          expression_attribute_values: {
            ":h" => 1
          }
        )
        expect(response.items.length).to eq(1)
        expect(response.items.first[:range_key_field]).to eq(1)
        expect(response.items.first[:hash_key_field]).to eq(1)
      end
    end

    context 'with LE operator' do # broken
      it 'should return all items with range key less than or equal to the provided value' do
        response = test_client.query(
          table_name: table_name,
          key_condition_expression: "#H = :h AND #R <= :e",
          expression_attribute_names: {'#H' => 'hash_key_field', '#R' => 'range_key_field'},
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
          key_condition_expression: "#H = :h AND #R >= :s",
          expression_attribute_names: {'#H' => 'hash_key_field', '#R' => 'range_key_field'},
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
          key_condition_expression: "#H = :h AND #R BETWEEN :s AND :e",
          expression_attribute_names: {'#H' => 'hash_key_field', '#R' => 'range_key_field'},
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
          key_condition_expression: "#H = :h",
          expression_attribute_names: {'#H' => 'hash_key_field'},
          expression_attribute_values: {
            ":h" => 'foo'
          }
        )
        expect(response.items.length).to eq(4)
        expect(response.items.first[:range_key_field]).to eq(1)
        expect(response.items.last[:range_key_field]).to eq(4)
      end
    end

    context 'with invalid expression_attribute_names' do
      it 'should raise an error about an invalid hash_key' do
        expect{ test_client.query(
          table_name: table_name,
          key_condition_expression: "#H = :h",
          expression_attribute_names: {'#H' => 'not_hash_key_field'},
          expression_attribute_values: {
            ':h' => 'foo'
          }
        ) }.to raise_error(Aws::DynamoDB::Errors::ValidationException, "Query condition missed key schema element: hash_key_field")
      end

      it 'should raise an error about an invalid range_key' do
        expect{ test_client.query(
            table_name: table_name,
            key_condition_expression: "#H = :h AND #R >= :s",
            expression_attribute_names: {'#H' => 'not_hash_key_field', '#R' => 'not_range_key_field'},
            expression_attribute_values: {
                ':h' => 'foo',
                ':s' => 30
            }
        ) }.to raise_error(Aws::DynamoDB::Errors::ValidationException, "Query condition missed key schema element: hash_key_field, range_key_field")
      end
    end

    context 'with secondary index' do
      before do
        test_client.update_item(table_name: table_name,
            key: {hash_key_field: 'bar', range_key_field: 10},
            attribute_updates: {'abc' => {value: 'abc', action: 'PUT'},
            'secondary_range_key' => {value: 11, action: 'PUT'}})
      end

      context 'with LE operator' do
        it 'should return all items with secondary range key less than or equal to the provided value' do
          response = test_client.query(
              table_name: table_name,
              key_condition_expression: "#H = :h AND #R <= :e",
              expression_attribute_names: {'#H' => 'abc', '#R' => 'secondary_range_key'},
              expression_attribute_values: {
                ":h" => 'abc',
                ":e" => 8
              },
              index_name: 'secondary_index'
          )
          expect(response.items.length).to eq(2)
          expect(response.items.first['secondary_range_key']).to eq(7)
          expect(response.items.last['secondary_range_key']).to eq(8)
        end
      end

      context 'with GE operator' do
        it 'should return all items with secondary range key greater than or equal to the provided value' do
          response = test_client.query(
              table_name: table_name,
              key_condition_expression: "#H = :h AND #R >= :s",
              expression_attribute_names: {'#H' => 'abc', '#R' => 'secondary_range_key'},
              expression_attribute_values: {
                ":h" => 'abc',
                ":s" => 8
              },
              index_name: 'secondary_index'
          )
          expect(response.items.length).to eq(4)
          expect(response.items.first['secondary_range_key']).to eq(8)
          expect(response.items.last['secondary_range_key']).to eq(11)
        end
      end

      context 'with BETWEEN operator' do
        it 'should return all items with secondary range key between the provided values' do
          response = test_client.query(
              table_name: table_name,
              key_condition_expression: "#H = :h AND #R BETWEEN :s AND :e",
              expression_attribute_names: {'#H' => 'abc', '#R' => 'secondary_range_key'},
              expression_attribute_values: {
                ":h" => 'abc',
                ":s" => 8,
                ":e" => 9
              },
              index_name: 'secondary_index'
          )
          expect(response.items.length).to eq(2)
          expect(response.items.first['secondary_range_key']).to eq(8)
          expect(response.items.last['secondary_range_key']).to eq(9)
        end
      end

      context 'with no operator' do
        it 'should return all items sorted by their secondary index' do
          response = test_client.query(
              table_name: table_name,
              key_condition_expression: "#H = :h",
              expression_attribute_names: {'#H' => 'abc'},
              expression_attribute_values: {
                ":h" => 'abc'
              },
              index_name: 'secondary_index'
          )

          expect(response.items.length).to eq(5)
          expect(response.items.first['secondary_range_key']).to eq(7)
          expect(response.items.last['secondary_range_key']).to eq(11)
        end
      end

      context 'with invalid expression_attribute_names' do
        it 'should raise an error about an invalid hash_key' do
          expect{ test_client.query(
              table_name: table_name,
              key_condition_expression: "#H = :h",
              expression_attribute_names: {'#H' => 'not_hash_key_field'},
              expression_attribute_values: {
                  ':h' => 'abc'
              },
              index_name: 'secondary_index'
          ) }.to raise_error(Aws::DynamoDB::Errors::ValidationException, "Query condition missed key schema element: abc")
        end

        it 'should raise an error about an invalid range_key' do
          expect{ test_client.query(
              table_name: table_name,
              key_condition_expression: "#H = :h AND #R >= :s",
              expression_attribute_names: {'#H' => 'not_hash_key_field', '#R' => 'not_range_key_field'},
              expression_attribute_values: {
                  ':h' => 'abc',
                  ':s' => 3
              },
              index_name: 'secondary_index'
          ) }.to raise_error(Aws::DynamoDB::Errors::ValidationException, "Query condition missed key schema element: abc, secondary_range_key")
        end
      end
    end

  end

  describe '#batch_write_item' do
    context 'with only hash key' do
      let(:test_client) { Dynamini::TestClient.new(:id) }

      it 'should store all items in the table correctly' do
        item1 = {'foo' => 'bar', 'id' => 1}
        item2 = {'foo' => 'bar', 'id' => 2}
        put_requests = [{put_request: {item: item1}},
                        {put_request: {item: item2}}]

        request_options = {request_items: {table_name => put_requests}}

        test_client.batch_write_item(request_options)
        expect(test_client.data[table_name][1]).to eq({foo: 'bar', id: 1})
        expect(test_client.data[table_name][2]).to eq({foo: 'bar', id: 2})
      end

      context 'batch deleting' do
        before do
          test_client.data[table_name] = {}
          test_client.data[table_name]['one'] = {name: 'item1'}
          test_client.data[table_name]['two'] = {name: 'item2'}
        end

        it 'should remove all items from the table' do

          delete_requests = [
              {delete_request: {key: {id: 'one'}}},
              {delete_request: {key: {id: 'two'}}}
          ]

          request_options = {request_items: {table_name => delete_requests}}
          expect(test_client.data[table_name]['one']).to eq({name: 'item1'})
          expect(test_client.data[table_name]['two']).to eq({name: 'item2'})
          test_client.batch_write_item(request_options)
          expect(test_client.data[table_name]['one']).to be_nil
          expect(test_client.data[table_name]['two']).to be_nil
        end
      end
    end

    context 'with hash key and range key' do
      let(:test_client) { Dynamini::TestClient.new(:hash_key, :range_key) }

      context 'executing put requests' do
        it 'should store all items in the table correctly' do
          item1 = {'foo' => 'bar', 'hash_key' => 1, 'range_key' => 'a'}
          item2 = {'foo' => 'bar', 'hash_key' => 2, 'range_key' => 'b'}
          put_requests = [{put_request: {item: item1}},
                          {put_request: {item: item2}}]

          request_options = {request_items: {table_name => put_requests}}

          test_client.batch_write_item(request_options)
          expect(test_client.data[table_name][1]['a']).to eq({foo: 'bar', hash_key: 1, range_key: 'a'})
          expect(test_client.data[table_name][2]['b']).to eq({foo: 'bar', hash_key: 2, range_key: 'b'})
        end

        it 'should add a new record to the hash key if it is a new range key' do
          item1 = {'foo' => 'bar', 'hash_key' => 1, 'range_key' => 'a'}
          item2 = {'foo' => 'bar', 'hash_key' => 1, 'range_key' => 'b'}

          put_requests1 = [{put_request: {item: item1}}]
          request_options1 = {request_items: {table_name => put_requests1}}

          put_requests2 = [{put_request: {item: item2}}]
          request_options2 = {request_items: {table_name => put_requests2}}

          test_client.batch_write_item(request_options1)
          test_client.batch_write_item(request_options2)
          expect(test_client.data[table_name][1]['a']).to eq({foo: 'bar', hash_key: 1, range_key: 'a'})
          expect(test_client.data[table_name][1]['b']).to eq({foo: 'bar', hash_key: 1, range_key: 'b'})
        end
      end

      context 'executing delete requests' do

      end
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
