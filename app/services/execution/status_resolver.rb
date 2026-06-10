module Execution
  class StatusResolver
    def self.call(status:, exit_signal:, expected_output:, stdout:)
      new(status: status, exit_signal: exit_signal, expected_output: expected_output, stdout: stdout).call
    end

    def initialize(status:, exit_signal:, expected_output:, stdout:)
      @status = status
      @exit_signal = exit_signal
      @expected_output = expected_output
      @stdout = stdout
    end

    def call
      case @status
      when "TO"
        Status.tle
      when "SG"
        Status.find_runtime_error_by_status_code(@exit_signal)
      when "RE"
        Status.nzec
      when "XX"
        Status.boxerr
      else
        accepted_output? ? Status.ac : Status.wa
      end
    end

    private

    def accepted_output?
      @expected_output.nil? || strip(@expected_output) == strip(@stdout)
    end

    def strip(text)
      return nil unless text

      text.split("\n").collect(&:rstrip).join("\n").rstrip
    rescue ArgumentError
      text
    end
  end
end
