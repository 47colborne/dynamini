require 'spec_helper'

describe Dynamini::Dirty do

  let(:model_attributes) {
   {
       name: 'Widget',
       price: 9.99,
       id: 'abcd1234',
       hash_key: '009'
   }
  }

  let(:dirty_model) { Dynamini::Base.new(model_attributes) }
  let(:model) { Dynamini::Base.new(model_attributes, false) }


  describe '.new' do


    it 'should append all initial attrs to @changed, including hash_key' do
      expect(dirty_model.changed).to eq(model_attributes.keys.map(&:to_s).delete_if { |k, v| k == 'id' })
    end

    it 'should not include the primary key in the changes' do
      expect(dirty_model.changes['id']).to be_nil
    end
  end

  describe '#mark' do
    context 'when marking an unchanged attribute' do
      it 'should add the marked attribute to @changed' do
        model.mark(:price)
        expect(model.changed).to eq(['price'])
      end
    end
    context 'when marking an already changed attribute' do
      it 'should do nothing' do
        dirty_model.mark(:price)
        expect(dirty_model.changes['price']).to eq([nil, model_attributes[:price]])
      end
    end
    context 'when using it to mark a changed array' do
      it 'should write the mutated array value when saving' do
        model_with_array = Dynamini::Base.new({elements: ['a','b','c'], id: 'foo'}, false)
        model_with_array.elements << 'd'
        model_with_array.mark(:elements)
        model_with_array.save
        expect(Dynamini::Base.find('foo').elements).to eq(['a','b','c','d'])
      end
    end
  end

  describe '#__was' do

    context 'nonexistent attribute' do
      it 'should raise an error' do
        expect { Dynamini::Base.new.thing_was }.to raise_error ArgumentError
      end
    end

    context 'after saving' do
      it 'should clear all _was values' do
        model = Dynamini::Base.new
        model.new_val = 'new'
        model.save
        expect(model.new_val_was).to eq('new')
      end
    end

    context 'new record' do

      subject(:model) { Dynamini::Base.new(baz: 'baz') }
      it { is_expected.to respond_to(:baz_was) }

      context 'handled attribute with default' do
        it 'should return the default value' do
          Dynamini::Base.handle(:num, :integer, default: 2)
          expect(model.num_was).to eq(2)
        end
      end

      context 'handled attribute with no default' do
        it 'should return nil' do
          Dynamini::Base.handle(:num, :integer)
          expect(model.num_was).to be_nil
        end
      end

      context 'newly assigned attribute' do
        it 'should return nil' do
          model.new_attribute = 'hello'
          expect(model.new_attribute_was).to be_nil
        end
      end
    end

    context 'previously saved record' do
      subject(:model) { Dynamini::Base.new({baz: 'baz', nil_val: nil}, false) }
      context 'unchanged attribute' do
        it 'should return the current value' do
          expect(model.baz_was).to eq('baz')
        end
      end

      context 'newly assigned attribute or attribute changed from explicit nil' do
        it 'should return nil' do
          model.nil_val = 'no longer nil'
          model.new_val = 'new'
          expect(model.nil_val_was).to be_nil
          expect(model.new_val_was).to be_nil
        end
      end

      context 'attribute changed from value to value' do
        it 'should return the old value' do
          model.baz = 'baz2'
          expect(model.baz_was).to eq('baz')
        end
      end
    end
  end

  describe '#changes' do
    it 'should not return the hash key or range key' do
      Dynamini::Base.set_range_key(:range_key)
      model.instance_variable_set(:@changes, {id: 'test_hash_key', range_key: "test_range_key"})
      expect(model.changes).to eq({})
      Dynamini::Base.set_range_key(nil)
    end

    context 'no change detected' do
      it 'should return an empty hash' do
        expect(model.changes).to eq({})
      end
    end

    context 'attribute changed' do
      before { model.price = 1 }
      it 'should include the changed attribute' do
        expect(model.changes['price']).to eq([9.99, 1])
      end
    end

    context 'attribute created' do
      before { model.foo = 'bar' }
      it 'should include the created attribute' do
        expect(model.changes['foo']).to eq([nil, 'bar'])
      end
    end

    context 'attribute changed twice' do
      before do
        model.foo = 'bar'
        model.foo = 'baz'
      end
      it 'should only include one copy of the changed attribute' do
        expect(model.changes['foo']).to eq(['bar', 'baz'])
      end
    end
  end

  describe '#changed' do
    it 'should stringify the keys of changes' do
      allow(model).to receive(:changes).and_return({'price' => [1, 2], 'name' => ['a', 'b']})
      expect(model.changed).to eq(['price', 'name'])
    end
  end
end
