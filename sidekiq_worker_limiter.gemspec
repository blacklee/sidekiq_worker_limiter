# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq_worker_limiter/version'
require 'sidekiq_worker_limiter'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq_worker_limiter'
  spec.version       = SidekiqWorkerLimiter::VERSION
  spec.authors       = ['Black Lee']
  spec.email         = ['myliltos@gmail.com']

  spec.summary       = %q{Sidekiq worker limiter}
  spec.description   = %q{SidekiqWorkerLimiter can limit the concurrency of a worker by a simple configuration}
  spec.homepage      = 'https://github.com/blacklee/sidekiq_worker_limiter'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency     'sidekiq', '>= 5.2'
end
