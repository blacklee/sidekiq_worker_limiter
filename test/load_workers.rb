require_relative 'redis_cfg'

Sidekiq.configure_client(&$configure_redis)

WORKERS = File.join(File.dirname(__FILE__), 'workers')
Dir[WORKERS + "/*.rb"].each {|f| require f}
