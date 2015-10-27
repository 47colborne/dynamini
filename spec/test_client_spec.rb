require 'spec_helper'

describe Dynamini::TestClient do

  let(:table_name) { 'table' }

  describe '#update_item' do

    context 'with hash key ONLY' do
      it 'should be able to save a record' do
        test_client = Dynamini::TestClient.new(:hash_key_name,)
        test_client.update_item(table_name: table_name, key: {hash_key_name: 'hash_key_value'}, attribute_updates: { abc: { value: 'abc', action: 'PUT'}})
        expect(test_client.data[table_name]['hash_key_value']).to eq(abc: 'abc', :hash_key_name=>"hash_key_value")
      end

      it 'should be able to update an existing record' do
        test_client = Dynamini::TestClient.new(:hash_key_name,)
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
  end
end
