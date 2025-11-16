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

  # Create a fake config.json file for testing
  def create_fake_config(path: 'config.json', **options)
    config_data = {
      "googleClientId" => "fake_client_id",
      "googleClientSecret" => "fake_client_secret",
      "flickrDataPath" => "flickr",
      "photoCachePath" => "photo_cache",
      "importedAlbums" => [],
      "ignoredAlbums" => []
    }.merge(options)

    File.write(path, JSON.pretty_generate(config_data))
    config_data
  end

  # Create fake Flickr data directory with sample files
  def create_fake_flickr_data(path: 'flickr')
    FileUtils.mkdir_p(path)

    # Create a sample albums.json
    albums_data = {
      "albums" => [
        {
          "id" => "72157644251234567",
          "title" => "Test Album 1",
          "description" => "A test album",
          "photos" => 5
        },
        {
          "id" => "72157644251234568",
          "title" => "Test Album 2",
          "description" => "Another test album",
          "photos" => 3
        }
      ]
    }
    File.write(File.join(path, 'albums.json'), JSON.pretty_generate(albums_data))

    # Create a few sample photo files
    photo_data = {
      "id" => "1234567890",
      "title" => "Test Photo",
      "description" => "A test photo",
      "urls" => {
        "original" => "https://example.com/photo.jpg"
      }
    }
    File.write(File.join(path, 'photo_1234567890.json'), JSON.pretty_generate(photo_data))

    albums_data
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
