# frozen_string_literal: true

# Only start SimpleCov in CI environments
if ENV['CI'] || ENV['GITHUB_ACTIONS']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'

    # Group coverage by logical sections
    add_group 'CLI', 'lib/flickr_to_google_photos/cli'
    add_group 'Flickr', 'lib/flickr_to_google_photos/flickr'
    add_group 'Google Photos', 'lib/flickr_to_google_photos/google_photos'
    add_group 'Utilities', 'lib/flickr_to_google_photos/util'
  end
end

require 'bundler/setup'
require 'rspec'
require 'webmock/rspec'
require 'tmpdir'
require 'fileutils'
require 'json'

# Require the main library
require 'flickr_to_google_photos'

# Require all support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

# Configure WebMock to disallow real HTTP requests
WebMock.disable_net_connect!

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Make sure each test starts with a clean slate
  config.before(:each) do
    FlickrToGooglePhotos.reset!
  end

  # Use around hooks to manage temporary directories
  config.around(:each) do |example|
    Dir.mktmpdir('f2gp_test') do |tmpdir|
      @tmpdir = tmpdir
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end
end

# Global helper to access tmpdir in tests
def tmpdir
  @tmpdir
end
