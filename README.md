## Dynamini
Dynamini is a lightweight DynamoDB interface designed as a drop-in replacement for ActiveRecord. This gem powers part of our stack at yroo.com.

[![Build Status](https://travis-ci.org/47colborne/dynamini.svg?branch=master)](https://travis-ci.org/47colborne/dynamini)
[![Code Climate](https://codeclimate.com/github/47colborne/dynamini/badges/gpa.svg)](https://codeclimate.com/github/47colborne/dynamini)
[![Gem Version](https://badge.fury.io/rb/dynamini.svg)](https://badge.fury.io/rb/dynamini)

## The Basics
This gem provides an opinionated interface, set up to let you use Amazon's DynamoDB at its most efficient. That means traditional relational DB functions like WHERE, GROUP BY, and HAVING aren't provided, since these trigger table scans that defeat the performance gains realized by switching to Dynamo in the first place. Use this gem when you have an relational table with too much concurrent activity, resulting in constant table locking. After you've moved your data to Dynamo, and installed and configured Dynamini, the following ActiveRecord functions will be preserved:

Class methods:
* create(attributes)
* create!(attributes)
* find(hash_key, range_key)
* exists?(hash_key, range_key)
* find_or_new(hash_key, range_key)
* import(model_array)
* before_save
* after_save

Note: The range_key arguments are only necessary if your DynamoDB table is configured with a range key.

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
* _was (e.g. model.foo_was, model.bar_was)
* new_record?
* updated_at
* created_at

We've included ActiveModel::Validations, so any validators will still work and be triggered by the save/create methods.
There are also some new functions specific to DynamoDB's API:

* batch_find([keys]) - to retrieve multiple objects at once.
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

Here's what a sample model looks like. This one includes a range key - sometimes your table will only need a hash key. If you aren't sure how or why to use range keys (also known as sort keys) with your DynamoDB instance, check here for help: http://stackoverflow.com/a/27348364

```ruby
class Vehicle < Dynamini::Base
    set_table_name 'cars-dev' # must match the table name configured in AWS
    set_hash_key :model       # defaults to :id if not set
    set_range_key :vin        # must be set if your AWS table is configured with a range key
    
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

## Querying With Range Keys

Dynamini includes a query function that's much more narrow than ActiveRecord's where function. It's designed to retrieve a selection of records that belong to a given hash key but have various range key values. To use .query, your table needs to be configured with a range key, and you need to :handle that range field as a fundamentally numeric type - integer, float, date, or time. If your range key field isn't numeric, you won't be able to .query, but you'll still be able to .find your records normally.

Query takes the following arguments:
* :hash_key (required)
* :start (optional)
* :end (optional)
* :limit (optional)
* :scan_index_forward (optional - set to false to sort by range key in desc order)

Here's how you'd use it to find daily temperature data for a given city, selecting for specific date ranges:

```ruby
class DailyWeather < Dynamini::Base
    set_hash_key :city
    set_range_key :record_date
    handle :temperature, :integer
    handle :record_date, :date
end

# Seeding our dataset...
A = DailyWeather.create!(city: "Toronto",  record_date: Date.new(2015,10,08), temperature: 15)
B = DailyWeather.create!(city: "Toronto",  record_date: Date.new(2015,10,09), temperature: 17)
C = DailyWeather.create!(city: "Toronto",  record_date: Date.new(2015,10,10), temperature: 12)
D = DailyWeather.create!(city: "Seville",  record_date: Date.new(2015,10,10), temperature: 30)

DailyWeather.query(hash_key: "Toronto")
> [A, B, C]

DailyWeather.query(hash_key: "Seville")
> [D]

DailyWeather.query(hash_key: "Bangkok")
> []

DailyWeather.query(hash_key: "Toronto", start: Date.new(2015,10,09))
> [B, C]

DailyWeather.query(hash_key: "Toronto", end: Date.new(2015,10,08))
> [A]

DailyWeather.query(hash_key: "Toronto", start: Date.new(2015,10,08), end: Date.new(2015,10,09))
> [A, B]

DailyWeather.query(hash_key: "Toronto", limit: 2)
> [A, B]

DailyWeather.query(hash_key: "Toronto", scan_index_forward: false)
> [C, B, A]
```

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

Please note that changing arrays in place using mutator methods like << or map! will not record a change to the object. 

If you want to make changes like this, either clone it then use the assignment operator (e.g. model.array = model.array.dup << 'foo') or call model.mark(:attribute) after mutation and before saving to force Dynamini to write the change.

## Testing
We've included an optional in-memory test client, so you don't necessarily have to connect to a real Dynamo instance when running tests. You could also use this in your development environment if you don't have a real Dynamo instance yet, but the data saved to it won't persist through a server restart.

To activate this feature, just require the testing module:
```ruby
require 'dynamini/testing'
```
This module replaces all API calls Dynamini makes to AWS DynamoDB with calls to Dynamini::TestClient.

The test client will not reset its database unless you tell it to, like so:
```ruby
Vehicle.client.reset
```

So, for instance, to get Rspec working with your test suite the way your ActiveRecord model behaved, add these lines to your spec_helper.rb:
```ruby
require 'dynamini/testing'

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

## Contributing

If you'd like to contribute, pull requests are welcome!
