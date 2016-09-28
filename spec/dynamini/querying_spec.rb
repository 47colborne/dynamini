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
    set_secondary_index :secondary_index, hash_key: :secondary_hash_key, range_key: :secondary_range_key
    handle :bar, :integer
    handle :secondary_range_key, :integer
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
      expect(found).to_not be_new_record
    end

    context 'when the object does not exist' do
      it 'should raise an error' do
        expect do
          Dynamini::Base.find('1')
        end.to raise_error Dynamini::RecordNotFound, "Couldn't find Dynamini::Base with 'id'=1"

        expect do
          TestClassWithRange.find('1', '2')
        end.to raise_error Dynamini::RecordNotFound, "Couldn't find TestClassWithRange with 'foo'=1 and 'bar'=2"
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

  describe '.find_or_nil' do
    it 'should return nil if it cannot find the item' do
      found = Dynamini::Base.find_or_nil('abcd1234')
      expect(found).to be_nil
    end

    it 'should return the record if it exists' do
      model.save
      found = Dynamini::Base.find_or_nil('abcd1234')
      expect(found.price).to eq(9.99)
      expect(found.name).to eq('Widget')
      expect(found.hash_key).to eq('009')
    end
  end

  describe '.query' do
    before do
      4.times do |i|
        TestClassWithRange.create(foo: 'foo', bar: i + 1, secondary_hash_key: 'secondary_hash_key', secondary_range_key: 10 - i)
      end
      TestClassWithRange.create(foo: 'foo2', bar: 5, secondary_hash_key: 'secondary_hash_key', secondary_range_key: 6)

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

    context 'hash key does not exist' do
      it 'should return an empty array' do
        expect(TestClassWithRange.query(hash_key: 'non-existent-key')).to eq([])
      end
    end

    context 'when :limit is provided' do
      it 'should return only the first two records' do
        records = TestClassWithRange.query(hash_key: 'foo', limit: 2)
        expect(records.length).to eq 2
        expect(records.first.bar).to eq 1
        expect(records.last.bar).to eq 2
      end
    end

    context 'when :scan_index_forward is provided' do
      it 'should return records in order when given true' do
        records = TestClassWithRange.query(hash_key: 'foo', scan_index_forward: true)
        expect(records.length).to eq 4
        expect(records.first.bar).to eq 1
        expect(records.last.bar).to eq 4
      end

      it 'should return records in reverse order when given false' do
        records = TestClassWithRange.query(hash_key: 'foo', scan_index_forward: false)
        expect(records.length).to eq 4
        expect(records.first.bar).to eq 4
        expect(records.last.bar).to eq 1
      end
    end

    context 'using secondary index' do
      it 'should be able to query using the secondary index' do
        records = TestClassWithRange.query(hash_key: 'secondary_hash_key', index_name: :secondary_index)
        expect(records.length).to eq(5)
        expect(records.first.secondary_range_key).to eq(6)
        expect(records.last.secondary_range_key).to eq(10)
      end

      it 'should be able to sort backwards' do
        records = TestClassWithRange.query(hash_key: 'secondary_hash_key', index_name: :secondary_index, scan_index_forward: false)
        expect(records.length).to eq(5)
        expect(records.first.secondary_range_key).to eq(10)
        expect(records.last.secondary_range_key).to eq(6)
      end

      it 'should be able to limit number of results' do
        records = TestClassWithRange.query(hash_key: 'secondary_hash_key', index_name: :secondary_index, limit: 3)
        expect(records.length).to eq(3)
        expect(records.first.secondary_range_key).to eq(6)
        expect(records.last.secondary_range_key).to eq(8)
      end

      it 'should be able to give a minimum value for the range key' do
        records = TestClassWithRange.query(hash_key: 'secondary_hash_key', index_name: :secondary_index, start: 8)
        expect(records.length).to eq(3)
        expect(records.first.secondary_range_key).to eq(8)
        expect(records.last.secondary_range_key).to eq(10)
      end

      it 'should be able to give a maximum for the range key' do
        records = TestClassWithRange.query(hash_key: 'secondary_hash_key', index_name: :secondary_index, end: 8)
        expect(records.length).to eq(3)
        expect(records.first.secondary_range_key).to eq(6)
        expect(records.last.secondary_range_key).to eq(8)
      end

      it 'should be able to give a maximum for the range key' do
        records = TestClassWithRange.query(hash_key: 'secondary_hash_key', index_name: :secondary_index, start: 7, end: 9)
        expect(records.length).to eq(3)
        expect(records.first.secondary_range_key).to eq(7)
        expect(records.last.secondary_range_key).to eq(9)
      end

      it 'should return no results if none are found with the secondary index' do
        expect(TestClassWithRange.query(hash_key: 'non-existent-key', index_name: :secondary_index)).to eq([])
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
