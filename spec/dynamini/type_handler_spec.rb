require 'spec_helper'

describe Dynamini::TypeHandler do
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
    end

    context 'when writing the handled attribute' do
      before { HandledClass.handle :price, :float, default: 9 }
      it 'should convert the value to handled format' do
        object = HandledClass.new(price: "1")
        expect(object.attributes[:price]).to eq(1.0)
      end
    end

  end

  class HandleModel < Dynamini::Base
    handle :price, :float, default: 10
    handle :start_date, :time
    handle :int_list, :integer
    handle :sym_list, :symbol
    handle :ary, :array
    handle :defaulted_ary, :array, default: [1,2,3]
    handle :float_array, :array, of: :float
    handle :sym_array, :array, of: :symbol
    handle :my_set, :set
    handle :defaulted_set, :set, default: Set.new([1,2,3])
    handle :sym_set, :set, of: :symbol
    handle :float_set, :set, of: :float
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

  it 'should reject non-enumerable data for enumerable handles' do
    expect { handle_model.my_set = 2 }.to raise_error ArgumentError
    expect { handle_model.ary = 2}.to raise_error ArgumentError
  end

  context 'when handling as array' do
    it 'should retrieve casted float arrays' do
      handle_model.float_array = [12, 24, 48]
      expectations = [12.0, 24.0, 48.0]
      handle_model.float_array.each_with_index do |e, i|
        expect(e).to equal(expectations[i])
      end
    end

    it 'should retrieve casted symbol arrays' do
      handle_model.sym_array = ['foo', 'bar', 'baz']
      expect(handle_model.sym_array).to eq([:foo, :bar, :baz])
    end

    it 'should default arrays to []' do
      expect(handle_model.ary).to eq([])
    end

    it 'should allow default values for arrays' do
      expect(handle_model.defaulted_ary).to eq([1, 2, 3])
    end

    it 'should convert sets to arrays' do
      handle_model.float_array = Set.new([12,24,48])
      expect(handle_model.float_array).to_not be_a(Set)
    end
  end

  context 'when handling as set' do
    it 'should retrieve casted float sets' do
      handle_model.float_set = Set.new([12, 24, 48])
      expect(handle_model.float_set).to eq(Set.new([12.0, 24.0, 48.0]))
    end

    it 'should retrieve casted symbol arrays' do
      handle_model.sym_set = Set.new(['foo', 'bar', 'baz'])
      expect(handle_model.sym_set).to eq(Set.new([:foo, :bar, :baz]))
    end

    it 'should default sets to empty sets' do
      expect(handle_model.my_set).to eq(Set.new)
    end

    it 'should allow default values for arrays' do
      expect(handle_model.defaulted_ary).to eq([1, 2, 3])
    end

    it 'should convert arrays to sets' do
      handle_model.float_set = [12,24,48]
      expect(handle_model.float_set).to_not be_a(Array)
    end

    it 'should complain if trying to cast elements as arrays' do
      expect{ HandleModel.handle :invalid, :set, of: :array}.to raise_error ArgumentError
    end

    it 'should complain if trying to cast elements as sets' do
      expect{ HandleModel.handle :invalid, :set, of: :set}.to raise_error ArgumentError
    end
  end
end
