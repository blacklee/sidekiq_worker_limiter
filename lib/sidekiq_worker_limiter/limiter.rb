# frozen_string_literal: true

require_relative 'help_workers/enqueue_job_worker'
require 'sidekiq/processor'

module SidekiqWorkerLimiter
  class Limiter
    def call(worker, job, queue, &block)
      limiter_options = worker.class.sidekiq_options["worker_limiter"]
      limited = determine_limited(worker, job, limiter_options)
      if !limited
        yield
      end
    ensure
      if limiter_options && !limited
        post_actions(worker, limiter_options)
      end
    end

    private
    def re_add_to_queue(worker, job)
      Sidekiq::Processor::PROCESSED.incr(-1)
      # reach max limit, re-add it to queue.
      delay = worker.class.delay_time
      # NOTE if this job comes from retry set, we just broke Sidekiq's default retry mechanism
      new_jid = worker.class.perform_in(delay, *job["args"])
      if Sidekiq.logger.debug?
        Sidekiq.logger.debug "[SidekiqWorkerLimiter::Limiter] [#{worker.jid} -> #{new_jid}] #{worker.class.to_s}.perform_in(#{delay.to_i}#{", #{job["args"].join(', ')}" if !job['args'].empty?})"
      end
      new_jid
    end
    def determine_limited(worker, job, limiter_options)
      limited = nil
      if limiter_options
        limiter_options = worker.class.sidekiq_options["default_worker_limiter"].merge(limiter_options)
        if worker.class.running_count >= limiter_options[:max]
          re_add_to_queue(worker, job)
          limited = true
        else
          increase_running(worker.class)
        end
      end
      limited
    end
    def post_actions(worker, limiter_options)
      decrease_running(worker.class)
      if !limiter_options[:stop]
        if worker.class.running_count < worker.class.sidekiq_options["worker_limiter"][:max]
          enqueue_next(worker, limiter_options)
        end
      end
    end

    def increase_running(klass)
      klass.sidekiq_options["worker_limiter"][:running] ||= 0
      klass.sidekiq_options["worker_limiter"][:running] += 1
    end
    def decrease_running(klass)
      klass.sidekiq_options["worker_limiter"][:running] -= 1
      if klass.sidekiq_options["worker_limiter"][:running] < 0
        klass.sidekiq_options["worker_limiter"][:running] = 0
      end
    end

    def enqueue_next(worker, limiter_options)
      max = limiter_options[:max] || 1
      if Sidekiq::ScheduledSet.new.size < SidekiqWorkerLimiter::HelpWorkers::EnqueueJobWorker.threshold
        HelpWorkers::EnqueueJobWorker.enqueue_next(worker.class.to_s, max)
      else
        HelpWorkers::EnqueueJobWorker.perform_async(worker.class.to_s, max)
      end
    end
  end
end
