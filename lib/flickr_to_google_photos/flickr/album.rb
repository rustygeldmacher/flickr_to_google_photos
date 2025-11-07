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
