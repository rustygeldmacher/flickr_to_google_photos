require "spec_helper"

RSpec.describe 'albums command', type: :integration do
  include_context "fixtures"

  describe 'f2gp albums' do
    context 'help option' do
      it 'displays help message with --help' do
        result = run_command('albums', '--help')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
        expect(result.stdout).to include('albums [options]')
        expect(result.stdout).to include('--status [STATUS]')
        expect(result.stdout).to include('List Flickr albums (all, imported, remaining, ignored)')
        expect(result.stdout).to include('-h, --help')
      end

      it 'displays help message with -h' do
        result = run_command('albums', '-h')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
      end
    end

    context 'when no albums exist' do
      before do
        # Create empty albums.json
        FileUtils.mkdir_p('flickr')
        File.write('flickr/albums.json', JSON.pretty_generate({"albums" => []}))
      end

      it 'displays no albums found message' do
        result = run_command('albums')

        expect(result).to be_success
        expect(result.stdout).to include('No albums found.')
      end
    end

    context 'status filtering' do
      it 'displays all albums by default' do
        result = run_command('albums')

        expect(result).to be_success
        expect(result.stdout).to include('Album ID')
        expect(result.stdout).to include('Title')
        expect(result.stdout).to include('Photos')
        expect(result.stdout).to include('Status')
        expect(result.stdout).to include('Description')
        expect(result.stdout).to include(album_already_imported["title"])
        expect(result.stdout).to include(album_remaining_1["title"])
        expect(result.stdout).to include(album_ignored["title"])
        expect(result.stdout).to include(album_remaining_2["title"])
        expect(result.stdout).to include('Total 4 albums (all)')
      end

      it 'displays all albums with --status all' do
        result = run_command('albums', '--status', 'all')

        expect(result).to be_success
        expect(result.stdout).to include('Total 4 albums (all)')
      end

      it 'displays only imported albums with --status imported' do
        result = run_command('albums', '--status', 'imported')

        expect(result).to be_success
        expect(result.stdout).to include(album_already_imported["title"])
        expect(result.stdout).to include('Imported')
        expect(result.stdout).to include('Total 1 albums (imported)')
      end

      it 'displays only remaining albums with --status remaining' do
        result = run_command('albums', '--status', 'remaining')

        expect(result).to be_success
        expect(result.stdout).to include(album_remaining_1["title"])
        expect(result.stdout).to include(album_remaining_2["title"])
        expect(result.stdout).to include('Remaining')
        expect(result.stdout).to include('Total 2 albums (remaining)')
      end

      it 'displays only ignored albums with --status ignored' do
        result = run_command('albums', '--status', 'ignored')

        expect(result).to be_success
        expect(result.stdout).to include('Ignored Album')
        expect(result.stdout).to include('Ignored')
        expect(result.stdout).not_to include('Imported Album')
        expect(result.stdout).not_to include('Remaining Album')
        expect(result.stdout).to include('Total 1 albums (ignored)')
      end

      it 'handles --status with no value defaulting to all' do
        result = run_command('albums', '--status')

        expect(result).to be_success
        expect(result.stdout).to include('Total 4 albums (all)')
      end
    end

    context 'invalid status handling' do
      it 'returns error for invalid status' do
        result = run_command('albums', '--status', 'invalid')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include("Error: Invalid status 'invalid'")
        expect(result.stdout).to include('Valid options are: all, imported, remaining, ignored')
      end
    end

    context 'empty filtered results' do
      before do
        # Create config with no imported or ignored albums
        create_fake_config(
          "importedAlbums" => [],
          "ignoredAlbums" => []
        )
      end

      it 'displays no albums message for empty imported filter' do
        result = run_command('albums', '--status', 'imported')

        expect(result).to be_success
        expect(result.stdout).to include("No albums found with status 'imported'.")
      end

      it 'displays no albums message for empty ignored filter' do
        result = run_command('albums', '--status', 'ignored')

        expect(result).to be_success
        expect(result.stdout).to include("No albums found with status 'ignored'.")
      end
    end

    context 'table formatting' do
      it 'truncates long descriptions' do
        # Create an album with a very long description
        albums_data = {
          "albums" => [
            {
              "id" => "72157644251234567",
              "title" => "Album with Long Description",
              "description" => "This is a very long description that should be truncated because it exceeds the maximum length allowed in the table display format",
              "photos" => []
            }
          ]
        }
        File.write('flickr/albums.json', JSON.pretty_generate(albums_data))

        result = run_command('albums')

        expect(result).to be_success
        expect(result.stdout).to include('Album with Long Description')
        expect(result.stdout).to include('This is a very long description that should be ...')
        expect(result.stdout).not_to include('truncated because it exceeds')
      end

      it 'handles albums with empty descriptions' do
        albums_data = {
          "albums" => [
            {
              "id" => "72157644251234567",
              "title" => "Album with No Description",
              "description" => "",
              "photos" => []
            }
          ]
        }
        File.write('flickr/albums.json', JSON.pretty_generate(albums_data))

        result = run_command('albums')

        expect(result).to be_success
        expect(result.stdout).to include('Album with No Description')
      end

      it 'handles albums with nil descriptions' do
        albums_data = {
          "albums" => [
            {
              "id" => "72157644251234567",
              "title" => "Album with Nil Description",
              "description" => nil,
              "photos" => []
            }
          ]
        }
        File.write('flickr/albums.json', JSON.pretty_generate(albums_data))

        result = run_command('albums')

        expect(result).to be_success
        expect(result.stdout).to include('Album with Nil Description')
      end
    end

    context 'error handling' do
      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf('flickr')

        result = run_command('albums')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f('flickr/albums.json')

        result = run_command('albums')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles malformed albums.json gracefully' do
        File.write('flickr/albums.json', '{"invalid": json}')

        result = run_command('albums')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end
    end
  end
end
