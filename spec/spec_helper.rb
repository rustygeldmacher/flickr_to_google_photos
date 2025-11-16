# frozen_string_literal: true

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

  # Use around hooks to manage temporary directories
  config.around(:each) do |example|
    Dir.mktmpdir('f2gp_test') do |tmpdir|
      @tmpdir = tmpdir
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  # Helper method to access the temporary directory
  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true if meta[:type] == :integration
  end
end

# Global helper to access tmpdir in tests
def tmpdir
  @tmpdir
end
