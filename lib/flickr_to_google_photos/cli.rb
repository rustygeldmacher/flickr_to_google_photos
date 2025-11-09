module FlickrToGooglePhotos
  class CLI
    def start(argv)
      command_name = argv.shift

      if command_name.nil?
        # print help message
        return 0
      end

      command_class = begin
        FlickrToGooglePhotos::CLI::Commands.const_get(command_name.capitalize)
      rescue NameError
        puts "Error: Unknown command: #{command_name}"
        # print help message
        return 1
      end

      command_class.new(argv).run
    end
  end
end

require_relative 'cli/commands/auth'
require_relative 'cli/commands/import'
require_relative 'cli/commands/albums'
