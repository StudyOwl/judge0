require "rails_helper"
require "tmpdir"

RSpec.describe Execution::BoxLease do
  it "leases unique boxes from the configured pool" do
    Dir.mktmpdir do |lock_dir|
      first = described_class.acquire(1, min_id: 10, pool_size: 2, lock_dir: lock_dir, timeout: 0.1)
      second = described_class.acquire(2, min_id: 10, pool_size: 2, lock_dir: lock_dir, timeout: 0.1)

      expect([first.id, second.id]).to contain_exactly(10, 11)
    ensure
      first&.release
      second&.release
    end
  end

  it "raises when the pool is exhausted" do
    Dir.mktmpdir do |lock_dir|
      lease = described_class.acquire(1, min_id: 20, pool_size: 1, lock_dir: lock_dir, timeout: 0.1)

      expect {
        described_class.acquire(2, min_id: 20, pool_size: 1, lock_dir: lock_dir, timeout: 0.01)
      }.to raise_error(Execution::BoxLease::Unavailable)
    ensure
      lease&.release
    end
  end
end
