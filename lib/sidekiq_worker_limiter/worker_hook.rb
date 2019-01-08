# frozen_string_literal: true

module SidekiqWorkerLimiter
  class WorkerHook
    @@prefix = nil
    def self.prefix=(p)
      @@prefix = p
    end

    def call(worker, job, queue, &block)
      if worker.respond_to?("#{@@prefix}before_perform")
        worker.send("#{@@prefix}before_perform", *job['args'])
      end
      
      yield

      if worker.respond_to?("#{@@prefix}after_perform")
        worker.send("#{@@prefix}after_perform", *job['args'])
      end
    end
  end
end
