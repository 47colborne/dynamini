require 'spec_helper'

describe Dynamini::Attributes do

  class HandledModel < Dynamini::Base
    handle :price, :float
    handle :things, :set
    handle :stuff, :array
    handle :when, :date
    handle :what_time, :time
    handle :widget_count, :integer
    handle :new_set, :set
    handle :new_array, :array
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

  let(:model) { HandledModel.new(model_attributes) }

  describe '#attributes' do
    it 'should return all attributes of the object' do
      expect(model.attributes).to include model_attributes
    end
  end

  describe '#assign_attributes' do
    it 'should return nil' do
      expect(model.assign_attributes(price: '5')).to be_nil
    end

    it 'should update the attributes of the model' do
      model.assign_attributes(price: '5')
      expect(model.attributes[:price]).to eq(5.0)
    end

    it 'should append changed attributes to @changed' do
      model.save
      model.assign_attributes(name: 'Widget', price: '5')
      expect(model.changed).to eq ['price']
    end
  end

  describe '#update_attribute' do

    it 'should update the attribute and save the object' do
      expect(model).to receive(:save!)
      model.update_attribute(:name, 'Widget 2.0')
      expect(model.name).to eq('Widget 2.0')
    end
  end

  describe '#update_attributes' do
    it 'should update multiple attributes and save the object' do
      expect(model).to receive(:save!)
      model.update_attributes(name: 'Widget 2.0', price: '12.00')
      expect(model.attributes).to include(name: 'Widget 2.0', price: 12.00)
    end
  end

  describe 'reader method' do
    it 'responds to handled columns but not unhandled columns' do
      expect(model).to respond_to(:price)
      expect(model).not_to respond_to(:foo)
    end

    it 'does not treat method calls with arguments as readers' do
        expect{ model.accidental_method_call(1,2,3) }.to raise_error NoMethodError
    end

    context 'existing attribute' do
      it 'should return the attribute' do
        expect(model.price).to eq(9.99)
      end
    end

    context 'new attribute' do
      before { model.description = 'test model' }
      it 'should return the attribute' do
        expect(model.description).to eq('test model')
      end
    end

    context 'nonexistent attribute' do
      it 'should return nil' do
        expect(model.foo).to be_nil
      end
    end

    context 'attribute set to nil' do
      before { model.price = nil }
      it 'should return nil' do
        expect(model.price).to be_nil
      end
    end
  end

  describe 'writer method' do
    it 'responds to handled columns but not unhandled columns' do
      expect(model).to respond_to(:price=)
    end

    context 'existing attribute' do
      before { model.price = '1' }
      it 'should overwrite the attribute' do
        expect(model.price).to eq(1.0)
      end
    end
    context 'new attribute' do
      before { model.foo = 'bar' }
      it 'should write to the attribute' do
        expect(model.foo).to eq('bar')
      end
    end

    context 'arrays' do
      it 'should write to the attribute and switch type freely' do
        model.foo = ['bar', 'baz']
        expect(model.foo).to eq(['bar', 'baz'])
        model.foo = ['quux']
        expect(model.foo).to eq(['quux'])
        model.foo = 'zort'
        expect(model.foo).to eq('zort')
        model.foo = []
        expect(model.foo).to eq([])
      end
    end

    context 'when setting a handled attribute to its current value' do
      it 'should not detect a change' do
        Dynamini::Base.handle(:my_set, :set, of: :string)
        Dynamini::Base.create!(id: '123', my_set: nil)
        model = Dynamini::Base.find('123')
        model.my_set = nil
        expect(model.changes).to be_empty
      end
    end
  end

  describe '#delete_attribute' do
    context 'the attribute exists' do
      it 'should enqueue a DELETE change for that attribute' do
        model.delete_attribute(:stuff)
        expect(model.changes['stuff']).to eq([model_attributes[:stuff], Dynamini::Attributes::DELETED_TOKEN, 'DELETE'])
        expect(model.send(:attribute_updates)['stuff'].keys).to_not include(:value)
      end

      it 'should remove the attribute from the in-memory attributes' do
        model.delete_attribute(:stuff)
        expect(model.attributes.keys).to_not include('stuff')
      end
    end

    context 'the attribute does not exist' do
      it 'does not enqueue a change' do
        model.delete_attribute(:nonexistent)
        expect(model.changes.keys).to_not include('nonexistent')
      end
    end
  end

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
      context 'adding to an uninitialized set' do
        it 'creates the set' do
          model.add_to(:new_set, Set.new([4]))
          expect(model.new_set).to eq(Set.new([4]))
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
      context 'adding to an empty array' do
        it 'creates the array' do
          model.add_to(:new_array, [4])
          expect(model.new_array).to eq([4])
        end
      end
    end

    context 'without reading a previously saved item' do
      it 'still adds' do
        model.save
        model_clone = HandledModel.new(id: model_attributes[:id])
        model_clone.add_to(:price, 2)
        model_clone.save
        expect(HandledModel.find(model_attributes[:id]).price).to eq(11.99)
      end
    end
  end

  describe '#handled_attributes' do
    it 'returns a hash of attributes with type conversion applied' do
      expect(model.handled_attributes).to eq(
        name: "Widget", price: 9.99, id: "abcd1234", hash_key: "009", things: Set.new([1, 2, 3]), stuff: [4, 5, 6]
      )
    end
  end

  describe '#inspect' do
    it 'serializes the class name and the handled attributes' do
      expect(model.inspect).to eq('#<HandledModel name: "Widget", price: 9.99, id: "abcd1234", hash_key: "009", things: #<Set: {1, 2, 3}>, stuff: [4, 5, 6]>')
    end
  end
end
