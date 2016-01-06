require 'spec_helper'

describe Dynamini::Base do
  let(:model_attributes) {
    {
        name: 'Widget',
        price: 9.99,
        id: 'abcd1234',
        hash_key: '009'
    }
  }

  subject(:model) { Dynamini::Base.new(model_attributes) }

  class TestClassWithRange < Dynamini::Base
    set_hash_key :foo
    set_range_key :bar
    self.in_memory = true
    handle :bar, :integer
  end

  before do
    model.save
  end

  describe '.set_table_name' do
    before do
      class TestClass < Dynamini::Base
      end
    end
    it 'should' do
      expect(TestClass.table_name).to eq('test_classes')
    end
  end

  describe '#configure' do
    before do
      Dynamini.configure do |config|
        config.region = 'eu-west-1'
      end
    end

    it 'returns the configured variables' do
      expect(Dynamini.configuration.region).to eq('eu-west-1')
    end
  end

  describe '.client' do
    it 'should not reinstantiate the client' do
      expect(Dynamini::TestClient).to_not receive(:new)
      Dynamini::Base.client
    end
  end

  describe 'operations' do

    describe '.handle' do

      class HandledClass < Dynamini::Base;
      end

      context 'when reading the handled attirubte' do
        before { HandledClass.handle :price, :integer, default: 9 }
        it 'should return the proper format' do
          object = HandledClass.new(price: "1")
          expect(object.price).to eq(1)
        end
        it 'should return the default value if not assigned' do
          object = HandledClass.new
          expect(object.price).to eq(9)
        end
        it 'should return an array with formated item if handled' do
          object = HandledClass.new(price: ["1", "2"])
          expect(object.price).to eq([1, 2])
        end
      end

      context 'when writing the handled attribute' do
        before { HandledClass.handle :price, :float, default: 9 }
        it 'should convert the value to handled format' do
          object = HandledClass.new(price: "1")
          expect(object.attributes[:price]).to eq(1.0)
        end
      end

    end

    describe '.new' do
      let(:dirty_model) { Dynamini::Base.new(model_attributes) }

      it 'should append all initial attrs to @changed, including hash_key' do
        expect(dirty_model.changed).to eq(model_attributes.keys.map(&:to_s).delete_if { |k, v| k == 'id' })
      end

      it 'should not include the primary key in the changes' do
        expect(dirty_model.changes[:id]).to be_nil
      end
    end

    describe '.create' do
      it 'should save the item' do
        other_model_attributes = model_attributes
        other_model_attributes[:id] = 'xyzzy'
        Dynamini::Base.create(other_model_attributes)
        expect(Dynamini::Base.find(other_model_attributes[:id])).to_not be_nil
      end

      it 'should return an instance of the model' do
        expect(Dynamini::Base.create(model_attributes)).to be_a(Dynamini::Base)
      end

      context 'when creating a subclass' do
        class Foo < Dynamini::Base
        end

        it 'should return the object as an instance of the subclass' do
          expect(Foo.create(value: '1')).to be_a Foo
        end
      end
    end

    describe '.find' do

      it 'should return a model with the retrieved attributes' do
        found = Dynamini::Base.find('abcd1234')
        expect(found.price).to eq(9.99)
        expect(found.name).to eq('Widget')
        expect(found.hash_key).to eq('009')
      end

      context 'when the object does not exist' do
        it 'should raise an error' do
          expect { Dynamini::Base.find('f') }.to raise_error 'Item not found.'
        end

      end

      context 'when retrieving a subclass' do
        class Foo < Dynamini::Base
          self.in_memory = true
        end

        it 'should return the object as an instance of the subclass' do
          Foo.create(id: '1')
          expect(Foo.find('1')).to be_a Foo
        end
      end
    end

    describe '.query' do
      before do
        4.times do |i|
          TestClassWithRange.create(foo: 'foo', bar: i + 1)
        end
      end
      context 'start value provided' do
        it 'should return records with a range key greater than or equal to the start value' do
          records = TestClassWithRange.query(hash_key: 'foo', start: 2)
          expect(records.length).to eq 3
          expect(records.first.bar).to eq 2
          expect(records.last.bar).to eq 4
        end
      end
      context 'end value provided' do
        it 'should return records with a range key less than or equal to the start value' do
          records = TestClassWithRange.query(hash_key: 'foo', end: 2)
          expect(records.length).to eq 2
          expect(records.first.bar).to eq 1
          expect(records.last.bar).to eq 2
        end
      end
      context 'start and end values provided' do
        it 'should return records between the two values inclusive' do
          records = TestClassWithRange.query(hash_key: 'foo', start: 1, end: 3)
          expect(records.length).to eq 3
          expect(records.first.bar).to eq 1
          expect(records.last.bar).to eq 3
        end
      end
      context 'neither value provided' do
        it 'should return all records belonging to that hash key' do
          records = TestClassWithRange.query(hash_key: 'foo')
          expect(records.length).to eq 4
          expect(records.first.bar).to eq 1
          expect(records.last.bar).to eq 4
        end
      end

      context 'a non-numeric range field' do
        it 'should raise an error' do
          class TestClassWithStringRange < Dynamini::Base
            self.in_memory = true
            set_hash_key :group
            set_range_key :user_name
          end
          expect { TestClassWithStringRange.query(hash_key: 'registered', start: 'a') }.to raise_error TypeError
        end
      end

      context 'hash key does not exist' do
        it 'should return an empty array' do
          expect(TestClassWithRange.query(hash_key: 'non-existent key')).to eq([])
        end
      end
    end

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

    describe '.find_or_new' do
      context 'when a record with the given key exists' do
        it 'should return that record' do
          existing_record = Dynamini::Base.find_or_new(model.id)
          expect(existing_record.new_record?).to eq(false)
          expect(existing_record.id).to eq(model.id)
        end

        it 'should return the record for table with range key' do
          existing_record = TestClassWithRange.create!(foo: 1, bar: 123)
          expect(TestClassWithRange.find_or_new(existing_record.foo, existing_record.bar).new_record?).to eq(false)
          expect(existing_record.foo).to eq(1)
          expect(existing_record.bar).to eq(123)
        end

      end
      context 'when the key cannot be found' do
        it 'should initialize a new object with that key' do
          expect(Dynamini::Base.find_or_new('foo').new_record?).to be_truthy
        end

        it 'should initialize a new object with hash key and range key' do
          new_record = TestClassWithRange.find_or_new(1, 6)
          expect(new_record.new_record?).to be_truthy
          expect(new_record.foo).to eq(1)
          expect(new_record.bar).to eq(6)
        end
      end
    end

    describe '#==' do
      let(:model_a) { Dynamini::Base.new(model_attributes).tap {
          |model| model.send(:clear_changes)
      } }
      let(:model_attributes_d) { {
          name: 'Widget',
          price: 9.99,
          hash_key: '007'
      } }

      context 'when the object is reflexive ( a = a )' do
        it 'it should return true' do
          expect(model_a.==(model_a)).to be_truthy
        end
      end

      context 'when the object is symmetric ( if a = b then b = a )' do
        it 'it should return true' do
          model_b = model_a
          expect(model_a.==(model_b)).to be_truthy
        end
      end

      context 'when the object is transitive (if a = b and b = c then a = c)' do
        it 'it should return true' do
          model_b = model_a
          model_c = model_b
          expect(model_a.==(model_c)).to be_truthy
        end
      end

      context 'when the object attributes are different' do
        it 'should return false' do
          model_d = Dynamini::Base.new(model_attributes_d).tap {
              |model| model.send(:clear_changes)
          }
          expect(model_a.==(model_d)).to be_falsey
        end
      end
    end

    describe '#assign_attributes' do
      it 'should return nil' do
        expect(model.assign_attributes(price: '5')).to be_nil
      end

      it 'should update the attributes of the model' do
        model.assign_attributes(price: '5')
        expect(model.attributes[:price]).to eq('5')
      end

      it 'should append changed attributes to @changed' do
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
        expect(model.attributes).to include(name: 'Widget 2.0', price: '12.00')
      end
    end

    describe '#save' do

      context 'when passing validation' do
        it 'should return true' do
          expect(model.save).to eq true
        end

        context 'something has changed' do
          it 'should call update_item with the changed attributes' do
            expect(model.class.client).to receive(:update_item).with(
                                              table_name: 'bases',
                                              key: {id: model_attributes[:id]},
                                              attribute_updates: hash_including(
                                                  "price" => {
                                                      value: '5',
                                                      action: 'PUT'
                                                  }
                                              )
                                          )
            model.price = '5'
            model.save
          end

          it 'should not return any changes after saving' do
            model.price = 5
            model.save
            expect(model.changed).to be_empty
          end
        end

        context 'when a blank field has been added' do
          it 'should suppress any blank keys' do
            expect(model.class.client).to receive(:update_item).with(
                                              table_name: 'bases',
                                              key: {id: model_attributes[:id]},
                                              attribute_updates: hash_not_including(
                                                  foo: {
                                                      value: '',
                                                      action: 'PUT'
                                                  }
                                              )
                                          )
            model.foo = ''
            model.bar = 4
            model.save
          end
        end
      end

      context 'when failing validation' do
        before do
          allow(model).to receive(:valid?).and_return(false)
          model.price = 5
        end

        it 'should return false' do
          expect(model.save).to eq false
        end

        it 'should not trigger an update' do
          expect(model.class.client).not_to receive(:update_item)
          model.save
        end
      end

      context 'nothing has changed' do
        it 'should not trigger an update' do
          expect(model.class.client).not_to receive(:update_item)
          model.save
        end
      end

      context 'when validation is ignored' do
        it 'should trigger an update' do
          allow(model).to receive(:valid?).and_return(false)
          model.price = 5
          expect(model.save!(validate: false)).to eq true
        end
      end
    end

    describe '#delete' do
      context 'when the item exists in the DB' do
        it 'should delete the item and return the item' do
          expect(model.delete).to eq(model)
          expect { Dynamini::Base.find(model.id) }.to raise_error ('Item not found.')
        end
      end
      context 'when the item does not exist in the DB' do
        it 'should return the item' do
          expect(model.delete).to eq(model)
        end
      end
    end
  end

  describe '#touch' do
    it 'should only send the updated time timestamp to the client' do
      allow(Time).to receive(:now).and_return 1
      expect(model.class.client).to receive(:update_item).with(
                                        table_name: 'bases',
                                        key: {id: model_attributes[:id]},
                                        attribute_updates: {
                                            updated_at: {
                                                value: 1,
                                                action: 'PUT'
                                            }
                                        }
                                    )
      model.touch
    end

    it 'should raise an error when called on a new record' do
      new_model = Dynamini::Base.new(id: '3456')
      expect { new_model.touch }.to raise_error StandardError
    end
  end

  describe '#save!' do

    context 'hash key only' do
      class TestValidation < Dynamini::Base
        set_hash_key :bar
        validates_presence_of :foo
        self.in_memory = true
      end

      it 'should raise its failed validation errors' do
        model = TestValidation.new(bar: 'baz')
        expect { model.save! }.to raise_error StandardError
      end

      it 'should not validate if validate: false is passed' do
        model = TestValidation.new(bar: 'baz')
        expect(model.save!(validate: false)).to eq true
      end
    end
  end

  describe '.create!' do
    class TestValidation < Dynamini::Base
      set_hash_key :bar
      validates_presence_of :foo
    end

    it 'should raise its failed validation errors' do
      expect { TestValidation.create!(bar: 'baz') }.to raise_error StandardError
    end
  end

  describe '#trigger_save' do
    class TestHashRangeTable < Dynamini::Base
      set_hash_key :bar
      set_range_key :abc
    end

    TestHashRangeTable.in_memory = true

    let(:time) { Time.now }
    before do
      allow(Time).to receive(:now).and_return(time)
    end
    context 'new record' do
      it 'should set created and updated time to current time for hash key only table' do
        new_model = Dynamini::Base.create(id: '6789')
        # stringify to handle floating point rounding issue
        expect(new_model.created_at.to_s).to eq(time.to_s)
        expect(new_model.updated_at.to_s).to eq(time.to_s)
        expect(new_model.id).to eq('6789')
      end

      # create fake dynamini child class for testing range key

      it 'should set created and updated time to current time for hash and range key table' do
        new_model = TestHashRangeTable.create!(bar: '6789', abc: '1234')

        # stringify to handle floating point rounding issue
        expect(new_model.created_at.to_s).to eq(time.to_s)
        expect(new_model.updated_at.to_s).to eq(time.to_s)
        expect(new_model.bar).to eq('6789')
        expect(new_model.abc).to eq('1234')
      end

    end
    context 'existing record' do
      it 'should set updated time but not created time' do
        existing_model = Dynamini::Base.new({name: 'foo'}, false)
        existing_model.price = 5
        existing_model.save
        expect(existing_model.updated_at.to_s).to eq(time.to_s)
        expect(existing_model.created_at.to_s).to_not eq(time.to_s)
      end
      it 'should not update created_at again' do
        object = Dynamini::Base.new(name: 'foo')
        object.save
        created_at = object.created_at
        object.name = "bar"
        object.save
        expect(object.created_at).to eq created_at
      end
      it 'should preserve previously saved attributes' do
        model.foo = '1'
        model.save
        model.bar = 2
        model.save
        expect(model.foo).to eq '1'
      end
    end
    context 'when suppressing timestamps' do
      it 'should not set either timestamp' do
        existing_model = Dynamini::Base.new({name: 'foo'}, false)
        existing_model.price = 5

        existing_model.save(skip_timestamps: true)

        expect(existing_model.updated_at.to_s).to_not eq(time.to_s)
        expect(existing_model.created_at.to_s).to_not eq(time.to_s)
      end
    end
  end

  describe 'table config' do
    class TestModel < Dynamini::Base
      set_hash_key :email
      set_table_name 'people'

    end

    it 'should override the primary_key' do
      expect(TestModel.hash_key).to eq :email
    end

    it 'should override the table_name' do
      expect(TestModel.table_name).to eq 'people'
    end
  end

  describe 'custom column handling' do
    class HandleModel < Dynamini::Base
      handle :price, :float, default: 10
      handle :start_date, :time
      handle :int_list, :integer
      handle :sym_list, :symbol
    end

    let(:handle_model) { HandleModel.new }

    it 'should create getters and setters' do
      expect(handle_model).to_not receive(:method_missing)
      handle_model.price = 1
      handle_model.price
    end

    it 'should retrieve price as a float' do
      handle_model.price = '5.2'
      expect(handle_model.price).to be_a(Float)
    end

    it 'should default price to 0 if not set' do
      expect(handle_model.price).to eq 10
    end

    it 'should store times as floats' do
      handle_model.start_date = Time.now
      expect(handle_model.attributes[:start_date]).to be_a(Float)
      expect(handle_model.attributes[:start_date] > 1_000_000_000).to be_truthy
      expect(handle_model.start_date).to be_a(Time)
    end

    it 'should reject bad data' do
      expect { handle_model.int_list = {a: 1} }.to raise_error NoMethodError
    end

    it 'should save casted arrays' do
      handle_model.int_list = [12, 24, 48]
      expect(handle_model.int_list).to eq([12, 24, 48])
    end

    it 'should retrieve casted arrays' do
      handle_model.sym_list = ['foo', 'bar', 'baz']
      expect(handle_model.sym_list).to eq([:foo, :bar, :baz])
    end
  end

  describe 'attributes' do
    describe '#attributes' do
      it 'should return all attributes of the object' do
        expect(model.attributes).to include model_attributes
      end
    end

    describe '.exists?' do

      context 'with hash key' do
        context 'the item exists' do
          it 'should return true' do
            expect(Dynamini::Base.exists?(model_attributes[:id])).to be_truthy
          end
        end

        context 'the item does not exist' do
          it 'should return false' do
            expect(Dynamini::Base.exists?('nonexistent id')).to eq(false)
          end
        end
      end

      context 'with hash key and range key' do

        it 'should return true if item exists' do
          TestClassWithRange.create!(foo: 'abc', bar: 123)

          expect(TestClassWithRange.exists?('abc', 123)).to eq(true)
        end

        it 'should return false if the item does not exist' do
          TestClassWithRange.create!(foo: 'abc', bar: 123)

          expect(TestClassWithRange.exists?('abc', 'nonexistent range key')).to eq(false)
        end

      end
    end


    describe '#new_record?' do
      it 'should return true for a new record' do
        expect(Dynamini::Base.new).to be_truthy
      end
      it 'should return false for a retrieved record' do
        expect(Dynamini::Base.find('abcd1234').new_record?).to be_falsey
      end
      it 'should return false after a new record is saved' do
        expect(model.new_record?).to be_falsey
      end
    end

    describe 'reader method' do
      it { is_expected.to respond_to(:price) }
      it { is_expected.not_to respond_to(:foo) }

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
          expect(subject.foo).to be_nil
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
      it { is_expected.to respond_to(:baz=) }

      context 'existing attribute' do
        before { model.price = '1' }
        it 'should overwrite the attribute' do
          expect(model.price).to eq('1')
        end
      end
      context 'new attribute' do
        before { model.foo = 'bar' }
        it 'should write to the attribute' do
          expect(model.foo).to eq('bar')
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

    describe '#key' do
      context 'when using hash key only' do

        before do
          class TestClass < Dynamini::Base
            set_hash_key :foo
            self.in_memory = true
          end
        end

        it 'should return an hash containing only the hash_key name and value' do
          expect(TestClass.new(foo: 2).send(:key)).to eq(foo: 2)
        end
      end
      context 'when using both hash_key and range_key' do
        it 'should return an hash containing only the hash_key name and value' do
          key_hash = TestClassWithRange.new(foo: 2, bar: 2015).send(:key)
          expect(key_hash).to eq(foo: 2, bar: 2015)
        end
      end
    end
  end
end

