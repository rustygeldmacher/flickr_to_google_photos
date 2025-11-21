RSpec.shared_context "fixtures" do
  let(:album_already_imported) do
    {
      "id" => "72157644251234567",
      "title" => "Already Imported Album",
      "description" => "This album is already imported",
      "photos" => [
        {
          "id" => "123",
          "name" => "AlreadyImported_01",
          "original": "https://live.staticflickr.com/99/3422.jpg",
          "description": "First photo"
        }
      ],
      "cover_photo" => "https://live.staticflickr.com/photos/user/123"
    }
  end

  let(:album_remaining_1) do
    {
      "id" => "72157644251234568",
      "title" => "Remaining Album 1",
      "description" => "First album ready for import",
      "photos" => [
        {
          "id" => "456",
          "name" => "RemainingOne_01",
          "original": "https://live.staticflickr.com/943/63463.jpg",
          "description": "A photo of a thing"
        },
        {
          "id" => "789",
          "name" => "RemainingOne_02",
          "original": "https://live.staticflickr.com/43/53463.jpg",
          "description": ""
        },
        {
          "id" => "321",
          "name" => "RemainingOne_03",
          "original": "https://live.staticflickr.com/355/5667.jpg",
          "description": "Another photo of a thing"
        },
      ],
      "cover_photo" => "https://live.staticflickr.com/photos/user/789"
    }
  end

  let(:album_ignored) do
    {
      "id" => "72157644251234569",
      "title" => "Ignored Album",
      "description" => "This album is ignored",
      "photos" => [
        {
          "id" => "987",
          "name" => "Ignored_07",
          "original": "https://live.staticflickr.com/9567/7962.jpg",
          "description": ""
        },
        {
          "id" => "654",
          "name" => "Ignored_11",
          "original": "https://live.staticflickr.com/560/5261.jpg",
          "description": ""
        },
      ],
      "cover_photo" => "https://live.staticflickr.com/photos/user/654"
    }
  end

  let(:album_remaining_2) do
    {
      "id" => "72157644251234570",
      "title" => "Remaining Album 2",
      "description" => "Second album ready for import",
      "photos" => [
        {
          "id" => "678",
          "name" => "MoreRemaining05",
          "original": "https://live.staticflickr.com/7325/7899.jpg",
          "description": "Some more stuff"
        },
        {
          "id" => "901",
          "name" => "MoreRemaining99",
          "original": "https://live.staticflickr.com/6367/57432.jpg",
          "description": ""
        },
      ],
      "cover_photo" => "https://live.staticflickr.com/photos/user/789"
    }
  end

  let(:albums_json) do
    [
      album_already_imported,
      album_remaining_1,
      album_ignored,
      album_remaining_2
    ]
  end

  let(:flickr_data_path) { "flickr" }
  let(:photo_cache_path) { "photo_cache" }

  let(:config_json) do
    {
      "googleClientId" => "test_client_id",
      "googleClientSecret" => "test_client_secret",
      "flickrDataPath" => flickr_data_path,
      "photoCachePath" => photo_cache_path,
      "importedAlbums" => [{
        "title" => album_already_imported["title"],
        "flickrId" => album_already_imported["id"],
        "googlePhotosId" => "google_album_123"
      }],
      "ignoredAlbums" => [
        album_ignored["id"]
      ]
    }
  end

  # Write the fixtures to disk
  before do
    File.write('config.json', JSON.pretty_generate(config_json))

    FileUtils.mkdir_p(flickr_data_path)
    FileUtils.mkdir_p(photo_cache_path)

    albums = albums_json.map do |album|
      photos = album["photos"]

      FileUtils.mkdir_p("#{photo_cache_path}/#{album["id"]}")

      photo_ids = photos.each_with_object([]) do |photo, ids|
        photo_id = photo["id"]
        ids << photo_id
        File.write("#{flickr_data_path}/photo_#{photo_id}.json", JSON.pretty_generate(photo))
        File.write("#{photo_cache_path}/#{album["id"]}/#{photo["name"]}.jpg", "photo data")
      end

      album.merge("photos" => photo_ids)
    end

    File.write("#{flickr_data_path}/albums.json", JSON.pretty_generate({ "albums" => albums }))
  end
end
