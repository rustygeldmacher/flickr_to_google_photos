require "spec_helper"

RSpec.describe "import command", type: :integration do
  include_context "fixtures"

  describe 'f2gp import' do
    before do
      # Mock external services (but not Flickr classes)
      mock_external_services
    end

    context 'help option' do
      it 'displays help message with --help' do
        result = run_command('import', '--help')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
        expect(result.stdout).to include('--next')
        expect(result.stdout).to include('--album ALBUM_NAME')
        expect(result.stdout).to include('--all')
        expect(result.stdout).to include('--[no-]interactive')
      end

      it 'displays help message with -h' do
        result = run_command('import', '-h')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
      end
    end

    context 'authentication errors' do
      before do
        # Make Google Photos auth fail before any album logic runs
        allow(GooglePhotos::Auth).to receive(:new).and_raise(GooglePhotos::Auth::NotAuthenticated.new("Not authenticated"))
      end

      it 'returns error when not authenticated with Google Photos' do
        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('Error: Not authenticated with Google Photos!')
        expect(result.stdout).to include('auth')
      end
    end

    context 'option validation' do
      it 'returns error when multiple exclusive options are specified' do
        result = run_command('import', '--next', '--all')

        expect(result.stdout).to include('Error: Cannot specify more than one of --next, --album, or --all options')
        expect(result.exit_code).to eq(1)
      end

      it 'returns error when --album and --all are specified together' do
        result = run_command('import', '--album', 'Test Album', '--all')

        expect(result.stdout).to include('Error: Cannot specify more than one of --next, --album, or --all options')
        expect(result.exit_code).to eq(1)
      end

      it 'returns error when --next and --album are specified together' do
        result = run_command('import', '--next', '--album', 'Test Album')

        expect(result.stdout).to include('Error: Cannot specify more than one of --next, --album, or --all options')
        expect(result.exit_code).to eq(1)
      end
    end

    context '--next option' do
      # From the fixtures, this should be the next one
      let(:next_album) { album_remaining_1 }

      it 'imports the next unimported album with --next' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include("Importing album: #{next_album["title"]}")
          expect(result.stdout).to include('1. Uploading photos...')
          # Table of files
          expect(result.stdout).to include('Filename')
          expect(result.stdout).to include('Date')
          expect(result.stdout).to include('Description')
          # Confirmation
          expect(result.stdout).to include('files ready to upload, continue?')
          expect(result.stdout).to include('2. Creating album...')
          expect(result.stdout).to include('3. Adding album description...')
          expect(result.stdout).to include('4. Adding photos to album...')
          expect(result.stdout).to include('5. Setting album cover...')
          expect(result.stdout).to include('SUCCESS!')
          expect(result.stdout).to include('Photos uploaded: 3')
        end
      end

      it 'defaults to --next when no options specified' do
        with_user_input('y') do
          result = run_command('import')

          expect(result).to be_success
          expect(result.stdout).to include("Importing album: #{next_album["title"]}")
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'allows user to decline import in interactive mode' do
        # Mock gets to return 'n' for declining
        allow_any_instance_of(Object).to receive(:gets).and_return("n\n")

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('continue? (Y/n)')
        expect(result.stdout).not_to include('Uploading photos...')
      end

      it 'skips confirmation with --no-interactive' do
        result = run_command('import', '--next', '--no-interactive')

        expect(result).to be_success
        expect(result.stdout).not_to include('files ready to upload, continue?')
        expect(result.stdout).to include('SUCCESS!')
      end

      it 'tracks imported album in config after successful import' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success

          # Verify album was tracked in config
          config = JSON.parse(File.read('config.json'))
          imported_albums = config['importedAlbums']
          expect(imported_albums).to include(
            hash_including(
              "title" => next_album["title"],
              "flickrId" => next_album["id"],
              "googlePhotosId" => "fake_google_album_id"
            )
          )
        end
      end

      context 'there are no more albums to import' do
        # Fixtures will pick this up as the only album
        let(:albums_json) { [album_already_imported] }

        it 'returns error' do
          result = run_command('import', '--next')

          expect(result).not_to be_success
          expect(result.exit_code).to eq(1)
          expect(result.stdout).to include('No more albums to import')
        end
      end
    end

    context '--album option' do
      let(:album) { album_remaining_2 }

      it 'imports specific album by name' do
        with_user_input('y') do
          result = run_command('import', '--album', album["title"])

          expect(result).to be_success
          expect(result.stdout).to include("Importing album: #{album["title"]}")
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'imports specific album by ID' do
        with_user_input('y') do
          result = run_command('import', '--album', album["id"])

          expect(result).to be_success
          expect(result.stdout).to include("Importing album: #{album["title"]}")
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'returns error when album not found' do
        result = run_command('import', '--album', 'Nonexistent Album')

        expect(result.stdout).to include("Error: Album 'Nonexistent Album' not found")
        expect(result.exit_code).to eq(1)
      end

      it 'shows confirmation prompt in interactive mode by default' do
        with_user_input('n') do
          result = run_command('import', '--album', album["title"])

          expect(result).to be_success
          expect(result.stdout).to include('files ready to upload, continue? (Y/n)')
        end
      end
    end

    context '--all option' do
      it 'imports all remaining albums' do
        result = run_command('import', '--all')

        expect(result).to be_success
        expect(result.stdout).to include('Starting import of all remaining albums...')
        expect(result.stdout).to include("Importing album 1: #{album_remaining_1["title"]}")
        expect(result.stdout).to include("Importing album 2: #{album_remaining_2["title"]}")
        expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
        expect(result.stdout).to include('Albums successfully imported: 2')
      end

      it 'can be forced to interactive mode with --interactive' do
        with_user_input('y', 'y') do
          result = run_command('import', '--all', '--interactive')

          expect(result).to be_success
          expect(result.stdout).to include('files ready to upload, continue? (Y/n)')
          expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
        end
      end

      it 'continues with remaining albums after one fails' do
        # Mock one album to fail during import
        allow_any_instance_of(FlickrToGooglePhotos::CLI::Commands::Import)
          .to receive(:import_single_album)
          .and_return(1, 0)  # First fails, second succeeds

        result = run_command('import', '--all')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
        expect(result.stdout).to include('Albums successfully imported: 1')
        expect(result.stdout).to include('Albums failed: 1')
      end

      context "no albums remain to import" do
        let(:albums_json) do
          [
            album_already_imported,
            album_ignored
          ]
        end

        it 'gracefully handles it' do
          result = run_command('import', '--all')

          expect(result).to be_success
          expect(result.stdout).to include('Starting import of all remaining albums...')
          expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
          expect(result.stdout).to include('Albums successfully imported: 0')
        end
      end
    end

    context 'album without description' do
      let(:albums_json) do
        [
          album_remaining_1.merge(
            "title" => "Album Without Description",
            "description" => ""
          )
        ]
      end

      it 'skips description step for albums without descriptions' do
        with_user_input('y') do
          result = run_command('import', '--album', 'Album Without Description')

          expect(result).to be_success
          expect(result.stdout).to include('1. Uploading photos...')
          expect(result.stdout).to include('2. Creating album...')
          expect(result.stdout).to include('3. Adding photos to album...')
          expect(result.stdout).to include('4. Setting album cover...')
          expect(result.stdout).not_to include('Adding album description...')
          expect(result.stdout).to include('SUCCESS!')
        end
      end
    end

    context 'error handling' do
      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf(flickr_data_path)

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f("#{flickr_data_path}/albums.json")

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles malformed albums.json gracefully' do
        File.write("#{flickr_data_path}/albums.json", '{"invalid": json}')

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles Google Photos API errors gracefully' do
        # Mock API to raise an error
        fake_client = double('GooglePhotosClient')
        allow(fake_client).to receive(:upload_photo_bytes).and_raise(StandardError, 'API Error')
        allow(GooglePhotosClient).to receive(:new).and_return(fake_client)

        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).not_to be_success
          expect(result.exit_code).to eq(1)
        end
      end
    end

    context 'album cover handling' do
      let(:albums_json) do
        [
          album_remaining_1.merge("cover_photo" => "")
        ]
      end

      it 'handles missing cover photo gracefully' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).not_to include('Setting album cover...')
          expect(result.stdout).to include('SUCCESS!')
        end
      end
    end
  end

  private

  def mock_external_services
    # Mock Google Photos authentication to avoid actual OAuth flow
    fake_credentials = double('credentials')
    fake_auth = double('auth')
    allow(fake_auth).to receive(:authorize).and_return(fake_credentials)
    allow(GooglePhotos::Auth).to receive(:new).and_return(fake_auth)

    # Mock Google Photos API client and its methods
    fake_client = double('GooglePhotosClient')

    # Mock album creation
    allow(fake_client).to receive(:create_album).and_return({
      "id" => "fake_google_album_id",
      "title" => "Test Album",
      "productUrl" => "https://photos.google.com/album/fake_id"
    })

    # Mock photo upload
    allow(fake_client).to receive(:upload_photo_bytes).and_return("fake_upload_token")

    # Mock media item creation
    allow(fake_client).to receive(:create_media_items).and_return([])

    # Mock text enrichment
    allow(fake_client).to receive(:add_text_enrichment).and_return(true)

    # Mock album cover setting
    allow(fake_client).to receive(:update_album_cover).and_return(true)

    # Mock client initialization
    allow(GooglePhotosClient).to receive(:new).and_return(fake_client)

    # Mock EXIF data
    fake_exif = double('EXIF')
    allow(fake_exif).to receive(:date_time_original).and_return(Time.now)
    allow(Exif::Data).to receive(:new).and_return(fake_exif)

    # Mock gets for user input
    allow_any_instance_of(Object).to receive(:gets).and_return("y\n")
  end
end
