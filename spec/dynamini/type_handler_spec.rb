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
      it 'should return an array with formatted items if handled' do
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