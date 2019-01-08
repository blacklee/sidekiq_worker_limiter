require_relative 'redis_cfg'

require './lib/sidekiq_worker_limiter/help_workers/monitor_worker_worker.rb'

Sidekiq::Worker::ClassMethods.include(SidekiqWorkerLimiter::WorkerClassMethods)

require_relative 'load_workers'

Thread.new do |t|
  while true
    stat = Sidekiq::ScheduledSet.new.to_a.group_by do |job|
      job.item["class"]
    end.map do |klass, array|
      {klass => array.count}
    end.sort_by do |h1|
      h1.keys[0]
    end
    puts "#{Time.now} \t #{stat}"
    sleep 1
  end
end

Thread.new do |t|
  # 1000 ping workers
  ping_count = 500
  ping_started = Time.now.to_f
  puts "#{Time.now} gen #{ping_count} count PingWorker"
  (0...ping_count).step(1).each do |i|
    if i % 111 == 0
      PingWorker.perform_async(i * rand)
    else
      PingWorker.perform_in(i * rand, i)
    end
  end

  while true
    sleep 1
    if Time.now.to_f - ping_started > ping_count * 0.5 * 0.5
      puts "There should be only a few PingWorkers left"
      break
    end
  end
end


Thread.new do |t|
  # 2500
  pong_count = 1000
  pong_started = Time.now.to_f
  puts "#{Time.now} gen #{pong_count} count PongWorker"
  (0...pong_count).step(1).each do |i|
    if i % 111 == 0
      PongWorker.perform_async(i * rand)
    else
      PongWorker.perform_in(i * rand, i)
    end
  end
  while true
    sleep 1
    if Time.now.to_f - pong_started > pong_count * 0.5 * 0.5 / PongWorker.max_count
      puts "There should be only a few PongWorkers left"
      break
    end
  end
end

Thread.new do |t|
  stop_count = 500
  stop_started = Time.now.to_f
  puts "#{Time.now} gen #{stop_count} count ExecThenStopWorker"
  (0...stop_count).step(1).each do |i|
    if i == 10
      SidekiqWorkerLimiter::HelpWorkers::MonitorWorkerWorker.perform_async('ExecThenStopWorker', 60)
    end
    if i % 111 == 0
      ExecThenStopWorker.perform_async(i * rand)
    else
      ExecThenStopWorker.perform_in(i * rand, i)
    end
  end
end

while true
  sleep 1
end
