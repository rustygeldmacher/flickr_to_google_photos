require "spec_helper"

RSpec.describe 'ignore command', type: :integration do
  include_context "fixtures"

  describe 'f2gp ignore' do
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
    end

    context 'successfully ignoring albums' do
      let(:album_id) { album_remaining_2["id"] }
      let(:album_title) { album_remaining_2["title"] }
      let(:another_album_id) { album_remaining_1["id"] }
      let(:another_album_title) { album_remaining_1["title"] }

      it 'ignores album by name' do
        result = run_command('ignore', '--album', album_title)

        expect(result).to be_success
        expect(result.stdout).to include("Album '#{album_title}' (ID: #{album_id}) has been added to the ignore list")

        # Verify the album was added to the ignore list in config
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include(album_id)
      end

      it 'ignores album by ID' do
        result = run_command('ignore', '--album', album_id)

        expect(result).to be_success
        expect(result.stdout).to include("Album '#{album_title}' (ID: #{album_id}) has been added to the ignore list")

        # Verify the album was added to the ignore list in config
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include(album_id)
      end

      it 'ignores second album while preserving existing ignored albums' do
        result = run_command('ignore', '--album', album_id)
        result = run_command('ignore', '--album', another_album_id)

        expect(result).to be_success
        expect(result.stdout).to include("Album '#{another_album_title}' (ID: #{another_album_id}) has been added to the ignore list")

        # Verify both albums are in the ignore list
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['ignoredAlbums']).to include(album_id) # Original
        expect(config_data['ignoredAlbums']).to include(another_album_id) # New
      end
    end

    context 'already ignored albums' do
      let(:ignored_album_id) { album_ignored["id"] }
      let(:ignored_album_title) { album_ignored["title"] }

      it 'handles album that is already ignored gracefully' do
        result = run_command('ignore', '--album', ignored_album_id)

        expect(result).to be_success
        expect(result.stdout).to include("Album '#{ignored_album_title}' (ID: #{ignored_album_id}) is already ignored")

        # Verify no duplicate entries in config
        config_data = JSON.parse(File.read('config.json'))
        ignored_albums = config_data['ignoredAlbums']
        expect(ignored_albums.count(ignored_album_id)).to eq(1)
      end
    end

    context 'error handling' do
      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf(flickr_data_path)

        result = run_command('ignore', '--album', album_remaining_1["id"])

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f("#{flickr_data_path}/albums.json")

        result = run_command('ignore', '--album', album_remaining_1["id"])

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles malformed albums.json gracefully' do
        File.write("#{flickr_data_path}/albums.json", '{"invalid": json}')

        result = run_command('ignore', '--album', album_remaining_1["id"])

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing config.json gracefully' do
        FileUtils.rm_f('config.json')

        result = run_command('ignore', '--album', album_remaining_1["id"])

        expect(result).to be_success
        expect(result.exit_code).to eq(0)
      end
    end
  end
end
