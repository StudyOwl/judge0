module Execution
  class Engine
    def self.call(submission_id)
      new(submission_id).call
    end

    def initialize(submission_id, command_runner: CommandRunner.new)
      @submission_id = submission_id
      @command_runner = command_runner
    end

    def call
      @submission = Submission.find(@submission_id)
      @submission.update(status: Status.process, started_at: DateTime.now, execution_host: ENV["HOSTNAME"])

      BoxLease.with(@submission.id) do |lease|
        SandboxRunner.new(@submission, lease: lease, command_runner: @command_runner).call
      end
    rescue Exception => e
      raise unless @submission

      @submission.update(message: e.message, status: Status.boxerr, finished_at: DateTime.now)
    ensure
      CallbackNotifier.new(@submission).call if @submission
    end
  end
end
