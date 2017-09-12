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

* find_or_nil(hash_key, range_key) - since ActiveRecord's find_by isn't applicable to noSQL, use this method if you want a .find that doesn't raise exceptions when the item doesn't exist
* batch_find([keys]) - to retrieve multiple objects at once.
* increment!({attribute1: amount, attribute2: amount}) - to update your record using DynamoDB's Atomic Counter functionality. (For more information, see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html#WorkingWithItems.AtomicCounters )
* add_to(attribute, value) - If you use this to modify your attribute, when saving, Dynamini will update that attribute with ADD instead of PUT. Your attribute must be handled as an addable type - :integer, :float, :array, :set, :date, or :time. (For more information on ADD actions, see http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_UpdateItem.html )
* delete_attribute(attribute) - Use this to delete an attribute from a record completely, rather than just blanking it or nullifying it.
* delete_attribute!(attrubute) - same as above but with an included save!

## Configuration
In application.rb, or in initializers/dynamini.rb, include your AWS settings like so:

```ruby
Dynamini.configure do |config|
  config.region = '[AWS region containing your DynamoDB instance]'
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
* :array
* :set

Booleans and strings don't actually need to be translated, but you can set up defaults for those fields this way.
The magic fields updated_at and created_at are handled as :time by default.

## Enumerable Support
You can save arrays and sets to your Dynamini model. Optionally, you can have Dynamini perform type conversion on each element of your enumerable. Here's how it works:

```ruby
class Vehicle < Dynamini::Base
    set_hash_key :vin
    handle :parts, :array, of: :symbol # :of accepts all types except :set and :array
    handle :other_array, :array
end

car = Vehicle.create(vin: 'H3LL0')
car.parts
> []

car.parts = ['wheel']
car.parts
> [:wheel]

car.parts = ['wheel', 'brakes', 'seat']
car.parts
> [:wheel, :brakes, :seat]

# This line will raise an error since 5 cannot be converted to a symbol.
car.parts = ['wheel', 'brakes', 5]

# If you want a multitype array, use :handle without the :of option.
car.other_array = ['wheel', 'brakes', 5]
car.other_array
> ['wheel', 'brakes', 5]
# But then you won't have any type conversion.
car.save
Vehicle.find('H3LLO').other_array
> ['wheel', 'brakes', BigDecimal(5)]
```

Please note that changing enumerables in place using mutator methods like << or map! will not record a change to the object.

If you want to make changes like this, either clone it then use the assignment operator (e.g. model.array = model.array.dup << 'foo') or call model.mark(:attribute) after mutation and before saving to force Dynamini to write the change.

## Querying With Range Keys

Dynamini includes a query function that's much more narrow than ActiveRecord's where function. It's designed to retrieve a selection of records that belong to a given hash key but have various range key values. To use .query, your table needs to be configured with a range key, and you need to :handle that range field as a fundamentally numeric type - integer, float, date, or time. If your range key field isn't numeric, you won't be able to .query, but you'll still be able to .find your records normally.

Query takes the following arguments:
* :hash_key (required)
* :start (optional)
* :end (optional)
* :limit (optional)
* :scan_index_forward (optional - set to false to sort by range key in desc order)
* :index_name (to query a secondary index - see below)

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
  
## Table Scans
Table scanning is a very expensive operation, and should not be undertaken without a good understanding of the read/write costs. As such, Dynamini doesn't implement the traditional ActiveRecord collection methods like .all or .where. Instead, you can .scan, which has an interface much closer to DynamoDB's native SDK method.

The following options are supported:

* :consistent_read (default: false)
* :start_key (key of first desired item, if unset will scan from beginning)
* :index_name (if scanning a secondary index - see below)
* :limit (default: no limit except for AWS chunk size)
* :segment (for multiprocess scanning)
* :total_segments (for multiprocess scanning)

Note that start_key can be either a hash { "AttributeName" => "Value" } or a value literal. If start_key is a literal then the attribute name will be inferred automatically, either being the main hash_key of your model or the key of the secondary index matching the provided index_name. 

For more information about using segment and total_segments for parallelization, see: http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Scan.html


```ruby
products_page_one = Product.scan(limit: 100, start_key: 'abcd')

products_page_one.found 
> [product, product...]

products_page_one.last_evaluated_key
> {'id' => 'wxyz'}

page_two = Product.scan(start_key: products_page_one.last_evaluated_key)
```

## Secondary Indices
To define a secondary index (so that you can .scan it or .query it), you can list them at the top of your Dynamini subclass. The index names have to match the names you've set up through the DynamoDB console. If your secondary index uses a range key, specify it here as well.

```ruby
class Comment < Dynamini::Base
    set_hash_key :id
    set_range_key :comment_date
    set_secondary_index :score_index
    set_secondary_index :popularity_index, range_key: :popularity
end
```
For more information on how and why to use secondary indices, see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html
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

## Batch Saving
Dynamini implements DynamoDB's batch write operation, mapped to the .import method you might be used to from ActiveRecord. http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html

```ruby
class Product < Dynamini::Base
    set_hash_key :upc
end

model1 = Product.new({upc: 'abc', name: 'model1'})
model2 = Product.new({upc: 'xyz', name: 'model2'})

Product.import([model1, model2])

Product.find('abc').name
> 'model1'

model3 = Product.new({upc: 'qwerty', name: 'model3'}, skip_timestamps: true)

Product.import([model3], skip_timestamps: true)

Product.find('qwerty').name
> 'model3'

Product.find('qwerty').created_at
> nil

Product.find('qwerty').updated_at
> nil

````

## Things to remember
* Since DynamoDB is schemaless, your model will respond to any method that looks like a reader, meaning model.foo will return nil.
* You can also write any arbitrary attribute to your model.
* Other models in your app cannot have a has_one or has_many relationship with your Dynamini model, since these would require a table scan. Your other models can still use belongs_to.
* If you change the primary key value on an instance of your model, then resave it, you'll have two copies in your database.
* If you use non-numeric strings for your primary key, remember to change your foreign key columns on related ActiveRecord tables to be string type.
* You might want to conditionally set the table name for your model based on the Rails.env, enabling separate tables for development and production.

## Contributing

If you'd like to contribute, pull requests are welcome!
