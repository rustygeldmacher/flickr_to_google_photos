require 'optparse'
require 'tty-table'

module FlickrToGooglePhotos::CLI::Commands
  class Albums
    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
      # Parse command line options
      options = {
        list: false,
        ignore: nil
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} albums [options]"

        opts.on("--list", "List all Flickr albums") do
          options[:list] = true
        end

        opts.on("--ignore ALBUM_NAME_OR_ID", "Add album to ignore list") do |album|
          options[:ignore] = album
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      # Validate mutual exclusion
      if options[:list] && options[:ignore]
        puts "Error: Cannot specify both --list and --ignore options"
        return 1
      end

      execute(options)
    end

    def execute(options)
      if options[:ignore]
        return ignore_album(options[:ignore])
      else
        display_albums_table
        return 0
      end
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

    def display_albums_table
      albums = FlickrToGooglePhotos::Flickr::Albums.to_a

      if albums.empty?
        puts "No albums found."
        return
      end

      # Prepare table data
      table_data = albums.map do |album|
        [
          album.id,
          album.title,
          album.photos.count,
          truncate_description(album.description)
        ]
      end

      # Create and display table
      table = TTY::Table.new(
        header: ['Album ID', 'Title', 'Photos', 'Description'],
        rows: table_data
      )

      puts table.render(:unicode, padding: [0, 1])
      puts "Total #{albums.count} albums"
    end

    def truncate_description(description)
      return "" if description.nil? || description.empty?

      # Truncate long descriptions to keep table readable
      max_length = 50
      if description.length > max_length
        description[0..max_length-4] + "..."
      else
        description
      end
    end
  end
end
