class PongWorker
  include Sidekiq::Worker
  sidekiq_options worker_limiter: {max: 5}

  def perform(t)
    sleep 0.5 * rand
    logger.info("\t\t\t#{self.class.to_s} running:#{self.class.running_count.to_s * 8}, max:#{self.class.max_count.to_s * 8}")
  end
end
