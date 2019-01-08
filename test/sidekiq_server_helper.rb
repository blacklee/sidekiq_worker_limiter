require_relative 'redis_cfg'

Sidekiq.configure_server(&$configure_redis)

Sidekiq.redis do |conn|
  if conn.dbsize > 0
    STDERR.puts "redis is not empty(#{conn.dbsize} items in it), you should use an empty redis db to run test."
    exit 1 # comment this if you have confidence
  end
end

puts "SidekiqWorkerLimiter::VERSION => #{SidekiqWorkerLimiter::VERSION}"

SidekiqWorkerLimiter.boot!(custom_enq: true, hook_prefix: nil, enqueue_job_worker_threshold: 1500)

require_relative 'load_workers'

require './lib/sidekiq_worker_limiter/help_workers/monitor_worker_worker.rb'

#Sidekiq::Logging.logger.level = 0

