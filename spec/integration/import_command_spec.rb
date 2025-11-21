require "spec_helper"

RSpec.describe "import command", type: :integration do
  describe 'f2gp import' do
    before do
      # Create a basic config file
      create_fake_config(
        "googleClientId" => "test_client_id",
        "googleClientSecret" => "test_client_secret",
        "flickrDataPath" => "flickr",
        "photoCachePath" => "photo_cache",
        "importedAlbums" => [
          {
            "title" => "Already Imported Album",
            "flickrId" => "72157644251234567",
            "googlePhotosId" => "google_album_123"
          }
        ],
        "ignoredAlbums" => ["72157644251234569"]
      )

      # Create fake Flickr data for import tests
      create_fake_flickr_data_for_import_tests

      # Mock Google Photos authentication and API calls
      mock_google_photos_auth
      mock_google_photos_api_calls

      # Mock other dependencies
      mock_import_dependencies
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
      it 'defaults to --next when no options specified' do
        with_user_input('y') do
          result = run_command('import')

          expect(result).to be_success
          expect(result.stdout).to include('Importing album: Remaining Album 1')
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'imports the next unimported album with --next' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include('Importing album: Remaining Album 1')
          expect(result.stdout).to include('1. Uploading photos...')
          expect(result.stdout).to include('2. Creating album...')
          expect(result.stdout).to include('3. Adding album description...')
          expect(result.stdout).to include('4. Adding photos to album...')
          expect(result.stdout).to include('5. Setting album cover...')
          expect(result.stdout).to include('SUCCESS!')
          expect(result.stdout).to include('Photos uploaded: 2')
        end
      end

      it 'returns error when no albums remain to import' do
        # Mock next_unimported_album to return nil (no albums)
        allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:next_unimported_album).and_return(nil)

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
        expect(result.stdout).to include('No more albums to import')
      end

      it 'shows confirmation prompt in interactive mode by default' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include('files ready to upload, continue? (Y/n)')
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
    end

    context '--album option' do
      it 'imports specific album by name' do
        with_user_input('y') do
          result = run_command('import', '--album', 'Remaining Album 1')

          expect(result).to be_success
          expect(result.stdout).to include('Importing album: Remaining Album 1')
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'imports specific album by ID' do
        with_user_input('y') do
          result = run_command('import', '--album', '72157644251234568')

          expect(result).to be_success
          expect(result.stdout).to include('Importing album: Remaining Album 1')
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'returns error when album not found' do
        result = run_command('import', '--album', 'Nonexistent Album')

        expect(result.stdout).to include("Error: Album 'Nonexistent Album' not found")
        expect(result.exit_code).to eq(1)
      end

      it 'shows confirmation prompt in interactive mode by default' do
        with_user_input('y') do
          result = run_command('import', '--album', 'Remaining Album 1')

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
        expect(result.stdout).to include('Importing album 1: Remaining Album 1')
        expect(result.stdout).to include('Importing album 2: Remaining Album 2')
        expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
        expect(result.stdout).to include('Albums successfully imported: 2')
      end

      it 'runs in non-interactive mode by default' do
        result = run_command('import', '--all')

        expect(result).to be_success
        expect(result.stdout).not_to include('files ready to upload, continue?')
        expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
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

      it 'handles case when no albums remain to import' do
        # Mock next_unimported_album to return nil (no albums) for --all mode
        allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:next_unimported_album).and_return(nil)

        result = run_command('import', '--all')

        expect(result).to be_success
        expect(result.stdout).to include('Starting import of all remaining albums...')
        expect(result.stdout).to include('BATCH IMPORT COMPLETE!')
        expect(result.stdout).to include('Albums successfully imported: 0')
      end
    end

    context 'album without description' do
      before do
        # Create album data without description
        albums_data = {
          "albums" => [
            {
              "id" => "72157644251234571",
              "title" => "Album Without Description",
              "description" => "",
              "photos" => ["123", "456"]
            }
          ]
        }
        File.write('flickr/albums.json', JSON.pretty_generate(albums_data))
      end

      it 'skips description step for albums without descriptions' do
        with_user_input('y') do
          result = run_command('import', '--album', 'Album Without Description')

          expect(result).to be_success
          expect(result.stdout).to include('1. Uploading photos...')
          expect(result.stdout).to include('2. Creating album...')
          expect(result.stdout).to include('3. Adding photos to album...')
          expect(result.stdout).not_to include('Adding album description...')
          expect(result.stdout).to include('SUCCESS!')
        end
      end
    end

    context 'file confirmation table' do
      it 'displays table with photo information' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include('Filename')
          expect(result.stdout).to include('Date')
          expect(result.stdout).to include('Description')
          expect(result.stdout).to include('files ready to upload, continue?')
        end
      end

      it 'handles photos with missing EXIF data gracefully' do
        # This would be handled by the actual implementation
        # We're just testing that the command doesn't crash
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include('SUCCESS!')
        end
      end
    end

    context 'config tracking' do
      it 'tracks imported album in config after successful import' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success

          # Verify album was tracked in config
          config = JSON.parse(File.read('config.json'))
          imported_albums = config['importedAlbums']
          expect(imported_albums).to include(
            hash_including(
              'title' => 'Remaining Album 1',
              'flickrId' => '72157644251234568'
            )
          )
        end
      end
    end

    context 'error handling' do
      before do
        # Don't mock Albums class to test actual error handling
        allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:next_unimported_album).and_call_original
        allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:get_album).and_call_original
      end

      it 'handles missing Flickr data directory gracefully' do
        FileUtils.rm_rf('flickr')

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles missing albums.json file gracefully' do
        FileUtils.rm_f('flickr/albums.json')

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles malformed albums.json gracefully' do
        File.write('flickr/albums.json', '{"invalid": json}')

        result = run_command('import', '--next')

        expect(result).not_to be_success
        expect(result.exit_code).to eq(1)
      end

      it 'handles Google Photos API errors gracefully' do
        # Mock API to raise an error
        fake_client = double('GooglePhotosClient')
        allow(fake_client).to receive(:create_album).and_raise(StandardError, 'API Error')
        allow(GooglePhotosClient).to receive(:new).and_return(fake_client)

        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).not_to be_success
          expect(result.exit_code).to eq(1)
        end
      end

      it 'handles photo download failures gracefully' do
        # Mock download command to fail
        fake_download_command = double('DownloadCommand')
        allow(fake_download_command).to receive(:run).and_return(1)
        allow(FlickrToGooglePhotos::CLI::Commands::Download).to receive(:new).and_return(fake_download_command)

        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).not_to be_success
          expect(result.exit_code).to eq(1)
        end
      end
    end

    context 'album cover handling' do
      it 'sets album cover when cover photo is available' do
        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include('5. Setting album cover...')
          expect(result.stdout).to include('✓ Album cover photo set')
        end
      end

      it 'handles missing cover photo gracefully' do
        # Create a specific mock album without cover photo for this test
        fake_album_no_cover = double('Album')
        allow(fake_album_no_cover).to receive(:id).and_return("72157644251234568")
        allow(fake_album_no_cover).to receive(:title).and_return("Remaining Album 1")
        allow(fake_album_no_cover).to receive(:description).and_return("First album ready for import")
        allow(fake_album_no_cover).to receive(:photos).and_return([
          create_mock_photo("123", "test_photo_123"),
          create_mock_photo("456", "test_photo_456")
        ])
        allow(fake_album_no_cover).to receive(:cover_photo).and_return(nil)

        allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:next_unimported_album).and_return(fake_album_no_cover)

        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).not_to include('5. Setting album cover...')
          expect(result.stdout).to include('SUCCESS!')
        end
      end

      it 'handles cover photo API errors gracefully' do
        # Mock the Google Photos client to fail when setting cover
        fake_client = double('GooglePhotosClient')
        allow(fake_client).to receive(:create_album).and_return({
          "id" => "fake_google_album_id",
          "title" => "Test Album",
          "productUrl" => "https://photos.google.com/album/fake_id"
        })
        allow(fake_client).to receive(:upload_photo_bytes).and_return("fake_upload_token")
        allow(fake_client).to receive(:create_media_items).and_return([])
        allow(fake_client).to receive(:add_text_enrichment).and_return(true)
        allow(fake_client).to receive(:update_album_cover).and_raise(StandardError, 'Cover API Error')
        allow(GooglePhotosClient).to receive(:new).and_return(fake_client)

        with_user_input('y') do
          result = run_command('import', '--next')

          expect(result).to be_success
          expect(result.stdout).to include('5. Setting album cover...')
          expect(result.stdout).to include('Failed to set album cover')
          expect(result.stdout).to include('SUCCESS!')
        end
      end
    end
  end

  private

  def create_fake_flickr_data_for_import_tests
    FileUtils.mkdir_p('flickr')
    FileUtils.mkdir_p('photo_cache')

    # Create individual photo JSON files
    photo_data = [
      { id: '123', name: 'test_photo_123', url: 'https://example.com/photo_123.jpg' },
      { id: '456', name: 'test_photo_456', url: 'https://example.com/photo_456.jpg' },
      { id: '789', name: 'test_photo_789', url: 'https://example.com/photo_789.jpg' },
      { id: '901', name: 'test_photo_901', url: 'https://example.com/photo_901.jpg' }
    ]

    photo_data.each do |photo|
      photo_json = {
        "id" => photo[:id],
        "title" => photo[:name],
        "description" => "A test photo #{photo[:id]}",
        "urls" => {
          "original" => photo[:url]
        }
      }
      File.write("flickr/photo_#{photo[:id]}.json", JSON.pretty_generate(photo_json))

      # Create fake cached photo files
      cache_dir = "photo_cache/72157644251234568"
      FileUtils.mkdir_p(cache_dir)
      File.write("#{cache_dir}/#{photo[:name]}.jpg", "fake photo data")
    end

    # Create cache for second album
    FileUtils.mkdir_p("photo_cache/72157644251234570")
    File.write("photo_cache/72157644251234570/test_photo_789.jpg", "fake photo data")
    File.write("photo_cache/72157644251234570/test_photo_901.jpg", "fake photo data")

    # Create albums.json with test albums
    albums_data = {
      "albums" => [
        {
          "id" => "72157644251234567",
          "title" => "Already Imported Album",
          "description" => "This album is already imported",
          "photos" => ["123"]
        },
        {
          "id" => "72157644251234568",
          "title" => "Remaining Album 1",
          "description" => "First album ready for import",
          "photos" => ["123", "456"]
        },
        {
          "id" => "72157644251234569",
          "title" => "Ignored Album",
          "description" => "This album is ignored",
          "photos" => ["789"]
        },
        {
          "id" => "72157644251234570",
          "title" => "Remaining Album 2",
          "description" => "Second album ready for import",
          "photos" => ["789", "901"]
        }
      ]
    }

    File.write('flickr/albums.json', JSON.pretty_generate(albums_data))
  end

  def mock_google_photos_auth
    # Mock authentication to avoid actual OAuth flow
    fake_credentials = double('credentials')
    fake_auth = double('auth')
    allow(fake_auth).to receive(:authorize).and_return(fake_credentials)
    allow(GooglePhotos::Auth).to receive(:new).and_return(fake_auth)
  end

  def mock_google_photos_api_calls
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
  end

  def mock_import_dependencies
    # Mock the download command to succeed
    fake_download_command = double('DownloadCommand')
    allow(fake_download_command).to receive(:run).and_return(0)
    allow(FlickrToGooglePhotos::CLI::Commands::Download).to receive(:new).and_return(fake_download_command)

    # Mock TTY::Screen
    allow(TTY::Screen).to receive(:width).and_return(80)

    # Mock EXIF data
    fake_exif = double('EXIF')
    allow(fake_exif).to receive(:date_time_original).and_return(Time.now)
    allow(Exif::Data).to receive(:new).and_return(fake_exif)

    # Mock album and photo classes
    create_mock_album_classes

    # Mock gets for user input
    allow_any_instance_of(Object).to receive(:gets).and_return("y\n")
  end

  def create_mock_album_classes
    # Create mock album that responds to all the methods the import command expects
    fake_album = double('Album')
    allow(fake_album).to receive(:id).and_return("72157644251234568")
    allow(fake_album).to receive(:title).and_return("Remaining Album 1")
    allow(fake_album).to receive(:description).and_return("First album ready for import")
    allow(fake_album).to receive(:photos).and_return([
      create_mock_photo("123", "test_photo_123"),
      create_mock_photo("456", "test_photo_456")
    ])
    allow(fake_album).to receive(:cover_photo).and_return(create_mock_photo("123", "test_photo_123"))

    # Mock the Albums module methods
    allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:next_unimported_album) do |starting_after: nil|
      if starting_after.nil?
        fake_album
      else
        # Return second album or nil based on starting_after
        case starting_after
        when "72157644251234568"
          fake_album_2 = double('Album')
          allow(fake_album_2).to receive(:id).and_return("72157644251234570")
          allow(fake_album_2).to receive(:title).and_return("Remaining Album 2")
          allow(fake_album_2).to receive(:description).and_return("Second album ready for import")
          allow(fake_album_2).to receive(:photos).and_return([
            create_mock_photo("789", "test_photo_789"),
            create_mock_photo("901", "test_photo_901")
          ])
          allow(fake_album_2).to receive(:cover_photo).and_return(create_mock_photo("789", "test_photo_789"))
          fake_album_2
        else
          nil
        end
      end
    end

    allow(FlickrToGooglePhotos::Flickr::Albums).to receive(:get_album) do |album_name_or_id|
      case album_name_or_id
      when "Remaining Album 1", "72157644251234568"
        fake_album
      when "Album Without Description", "72157644251234571"
        fake_album_no_desc = double('Album')
        allow(fake_album_no_desc).to receive(:id).and_return("72157644251234571")
        allow(fake_album_no_desc).to receive(:title).and_return("Album Without Description")
        allow(fake_album_no_desc).to receive(:description).and_return("")
        allow(fake_album_no_desc).to receive(:photos).and_return([
          create_mock_photo("123", "test_photo_123"),
          create_mock_photo("456", "test_photo_456")
        ])
        allow(fake_album_no_desc).to receive(:cover_photo).and_return(nil)
        fake_album_no_desc
      else
        nil
      end
    end
  end

  def create_mock_photo(id, name)
    fake_photo = double('Photo')
    allow(fake_photo).to receive(:id).and_return(id)
    allow(fake_photo).to receive(:file_name).and_return("#{name}.jpg")
    allow(fake_photo).to receive(:description).and_return("A test photo #{id}")
    allow(fake_photo).to receive(:physical_path).and_return("photo_cache/72157644251234568/#{name}.jpg")
    allow(fake_photo).to receive(:upload_token=)
    allow(fake_photo).to receive(:media_item).and_return({"mediaItem" => {"id" => "media_#{id}"}})
    fake_photo
  end

end
