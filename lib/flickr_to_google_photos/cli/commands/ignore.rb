require 'optparse'

module FlickrToGooglePhotos::CLI::Commands
  class Ignore
    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
      # Parse command line options
      options = {
        album: nil
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} ignore [options]"
        opts.separator ""
        opts.separator "Add Flickr albums to the ignore list to skip them during import."
        opts.separator ""
        opts.separator "Options:"

        opts.on("--album ALBUM_NAME_OR_ID", "Add album to ignore list") do |album|
          options[:album] = album
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      # Validate required parameters
      unless options[:album]
        puts "Error: --album option is required"
        puts "Run '#{$0} ignore --help' for usage information"
        return 1
      end

      ignore_album(options[:album])
    end

    private

    def ignore_album(album_name_or_id)
      album = FlickrToGooglePhotos::Flickr::Albums.get_album(album_name_or_id)

      if album.nil?
        puts "Error: Album '#{album_name_or_id}' not found"
        return 1
      end

      # Check if already ignored
      if FlickrToGooglePhotos.config.ignored_album_ids.include?(album.id)
        puts "Album '#{album.title}' (ID: #{album.id}) is already ignored"
        return 0
      end

      # Add to ignored list
      FlickrToGooglePhotos.config.ignore_album(album.id)
      puts "Album '#{album.title}' (ID: #{album.id}) has been added to the ignore list"
      return 0
    end
  end
end
