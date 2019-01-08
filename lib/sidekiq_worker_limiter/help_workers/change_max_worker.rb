# frozen_string_literal: true

module SidekiqWorkerLimiter
  module HelpWorkers
    class ChangeMaxWorker
      include Sidekiq::Worker
      sidekiq_options retry: false

      def perform(klass_name, max)
        if !max.is_a?(Integer)
          raise "Error params of max, class=#{max.class}, max=[#{max}]"
        end
        klass = SidekiqWorkerLimiter.constantize(klass_name)
        if klass.sidekiq_options["worker_limiter"]
          logger.info("change #{klass_name}.worker_limiter[:max], #{klass.sidekiq_options["worker_limiter"][:max]} -> #{max}")
          klass.sidekiq_options["worker_limiter"][:max] = max
        end
      end
    end
  end
end
