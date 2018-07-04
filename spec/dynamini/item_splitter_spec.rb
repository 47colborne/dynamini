require 'spec_helper'

describe Dynamini::ItemSplitter do
  before do
    stub_const("Dynamini::ItemSplitter::MAX_SIZE", 200)
  end

  context 'regular update' do
    it 'returns one update' do
      input = {foo: {action: 'PUT', value: '123'}, bar: {action: 'ADD', value: [4,5,6]}}
      expect(Dynamini::ItemSplitter.split(input)).to eq([input])
    end
  end

  context 'large update' do
    it 'returns multiple updates' do
      input = {foo: {action: 'PUT', value: '123'}, bar: {action: 'ADD', value: [4,5,6]}, baz: {action: 'PUT', value: 'hello'}}
      output = Dynamini::ItemSplitter.split(input)
      expect(output[0]).to eq({foo: {action: 'PUT', value: '123'}, bar: {action: 'ADD', value: [4,5,6]}})
      expect(output[1]).to eq(baz: {action: 'PUT', value: 'hello'})
    end
  end

  context 'large enumerable attribute' do
    it 'splits the attribute' do
      input = {enum: {action: 'PUT', value: Array.new(20, 'hello')}}
      output = Dynamini::ItemSplitter.split(input)
      expect(output.length).to eq(2)
      expect(output[0][:enum][:action]).to eq('PUT')
      expect(output[1][:enum][:action]).to eq('ADD')
    end
  end

  context 'large non-enumerable attribute' do
    it 'raises an error' do
      input = {not_enum: {action: 'PUT', value: Array.new(20, 'hello').to_s}}
      expect{ Dynamini::ItemSplitter.split(input) }.to raise_error("not_enum is too large to save and is not splittable (not enumerable).")
    end
  end
end
