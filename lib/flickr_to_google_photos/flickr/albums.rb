module FlickrToGooglePhotos
  module Flickr
    module Albums
      extend Enumerable

      def self.each
        albums_json.each do |album_json|
          yield Flickr::Album.new(album_json)
        end
      end

      def self.get_album(album_name_or_id)
        # Load Flickr Albums
        album_json = albums_json.find do |a|
          [a['title'], a['id']].include?(album_name_or_id)
        end
        if album_json
          Flickr::Album.new(album_json)
        end
      end

      def self.albums_json
        @albums_json ||= begin
          flickr_albums_path = File.expand_path('../../../flickr/albums.json', __dir__)
          JSON.parse(File.read(flickr_albums_path))['albums']
        end
      end
    end
  end
end
