# frozen_string_literal: true

require 'stringio'
require 'ostruct'

module CLIHelpers
  # Run a CLI command and capture its output and exit code
  def run_command(*args)
    original_stdout = $stdout
    original_stderr = $stderr
    original_stdin = $stdin

    stdout = StringIO.new
    def stdout.ioctl(*args); 100; end

    stderr = StringIO.new
    stdin = StringIO.new

    $stdout = stdout
    $stderr = stderr
    $stdin = stdin

    exit_code = begin
      cli = FlickrToGooglePhotos::CLI.new
      cli.start(args.flatten.map(&:to_s))
    rescue SystemExit => e
      e.status
    rescue => e
      # Print the error to stderr for debugging
      stderr.puts "Error: #{e.class}: #{e.message}"
      stderr.puts e.backtrace.join("\n")
      1
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
      $stdin = original_stdin
    end

    OpenStruct.new(
      stdout: stdout.string,
      stderr: stderr.string,
      exit_code: exit_code || 0,
      success?: (exit_code || 0) == 0
    )
  end

  # Mock user input for interactive commands
  def with_user_input(*inputs)
    original_stdin = $stdin
    $stdin = StringIO.new(inputs.join("\n") + "\n")
    yield
  ensure
    $stdin = original_stdin
  end

  # Mock gets for interactive input
  def mock_gets_with(*responses)
    responses_queue = responses.dup
    allow_any_instance_of(Object).to receive(:gets) do
      response = responses_queue.shift
      raise "No more mocked responses available" if response.nil?
      "#{response}\n"
    end
  end
end

RSpec.configure do |config|
  config.include CLIHelpers
end
