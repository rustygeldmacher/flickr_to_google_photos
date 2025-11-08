module FlickrToGooglePhotos
  module Flickr
    module Albums
      extend Enumerable

      def self.each
        albums_json.each do |album_json|
          yield Flickr::Album.new(album_json)
        end
      end

      def self.next_unimported_album
        album = find do |album|
          !FlickrToGooglePhotos.config.imported_album_ids.include?(album.id) &&
          !FlickrToGooglePhotos.config.ignored_album_ids.include?(album.id)
        end
      end

      def self.get_album(album_name_or_id)
        album_json = albums_json.find do |a|
          [a['title'], a['id']].include?(album_name_or_id)
        end
        if album_json
          Flickr::Album.new(album_json)
        end
      end

      def self.albums_json
        @albums_json ||= begin
          flickr_albums_path = File.join(
            FlickrToGooglePhotos.config.flickr_data_path,
            "albums.json"
          )
          JSON.parse(File.read(flickr_albums_path))["albums"]
        end
      end
    end
  end
end
