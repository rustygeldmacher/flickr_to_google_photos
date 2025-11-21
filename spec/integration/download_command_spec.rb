# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'download command', type: :integration do
  include_context "fixtures"

  # From the fixtures
  let(:album) { album_remaining_1 }
  let(:photos) { album["photos"]}

  describe 'f2gp download' do
    before do
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
      before do
        FileUtils.rm_rf(photo_cache_path)
      end

      it 'downloads album by name' do
        result = run_command('download', '--album', album["title"])

        expect(result).to be_success
        expect(result.stdout).to include("Downloading album: #{album["title"]}")
        expect(result.stdout).to include("Downloading #{photos.size} photos...")

        # Verify photos were downloaded to cache
        photos.each do |photo|
          expected_path = File.join(photo_cache_path, album["id"], photo["name"]) + ".jpg"
          expect(File.exist?(expected_path)).to be true
        end
      end

      it 'downloads album by ID' do
        result = run_command('download', '--album', album["id"])

        expect(result).to be_success
        expect(result.stdout).to include("Downloading album: #{album["title"]}")
        expect(result.stdout).to include("Downloading #{photos.size} photos...")

        # Verify photos were downloaded to cache
        photos.each do |photo|
          expected_path = File.join(photo_cache_path, album["id"], photo["name"]) + ".jpg"
          expect(File.exist?(expected_path)).to be true
        end
      end
    end

    context 'already downloaded photos' do
      it 'skips already downloaded photos and downloads remaining ones' do
        # Remove a photo from the downloads
        photo_path = File.join(photo_cache_path, album["id"], album["photos"][1]["name"]) + ".jpg"
        FileUtils.rm(photo_path)

        result = run_command('download', '--album', album["title"])

        expect(result).to be_success
        expect(result.stdout).to include("Downloading album: #{album["title"]}")
        expect(result.stdout).to include('Downloading 3 photos...')

        # Verify only the missing photo was downloaded (HTTP.get called once)
        expect(Net::HTTP).to have_received(:get).once

        # Verify photos were downloaded to cache
        photos.each do |photo|
          expected_path = File.join(photo_cache_path, album["id"], photo["name"]) + ".jpg"
          expect(File.exist?(expected_path)).to be true
        end
      end

      it 'displays success message when all photos are already downloaded' do
        result = run_command('download', '--album', album["title"])

        expect(result).to be_success
        expect(result.stdout).to include("Downloading album: #{album["title"]}")
        expect(result.stdout).to include('✓ All photos are already downloaded.')

        # Verify no HTTP requests were made
        expect(Net::HTTP).not_to have_received(:get)
      end
    end

    context 'empty albums' do
      let(:empty_album) do
        album = album_remaining_1.dup
        album["title"] = "Empty Album"
        album["photos"] = []
        album
      end

      # Fixtures will pick this up
      let(:albums_json) do
        [ empty_album ]
      end

      it 'handles album with no photos gracefully' do
        result = run_command('download', '--album', empty_album["id"])

        expect(result).to be_success
        expect(result.stdout).to include('Downloading album: Empty Album')
        expect(result.stdout).to include('✓ All photos are already downloaded.')
      end
    end

    context 'error handling' do
      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf(flickr_data_path)

        result = run_command('download', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Configuration file not found")
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f("#{flickr_data_path}/albums.json")

        result = run_command('download', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Configuration file not found")
      end

      it 'handles malformed albums.json gracefully' do
        File.write("#{flickr_data_path}/albums.json", '{"invalid": json}')

        result = run_command('download', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Invalid configuration file")
      end

      it 'handles missing photo JSON files gracefully' do
        photo_id = photos[1]["id"]
        FileUtils.rm_f("#{flickr_data_path}/photo_#{photo_id}.json")

        result = run_command('download', '--album', album["id"])

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles network errors during download' do
        FileUtils.rm_rf(photo_cache_path)

        allow(Net::HTTP).to receive(:get).and_raise(StandardError, 'Network error')

        result = run_command('download', '--album', album["id"])

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles permission errors with cache directory' do
        # Create cache directory with no write permissions
        File.chmod(0444, photo_cache_path)

        result = run_command('download', '--album', album["id"])

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      ensure
        # Restore permissions for cleanup
        File.chmod(0755, photo_cache_path) if Dir.exist?(photo_cache_path)
      end
    end
  end
end
