require 'spec_helper'

describe Dynamini::Adder do

  class AddHandledModel < Dynamini::Base
    handle :price, :float
    handle :things, :set
    handle :stuff, :array
    handle :when, :date
    handle :what_time, :time
    handle :widget_count, :integer
  end

  let(:model_attributes) {
    {
        name: 'Widget',
        price: 9.99,
        id: 'abcd1234',
        hash_key: '009',
        things: Set.new([1,2,3]),
        stuff: [4,5,6]
    }
  }

  let(:model) { AddHandledModel.new(model_attributes, false) }


  describe '.add_to' do
    context 'a change exists for the given attribute' do
      it 'should overwrite the change with a change that adds to the previously set value' do
        model.price = 2
        model.add_to(:price, 3)
        expect(model.price).to eq(5)
        expect(model.changes['price']).to eq([2, 3, 'ADD'])
      end
    end

    context 'no change exists for the given attribute' do
      it 'should create an add change' do
        model.add_to(:price, 2)
        expect(model.price).to eq(11.99)
        expect(model.changes['price']).to eq([9.99, 2, 'ADD'])
      end
    end

    context 'a setter is called after adding' do
      it 'should overwrite the ADD change with a PUT change' do
        model.add_to(:price, 2)
        model.price = 2
        expect(model.changes['price']).to eq([11.99, 2, 'PUT'])
      end
    end

    context 'adding to a set' do
      context 'the provided value is enumerable' do
        it 'merges the sets' do
          model.add_to(:things, Set.new([4]))
          expect(model.things).to eq(Set.new([1,2,3,4]))
        end
      end
      context 'the provided value is not enumerable' do
        it 'raises an error' do
          expect{ model.add_to(:things, 4) }.to raise_error ArgumentError
        end
      end
    end

    context 'adding to an array' do
      context 'the provided value is enumerable' do
        it 'merges the arrays' do
          model.add_to(:stuff, [7])
          expect(model.stuff).to eq([4,5,6,7])
        end
      end
      context 'the provided value is not enumerable' do
        it 'raises an error' do
          expect{ model.add_to(:stuff, 4) }.to raise_error ArgumentError
        end
      end
    end
  end
end
