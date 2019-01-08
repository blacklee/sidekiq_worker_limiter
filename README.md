# Sidekiq Worker Limiter

Limit the concurrency of your Sidekiq workers to a constant by a simple config.

You may want to limit the concurrency of a worker due to following reasons:

1. it takes up a lot of resources of your system, such as CPU or memory;
2. it accesses (upload files) to extrenal website, and that website may limit your access rate;
3. it writes massive amounts of data to a single database table.

## Compatibility

Sidekiq Worker Limiter works by adding a simple middleware to the Sidekiq server middleware chain, I just tested it with Sidekiq 5.2+(5.2.1, 5.2.3). But this is very simple and it should have good compatibility with other versions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq_worker_limiter'
```

## Usage

After you starting Sidekiq server, attach Sidekiq Worker Limiter to the server middleware chain by(e.g. `config/initializers/sidekiq.rb` if you are using Rails):

```ruby
SidekiqWorkerLimiter.boot!
```

Configure a worker is simple:

```ruby
class PingWorker
  include Sidekiq::Worker
  sidekiq_options worker_limiter: {max: 1}
  def perform(*args)
  end
end
```

Then this `PingWorker` will be restricted to running **1** instance, no matter how many times you call: `PingWorker.perform_async`, and after completing a job, it will find 1 `PingWorker` job and add it to queue.

And you can change the limited value by calling `SidekiqWorkerLimiter::HelpWorkers::ChangeMaxWorker.perform_async('PingWorker', 3)`.

There're some other options in `SidekiqWorkerLimiter.boot!`, check it in [lib/sidekiq_worker_limiter.rb](lib/sidekiq_worker_limiter.rb) or [test/sidekiq_helper.rb](test/sidekiq_helper.rb).

## Tips

All the source code are extremely simple, no one file have 100+ lines, you may read it before using it.

- The default keys in `worker_limiter` option are :symbols, not strings.
- This middleware only works for 1 Sidekiq process.
- By default, if you have 10_000+ jobs in scheduled set, Sidekiq Worker Limiter will perform `SidekiqWorkerLimiter::HelpWorkers::EnqueueJobWorker` to enqueue next job.
- To speed up a kind of job execution, you may consider `SidekiqWorkerLimiter::HelpWorkers::MonitorWorkerWorker`.
- As Sidekiq Worker Limiter automatically queues new job after completing one, if you want to prevent running a job before some time, you can call `WakeupWorker.perform_after!(9.hour, "Wake up, it's 7 o'clock")`.

## Demo

run `bundler install --standalone` to install dependencies.

1. Starting server by `bundle exec sidekiq -r ./test/sidekiq_server_helper.rb`

2. Starting client to add jobs `bundle exec ruby test/sidekiq_client_helper.rb`

test workers are very simple, just sleep a random time and print log to check the `running_count` and `max_count`:
- test/workers/ping_worker.rb
- test/workers/pong_worker.rb
- test/workers/exec_then_stop_worker.rb
