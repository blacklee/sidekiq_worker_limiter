# frozen_string_literal: true

module SidekiqWorkerLimiter
  module GetJobs
    def get_jobs(klass, exclude_jids, count)
      page_size = count * 30
      page = -1
      offset_size = 0

      jobs = []
      Sidekiq.redis do |conn|
        while true
          range_start = page * page_size + offset_size
          range_end   = range_start + page_size - 1
          elements = conn.zrange("schedule", range_start, range_end, with_scores: true)
          break if elements.empty?
          elements.each do |element, score|
            if element.index(klass)
              message = Sidekiq.load_json(element)
              if message["class"] == klass && !exclude_jids.index(message["jid"])
                jobs << Sidekiq::SortedEntry.new(self, score, element)
                break if jobs.count >= count
              end
            end
          end
          break if jobs.count >= count
          page += 1
        end
      end
      jobs
    end
  end
end
