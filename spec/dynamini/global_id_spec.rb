require 'spec_helper'
require 'dynamini/global_id'

describe Dynamini::GlobalId do

  let(:model) do
    Class.new(Dynamini::Base) do
      include Dynamini::GlobalId

      set_table_name :test
      set_hash_key :attr1
    end
  end

  subject { model.new }

  describe '#serialize_id' do
    it 'returns hash key' do
      id = 'this is primary id'
      subject.attr1 = id
      expect(subject.serialize_id).to eq(id)
    end

    context 'when range key is used' do
      before { model.set_range_key :attr2 }

      it 'raises error if not being defined' do
        error_message = 'Dynamini::GlobalId#serialize_id requires range key. please define #serialize_id'
        expect { subject.serialize_id }.to raise_error(error_message)
      end
    end
  end

  describe '#id' do
    it 'return serialized id' do
      expect(subject.id).to eq(subject.serialize_id)
    end
  end

  describe '.deserialize_id' do
    it 'return the given id' do
      id = "test id"
      expect(model.deserialize_id(id)).to eq id
    end

    context 'when range key is used' do
      before { model.set_range_key :attr2 }

      it 'raises error if not being defined' do
        error_message = 'Dynamini::GlobalId.deserialize_id requires range key. please define .deserialize_id'
        expect { model.deserialize_id("id") }.to raise_error(error_message)
      end
    end
  end

  describe '.find' do
    let(:id) { 'test id' }

    before do
      subject.attr1 = id
      subject.save
    end

    it 'triggers .deserialize_id with given id' do
      expect(model).to receive(:deserialize_id).with(id).and_return(id)
      expect(model.find(id)).to eq(subject)
    end
  end

end