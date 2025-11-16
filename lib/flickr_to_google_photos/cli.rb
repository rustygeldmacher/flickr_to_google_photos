module FlickrToGooglePhotos
  class CLI
    def start(argv)
      command_name = argv.shift

      # Handle global help when no command provided or when first argument is --help
      if [nil, "--help", "-h"].include?(command_name)
        print_help_message
        return 0
      end

      command_class = begin
        FlickrToGooglePhotos::CLI::Commands.const_get(command_name.capitalize)
      rescue NameError
        puts "Error: Unknown command: #{command_name}"
        puts
        print_help_message
        return 1
      end

      command_class.new(argv).run
    end

    private

    def print_help_message
      puts <<~HELP
        FlickrToGooglePhotos - Move your Flickr photo albums into Google Photos

        USAGE:
            f2gp <command> [options]

        COMMANDS:
            config      Initialize configuration file
            auth        Authenticate with Google Photos
            import      Import Flickr albums to Google Photos
            download    Download photos from Flickr albums
            albums      List and manage Flickr albums
            ignore      Add albums to ignore list

        OPTIONS:
            -h, --help    Show this help message

        Run 'f2gp <command> --help' for more information about a specific command.
      HELP
    end
  end
end

require_relative 'cli/commands/config'
require_relative 'cli/commands/auth'
require_relative 'cli/commands/download'
require_relative 'cli/commands/import'
require_relative 'cli/commands/albums'
require_relative 'cli/commands/ignore'
