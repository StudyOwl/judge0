class IsolateJob < ApplicationJob
  retry_on RuntimeError, wait: 0.1.seconds, attempts: 100

  queue_as ENV["JUDGE0_VERSION"].to_sym

  def perform(submission_id)
    Execution::Engine.call(submission_id)
  end
end
