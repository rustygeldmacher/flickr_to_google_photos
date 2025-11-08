module FlickrToGooglePhotos
  module Flickr
    class Album
      def initialize(json)
        @json = json
      end

      def id
        @json['id']
      end

      def title
        @json['title']
      end

      def description
        @description ||= Util::StringUtils.strip_html_tags(@json['description'])
      end

      def cover_photo
        return nil unless @json['cover_photo']

        @cover_photo_id ||= begin
          match = @json['cover_photo'].match(%r{/photos/[^/]+/(\d+)})
          cover_photo_id = match ? match[1] : nil
          if cover_photo_id
            photos.find { |photo| photo.id == cover_photo_id }
          end
        end
      end

      def status
        config = FlickrToGooglePhotos.config
        if config.imported_album_ids.include?(id)
          :imported
        elsif config.ignored_album_ids.include?(id)
          :ignored
        else
          :remaining
        end
      end

      def photos
        @photos ||= @json['photos'].map do |photo_json|
          # Sometimes this happens, not sure why
          next if photo_json["id"] == "0"
          Flickr::Photo.new(photo_json)
        end.compact
      end
    end
  end
end
