## Dynamini
Dynamini is a lightweight DynamoDB interface designed as a drop-in replacement for ActiveRecord.

[![Build Status](https://travis-ci.org/47colborne/dynamini.svg?branch=master)](https://travis-ci.org/47colborne/dynamini)
[![Code Climate](https://codeclimate.com/github/47colborne/dynamini/badges/gpa.svg)](https://codeclimate.com/github/47colborne/dynamini)
[![Gem Version](https://badge.fury.io/rb/dynamini.svg)](https://badge.fury.io/rb/dynamini)

##### Table of Contents  
- [The Basics](#the-basics)  
- [Configuration](#configuration)
- [Datatype Handling](#datatype-handling)
- [Enumerable Attributes](#enumerable-attributes)
- [Querying](#querying)
- [Scanning](#scanning)
- [Secondary Indices](#secondary-indices)
- [Batch Saving](#batch-saving)
- [Testing](#testing)
- [Things to Remember](#things-to-remember)
- [Contributing](#contributing)
      
## The Basics
This gem is designed to provide an ActiveRecord-like interface for Amazon's DynamoDB, making it easy for you to make the switch from a traditional relational DB. Once you've set up your table in the DynamoDB console, and installed and configured Dynamini, the behavior of the following ActiveRecord methods will be preserved:

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

There are also some new methods specific to DynamoDB's API that don't have a counterpart in ActiveRecord:

* find_or_nil(hash_key, range_key) - since ActiveRecord's find_by isn't applicable to noSQL, use this method if you want a .find that doesn't raise exceptions when the item doesn't exist
* batch_find([keys]) - to retrieve multiple objects at once.
* increment!({attribute1: amount, attribute2: amount}) - to update your record using DynamoDB's Atomic Counter functionality. (For more information, see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html#WorkingWithItems.AtomicCounters )
* add_to(attribute, value) - If you use this to modify your attribute, when saving, Dynamini will update that attribute with ADD instead of PUT. Your attribute must be handled as an addable type - :integer, :float, :array, :set, :date, or :time. (For more information on ADD actions, see http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_UpdateItem.html )
* delete_attribute(attribute) - Use this to delete an attribute from a record completely, rather than just blanking it or nullifying it.
* delete_attribute!(attrubute) - same as above but with an included save!

## Configuration
In application.rb, or in initializers/dynamini.rb, include your AWS settings like this:

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
    set_table_name 'cars'     # must match the table name configured in AWS
    set_hash_key :model       # defaults to :id if not set
    set_range_key :vin        # must be set if your AWS table is configured with a range key

    # ...All the rest of your class methods, instance methods, and validators
end
```

If you don't use set_table_name, Dynamini will try to find a table with the pluralized, downcased class name. For instance, a Dynamini class called PageView would look for a table called 'page_views'. If you use separate DynamoDB tables for development and production, wrap set_table_name in a conditional to determine the appropriate table when your class initializes. In this example, the production table is 'vehicles' and the development table is 'vehicles-dev':

```ruby
class Vehicle < Dynamini::Base
    set_table_name 'vehicles-dev' unless Rails.env.production?
end
```

## Datatype Handling
There are a few quirks about how the Dynamo Ruby SDK stores data. It stores numeric values as BigDecimal objects, symbols as strings, and doesn't accept ruby Date or Time objects. To save you from having to convert your data to the correct type before saving and after retrieval, you can use :handle to manage automatic type conversion. This is also where you can specify default values for your attributes. Here's how it works:

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

Dynamini lets you :handle the following types:
* :integer
* :float
* :symbol
* :boolean
* :date
* :time
* :string
* :array
* :set

Default values aren't actually written to the database when saving your instance. Instead, they define what will be returned when reading an unset or nullified attribute. If you don't provide your own default, the "default default" value depends on the specified type:

* array: []
* set: Set.new
* all other types: nil
* attribute not handled: nil

The auto-generated fields updated_at and created_at are intrinsically handled as :time.

If you want to see all your attributes at once, with type conversions applied (e.g for serialization as JSON), call :handled_attributes. The :attributes method, conversely, will show you the real values as written to DynamoDB.

## Enumerable Attributes
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

## Querying

Dynamini includes a query function that's much more narrow than ActiveRecord's where function, since DynamoDB is not automatically optimized for highly flexible read operations. It's designed to retrieve a selection of records that belong to a given hash key but have various range key values. 

To use .query, your table needs to be configured with a range key, and you need to :handle that range field as a fundamentally numeric type - integer, float, date, or time. If your range key field isn't numeric, you won't be able to .query, but you'll still be able to .find your records normally.

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
  
## Scanning
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
To define a secondary index (so that you can .scan or .query it), you can set them at the top of your Dynamini subclass. The index names have to match the names you've set up through the DynamoDB console. You'll need to specify which attribute your index is keyed to, and if your secondary index uses a range key, specify it here as well.

```ruby
class Comment < Dynamini::Base
    set_hash_key :id
    set_range_key :comment_date # filter comments by date
    set_secondary_index :score_index, hash_key: :score  # lookup comments by score
    set_secondary_index :user_index, hash_key: :user_id, range_key: :comment_date # lookup comments by user, filtering by date
end
```
For more information on how and why to use secondary indices, see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html

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

## Testing
Dynamini includes an in-memory test client, so you don't have to connect to a real Dynamo instance when running tests. To activate this feature, just require the testing module:
```ruby
require 'dynamini/testing'
```
Requiring the module replaces all API calls Dynamini makes to AWS with calls to Dynamini::TestClient.

You probably don't want your data to persist between tests, so you'll have to reset the test client to wipe its data:
```ruby
# in this case Vehicle is our Dynamini subclass
Vehicle.client.reset
```

Here's an implementation of the above in a typical spec_helper.rb:
```ruby
require 'dynamini/testing'

config.after(:each) {
  Vehicle.client.reset
}
```
Each of your Dynamini subclasses uses a separate sandboxed TestClient, which can cause some unexpected behavior when testing polymorphic classes that are meant to share the same production table.

## Things to remember
* Since DynamoDB is schemaless, Dynamini is designed to allow your instance to respond to any method call that looks like an attribute name, even if you've never referenced it before. For instance, model.i_bet_this_will_raise_an_error will return nil.
* Similarly, you can write any arbitrarily-named attribute to your instance without defining its name or properties beforehand.
* Dynamini will attempt to split very large item updates into multiple save operations. However, if a single attribute is not enumerable and is itself larger than AWS's size limit, the update will be rejected.
* If you change the primary key value on an instance of your model, then resave it, you'll have two records in your database.
* If you have a model with a foreign key attribute that points to your Dynamini model, you can use Rails' :belongs_to association helper normally. (If you use non-numeric strings for your Dynamini hash key, remember to change your foreign key columns on related ActiveRecord tables to be string type.)

## Contributing

If you'd like to contribute, pull requests are welcome!
