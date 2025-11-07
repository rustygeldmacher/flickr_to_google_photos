module FlickrToGooglePhotos::Util
  module StringUtils
    def self.strip_html_tags(str)
      (str || "").gsub(/<[^>]*>/, "")
    end
  end
end
