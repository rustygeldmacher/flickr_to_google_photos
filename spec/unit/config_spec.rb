# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlickrToGooglePhotos::Config do
  let(:config_file) { 'test_config.json' }
  let(:config) { described_class.new(config_file) }

  describe '#initialize' do
    it 'defaults to config.json when no path provided' do
      default_config = described_class.new
      expect(default_config.config_file_path).to eq('config.json')
    end

    it 'accepts custom config file path' do
      expect(config.config_file_path).to eq(config_file)
    end
  end

  describe '#google_client_id' do
    context 'when config file exists' do
      before do
        create_fake_config(path: config_file, 'googleClientId' => 'test_client_id')
      end

      it 'returns the stored client ID' do
        expect(config.google_client_id).to eq('test_client_id')
      end
    end

    context 'when config file does not exist' do
      it 'returns nil for missing client ID' do
        expect(config.google_client_id).to be_nil
      end
    end
  end

  describe '#google_client_secret' do
    context 'when config file exists' do
      before do
        create_fake_config(path: config_file, 'googleClientSecret' => 'test_secret')
      end

      it 'returns the stored client secret' do
        expect(config.google_client_secret).to eq('test_secret')
      end
    end

    context 'when config file does not exist' do
      it 'returns nil for missing client secret' do
        expect(config.google_client_secret).to be_nil
      end
    end
  end

  describe '#google_client_id=' do
    it 'sets the client ID' do
      config.google_client_id = 'new_client_id'
      expect(config.google_client_id).to eq('new_client_id')
    end
  end

  describe '#google_client_secret=' do
    it 'sets the client secret' do
      config.google_client_secret = 'new_secret'
      expect(config.google_client_secret).to eq('new_secret')
    end
  end

  describe '#flickr_data_path' do
    context 'with default path' do
      it 'returns expanded path relative to config file directory' do
        config.flickr_data_path = 'flickr'
        expected_path = File.expand_path('flickr', File.dirname(config_file))
        expect(config.flickr_data_path).to eq(expected_path)
      end
    end

    context 'with custom path' do
      it 'returns expanded custom path' do
        config.flickr_data_path = 'custom_flickr'
        expected_path = File.expand_path('custom_flickr', File.dirname(config_file))
        expect(config.flickr_data_path).to eq(expected_path)
      end
    end

    context 'when not set in config' do
      it 'uses default flickr directory' do
        expected_path = File.expand_path('flickr', File.dirname(config_file))
        expect(config.flickr_data_path).to eq(expected_path)
      end
    end
  end

  describe '#photo_cache_path' do
    context 'with default path' do
      it 'returns expanded path relative to config file' do
        config.photo_cache_path = 'photo_cache'
        expected_path = File.expand_path(File.join('..', 'photo_cache'), config_file)
        expect(config.photo_cache_path).to eq(expected_path)
      end
    end

    context 'with custom path' do
      it 'returns expanded custom path' do
        config.photo_cache_path = 'custom_cache'
        expected_path = File.expand_path(File.join('..', 'custom_cache'), config_file)
        expect(config.photo_cache_path).to eq(expected_path)
      end
    end

    context 'when not set in config' do
      it 'uses default photo-cache directory' do
        expected_path = File.expand_path(File.join('..', 'photo-cache'), config_file)
        expect(config.photo_cache_path).to eq(expected_path)
      end
    end
  end

  describe '#imported_album_ids' do
    context 'with imported albums' do
      before do
        create_fake_config(
          path: config_file,
          'importedAlbums' => [
            { 'title' => 'Album 1', 'flickrId' => 'flickr123', 'googlePhotosId' => 'google123' },
            { 'title' => 'Album 2', 'flickrId' => 'flickr456', 'googlePhotosId' => 'google456' }
          ]
        )
      end

      it 'returns a set of Flickr album IDs' do
        ids = config.imported_album_ids
        expect(ids).to be_a(Set)
        expect(ids).to include('flickr123', 'flickr456')
        expect(ids.size).to eq(2)
      end
    end

    context 'with no imported albums' do
      it 'returns an empty set' do
        expect(config.imported_album_ids).to be_a(Set)
        expect(config.imported_album_ids).to be_empty
      end
    end
  end

  describe '#ignored_album_ids' do
    context 'with ignored albums' do
      before do
        create_fake_config(
          path: config_file,
          'ignoredAlbums' => ['ignored123', 'ignored456']
        )
      end

      it 'returns a set of ignored album IDs' do
        ids = config.ignored_album_ids
        expect(ids).to be_a(Set)
        expect(ids).to include('ignored123', 'ignored456')
        expect(ids.size).to eq(2)
      end
    end

    context 'with no ignored albums' do
      it 'returns an empty set' do
        expect(config.ignored_album_ids).to be_a(Set)
        expect(config.ignored_album_ids).to be_empty
      end
    end
  end

  describe '#ignore_album' do
    it 'adds album ID to ignored list' do
      config.ignore_album('album123')
      expect(config.ignored_album_ids).to include('album123')
    end

    it 'does not add duplicate album IDs' do
      config.ignore_album('album123')
      config.ignore_album('album123')
      expect(config.ignored_album_ids.count('album123')).to eq(1)
    end

    it 'saves the config after adding ignored album' do
      expect(config).to receive(:save!)
      config.ignore_album('album123')
    end
  end

  describe '#track_imported_album' do
    let(:album_data) do
      {
        title: 'Test Album',
        flickrAlbumId: 'flickr123',
        googlePhotosAlbumId: 'google123'
      }
    end

    it 'adds album to imported albums list' do
      config.track_imported_album(**album_data)
      expect(config.imported_album_ids).to include('flickr123')
    end

    it 'saves the config after tracking album' do
      expect(config).to receive(:save!)
      config.track_imported_album(**album_data)
    end

    it 'stores complete album information' do
      config.track_imported_album(**album_data)
      config.save!

      # Reload config to verify persistence
      reloaded_config = described_class.new(config_file)
      imported_albums = JSON.parse(File.read(config_file))['importedAlbums']

      expect(imported_albums).to include(
        'title' => 'Test Album',
        'flickrId' => 'flickr123',
        'googlePhotosId' => 'google123'
      )
    end
  end

  describe '#save!' do
    it 'writes config to file in pretty JSON format' do
      config.google_client_id = 'test_id'
      config.google_client_secret = 'test_secret'
      config.save!

      expect(File.exist?(config_file)).to be true

      saved_data = JSON.parse(File.read(config_file))
      expect(saved_data['googleClientId']).to eq('test_id')
      expect(saved_data['googleClientSecret']).to eq('test_secret')
    end

    it 'creates properly formatted JSON' do
      config.google_client_id = 'test_id'
      config.save!

      file_content = File.read(config_file)
      expect { JSON.parse(file_content) }.not_to raise_error
      expect(file_content).to include("\n")  # Pretty printed JSON should have newlines
    end

    it 'initializes default structure for new config files' do
      config.save!

      saved_data = JSON.parse(File.read(config_file))
      expect(saved_data).to include(
        'googleClientId' => nil,
        'googleClientSecret' => nil,
        'flickrDataPath' => 'flickr',
        'photoCachePath' => 'photo-cache',
        'importedAlbums' => [],
        'ignoredAlbums' => []
      )
    end
  end

  describe 'default config structure' do
    it 'provides sensible defaults for new config' do
      # Access config data to trigger initialization
      config.google_client_id

      expect(config.google_client_id).to be_nil
      expect(config.google_client_secret).to be_nil
      expect(config.imported_album_ids).to be_empty
      expect(config.ignored_album_ids).to be_empty
    end
  end

  describe 'file handling' do
    context 'when config file is malformed JSON' do
      before do
        File.write(config_file, 'invalid json content')
      end

      it 'raises an error when trying to read malformed JSON' do
        expect { config.google_client_id }.to raise_error(JSON::ParserError)
      end
    end

    context 'when config file has unexpected structure' do
      before do
        File.write(config_file, '{"unexpectedKey": "value"}')
      end

      it 'handles missing keys gracefully' do
        expect(config.google_client_id).to be_nil
        expect(config.google_client_secret).to be_nil
        expect(config.imported_album_ids).to be_empty
      end
    end
  end
end
