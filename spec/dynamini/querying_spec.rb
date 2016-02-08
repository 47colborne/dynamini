require 'spec_helper'

describe Dynamini::Querying do

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
    handle :bar, :integer
  end

  describe '.find' do

    before do
      model.save
    end

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

  describe '.exists?' do
    context 'with hash key' do
      context 'the item exists' do
        before do
          model.save
        end
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

  describe '.find_or_new' do
    context 'when a record with the given key exists' do
      before do
        model.save
      end
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
end