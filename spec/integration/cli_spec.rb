# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CLI behavior', type: :integration do
  describe 'f2gp command' do
    # Instance doubles for command classes
    let(:config_command) { instance_double(FlickrToGooglePhotos::CLI::Commands::Config) }
    let(:auth_command) { instance_double(FlickrToGooglePhotos::CLI::Commands::Auth) }
    let(:download_command) { instance_double(FlickrToGooglePhotos::CLI::Commands::Download) }
    let(:import_command) { instance_double(FlickrToGooglePhotos::CLI::Commands::Import) }
    let(:albums_command) { instance_double(FlickrToGooglePhotos::CLI::Commands::Albums) }
    let(:ignore_command) { instance_double(FlickrToGooglePhotos::CLI::Commands::Ignore) }

    # Set up constructor mocking
    before do
      allow(FlickrToGooglePhotos::CLI::Commands::Config).to receive(:new).and_return(config_command)
      allow(FlickrToGooglePhotos::CLI::Commands::Auth).to receive(:new).and_return(auth_command)
      allow(FlickrToGooglePhotos::CLI::Commands::Download).to receive(:new).and_return(download_command)
      allow(FlickrToGooglePhotos::CLI::Commands::Import).to receive(:new).and_return(import_command)
      allow(FlickrToGooglePhotos::CLI::Commands::Albums).to receive(:new).and_return(albums_command)
      allow(FlickrToGooglePhotos::CLI::Commands::Ignore).to receive(:new).and_return(ignore_command)
    end

    context 'help and usage' do
      it 'displays help when run without arguments' do
        result = run_command

        expect(result).to be_success
        expect(result.stdout).to include('FlickrToGooglePhotos - Move your Flickr photo albums into Google Photos')
        expect(result.stdout).to include('USAGE:')
        expect(result.stdout).to include('f2gp <command> [options]')
        expect(result.stdout).to include('COMMANDS:')
        expect(result.stdout).to include('config      Initialize configuration file')
        expect(result.stdout).to include('auth        Authenticate with Google Photos')
        expect(result.stdout).to include('import      Import Flickr albums to Google Photos')
        expect(result.stdout).to include('download    Download photos from Flickr albums')
        expect(result.stdout).to include('albums      List and manage Flickr albums')
        expect(result.stdout).to include('ignore      Add albums to ignore list')
      end

      it 'displays help when --help flag is used' do
        result = run_command('--help')

        expect(result).to be_success
        expect(result.stdout).to include('FlickrToGooglePhotos - Move your Flickr photo albums')
        expect(result.stdout).to include('USAGE:')
        expect(result.stdout).to include('COMMANDS:')
      end

      it 'displays help when -h flag is used' do
        result = run_command('-h')

        expect(result).to be_success
        expect(result.stdout).to include('FlickrToGooglePhotos - Move your Flickr photo albums')
        expect(result.stdout).to include('USAGE:')
      end

      it 'includes help footer with command-specific help instructions' do
        result = run_command

        expect(result).to be_success
        expect(result.stdout).to include("Run 'f2gp <command> --help' for more information about a specific command.")
      end
    end

    context 'unknown commands' do
      it 'displays error for unknown command' do
        result = run_command('nonexistent')

        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('Error: Unknown command: nonexistent')
        expect(result.stdout).to include('USAGE:')
        expect(result.stdout).to include('COMMANDS:')
      end

      it 'handles commands with special characters' do
        result = run_command('foo-bar')

        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('Error: Unknown command: foo-bar')
      end

      it 'handles empty string command' do
        result = run_command('')

        expect(result).not_to be_success
        expect(result.stdout).to include('USAGE:')
      end
    end

    context 'command routing' do
      it 'routes to config command correctly' do
        allow(config_command).to receive(:run).and_return(0)

        result = run_command('config', '--help')

        expect(result).to be_success
        expect(config_command).to have_received(:run)
      end

      it 'routes to auth command correctly' do
        allow(auth_command).to receive(:run).and_return(0)

        result = run_command('auth', '--help')

        expect(result).to be_success
        expect(auth_command).to have_received(:run)
      end

      it 'routes to download command correctly' do
        allow(download_command).to receive(:run).and_return(0)

        result = run_command('download', '--help')

        expect(result).to be_success
        expect(download_command).to have_received(:run)
      end

      it 'routes to import command correctly' do
        allow(import_command).to receive(:run).and_return(0)

        result = run_command('import', '--help')

        expect(result).to be_success
        expect(import_command).to have_received(:run)
      end

      it 'routes to albums command correctly' do
        allow(albums_command).to receive(:run).and_return(0)

        result = run_command('albums', '--help')

        expect(result).to be_success
        expect(albums_command).to have_received(:run)
      end

      it 'routes to ignore command correctly' do
        allow(ignore_command).to receive(:run).and_return(0)

        result = run_command('ignore', '--help')

        expect(result).to be_success
        expect(ignore_command).to have_received(:run)
      end
    end

    context 'command case sensitivity' do
      it 'handles capitalized commands by capitalizing internally' do
        # The CLI capitalizes the command name to find the class
        allow(config_command).to receive(:run).and_return(0)

        result = run_command('CONFIG', '--help')

        expect(result).to be_success
        expect(config_command).to have_received(:run)
      end

      it 'handles mixed case commands' do
        allow(config_command).to receive(:run).and_return(0)

        result = run_command('Config', '--help')

        expect(result).to be_success
        expect(config_command).to have_received(:run)
      end
    end

    context 'argument passing' do
      it 'passes arguments correctly to commands' do
        # Test that additional arguments are passed through
        allow(config_command).to receive(:run).and_return(0)

        result = run_command('config', '--help', 'extra_arg')

        expect(result).to be_success
        expect(config_command).to have_received(:run)
      end

      it 'handles multiple flags correctly' do
        allow(config_command).to receive(:run).and_return(0)

        result = run_command('config', '-h', '--verbose')

        expect(result).to be_success
        expect(config_command).to have_received(:run)
      end
    end
  end
end
