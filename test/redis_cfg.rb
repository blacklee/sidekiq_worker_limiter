$configure_redis = proc do |config|
  config.redis = { :url => "redis://localhost/15" }
end
