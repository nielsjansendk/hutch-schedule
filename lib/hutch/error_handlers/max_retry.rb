require 'hutch/logging'

module Hutch
  module ErrorHandlers

    # When reach the Max Attempts, republish this message to RabbitMQ,
    # And persisted the properties[:headers] to tell RabbitMQ the `x-dead.count`
    class MaxRetry
      include Logging

      # properties.headers example:
      # {
      #   "x-death": [
      #     {
      #       "count": 7,
      #       "exchange": "hutch.topic",
      #       "queue": "retry_queue",
      #       "reason": "expired",
      #       "routing-keys": [
      #         "plan"
      #       ],
      #       "time": "2017-05-13 23:37:15 +0800"
      #     },
      #     {
      #       "count": 7,
      #       "exchange": "hutch",
      #       "original-expiration": "3000",
      #       "queue": "plan_consumer",
      #       "reason": "rejected",
      #       "routing-keys": [
      #         "plan"
      #       ],
      #       "time": "2017-05-13 23:37:05 +0800"
      #     }
      #   ]
      # }
      def handle(properties, payload, consumer, ex)
        unless consumer.ancestors.include?(Hutch::Enqueue)
          logger.warn("Consumer: #{consumer} is not include Hutch::Enqueue can`t use #enqueue_in`")
          return false
        end

        prop_headers = properties[:headers] || {}
        attempts     = failure_count(prop_headers, consumer) + 1
        if attempts <= consumer.max_attempts
          logger.debug("retrying, count=#{attempts}, headers:#{prop_headers}")
          # execute_times = attempts - 1
          consumer.enqueue_in(retry_delay(attempts - 1), MultiJson.decode(payload), { headers: prop_headers })
        else
          logger.debug("failing, retry_count=#{attempts}, ex:#{ex}, headers: #{prop_headers}")
        end
      end

      def retry_delay(executes)
        (executes**4) + 2
      end

      def failure_count(headers, consumer)
        if headers.nil? || headers['x-death'].nil?
          0
        else
          x_death_array = headers['x-death'].select do |x_death|
            x_death['routing-keys'].include?(consumer.enqueue_routing_key)
          end

          if x_death_array.count > 0 && x_death_array.first['count']
            # Newer versions of RabbitMQ return headers with a count key
            x_death_array.inject(0) { |sum, x_death| sum + x_death['count'] }
          else
            # Older versions return a separate x-death header for each failure
            x_death_array.count
          end
        end
      end
    end
  end
end