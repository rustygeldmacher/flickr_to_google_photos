module FlickrToGooglePhotos
  module Flickr
    class Photo
      attr_reader :id
      attr_accessor :physical_path, :upload_token, :media_item

      def initialize(id)
        @id = id
      end

      def file_name
        @file_name ||= begin
          ext = File.extname(url)
          photo_json["name"] + ext
        end
      end

      def description
        @description ||= Util::StringUtils.strip_html_tags(photo_json["description"])
      end

      def url
        photo_json["original"]
      end

      private

      def photo_json
        @photo_json ||= begin
          photo_json_path = File.join(
            FlickrToGooglePhotos.config.flickr_data_path,
            "photo_#{id}.json"
          )
          JSON.parse(File.read(photo_json_path))
        end
      end
    end
  end
end
