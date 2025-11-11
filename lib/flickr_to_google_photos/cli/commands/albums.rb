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
        status: 'all'
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} albums [options]"

        opts.on("--list [STATUS]", "List Flickr albums (all, imported, remaining, ignored)") do |status|
          options[:list] = true
          options[:status] = status || 'all'
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      # Validate status parameter
      valid_statuses = %w[all imported remaining ignored]
      unless valid_statuses.include?(options[:status])
        puts "Error: Invalid status '#{options[:status]}'. Valid options are: #{valid_statuses.join(', ')}"
        return 1
      end

      execute(options)
    end

    def execute(options)
      display_albums_table(options[:status])
      return 0
    end

    private

    def display_albums_table(status_filter = 'all')
      albums = FlickrToGooglePhotos::Flickr::Albums.to_a

      if albums.empty?
        puts "No albums found."
        return
      end

      # Filter albums based on status
      filtered_albums = filter_albums_by_status(albums, status_filter)

      if filtered_albums.empty?
        puts "No albums found with status '#{status_filter}'."
        return
      end

      # Prepare table data
      table_data = filtered_albums.map do |album|
        [
          album.id,
          album.title,
          album.photos.count,
          status_display_name(album.status),
          truncate_description(album.description)
        ]
      end

      # Create and display table
      table = TTY::Table.new(
        header: ['Album ID', 'Title', 'Photos', 'Status', 'Description'],
        rows: table_data
      )

      puts table.render(:unicode, padding: [0, 1])
      puts "Total #{filtered_albums.count} albums (#{status_filter})"
    end

    def filter_albums_by_status(albums, status_filter)
      return albums if status_filter == 'all'

      status_symbol = status_filter.to_sym
      albums.select { |album| album.status == status_symbol }
    end

    def status_display_name(status_symbol)
      case status_symbol
      when :imported
        'Imported'
      when :ignored
        'Ignored'
      when :remaining
        'Remaining'
      else
        status_symbol.to_s.capitalize
      end
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
