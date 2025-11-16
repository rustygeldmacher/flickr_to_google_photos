require "set"

module FlickrToGooglePhotos
  class Config
    attr_reader :config_file_path

    def initialize(config_file_path = "config.json")
      @config_file_path = config_file_path
    end

    # Setter methods for basic configuration
    def google_client_id=(value)
      config_json["googleClientId"] = value
    end

    def google_client_secret=(value)
      config_json["googleClientSecret"] = value
    end

    def flickr_data_path=(value)
      config_json["flickrDataPath"] = value
    end

    def photo_cache_path=(value)
      config_json["photoCachePath"] = value
    end

    def google_client_id
      config_json["googleClientId"]
    end

    def google_client_secret
      config_json["googleClientSecret"]
    end

    def photo_cache_path
      @photo_cache_path ||= File.expand_path(File.join("..", photo_cache_json), config_file_path)
    end

    def flickr_data_path
      @flickr_data_path ||= File.expand_path(flickr_data_json, File.dirname(config_file_path))
    end

    def imported_album_ids
      Set.new(imported_albums.map { |album| album["flickrId"] })
    end

    def ignored_album_ids
      Set.new(ignored_albums)
    end

    def ignore_album(album_id)
      ignored_albums << album_id unless ignored_albums.include?(album_id)
      save!
    end

    def track_imported_album(title:, flickrAlbumId:, googlePhotosAlbumId:)
      imported_albums << {
        "title" => title,
        "flickrId" => flickrAlbumId,
        "googlePhotosId" => googlePhotosAlbumId
      }
      save!
    end

    def save!
      json = JSON.pretty_generate(config_json)
      File.write(config_file_path, json)
    end

    private

    def imported_albums
      config_json["importedAlbums"] ||= []
    end

    def ignored_albums
      config_json["ignoredAlbums"] ||= []
    end

    def photo_cache_json
      config_json["photoCachePath"] || "photo-cache"
    end

    def flickr_data_json
      config_json["flickrDataPath"] || "flickr"
    end

    def config_json
      @config_json ||= if File.exist?(config_file_path)
        JSON.parse(File.read(config_file_path))
      else
        # Initialize with default structure for new config files
        {
          "googleClientId" => nil,
          "googleClientSecret" => nil,
          "flickrDataPath" => "flickr",
          "photoCachePath" => "photo_cache",
          "importedAlbums" => [],
          "ignoredAlbums" => []
        }
      end
    end
  end
end
