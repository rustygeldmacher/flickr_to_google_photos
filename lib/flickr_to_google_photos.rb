require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'exif'
require 'optparse'

require 'tty-table'
require 'tty-progressbar'

require_relative 'flickr_to_google_photos/version'

module FlickrToGooglePhotos
  def self.config
    @config ||= begin
      config_file_path = File.join(Dir.pwd, "config.json")
      FlickrToGooglePhotos::Config.new(config_file_path)
    end
  end
end

require_relative 'flickr_to_google_photos/config'
require_relative 'flickr_to_google_photos/util/string_utils'
require_relative 'flickr_to_google_photos/google_photos/auth'
require_relative 'flickr_to_google_photos/google_photos/client'
require_relative 'flickr_to_google_photos/flickr/photo'
require_relative 'flickr_to_google_photos/flickr/album'
require_relative 'flickr_to_google_photos/flickr/albums'
require_relative 'flickr_to_google_photos/cli'
