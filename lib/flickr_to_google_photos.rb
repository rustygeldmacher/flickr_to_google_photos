require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'exif'
require 'optparse'

module FlickrToGooglePhotos
end

require_relative 'flickr_to_google_photos/google_photos/auth'
require_relative 'flickr_to_google_photos/google_photos/client'
require_relative 'flickr_to_google_photos/flickr/photo'
require_relative 'flickr_to_google_photos/flickr/album'
require_relative 'flickr_to_google_photos/flickr/albums'
require_relative 'flickr_to_google_photos/cli'
