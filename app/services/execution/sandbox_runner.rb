require "etc"
require "fileutils"
require "shellwords"

module Execution
  class SandboxRunner
    STDIN_FILE_NAME = "stdin.txt"
    STDOUT_FILE_NAME = "stdout.txt"
    STDERR_FILE_NAME = "stderr.txt"
    METADATA_FILE_NAME = "metadata.txt"
    ADDITIONAL_FILES_ARCHIVE_FILE_NAME = "additional_files.zip"
    ENVIRONMENT_FLAGS = '-E HOME=/tmp -E PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" -E LANG -E LANGUAGE -E LC_ALL -E JUDGE0_HOMEPAGE -E JUDGE0_SOURCE_CODE -E JUDGE0_MAINTAINER -E JUDGE0_VERSION'.freeze

    def initialize(submission, lease:, command_runner: CommandRunner.new)
      @submission = submission
      @lease = lease
      @command_runner = command_runner
    end

    def call
      initialize_workspace
      return :compile_error if compile == :failure

      run_script = prepare_run_script
      times = []
      memories = []

      @submission.number_of_runs.times do |index|
        reset_runtime_files if index.positive?

        run_program(run_script)
        verify

        times << @submission.time
        memories << @submission.memory

        break unless @submission.status == Status.ac
      end

      persist_averages(times, memories)
      :ok
    ensure
      cleanup if @workdir
    end

    private

    attr_reader :box_id, :workdir, :boxdir, :tmpdir, :source_file,
                :stdin_file, :stdout_file, :stderr_file, :metadata_file,
                :additional_files_archive_file

    def initialize_workspace
      @box_id = @lease.id
      @cgroups = (!@submission.enable_per_process_and_thread_time_limit || !@submission.enable_per_process_and_thread_memory_limit) ? "--cg" : ""
      @workdir = @command_runner.run("isolate #{cgroups} -b #{box_id} --init", label: "Initializing sandbox", submission: @submission).stdout.chomp
      @boxdir = File.join(workdir, "box")
      @tmpdir = File.join(workdir, "tmp")
      @source_file = File.join(boxdir, @submission.language.source_file.to_s)
      @stdin_file = File.join(workdir, STDIN_FILE_NAME)
      @stdout_file = File.join(workdir, STDOUT_FILE_NAME)
      @stderr_file = File.join(workdir, STDERR_FILE_NAME)
      @metadata_file = File.join(workdir, METADATA_FILE_NAME)
      @additional_files_archive_file = File.join(boxdir, ADDITIONAL_FILES_ARCHIVE_FILE_NAME)

      [stdin_file, stdout_file, stderr_file, metadata_file].each { |file| ensure_writable_file(file) }

      write_file(source_file, @submission.source_code) unless @submission.is_project
      write_file(stdin_file, @submission.stdin)

      extract_archive
    end

    def extract_archive
      return unless @submission.additional_files?

      write_file(additional_files_archive_file, @submission.additional_files)

      command = "isolate #{cgroups} " \
                "-s " \
                "-b #{box_id} " \
                "--stderr-to-stdout " \
                "-t 2 " \
                "-x 1 " \
                "-w 4 " \
                "-k #{Config::MAX_STACK_LIMIT} " \
                "-p#{Config::MAX_MAX_PROCESSES_AND_OR_THREADS} " \
                "#{timing_option} " \
                "#{memory_option(Config::MAX_MEMORY_LIMIT)} " \
                "-f #{Config::MAX_EXTRACT_SIZE} " \
                "--run " \
                "-- /usr/bin/unzip -n -qq #{ADDITIONAL_FILES_ARCHIVE_FILE_NAME}"

      @command_runner.run(command, label: "Extracting archive", submission: @submission)
      FileUtils.rm_f(additional_files_archive_file)
    end

    def compile
      return :success if !@submission.is_project && @submission.language.compile_cmd.blank?

      compile_script = compile_script_path
      return :success unless compile_script

      compile_output_file = File.join(workdir, "compile_output.txt")
      ensure_writable_file(compile_output_file)

      command = "isolate #{cgroups} " \
                "-s " \
                "-b #{box_id} " \
                "-M #{sh(metadata_file)} " \
                "--stderr-to-stdout " \
                "-i /dev/null " \
                "-t #{Config::MAX_CPU_TIME_LIMIT} " \
                "-x 0 " \
                "-w #{Config::MAX_WALL_TIME_LIMIT} " \
                "-k #{Config::MAX_STACK_LIMIT} " \
                "-p#{Config::MAX_MAX_PROCESSES_AND_OR_THREADS} " \
                "#{timing_option} " \
                "#{memory_option(Config::MAX_MEMORY_LIMIT)} " \
                "-f #{Config::MAX_MAX_FILE_SIZE} " \
                "#{ENVIRONMENT_FLAGS} " \
                "-d /etc:noexec " \
                "--run " \
                "-- /bin/bash #{sh(File.basename(compile_script))} > #{sh(compile_output_file)}"

      result = @command_runner.run(command, label: "Compiling", submission: @submission)
      compile_output = read_optional_file(compile_output_file)
      @submission.compile_output = compile_output.presence

      metadata = get_metadata
      reset_metadata_file
      cleanup_compile_files(compile_script, compile_output_file)

      return :success if result.success?

      @submission.compile_output = "Compilation time limit exceeded." if metadata[:status] == "TO"
      mark_compilation_error
      :failure
    end

    def compile_script_path
      if @submission.is_project
        [File.join(boxdir, "compile.sh"), File.join(boxdir, "compile")].find { |path| File.file?(path) }
      else
        compile_script = File.join(boxdir, "compile.sh")
        compiler_options = sanitized_argument(@submission.compiler_options)
        write_file(compile_script, @submission.language.compile_cmd % compiler_options, mode: "w")
        compile_script
      end
    end

    def cleanup_compile_files(compile_script, compile_output_file)
      files = [compile_output_file]
      files << compile_script unless @submission.is_project
      safe_remove(*files)
    end

    def prepare_run_script
      run_script = if @submission.is_project
        [File.join(boxdir, "run.sh"), File.join(boxdir, "run")].find { |path| File.file?(path) } || File.join(boxdir, "run.sh")
      else
        File.join(boxdir, "run.sh")
      end

      unless @submission.is_project
        command_line_arguments = sanitized_argument(@submission.command_line_arguments)
        write_file(run_script, "#{@submission.language.run_cmd} #{command_line_arguments}", mode: "w")
      end

      run_script
    end

    def run_program(run_script)
      command = "isolate #{cgroups} " \
                "-s " \
                "-b #{box_id} " \
                "-M #{sh(metadata_file)} " \
                "#{@submission.redirect_stderr_to_stdout ? "--stderr-to-stdout" : ""} " \
                "#{@submission.enable_network ? "--share-net" : ""} " \
                "-t #{@submission.cpu_time_limit} " \
                "-x #{@submission.cpu_extra_time} " \
                "-w #{@submission.wall_time_limit} " \
                "-k #{@submission.stack_limit} " \
                "-p#{@submission.max_processes_and_or_threads} " \
                "#{timing_option} " \
                "#{memory_option(@submission.memory_limit)} " \
                "-f #{@submission.max_file_size} " \
                "#{ENVIRONMENT_FLAGS} " \
                "-d /etc:noexec " \
                "--run " \
                "-- /bin/bash #{sh(File.basename(run_script))} " \
                "< #{sh(stdin_file)} > #{sh(stdout_file)} 2> #{sh(stderr_file)}"

      @command_runner.run(command, label: "Running", submission: @submission)
    end

    def verify
      @submission.finished_at = DateTime.now

      metadata = get_metadata
      program_stdout = read_optional_file(stdout_file).presence
      program_stderr = read_optional_file(stderr_file).presence

      @submission.time = metadata[:time]
      @submission.wall_time = metadata[:"time-wall"]
      @submission.memory = cgroups.present? ? metadata[:"cg-mem"] : metadata[:"max-rss"]
      @submission.stdout = program_stdout
      @submission.stderr = program_stderr
      @submission.exit_code = metadata[:exitcode].try(:to_i) || 0
      @submission.exit_signal = metadata[:exitsig].try(:to_i)
      @submission.message = metadata[:message]
      @submission.status = StatusResolver.call(
        status: metadata[:status],
        exit_signal: @submission.exit_signal,
        expected_output: @submission.expected_output,
        stdout: @submission.stdout
      )

      if @submission.status == Status.boxerr &&
         (
           @submission.message.to_s.match(/^execve\(.+\): Exec format error$/) ||
           @submission.message.to_s.match(/^execve\(.+\): No such file or directory$/) ||
           @submission.message.to_s.match(/^execve\(.+\): Permission denied$/)
         )
        @submission.status = Status.exeerr
      end
    end

    def persist_averages(times, memories)
      @submission.time = average(times)
      @submission.memory = average(memories)&.round
      @submission.save
    end

    def mark_compilation_error
      @submission.finished_at = DateTime.now
      @submission.time = nil
      @submission.wall_time = nil
      @submission.memory = nil
      @submission.stdout = nil
      @submission.stderr = nil
      @submission.exit_code = nil
      @submission.exit_signal = nil
      @submission.message = nil
      @submission.status = Status.ce
      @submission.save
    end

    def reset_runtime_files
      safe_remove(stdout_file, stderr_file, metadata_file)
      [stdout_file, stderr_file, metadata_file].each { |file| ensure_writable_file(file) }
    end

    def reset_metadata_file
      safe_remove(metadata_file)
      ensure_writable_file(metadata_file)
    end

    def cleanup
      fix_permissions
      safe_remove(shell_glob(boxdir), shell_glob(tmpdir), stdin_file, stdout_file, stderr_file, metadata_file)
      @command_runner.run("isolate #{cgroups} -b #{box_id} --cleanup", label: "Cleaning sandbox", submission: @submission)
      raise "Cleanup of sandbox #{box_id} failed." if Dir.exist?(workdir)
    end

    def fix_permissions
      @command_runner.run("sudo chown -R #{sh(current_user)}: #{sh(boxdir)}", label: "Fixing sandbox permissions", submission: @submission)
    end

    def safe_remove(*targets)
      compact_targets = targets.compact
      return if compact_targets.empty?

      escaped_targets = compact_targets.map { |target| target.to_s.end_with?("/*") ? target : sh(target) }
      @command_runner.run("sudo rm -rf #{escaped_targets.join(" ")}", label: "Removing sandbox files", submission: @submission)
    end

    def ensure_writable_file(file)
      FileUtils.touch(file)
    rescue SystemCallError
      @command_runner.run("sudo touch #{sh(file)} && sudo chown #{sh(current_user)}: #{sh(file)}", label: "Creating sandbox file", submission: @submission)
    end

    def write_file(file, content, mode: "wb")
      File.open(file, mode) { |f| f.write(content.to_s) }
    end

    def read_optional_file(file)
      return "" unless File.exist?(file)

      File.read(file)
    end

    def get_metadata
      read_optional_file(metadata_file).split("\n").collect do |entry|
        key, *value = entry.split(":")
        { key.to_sym => value.join(":") }
      end.reduce({}, :merge)
    end

    def sanitized_argument(value)
      value.to_s.strip.encode("UTF-8", invalid: :replace).gsub(/[$&;<>|`]/, "")
    end

    def timing_option
      @submission.enable_per_process_and_thread_time_limit ? (cgroups.present? ? "--no-cg-timing" : "") : "--cg-timing"
    end

    def memory_option(limit)
      "#{@submission.enable_per_process_and_thread_memory_limit ? "-m " : "--cg-mem="}#{limit}"
    end

    def cgroups
      @cgroups
    end

    def average(values)
      numeric_values = values.compact.map(&:to_f)
      return nil if numeric_values.empty?

      numeric_values.inject(&:+) / numeric_values.size
    end

    def current_user
      @current_user ||= Etc.getpwuid(Process.uid).name
    end

    def shell_glob(path)
      "#{sh(path)}/*"
    end

    def sh(value)
      Shellwords.escape(value.to_s)
    end
  end
end
