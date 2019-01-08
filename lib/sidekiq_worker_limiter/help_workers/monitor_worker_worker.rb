# frozen_string_literal: true

module SidekiqWorkerLimiter
  module HelpWorkers
    class MonitorWorkerWorker
      include Sidekiq::Worker
      sidekiq_options retry: false
 
      def sk_process
        Sidekiq::ProcessSet.new.to_a.select {|pro| pro["pid"] == $$}.first
      end
 
      def perform(klass_name, interval)
        Sidekiq::ScheduledSet.new.entries.select do |job|
          job.item['class'] == self.class.to_s && job.item['args'][0] == klass_name
        end.each do |job|
          job.delete
        end
        self.class.perform_in(interval, klass_name, interval)
 
        started = Time.now.to_f
        stop_at = started + interval - 5
        klass = SidekiqWorkerLimiter.constantize(klass_name)
        if !klass.limiter_options[:stop]
          raise "When using SidekiqWorkerLimiter::HelpWorkers::MonitorWorkerWorker to add new jobs to queue, you must set worker_limiter: {stop: true} to prevent SidekiqWorkerLimiter::Limiter from adding new job."
        end
        max = klass.limiter_options[:max] || 1
        count = 0
        Sidekiq::ScheduledSet.new.entries.each do |job|
          if job.item["class"] == klass_name
            while klass.running_count >= max
              sleep 0.05
              break if Time.now.to_f > stop_at
              break if sk_process.stopping?
            end
            break if sk_process.stopping?
            if Sidekiq.logger.debug?
              Sidekiq.logger.debug "[SidekiqWorkerLimiter::HelpWorkers::MonitorWorkerWorker] add #{klass_name} JID-#{job.jid} to queue"
            end
            job.add_to_queue
            count += 1
            sleep 0.01
          end
          break if Time.now.to_f > stop_at
          break if sk_process.stopping?
        end
        Sidekiq.logger.info("add [#{count}] #{klass} to queue")
      end
    end
  end
end
