# frozen_string_literal: true

module SidekiqWorkerLimiter
  class Enq
    def enqueue_jobs(now=Time.now.to_f.to_s, sorted_sets=Sidekiq::Scheduled::SETS)
      # A job's "score" in Redis is the time at which it should be processed.
      # Just check Redis for the set of jobs with a timestamp before now.
      Sidekiq.redis do |conn|
        sorted_sets.each do |sorted_set|
          # Get the next item in the queue if it's score (time to execute) is <= now.
          # We need to go through the list one at a time to reduce the risk of something
          # going wrong between the time jobs are popped from the scheduled queue and when
          # they are pushed onto a work queue and losing the jobs.
          while job = conn.zrangebyscore(sorted_set, '-inf'.freeze, now, :limit => [0, 1]).first do
            hash = JSON.parse(job)
            klass = SidekiqWorkerLimiter.constantize(hash['class'])
            # it's good that we can intercept the worker before initialize a worker instance
            if limiter_options = klass.sidekiq_options["worker_limiter"]
              limiter_options = klass.sidekiq_options["default_worker_limiter"].merge(limiter_options)
              if klass.running_count >= limiter_options[:max]
                delay = sorted_set == 'retry' ? 60 : klass.delay_time # prioritize the retry set
                conn.zadd(sorted_set, [Time.now.to_i + delay, job])
                if Sidekiq::Logging.logger.debug?
                  Sidekiq::Logging.logger.debug "[SidekiqWorkerLimiter::Enq] #{klass.to_s} reach limit [#{limiter_options[:running]} >= #{limiter_options[:max]}] -> perform_in(#{delay.to_i}#{hash['args'].empty? ? nil : ", #{hash["args"].inspect}" })"
                end
                next
              end
            end

            # Pop item off the queue and add it to the work queue. If the job can't be popped from
            # the queue, it's because another process already popped it so we can move on to the
            # next one.
            if conn.zrem(sorted_set, job)
              Sidekiq::Client.push(hash)
              #Sidekiq::Logging.logger.debug { "enqueued #{sorted_set}: #{job}" }
            end
          end
        end
      end
    end
  end  
end

