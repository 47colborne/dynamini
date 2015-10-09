## Dynamini
Dynamini is a lightweight DynamoDB interface designed as a drop-in replacement for ActiveRecord. This gem powers part of our stack at yroo.com.

## The Basics
This gem is an opinionated interface, meaning it's set up to let you use DynamoDB at its most efficient. That means traditional relational DB functions like WHERE, GROUP BY, and HAVING are not implemented, since using these defeats the performance gains realized by switching to Dynamo in the first place. It's intended to be simple to use, understand, and extend. The ideal use case for this gem is when you have an ActiveRecord->SQL table with way too much concurrent activity, resulting in constant table locking. After you've moved your data to Dynamo, and installed and configured this gem, the following ActiveRecord commands will still work for your model:

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
* flush_queue! - to flush the batch_save queue early.

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
Dynamo stores all fields as strings. This can be inconvenient for numeric fields or dates, since you'll have to convert them to the correct type after retrieval. Dynamini supports automatic type conversion, allowing you to save non-string attributes to your model and retrieve them as the correct datatype later. If you want to see the stringified version sent to and from the database, just check the attributes hash. You can also specify default values for your fields. Here's how you set it up:

```ruby
class Vehicle < Dynamini::Base
    handle :top_speed, :integer, default: 80
end

car = Vehicle.new
car.top_speed
> 80
car.top_speed = 90
car.top_speed
> 90
car.attributes
> { top_speed: '90' }
```

Defaults are optional - without a default, a handled field without a value assigned to it will return nil like any other field.

The following datatypes are supported by handle:
* :integer
* :float
* :symbol
* :datetime
* :string

Note that the magic fields updated_at and created_at are handled as :datetime by default.


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
* The primary key is saved as a string. If you use stringified integers, your relationships should work normally,
 but if you use non-numeric strings for your keys, remember to change your foreign key columns on related objects to be string type.
* You might want to conditionally set the table name for your model based on the Rails.env, enabling separate tables for development and production.

## Coming Soon
* Support for range keys


## Contributing

If you'd like to contribute, pull requests are welcome!
