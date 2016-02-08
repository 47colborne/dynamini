module Dynamini
  module ClientInterface
    module ClassMethods
      def client
        @client ||= Dynamini::TestClient.new(hash_key, range_key)
      end
    end
  end
end