# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'download command', type: :integration do
  describe 'f2gp download' do
    before do
      # Create a basic config file
      create_fake_config(
        "googleClientId" => "test_client_id",
        "googleClientSecret" => "test_client_secret",
        "flickrDataPath" => "flickr",
        "photoCachePath" => "photo_cache",
        "importedAlbums" => [],
        "ignoredAlbums" => []
      )

      # Create fake Flickr data for download tests
      create_fake_flickr_data_for_download_tests

      # Mock HTTP requests to avoid actual network calls
      allow(Net::HTTP).to receive(:get).and_return("fake image data")
    end

    context 'help option' do
      it 'displays help message with --help' do
        result = run_command('download', '--help')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
        expect(result.stdout).to include('--album ALBUM_NAME')
        expect(result.stdout).to include('-h, --help')
      end

      it 'displays help message with -h' do
        result = run_command('download', '-h')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
      end
    end

    context 'missing required parameters' do
      it 'returns error when --album is not provided' do
        result = run_command('download')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('Please specify an album to download')
      end
    end

    context 'album not found' do
      it 'returns error when album does not exist' do
        result = run_command('download', '--album', 'Nonexistent Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('Cannot find album: Nonexistent Album')
      end
    end

    context 'successfully downloading albums' do
      it 'downloads album by name' do
        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).to be_success
        expect(result.stdout).to include('Downloading album: Test Album with Photos')
        expect(result.stdout).to include('Downloading 3 photos...')

        # Verify photos were downloaded to cache
        expect(File.exist?('photo_cache/72157644251234567/test_photo_123.jpg')).to be true
        expect(File.exist?('photo_cache/72157644251234567/test_photo_456.jpg')).to be true
        expect(File.exist?('photo_cache/72157644251234567/test_photo_789.jpg')).to be true
      end

      it 'downloads album by ID' do
        result = run_command('download', '--album', '72157644251234567')

        expect(result).to be_success
        expect(result.stdout).to include('Downloading album: Test Album with Photos')
        expect(result.stdout).to include('Downloading 3 photos...')

        # Verify photos were downloaded to cache
        expect(File.exist?('photo_cache/72157644251234567/test_photo_123.jpg')).to be true
        expect(File.exist?('photo_cache/72157644251234567/test_photo_456.jpg')).to be true
        expect(File.exist?('photo_cache/72157644251234567/test_photo_789.jpg')).to be true
      end
    end

    context 'already downloaded photos' do
      before do
        # Pre-create cache directory and some photos
        FileUtils.mkdir_p('photo_cache/72157644251234567')
        File.write('photo_cache/72157644251234567/test_photo_123.jpg', 'existing photo data')
        File.write('photo_cache/72157644251234567/test_photo_456.jpg', 'existing photo data')
      end

      it 'skips already downloaded photos and downloads remaining ones' do
        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).to be_success
        expect(result.stdout).to include('Downloading album: Test Album with Photos')
        expect(result.stdout).to include('Downloading 3 photos...')

        # Verify only the missing photo was downloaded (HTTP.get called once)
        expect(Net::HTTP).to have_received(:get).once
        expect(File.exist?('photo_cache/72157644251234567/test_photo_789.jpg')).to be true
      end

      it 'displays success message when all photos are already downloaded' do
        # Download the remaining photo
        File.write('photo_cache/72157644251234567/test_photo_789.jpg', 'existing photo data')

        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).to be_success
        expect(result.stdout).to include('Downloading album: Test Album with Photos')
        expect(result.stdout).to include('✓ All photos are already downloaded.')

        # Verify no HTTP requests were made
        expect(Net::HTTP).not_to have_received(:get)
      end
    end

    context 'empty albums' do
      it 'handles album with no photos gracefully' do
        result = run_command('download', '--album', 'Empty Album')

        expect(result).to be_success
        expect(result.stdout).to include('Downloading album: Empty Album')
        expect(result.stdout).to include('✓ All photos are already downloaded.')

        # Verify cache directory was still created
        expect(Dir.exist?('photo_cache/72157644251234568')).to be true
      end
    end

    context 'error handling' do
      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf('flickr')

        result = run_command('download', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Configuration file not found")
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f('flickr/albums.json')

        result = run_command('download', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Configuration file not found")
      end

      it 'handles malformed albums.json gracefully' do
        File.write('flickr/albums.json', '{"invalid": json}')

        result = run_command('download', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Invalid configuration file")
      end

      it 'handles missing photo JSON files gracefully' do
        FileUtils.rm_f('flickr/photo_123.json')

        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles network errors during download' do
        allow(Net::HTTP).to receive(:get).and_raise(StandardError, 'Network error')

        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles permission errors with cache directory' do
        # Create cache directory with no write permissions
        FileUtils.mkdir_p('photo_cache')
        File.chmod(0444, 'photo_cache')

        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      ensure
        # Restore permissions for cleanup
        File.chmod(0755, 'photo_cache') if Dir.exist?('photo_cache')
      end
    end

    context 'config file handling' do
      it 'creates cache directory based on config path' do
        create_fake_config("photoCachePath" => "custom_cache")

        result = run_command('download', '--album', 'Test Album with Photos')

        expect(result).to be_success
        expect(Dir.exist?('custom_cache')).to be true
        expect(Dir.exist?('custom_cache/72157644251234567')).to be true
        expect(File.exist?('custom_cache/72157644251234567/test_photo_123.jpg')).to be true
      end
    end
  end

  private

  def create_fake_flickr_data_for_download_tests
    FileUtils.mkdir_p('flickr')

    # Create individual photo JSON files
    photo_data = [
      { id: '123', name: 'test_photo_123', url: 'https://example.com/photo_123.jpg' },
      { id: '456', name: 'test_photo_456', url: 'https://example.com/photo_456.jpg' },
      { id: '789', name: 'test_photo_789', url: 'https://example.com/photo_789.jpg' }
    ]

    photo_data.each do |photo|
      photo_json = {
        "id" => photo[:id],
        "name" => photo[:name],
        "description" => "A test photo",
        "original" => photo[:url]
      }
      File.write("flickr/photo_#{photo[:id]}.json", JSON.pretty_generate(photo_json))
    end

    # Create albums.json with albums containing photo ID strings (not objects)
    albums_data = {
      "albums" => [
        {
          "id" => "72157644251234567",
          "title" => "Test Album with Photos",
          "description" => "An album with photos for download testing",
          "photos" => ["123", "456", "789"]
        },
        {
          "id" => "72157644251234568",
          "title" => "Empty Album",
          "description" => "An album with no photos",
          "photos" => []
        }
      ]
    }

    File.write('flickr/albums.json', JSON.pretty_generate(albums_data))
  end
end
