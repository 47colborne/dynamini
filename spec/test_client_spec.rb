require 'spec_helper'

describe Dynamini::TestClient do

  let(:table_name) { 'table' }

  describe '#update_item' do

    context 'with hash key ONLY' do
      it 'should be able to save a record' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: { abc: { value: 'abc', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: 'abc', :hash_key_name=>"hash_key_value")
      end

      it 'should be able to update an existing record' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: { abc: { value: 'abc', action: 'PUT'}})
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: { abc: { value: 'def', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: 'def', :hash_key_name=>"hash_key_value")
      end

    end

    context 'with Hash key and range key' do
      it 'should be able to save a record' do
        test_client = Dynamini::TestClient.new(:hash_key_name, :range_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value', range_key_name: 'range_key_value'}, attribute_updates: { abc: { value: 'abc', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']['range_key_value']).to eq({abc: 'abc', :hash_key_name=>"hash_key_value", :range_key_name=>"range_key_value"})
      end

      it 'should update an existing record' do
        test_client = Dynamini::TestClient.new(:hash_key_name, :range_key_name)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value', range_key_name: 'range_key_value' }, attribute_updates: { abc: { value: 'abc', action: 'PUT'}})

        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value', range_key_name: 'range_key_value' }, attribute_updates: { abc: { value: 'def', action: 'PUT'}})

        expect(test_client.data[table_name]['hash_key_value']['range_key_value']).to eq({abc: 'def', :hash_key_name=>"hash_key_value", :range_key_name=>"range_key_value"})
      end

    end

    context 'invalid args' do
      it 'should not try to add invalid args for a hash key only table' do
        test_client = Dynamini::TestClient.new(:hash_key_name)
        test_client.update_item(table_name: table_name, key: {}, attribute_updates: { abc: { value: 'def', action: 'PUT'}})

        expect(test_client.data[table_name]).to eq({})
      end

      it 'should not try to add invalid args for a hash key and range key table' do
        test_client = Dynamini::TestClient.new(:hash_key_name, :range_key_name)
        test_client.update_item(table_name: table_name, key: {}, attribute_updates: { abc: { value: 'def', action: 'PUT'}})

        expect(test_client.data[table_name]).to eq({})
      end
    end
  end

  describe '#get_item' do
    context 'table with just a hash key' do
      let(:test_client) {Dynamini::TestClient.new(:hash_key_name)}

      it 'should return the item identified by the hash_key' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key => "abc"}, attribute_updates: { test_attr: { value: 'test', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key => "abc"}).item[:test_attr]).to eq('test')
      end

      it 'should returns nil if the item does not exist' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key => "abc"}).item).to eq(nil)
      end

      it 'should ignore any extra keys in the args' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key => "abc"}, attribute_updates: { test_attr: { value: 'test', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key => "abc", :extra_key => "extra"}).item[:test_attr]).to eq('test')
      end
    end

    context 'table with hash and range key' do
      let(:test_client) {Dynamini::TestClient.new(:hash_key_name, :range_key_name)}

      it 'should return the item identified by the hash_key' do
        test_client.update_item(table_name: table_name, key: {test_client.hash_key => "abc", test_client.range_key => 'def'}, attribute_updates: { test_attr: { value: 'test_range', action: 'PUT'}})

        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key => "abc", test_client.range_key => 'def'}).item[:test_attr]).to eq('test_range')
      end

      it 'should returns nil if the item does not exist' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.hash_key => "abc", test_client.range_key => 'def'}).item).to eq(nil)
      end

      it 'should return nil when only supplied range key' do
        expect(test_client.get_item(table_name: table_name, key: {test_client.range_key => 'def'}).item).to eq(nil)
      end
    end
  end
end
