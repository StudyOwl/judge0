require "open3"

module Execution
  class CommandRunner
    Result = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
      def success?
        status.success?
      end
    end

    def run(command, label: nil, submission: nil)
      log(command, label: label, submission: submission)

      stdout, stderr, status = Open3.capture3(command)
      warn(stderr) if stderr.present?

      Result.new(stdout: stdout, stderr: stderr, status: status)
    end

    private

    def log(command, label:, submission:)
      prefix = "[#{DateTime.now}]"
      if label && submission
        puts "#{prefix} #{label} submission #{submission.token} (#{submission.id}):"
      elsif label
        puts "#{prefix} #{label}:"
      else
        puts "#{prefix} Running command:"
      end
      puts command.gsub(/\s+/, " ")
      puts
    end
  end
end
