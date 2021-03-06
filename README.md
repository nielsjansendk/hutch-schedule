# Hutch::Schedule

Add the schedule message function to [Hutch](https://github.com/gocardless/hutch).

See [hutch-schedule-demo](https://github.com/wppurking/hutch-schedule-demo) how to integration with rails.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hutch-schedule'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hutch-schedule

## Usage

Use the code below to initialize the Hutch::Schedule

```ruby
Hutch::Schedule.connect
```

They will do something below:

1. Declear an topic exchange called `<hutch>.schedule` just for routing message to <hutch>_delay_queue_<5s>.
2. Declear an queue named `<hutch>_delay_queue_<5s>` and with some params:
  - Set `x-dead-letter-exchange: <hutch>`: let queue republish message to default <hutch> exchange.
  - Set `x-message-ttl: <30.days>`: to avoid the queue is to large, because there is no consumer with this queue.
3. If ActiveJob is loaded. it will use `ActiveJob::Base.descendants` to register all ActiveJob class to one-job-per-consumer to Hutch::Consumer 

### Hutch::Enqueue
Let consumer to include `Hutch::Enqueue` then it has the ability of publishing message to RabbitMQ with the `consume '<routing_key>'`

* enqueue: just publish one message
* enqueue_in: publish one message and delay <interval> seconds
* enqueue_at: publish one message and auto calculate the <interval> seconds need to delay

According to the RabbitMQ [TTL Message design limits](http://www.rabbitmq.com/ttl.html#per-message-ttl-caveats) ([discus](https://github.com/rebus-org/Rebus/issues/594#issuecomment-289961537)),
We design the fixed delay level from seconds to hours, below is the details:

* seconds(4): 5s, 10s, 20s, 30s
* minutes(14): 1m, 2m, 3m, 4m, 5m, 6m, 7m, 8m, 9m, 10m, 20m, 30m, 40m, 50m
* hours(3): 1h, 2h, 3h

RabbitMQ is not fit for storage lot`s of delay message so if you want delay an message beyand 3 hours so you need to storage it
into database or some place.

### Error Retry
If you want use error retry, then:

1. Add `Hutch::ErrorHandlers::MaxRetry` to `Hutch::Config.error_handlers` like below
```ruby
Hutch::Config.error_handlers << Hutch::ErrorHandlers::MaxRetry.new
```

2. Let `Hutch::Consumer` to include `Hutch::Enqueue` and setup `attempts`
```ruby
class PlanConsumer
  include Hutch::Consumer
  include Hutch::Enqueue
  
  attempts 3
  consume 'abc.plan'
end
```

Error retry will use ActiveJob `exponentially_longer` algorithm `(executes**4) + 2` seconds


## Rails

### Work with Hutch it`s self
Add an `hutch.rb` to `conf/initializers`:
```ruby
# reuse Hutch config.yaml file
Hutch::Config.load_from_file(Rails.root.join('config', 'config.yaml'))
# replace error_handlers with Hutch::ErrorHandlers::MaxRetry
Hutch::Config.error_handlers = [Hutch::ErrorHandlers::MaxRetry.new]
# Init Hutch
Hutch.connect
# Init Hutch::Schedule
Hutch::Schedule.connect
```

Then you can enqueue message in Rails console like below:
```ruby
PlanConsumer.enqueue(a: 1)
# or schedule message
PlanConsumer.enqueue_in(5.seconds, a: 1)
```

### Work with ActiveJob
```ruby
class EmailJob < ApplicationJob
  queue_as :email
  
  retry_on StandardError, wait: :exponentially_longer
  
  def perform(user_id)
    user = User.find(user_id)
    user.send_email
  end
end

# in rails console, you can
EmailJob.perform_later(user.id)
# or
EmailJob.set(wait: 5.seconds).perform_later(user.id)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wppurking/hutch-schedule. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Performance
Use the repo: https://github.com/wppurking/hutch-schedule-demo

#### ActiveJob enqueue
![ActiveJob enqueue](http://ofooyx8i9.bkt.clouddn.com/enqueue.jpg)

#### Hutch publish message
![Hutch publish message](http://ofooyx8i9.bkt.clouddn.com/enqueue_raw.jpg)

#### ActiveJob dequeue to execute
![ActiveJob dequeue to execute](http://ofooyx8i9.bkt.clouddn.com/consume.jpg)

#### Hutch dequeue to execute
![Hutch dequeue to execute](http://ofooyx8i9.bkt.clouddn.com/consume2.jpg)


# TODO
* simplify usage
* add rate limit to hutch, per queue with dynamic key. process level and global level.
* add cron job support
* add unique job support
