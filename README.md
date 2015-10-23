## Dynamini
Dynamini is a lightweight DynamoDB interface designed as a drop-in replacement for ActiveRecord. This gem powers part of our stack at yroo.com.

[![Build Status](https://travis-ci.org/47colborne/dynamini.svg?branch=master)](https://travis-ci.org/47colborne/dynamini)
[![Code Climate](https://codeclimate.com/github/47colborne/dynamini/badges/gpa.svg)](https://codeclimate.com/github/47colborne/dynamini)
[![Gem Version](https://badge.fury.io/rb/dynamini@2x.png)](https://badge.fury.io/rb/dynamini)
[![Dependency Status](https://gemnasium.com/47colborne/dynamini.svg)](https://gemnasium.com/47colborne/dynamini)

## The Basics
This gem provides an opinionated interface, set up to let you use Amazon's DynamoDB at its most efficient. That means traditional relational DB functions like WHERE, GROUP BY, and HAVING aren't provided, since these trigger table scans that defeat the performance gains realized by switching to Dynamo in the first place. Use this gem when you have an relational table with too much concurrent activity, resulting in constant table locking. After you've moved your data to Dynamo, and installed and configured Dynamini, the following ActiveRecord functions will be preserved:

Class methods:
* create(attributes)
* create!(attributes)
* find(key)
* exists?(key)
* find_or_new(key)

Instance methods:
* new(attributes)
* ==(object)
* assign_attributes(attributes)
* update_attributes(attributes)
* update_attribute(attribute, value)
* save
* save!
* delete
* touch
* changes
* changed
* new_record?
* updated_at
* created_at

We've included ActiveModel::Validations, so any validators will still work and be triggered by the save/create methods.
There are also some new functions specific to DynamoDB's API:

* batch_find([keys]) - to retrieve multiple objects at once.
* enqueue_for_save(attributes) - to add your object to the batch write queue, which automatically sends a batch_save at length 25.
* flush_queue! - to send the items in batch_save queue before reaching length 25.
* increment!({attribute1: amount, attribute2: amount}) - to update your record using DynamoDB's Atomic Counter functionality. (For more information, see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html#WorkingWithItems.AtomicCounters )

## Configuration
In application.rb, or in initializers/dynamini.rb, include your AWS settings like so:

```ruby
Dynamini.configure do |config|
  config.aws_region = '[AWS region containing your DynamoDB instance]'
  config.access_key_id = '[access_key_id for your AWS account]'
  config.secret_access_key = '[secret_access_key for your AWS account]'
end
```

Then set up your model. You'll need to have it inherit from Dynamini::Base, then identify the primary key and table name to match your DynamoDB setup.
Here's what a sample model looks like. We'll refer back to this model later in the documentation.
```ruby
class Vehicle < Dynamini::Base
    set_hash_key :vin           # defaults to :id if not set
    set_table_name 'desks-dev'  # defaults to the pluralized, downcased model name if not set

    # ...All the rest of your class methods, instance methods, and validators
end
```

## Datatype Handling
There are a few quirks about how the Dynamo Ruby SDK stores data. It stores numeric values as BigDecimal objects, symbols as strings, and doesn't accept ruby Date or Time objects. To save you from having to convert your data to the correct type before saving and after retrieval, you can use the :handle helper for automatic type conversion. You can also use this to specify default values for your fields. Here's how it works:

```ruby
class Vehicle < Dynamini::Base
    set_hash_key :vin
    handle :top_speed, :integer, default: 80
end

car = Vehicle.new(vin: '43H1R')
car.top_speed
> 80
car.top_speed = 90
car.save
Vehicle.find('43H1R').top_speed
> 90
# This would return BigDecimal(90) without the handle helper.
```

Defaults are optional - without a default, a handled field without a value assigned to it will return nil like any other field.

The following datatypes are supported by handle:
* :integer
* :float
* :symbol
* :boolean
* :date
* :time
* :string

Booleans and strings don't actually need to be translated, but you can set up defaults for those fields this way.
The magic fields updated_at and created_at are handled as :time by default.

## Array Support
You can save arrays to your Dynamini model. If you've :handled that attribute, it will attempt to convert its contents to the correct datatype when setting and getting. Here's how it works:

```ruby
class Vehicle < Dynamini::Base
    set_hash_key :vin
    handle :parts, :symbol, default: []
end

car = Vehicle.new(vin: 'H3LL0')
car.parts
> []

car.parts = 'wheel'
car.parts
> :wheel

car.parts = ['wheel', 'brakes', 'seat']
car.parts
> [:wheel, :brakes, :seat]

# This line will raise an error since 5 cannot be converted to a symbol.
car.parts = ['wheel', 'brakes', 5]

# That multitype array can be saved to a non-:handled attribute.
car.stuff = ['wheel', 'brakes', 5]
car.stuff
> ['wheel', 'brakes', 5]
# But then you won't have any type conversion.
car.save
Vehicle.find('H3LLO').stuff
> ['wheel', 'brakes', BigDecimal(5)]
```

## Testing
There's a test client included with this gem, meaning you don't have to connect to a real Dynamo instance when testing.
You could also use this in development if you dont have a real Dynamo instance yet, but the data saved to it won't persist through a server restart.
To activate this feature, just call:
```ruby
Vehicle.in_memory = true
```
After which any internal API calls will be replaced with calls to Dynamini::TestClient.

The test client will not reset its database unless you tell it to, like so:
```ruby
Vehicle.client.reset
```

So, for instance, to get Rspec working with your test suite the way your ActiveRecord model behaved, add these lines to your spec_helper.rb:
```ruby
config.before(:all) {
  Vehicle.in_memory = true
}
config.after(:each) {
  Vehicle.client.reset # Large test suites will be very slow and unpredictable otherwise!
}
```

## Things to remember
* Since DynamoDB is schemaless, your model will respond to any method that looks like a reader, meaning model.foo will return nil.
* You can also write any arbitrary attribute to your model.
* Other models in your app cannot have a has_one or has_many relationship with your Dynamini model, since these would require a table scan. Your other models can still use belongs_to.
* If you change the primary key value on an instance of your model, then resave it, you'll have two copies in your database.
* If you use non-numeric strings for your primary key, remember to change your foreign key columns on related objects to be string type.
* You might want to conditionally set the table name for your model based on the Rails.env, enabling separate tables for development and production.

## Coming Soon
* Support for range keys

## Contributing

If you'd like to contribute, pull requests are welcome!
