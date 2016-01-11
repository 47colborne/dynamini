require 'spec_helper'

describe Dynamini::Increment do

  let(:model_attributes) {
    {
        name: 'Widget',
        price: 9.99,
        id: 'abcd1234',
        hash_key: '009'
    }
  }

  subject(:model) { Dynamini::Base.create!(model_attributes) }

  describe '.increment!' do
    context 'when incrementing a nil value' do
      it 'should save' do
        expect(model.class.client).to receive(:update_item).with(
                                          table_name: 'bases',
                                          key: {id: model_attributes[:id]},
                                          attribute_updates: hash_including(
                                              "foo" => {
                                                  value: 5,
                                                  action: 'ADD'
                                              }
                                          )
                                      )
        model.increment!(foo: 5)
      end
      it 'should update the value' do
        model.increment!(foo: 5)
        expect(Dynamini::Base.find('abcd1234').foo.to_i).to eq 5
      end
    end
    context 'when incrementing a numeric value' do
      it 'should save' do
        expect(model).to receive(:read_attribute).and_return(9.99)
        expect(model.class.client).to receive(:update_item).with(
                                          table_name: 'bases',
                                          key: {id: model_attributes[:id]},
                                          attribute_updates: hash_including(
                                              "price" => {
                                                  value: 5,
                                                  action: 'ADD'
                                              }
                                          )
                                      )
        model.increment!(price: 5)

      end
      it 'should sum the values' do
        expect(model).to receive(:read_attribute).and_return(9.99)
        model.increment!(price: 5)
        expect(Dynamini::Base.find('abcd1234').price).to eq 14.99
      end
    end
    context 'when incrementing a non-numeric value' do
      it 'should raise an error and not save' do
        expect(model).to receive(:read_attribute).and_return('hello')
        expect { model.increment!(price: 5) }.to raise_error(StandardError)
      end
    end
    context 'when incrementing with a non-numeric value' do
      it 'should raise an error and not save' do
        expect { model.increment!(foo: 'bar') }.to raise_error(StandardError)
      end
    end
    context 'when incrementing multiple values' do
      it 'should create/sum both values' do
        allow(model).to receive(:read_attribute).and_return(9.99)
        model.increment!(price: 5, baz: 6)
        found_model = Dynamini::Base.find('abcd1234')
        expect(found_model.price).to eq 14.99
        expect(found_model.baz).to eq 6
      end
    end
    context 'when incrementing a new record' do
      it 'should save the record and init the values and timestamps' do
        Dynamini::Base.new(id: 1, foo: 'bar').increment!(baz: 1)
        found_model = Dynamini::Base.find(1)
        expect(found_model.baz).to eq 1
        expect(found_model.created_at).to_not be_nil
        expect(found_model.updated_at).to_not be_nil
      end
    end
  end
end