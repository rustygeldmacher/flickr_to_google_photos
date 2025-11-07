require "set"

module FlickrToGooglePhotos
  class Config
    attr_reader :config_file_path

    def initialize(config_file_path)
      @config_file_path = config_file_path
    end

    def google_client_id
      config_json["googleClientId"]
    end

    def google_client_secret
      config_json["googleClientSecret"]
    end

    def flickr_data_path
      @flickr_data_path ||= File.expand_path("../flickr", config_file_path)
    end

    def imported_album_ids
      Set.new(imported_albums.map { |album| album["flickrId"] })
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

    def config_json
      @config_json ||= JSON.parse(File.read(config_file_path))
    end
  end
end
