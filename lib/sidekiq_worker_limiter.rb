# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/api'

require_relative 'sidekiq_worker_limiter/limiter'
require_relative 'sidekiq_worker_limiter/scheduled'
require_relative 'sidekiq_worker_limiter/worker_class_methods'
require_relative 'sidekiq_worker_limiter/worker_hook'
require_relative 'sidekiq_worker_limiter/get_jobs'
require_relative 'sidekiq_worker_limiter/help_workers/change_max_worker'

module SidekiqWorkerLimiter
  def self.boot!(custom_enq: false, hook: true, hook_prefix: "wl_", enqueue_job_worker_threshold: 10_000)
    if custom_enq
      Sidekiq.logger.warn "use SidekiqWorkerLimiter::Enq"
      Sidekiq.options[:scheduled_enq] = SidekiqWorkerLimiter::Enq
    end

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        Sidekiq.logger.info "add SidekiqWorkerLimiter::Limiter to Server Middleware"
        chain.add SidekiqWorkerLimiter::Limiter

        if hook
          Sidekiq.logger.info "add SidekiqWorkerLimiter::WorkerHook to Server Middleware"
          chain.add SidekiqWorkerLimiter::WorkerHook
          SidekiqWorkerLimiter::WorkerHook.prefix = hook_prefix
        end
      end
    end

    Sidekiq::Worker::ClassMethods.include(SidekiqWorkerLimiter::WorkerClassMethods)
    # there're 3 default options and 1 runtime option:
    #   - stop -> nil, set to true if you don't want to enqueue another job after completing one
    #   - delay -> 12 hour, it's a long time but it doesn't matter, because we have other mechanism to add the delayed job to the queue, this option work in 2 places:
    #         1. if you enabled the `custom_enq` option, see sidekiq_worker_limiter/scheduled.rb#L17
    #         2. it always works when you trying to execute a worker that exceed the `max` limit, see sidekiq_worker_limiter/limiter.rb#L24
    #   - max -> 1, limitation of a worker
    #   - *running*, runtime option: the number of the running workers of this worker class
    Sidekiq.default_worker_options = Sidekiq.default_worker_options.merge(default_worker_limiter: {stop: nil, delay: 3600 * 12, max: 1})
    SidekiqWorkerLimiter::HelpWorkers::EnqueueJobWorker.threshold = enqueue_job_worker_threshold
    Sidekiq::ScheduledSet.include(SidekiqWorkerLimiter::GetJobs)
  end

  # copy from sidekiq/processor.rb
  def self.constantize(str)
    names = str.split('::')
    names.shift if names.empty? || names.first.empty?

    names.inject(Object) do |constant, name|
      # the false flag limits search for name to under the constant namespace
      #   which mimics Rails' behaviour
      constant.const_defined?(name, false) ? constant.const_get(name, false) : constant.const_missing(name)
    end
  end
end
