require 'spec_helper'

describe Dynamini::ClientInterface do
  describe '.client' do
    it 'should not reinstantiate the client' do
      expect(Dynamini::TestClient).to_not receive(:new)
      Dynamini::Base.client
    end
  end
end