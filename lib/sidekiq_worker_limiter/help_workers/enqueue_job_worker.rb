# frozen_string_literal: true

module SidekiqWorkerLimiter
  module HelpWorkers
    class EnqueueJobWorker
      include Sidekiq::Worker
      sidekiq_options retry: false

      @@threshold = 10_000
      def self.threshold
        @@threshold
      end
      def self.threshold=(t)
        @@threshold = t
      end
 
      def perform(klass_name, max)
        self.class.enqueue_next(klass_name, max)
      end
 
      # TODO we just find job in scheduled-set, so jobs in the retry-set may be forgetten, how to avoid this?
      def self.enqueue_next(klass_name, max)
        excludes = []
        Sidekiq.redis do |conn|
          passed = []
          now = Time.now.to_i
          conn.hgetall("SidekiqWorkerLimiter:PerformAfter:#{klass_name}").each_pair do |jid, time|
            if time.to_i > now
              excludes << jid
            else
              passed << jid
            end
          end
          passed.each do |jid|
            if !excludes.empty?
              Sidekiq.logger.debug "[SidekiqWorkerLimiter] delete from redis hash [#{jid}]"
            end
            conn.hdel("SidekiqWorkerLimiter:PerformAfter:#{klass_name}", jid)
          end
        end
        if !excludes.empty? && Sidekiq.logger.debug?
          Sidekiq.logger.debug "[SidekiqWorkerLimiter] ignore [#{excludes.join(', ')}]"
        end
 
        # if a worker allows 2+ concurrency, and we just simply fetch the first job,
        # then multi jobs may get the same job if they reach here in the same time.
        # what we can do is decrease this probability by providing a random job from multi jobs
        count = max == 1 ? max : max * 2
        klass = SidekiqWorkerLimiter.constantize(klass_name)
        job = Sidekiq::ScheduledSet.new.get_jobs(klass_name, excludes, count).sample
        if job
          if Sidekiq.logger.debug?
            Sidekiq.logger.debug "[SidekiqWorkerLimiter] ADD TO QUEUE: #{klass_name} JID:#{job.item['jid']}"
          end
          job.add_to_queue
        end
      end
    end
  end
end
