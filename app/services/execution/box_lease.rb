require "etc"
require "fileutils"
require "timeout"

module Execution
  class BoxLease
    class Unavailable < RuntimeError; end

    DEFAULT_POOL_SIZE = [Etc.nprocessors * 64, 1024].max
    DEFAULT_LOCK_DIR = Rails.root.join("tmp", "execution_box_locks").to_s

    attr_reader :id

    def self.with(submission_id, **options)
      lease = acquire(submission_id, **options)
      yield lease
    ensure
      lease&.release
    end

    def self.acquire(submission_id, **options)
      new(submission_id, **options).acquire
    end

    def initialize(submission_id, min_id: nil, pool_size: nil, lock_dir: nil, timeout: nil)
      @submission_id = submission_id.to_i
      @min_id = min_id || Config::EXECUTION_BOX_ID_MIN
      @pool_size = pool_size || Config::EXECUTION_BOX_POOL_SIZE
      @lock_dir = lock_dir || Config::EXECUTION_BOX_LOCK_DIR
      @timeout = timeout || Config::EXECUTION_BOX_LEASE_TIMEOUT
    end

    def acquire
      raise ArgumentError, "execution box pool size must be positive" if @pool_size <= 0

      FileUtils.mkdir_p(@lock_dir)

      Timeout.timeout(@timeout) do
        loop do
          candidate_ids.each do |candidate_id|
            lock = File.open(lock_path(candidate_id), File::RDWR | File::CREAT, 0o644)
            if lock.flock(File::LOCK_EX | File::LOCK_NB)
              @id = candidate_id
              @lock = lock
              return self
            end
            lock.close
          end

          sleep(0.01)
        end
      end
    rescue Timeout::Error
      raise Unavailable, "no execution sandbox boxes available"
    end

    def release
      return unless @lock

      @lock.flock(File::LOCK_UN)
      @lock.close
      @lock = nil
    end

    private

    def candidate_ids
      start = (@submission_id + Process.pid) % @pool_size
      @pool_size.times.lazy.map { |offset| @min_id + ((start + offset) % @pool_size) }
    end

    def lock_path(candidate_id)
      File.join(@lock_dir, "#{candidate_id}.lock")
    end
  end
end
