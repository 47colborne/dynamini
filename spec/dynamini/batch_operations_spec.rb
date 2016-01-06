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
      expect_any_instance_of(subject).to receive(:generate_timestamps!).twice
      subject.import([model, model])
    end

    it 'should call .dynamo_batch_save with batches of 25 models' do
      models = Array.new(30, model)
      expect(subject).to receive(:dynamo_batch_save).with(array_including(models[0..24])).ordered
      expect(subject).to receive(:dynamo_batch_save).with(array_including(models[25..29])).ordered
      subject.import(models)
    end
  end

  describe '.enqueue_for_save' do
    before do
      Dynamini::Base.batch_write_queue = []
    end
    context 'when enqueuing a valid object' do
      it 'should return true' do
        expect(
            Dynamini::Base.enqueue_for_save(model_attributes)
        ).to eq true
      end
      it 'should append the object to the batch_write_queue' do
        Dynamini::Base.enqueue_for_save(model_attributes)
        expect(Dynamini::Base.batch_write_queue.length).to eq 1
      end
    end

    context 'when enqueuing an invalid object' do
      let(:bad_attributes) { {name: 'bad', id: nil} }
      before do
        allow_any_instance_of(Dynamini::Base).to receive(:valid?).and_return(false)
      end
      it 'should return false' do
        expect(Dynamini::Base.enqueue_for_save(bad_attributes)).to eq false
      end
      it 'should not append the object to the queue' do
        Dynamini::Base.enqueue_for_save(bad_attributes)
        expect(Dynamini::Base.batch_write_queue.length).to eq 0
      end
    end

    context 'when reaching the batch size threshold' do
      before do
        stub_const('Dynamini::BatchOperations::BATCH_SIZE', 1)
        allow(Dynamini::Base).to receive(:dynamo_batch_save)
      end
      it 'should return true' do
        expect(Dynamini::Base.enqueue_for_save(model_attributes)).to eq true
      end
      it 'should flush the queue' do
        Dynamini::Base.enqueue_for_save(model_attributes)
        expect(Dynamini::Base.batch_write_queue).to be_empty
      end
    end
  end

  describe '.flush_queue!' do
    it 'should empty the queue' do
      allow(Dynamini::Base).to receive(:dynamo_batch_save)
      Dynamini::Base.enqueue_for_save(model_attributes)
      Dynamini::Base.flush_queue!
      expect(Dynamini::Base.batch_write_queue).to be_empty
    end
    it 'should return the response from the db operation' do
      expect(Dynamini::Base).to receive(:dynamo_batch_save).and_return('foo')
      expect(Dynamini::Base.flush_queue!).to eq 'foo'
    end
    it 'should send the contents of the queue to dynamo_batch_save' do
      Dynamini::Base.enqueue_for_save(model_attributes)
      expect(Dynamini::Base).to receive(:dynamo_batch_save).with(
                                    Dynamini::Base.batch_write_queue
                                )
      Dynamini::Base.flush_queue!
    end
  end

  describe '.dynamo_batch_save' do
    before do
      Dynamini::Base.set_range_key(nil)
    end

    it 'should batch write the models to dynamo' do
      model2 = Dynamini::Base.new(id: '123')
      model3 = Dynamini::Base.new(id: '456')
      Dynamini::Base.dynamo_batch_save([model2, model3])
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
        expect(Dynamini::Base.batch_find).to eq []
      end
    end
    context 'when requesting 2 items' do
      it 'should return a 2-length array containing each item' do
        Dynamini::Base.create(id: '4321')
        objects = Dynamini::Base.batch_find(['abcd1234', '4321'])
        expect(objects.length).to eq 2
        expect(objects.first.id).to eq model.id
        expect(objects.last.id).to eq '4321'
      end
    end
    context 'when requesting too many items' do
      it 'should raise an error' do
        a = []
        150.times { a << 'foo' }
        expect { Dynamini::Base.batch_find(a) }.to raise_error StandardError
      end
    end
  end

end

