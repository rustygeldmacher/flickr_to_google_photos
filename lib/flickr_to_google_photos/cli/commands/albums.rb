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
        list: false
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} albums [options]"

        opts.on("--list", "List all Flickr albums") do
          options[:list] = true
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      execute(options)
    end

    def execute(options)
      display_albums_table
      return 0
    end

    private

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
