require 'spec_helper'

describe Dynamini::BatchOperations do

  let(:model_attributes) {
    {
        name: 'Widget',
        price: 9.99,
        id: 'abcd1234',
        hash_key: '009'
    }
  }

  let(:model) { Dynamini::Base.new(model_attributes) }

  subject { Dynamini::Base }

  describe '.import' do
    it 'should generate timestamps for each model' do
      model1 = Dynamini::Base.new(model_attributes)
      model2 = Dynamini::Base.new(model_attributes.merge(id: '2'))

      subject.import([model1, model2])

      expect(subject.find(model1.id).updated_at).not_to be_nil
      expect(subject.find(model1.id).created_at).not_to be_nil
      expect(subject.find(model2.id).updated_at).not_to be_nil
      expect(subject.find(model2.id).created_at).not_to be_nil
    end

    it 'should not generate timestamps if skip_timestamp flag is passed' do
      model1 = Dynamini::Base.new(model_attributes)
      model2 = Dynamini::Base.new(model_attributes.merge(id: '2'))

      subject.import([model1, model2], skip_timestamps: true)

      expect(subject.find(model1.id).updated_at).to be_nil
      expect(subject.find(model1.id).created_at).to be_nil
      expect(subject.find(model2.id).updated_at).to be_nil
      expect(subject.find(model2.id).created_at).to be_nil
    end

    it 'should call .dynamo_batch_save with batches of 25 models' do
      models = Array.new(30, model)
      expect(subject).to receive(:dynamo_batch_save).with(array_including(models[0..24])).ordered
      expect(subject).to receive(:dynamo_batch_save).with(array_including(models[25..29])).ordered
      subject.import(models)
    end
  end

  describe '.dynamo_batch_save' do
    it 'should batch write the models to dynamo' do
      model2 = Dynamini::Base.new(id: '123')
      model3 = Dynamini::Base.new(id: '456')
      Dynamini::Base.import([model2, model3])
      expect(Dynamini::Base.find('123')).to_not be_nil
      expect(Dynamini::Base.find('456')).to_not be_nil
    end
  end

  describe '.batch_find' do
    before do
      model.save
    end
    context 'when requesting 0 items' do
      it 'should return an empty array' do
        expect(Dynamini::Base.batch_find.found).to eq []
        expect(Dynamini::Base.batch_find.not_found).to eq []
      end
    end

    context 'when requesting multiple items' do
      let(:result) { Dynamini::Base.batch_find(%w(abcd1234 4321 foo)) }
      before do
        Dynamini::Base.create(id: '4321')
      end

      it 'should return the found items' do
        expect(result.found.length).to eq 2
        expect(result.found.first.id).to eq model.id
        expect(result.found.last.id).to eq '4321'
      end

      it 'should return the hash keys of the items not found' do
        expect(result.not_found).to eq(['foo'])
      end
    end

    context 'when requesting over 100 items' do
      let(:ids) do
        i =* (1..101)
        i.map(&:to_s)
      end

      before do
        i =* (1..51)
        i.each { |id| Dynamini::Base.create(id: id.to_s) }
      end

      it 'should call dynamo once for each 100 items' do
        expect(Dynamini::Base).to receive(:dynamo_batch_get).twice.and_call_original
        Dynamini::Base.batch_find(ids)
      end

      it 'should return the combined responses of multiple dynamo calls' do
        result = Dynamini::Base.batch_find(ids)
        expect(result.found.length).to eq(51)
        expect(result.not_found.length).to eq(50)
      end
    end
  end

  describe '.batch_delete' do
    let(:ids) { ['4321', '4567', '7890'] }

    before do
      Dynamini::Base.create(id: '4321')
      Dynamini::Base.create(id: '4567')
      Dynamini::Base.create(id: '7890')
    end

    it 'should delete all items in collection to the database' do
      subject.batch_delete(ids)
      expect{ Dynamini::Base.find('4321') }.to raise_error(Dynamini::RecordNotFound)
      expect{ Dynamini::Base.find('4567') }.to raise_error(Dynamini::RecordNotFound)
      expect{ Dynamini::Base.find('7890') }.to raise_error(Dynamini::RecordNotFound)
    end
  end

  class SecBase < Dynamini::Base
    set_hash_key :id
    set_secondary_index :sec, hash_key: :sec
    set_secondary_index :rev, hash_key: :sec
  end

  describe '.scan' do

    before do
      SecBase.create(id: '123', sec: 'D')
      SecBase.create(id: '124', sec: 'C')
      SecBase.create(id: '125', sec: 'B')
      SecBase.create(id: '126', sec: 'A')
    end

    context 'scanning the primary key' do
      context 'with an exclusive_start_key' do
        context 'with a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(start_key: '124', limit: 1)
            expect(response.items.map { |i| i.id }).to eq(['124'])
            expect(response.last_evaluated_key).to eq('id' => '124')
          end
        end
        context 'without a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(start_key: '124')
            expect(response.items.map { |i| i.id }).to eq(%w(124 125 126))
            expect(response.last_evaluated_key).to be_nil
          end
        end

        context 'the start key is in aws sdk style' do
          it 'retrieves the correct items' do
            response = SecBase.scan(start_key: {'id' => '124'}, limit: 2)
            expect(response.items.map { |i| i.id }).to eq(['124', '125'])
            expect(response.last_evaluated_key).to eq('id' => '125')
          end
        end
      end
      context 'without an exclusive_start_key' do
        context 'with a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(limit: 2)
            expect(response.items.map { |i| i.id }).to eq(%w(123 124))
            expect(response.last_evaluated_key).to eq('id' => '124')
          end
        end
        context 'without a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan
            expect(response.items.map { |i| i.id }).to eq(%w(123 124 125 126))
            expect(response.last_evaluated_key).to be_nil
          end
        end
      end
    end
    context 'scanning a secondary index' do
      context 'with an exclusive_start_key' do
        context 'with a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(index_name: 'sec', start_key: 'B', limit: 2)
            expect(response.items.map { |i| i.sec }).to eq(%w(B C))
            expect(response.last_evaluated_key).to eq('sec' => 'C')
          end
        end
        context 'without a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(index_name: 'sec', start_key: 'B')
            expect(response.items.map { |i| i.sec }).to eq(%w(B C D))
            expect(response.last_evaluated_key).to be_nil
          end
        end
      end
      context 'without an exclusive_start_key' do
        context 'with a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(index_name: 'sec', limit: 3)
            expect(response.items.map { |i| i.sec }).to eq(%w(A B C))
            expect(response.last_evaluated_key).to eq('sec' => 'C')
          end
        end
        context 'without a limit' do
          it 'retrieves the correct items' do
            response = SecBase.scan(index_name: 'sec')
            expect(response.items.map { |i| i.sec }).to eq(%w(A B C D))
            expect(response.last_evaluated_key).to be_nil
          end
        end
      end
    end
  end
end

