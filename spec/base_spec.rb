require 'spec_helper'


describe Dynamini::Base do
  let(:model_attributes) { {name: 'Widget', price: 9.99, id: 'abcd1234', hash_key: '009'} }

  subject(:model) { Dynamini::Base.new(model_attributes) }


  before do
    Dynamini::Base.in_memory = true
    model.save
  end

  after do
    Dynamini::Base.client.reset
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


    describe '.new' do
      let(:dirty_model) { Dynamini::Base.new(model_attributes) }

      it 'should append all initial attributes to @changed, including hash_key' do
        expect(dirty_model.changed).to eq(model_attributes.keys.map(&:to_s))
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
        expect(Dynamini::Base.create(model_attributes).attributes).to eq(model_attributes)
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
        expect(Dynamini::Base.find('abcd1234').attributes).to eq(model_attributes)
      end

      context 'when the object does not exist' do

        it 'should raise an error' do
          expect { Dynamini::Base.find('foo') }.to raise_error 'Item not found.'
        end

      end

      context 'when retrieving a subclass' do
        class Foo < Dynamini::Base
          self.in_memory = true
        end

        it 'should return the object as an instance of the subclass' do
          Foo.create({id: '1'})
          expect(Foo.find('1')).to be_a Foo
        end
      end
    end

    describe '.enqueue_for_save' do
      before do
        Dynamini::Base.batch_write_queue = []
      end
      context 'when enqueuing a valid object' do
        it 'should return true' do
          expect(Dynamini::Base.enqueue_for_save(model_attributes)).to eq true
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
          stub_const('Dynamini::Base::BATCH_SIZE', 1)
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
        expect(Dynamini::Base).to receive(:dynamo_batch_save).with(Dynamini::Base.batch_write_queue)
        Dynamini::Base.flush_queue!
      end
    end

    describe '.dynamo_batch_save' do
      it 'should batch write the models to dynamo' do
        model2 = Dynamini::Base.create(id: '123')
        model3 = Dynamini::Base.create(id: '456')
        Dynamini::Base.dynamo_batch_save([model2, model3])
        expect(Dynamini::Base.find('123')).to_not be_nil
        expect(Dynamini::Base.find('456')).to_not be_nil
      end
    end

    describe '.batch_find' do
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
          array = []
          150.times { array << 'foo' }
          expect { Dynamini::Base.batch_find(array) }.to raise_error StandardError
        end
      end
    end

    describe '.find_or_new' do
      context 'when a record with the given key exists' do
        it 'should return that record' do
          expect(Dynamini::Base.find_or_new(model.id).new_record?).to be_falsey
        end
      end
      context 'when the key cannot be found' do
        it 'should initialize a new object with that key' do
          expect(Dynamini::Base.find_or_new('foo').new_record?).to be_truthy
        end
      end
    end

    describe '#==' do
      let(:model_a) { Dynamini::Base.new(model_attributes).tap { |model| model.send(:clear_changes) } }
      let(:model_attributes_d) { {name: 'Widget', price: 9.99, hash_key: '007'} }

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
          model_d = Dynamini::Base.new(model_attributes_d).tap { |model| model.send(:clear_changes) }
          expect(model_a.==(model_d)).to be_falsey
        end
      end
    end

    describe '#assign_attributes' do
      it 'should return nil' do
        expect(model.assign_attributes(price: 5)).to be_nil
      end

      it 'should update the attributes of the model' do
        model.assign_attributes(price: 5)
        expect(model.attributes[:price]).to eq(5)
      end

      it 'should append changed attributes to @changed' do
        model.assign_attributes(name: 'Widget', price: 5)
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
        model.update_attributes(name: 'Widget 2.0', price: 12.00)
        expect(model.attributes).to include(name: 'Widget 2.0', price: 12.00)
      end
    end

    describe '#save' do

      context 'when passing validation' do
        it 'should return true' do
          expect(model.save).to eq true
        end

        context 'something has changed' do
          it 'should call update_item with the changed attributes' do
            expect(model.class.client).to receive(:update_item).with(table_name: 'bases',
                                                         key: {id: model_attributes[:id]},
                                                         attribute_updates: hash_including({price: {value: 5, action: 'PUT'}}))
            model.price = 5
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
            expect(model.class.client).to receive(:update_item).with(table_name: 'bases',
                                                         key: {id: model_attributes[:id]},
                                                         attribute_updates: hash_not_including({foo: {value: '', action: 'PUT'}}))
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
          expect{ Dynamini::Base.find(model.id) }.to raise_error 'Item not found.'
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
      expect(model.class.client).to receive(:update_item).with(table_name: 'bases',
                                                   key: {id: model_attributes[:id]},
                                                   attribute_updates: {updated_at: {value: 1.0, action: 'PUT'}})
      model.touch
    end

    it 'should raise an error when called on a new record' do
      new_model = Dynamini::Base.new(id: '3456')
      expect{ new_model.touch }.to raise_error StandardError
    end
  end

  describe '#save!' do
    class TestValidation < Dynamini::Base
      self.hash_key = :bar
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

  describe '.create!' do
    class TestValidation < Dynamini::Base
      self.hash_key = :bar
      validates_presence_of :foo
    end

    it 'should raise its failed validation errors' do
      expect { TestValidation.create!(bar: 'baz') }.to raise_error StandardError
    end
  end

  describe '#trigger_save' do
    let(:time) { Time.now }
    before do
      allow(Time).to receive(:now).and_return(time)
    end
    context 'new record' do
      it 'should set created and updated time to current time' do
        new_model = Dynamini::Base.create(id: '6789')
        expect(new_model.created_at).to eq(time.to_f)
        expect(new_model.updated_at).to eq(time.to_f)
      end
    end
    context 'existing record' do
      it 'should set updated time but not created time' do
        model.price = 5
        model.save
        expect(model.updated_at).to eq(time.to_f)
        expect(model.created_at).to_not eq(time.to_f)
      end
      it 'should preserve previously saved attributes' do
        model.foo = 1
        model.save
        model.bar = 2
        model.save
        expect(model.foo).to eq 1
      end
    end
    context 'when suppressing timestamps' do
      it 'should not set either timestamp' do
        model.instance_variable_set(:@new_record, false)
        model.price = 5
        model.save(skip_timestamps: true)
        expect(model.updated_at).to_not eq(time.to_f)
        expect(model.created_at).to_not eq(time.to_f)
      end
    end


  end

  describe 'metaconfig' do
    class TestModel < Dynamini::Base
      self.hash_key = :email
      self.table_name = 'people'
    end

    it 'should override the primary_key' do
      expect(TestModel.hash_key).to eq :email
    end

    it 'should override the table_name' do
      expect(TestModel.table_name).to eq 'people'
    end
  end

  describe 'attributes' do
    describe '#attributes' do
      it 'should return all attributes of the object' do
        expect(model.attributes).to eq model_attributes
      end
    end

    describe '.exists?' do
      context 'the item exists' do
        it 'should return true' do
          expect(Dynamini::Base.exists?(model_attributes[:id])).to be_truthy
        end
      end

      context 'the item does not exist' do
        it 'should return false' do
          expect(Dynamini::Base.exists?('nonexistent id')).to be_falsey
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
        before { model.price = 1 }
        it 'should overwrite the attribute' do
          expect(model.price).to eq(1)
        end
      end
      context 'new attribute' do
        before { model.foo = 'bar' }
        it 'should write to the attribute' do
          expect(model.foo).to eq('bar')
        end
      end
    end

    describe '#changed' do
      context 'no change detected' do
        before { model.price = 9.99 }
        it 'should return an empty array' do
          expect(model.changed).to be_empty
        end
      end

      context 'attribute changed' do
        before { model.price = 1 }
        it 'should include the changed attribute' do
          expect(model.changed).to include('price')
        end
      end

      context 'attribute created' do
        before { model.foo = 'bar' }
        it 'should include the created attribute' do
          expect(model.changed).to include('foo')
        end
      end

      context 'attribute changed twice' do
        before do
          model.foo = 'bar'
          model.foo = 'baz'
        end
        it 'should only include one copy of the changed attribute' do
          expect(model.changed).to eq(['foo'])
        end
      end
    end
  end
end

