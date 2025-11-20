# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ignore command', type: :integration do
  describe 'f2gp ignore' do
    before do
      # Create a basic config file
      create_fake_config(
        "googleClientId" => "test_client_id",
        "googleClientSecret" => "test_client_secret",
        "flickrDataPath" => "flickr",
        "photoCachePath" => "photo_cache",
        "importedAlbums" => [],
        "ignoredAlbums" => ["72157644251234569"]
      )

      # Create fake Flickr data
      create_fake_flickr_data_for_ignore_tests
    end

    context 'help option' do
      it 'displays help message with --help' do
        result = run_command('ignore', '--help')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
        expect(result.stdout).to include('ignore [options]')
        expect(result.stdout).to include('Add Flickr albums to the ignore list to skip them during import.')
        expect(result.stdout).to include('--album ALBUM_NAME_OR_ID')
        expect(result.stdout).to include('Add album to ignore list')
        expect(result.stdout).to include('-h, --help')
      end

      it 'displays help message with -h' do
        result = run_command('ignore', '-h')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
      end
    end

    context 'missing required parameters' do
      it 'returns error when --album is not provided' do
        result = run_command('ignore')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('Error: --album option is required')
        expect(result.stdout).to include("Run '#{$0} ignore --help' for usage information")
      end
    end

    context 'album not found' do
      it 'returns error when album name does not exist' do
        result = run_command('ignore', '--album', 'Nonexistent Album')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Album 'Nonexistent Album' not found")
      end

      it 'returns error when album ID does not exist' do
        result = run_command('ignore', '--album', '99999999999999999')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Album '99999999999999999' not found")
      end
    end

    context 'successfully ignoring albums' do
      it 'ignores album by name' do
        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).to be_success
        expect(result.stdout).to include("Album 'Test Album 1' (ID: 72157644251234567) has been added to the ignore list")

        # Verify the album was added to the ignore list in config
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include('72157644251234567')
      end

      it 'ignores album by ID' do
        result = run_command('ignore', '--album', '72157644251234567')

        expect(result).to be_success
        expect(result.stdout).to include("Album 'Test Album 1' (ID: 72157644251234567) has been added to the ignore list")

        # Verify the album was added to the ignore list in config
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include('72157644251234567')
      end

      it 'ignores second album while preserving existing ignored albums' do
        result = run_command('ignore', '--album', 'Test Album 2')

        expect(result).to be_success
        expect(result.stdout).to include("Album 'Test Album 2' (ID: 72157644251234568) has been added to the ignore list")

        # Verify both albums are in the ignore list
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include('72157644251234569') # Original
        expect(config_data['ignoredAlbums']).to include('72157644251234568') # New
      end
    end

    context 'already ignored albums' do
      it 'handles album that is already ignored gracefully' do
        result = run_command('ignore', '--album', 'Already Ignored Album')

        expect(result).to be_success
        expect(result.stdout).to include("Album 'Already Ignored Album' (ID: 72157644251234569) is already ignored")

        # Verify no duplicate entries in config
        config_data = JSON.parse(File.read('config.json'))
        ignored_albums = config_data['ignoredAlbums']
        expect(ignored_albums.count('72157644251234569')).to eq(1)
      end

      it 'handles already ignored album by ID' do
        result = run_command('ignore', '--album', '72157644251234569')

        expect(result).to be_success
        expect(result.stdout).to include("Album 'Already Ignored Album' (ID: 72157644251234569) is already ignored")
      end
    end

    context 'config file updates' do
      it 'preserves other config settings when adding ignored album' do
        original_config = JSON.parse(File.read('config.json'))
        original_client_id = original_config['googleClientId']
        original_imported_albums = original_config['importedAlbums']

        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).to be_success

        # Verify other config settings are preserved
        updated_config = JSON.parse(File.read('config.json'))
        expect(updated_config['googleClientId']).to eq(original_client_id)
        expect(updated_config['importedAlbums']).to eq(original_imported_albums)
        expect(updated_config['ignoredAlbums']).to include('72157644251234567')
      end

      it 'creates ignoredAlbums array if it does not exist' do
        # Create config without ignoredAlbums array
        config_without_ignored = {
          "googleClientId" => "test_client_id",
          "googleClientSecret" => "test_client_secret",
          "flickrDataPath" => "flickr",
          "photoCachePath" => "photo_cache",
          "importedAlbums" => []
        }
        File.write('config.json', JSON.pretty_generate(config_without_ignored))

        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).to be_success
        expect(result.stdout).to include("Album 'Test Album 1' (ID: 72157644251234567) has been added to the ignore list")

        # Verify ignoredAlbums array was created
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include('72157644251234567')
      end
    end

    context 'error handling' do
      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf('flickr')

        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f('flickr/albums.json')

        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles malformed albums.json gracefully' do
        File.write('flickr/albums.json', '{"invalid": json}')

        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing config.json gracefully' do
        FileUtils.rm_f('config.json')

        result = run_command('ignore', '--album', 'Test Album 1')

        expect(result).to be_success
        expect(result.exit_code).to eq(0)
      end
    end

    context 'case sensitivity' do
      it 'matches album names case-sensitively' do
        result = run_command('ignore', '--album', 'test album 1')

        expect(result).not_to be_success
        expect(result.stdout).to include("Error: Album 'test album 1' not found")
      end

      it 'matches exact album name' do
        result = run_command('ignore', '--album', 'Test Album')

        expect(result).not_to be_success
        expect(result.stdout).to include("Error: Album 'Test Album' not found")
      end
    end

    context 'partial name matching' do
      it 'does not match partial album names' do
        result = run_command('ignore', '--album', 'Test')

        expect(result).not_to be_success
        expect(result.stdout).to include("Error: Album 'Test' not found")
      end

      it 'requires exact title match' do
        result = run_command('ignore', '--album', 'Album 1')

        expect(result).not_to be_success
        expect(result.stdout).to include("Error: Album 'Album 1' not found")
      end
    end
  end

  private

  def create_fake_flickr_data_for_ignore_tests
    FileUtils.mkdir_p('flickr')

    albums_data = {
      "albums" => [
        {
          "id" => "72157644251234567",
          "title" => "Test Album 1",
          "description" => "First test album",
          "photos" => 5
        },
        {
          "id" => "72157644251234568",
          "title" => "Test Album 2",
          "description" => "Second test album",
          "photos" => 3
        },
        {
          "id" => "72157644251234569",
          "title" => "Already Ignored Album",
          "description" => "This album is already ignored",
          "photos" => 7
        },
        {
          "id" => "72157644251234570",
          "title" => "Another Test Album",
          "description" => "Another album for testing",
          "photos" => 12
        }
      ]
    }

    File.write('flickr/albums.json', JSON.pretty_generate(albums_data))
  end
end
