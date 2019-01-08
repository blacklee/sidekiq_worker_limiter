# frozen_string_literal: true

module SidekiqWorkerLimiter
  module WorkerClassMethods
    def delay_time
      delay = self.limiter_options[:delay] || 60
      delay * (1 + 0.1 * rand())
    end

    def limiter_options
      sidekiq_options["default_worker_limiter"].merge(sidekiq_options["worker_limiter"])
    end

    def running_count
      if !sidekiq_options['worker_limiter']
        raise "#{self.to_s} is not configured with worker_limiter"
      end
      sidekiq_options['worker_limiter'][:running] || 0
    end
    def max_count
      if !sidekiq_options['worker_limiter']
        raise "#{self.to_s} is not configured with worker_limiter"
      end
      sidekiq_options['worker_limiter'][:max] || 1
    end

    def perform_after!(time, *args)
      jid = perform_in(time, *args)
      Sidekiq.redis do |conn|
        # consume this in help_workers/enqueue_job_worker.rb#L27
        key = "SidekiqWorkerLimiter:PerformAfter:#{self.to_s}"
        conn.hset(key, jid, Time.now.to_i + time)
        conn.expire(key, [time, conn.ttl(key)].max)
      end
      jid
    end
  end
end
