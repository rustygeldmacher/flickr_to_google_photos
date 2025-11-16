require 'optparse'
require 'json'
require 'fileutils'

module FlickrToGooglePhotos::CLI::Commands
  class Config
    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
      # Parse command line options
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} config [options]"
        opts.separator ""
        opts.separator "Initialize a new config.json file for FlickrToGooglePhotos."
        opts.separator ""
        opts.separator "This command will:"
        opts.separator "  1. Check for existing config.json (backup if found)"
        opts.separator "  2. Prompt for Google API credentials"
        opts.separator "  3. Prompt for data and cache paths"
        opts.separator "  4. Generate a new config.json file"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      config = FlickrToGooglePhotos::Config.new

      # Check for existing config
      if File.exist?(config.config_file_path)
        puts "Found existing config.json file."
        print "Do you want to replace it? This will backup the current file to config.json.bak (y/N): "
        response = gets.chomp.downcase

        unless ['y', 'yes'].include?(response)
          puts "Config setup cancelled."
          return 0
        end

        # Backup existing config
        backup_path = "#{config.config_file_path}.bak"
        FileUtils.mv(config.config_file_path, backup_path)
        puts "✓ Backed up existing config to #{backup_path}"
      end

      puts "\n" + "=" * 60
      puts "FLICKR TO GOOGLE PHOTOS - CONFIGURATION SETUP"
      puts "=" * 60
      puts

      # Collect Google API credentials
      puts "Google API Configuration:"
      puts "You'll need to create a Google API project and enable the Photos Library API."
      puts "Visit: https://console.developers.google.com/"
      puts "See https://github.com/rustygeldmacher/flickr_to_google_photos for more documentation"

      print "Enter your Google API Project Client ID: "
      client_id = gets.chomp.strip

      while client_id.empty?
        print "Client ID cannot be empty. Please enter your Client ID: "
        client_id = gets.chomp.strip
      end

      print "Enter your Google API Project Client Secret: "
      client_secret = gets.chomp.strip

      while client_secret.empty?
        print "Client Secret cannot be empty. Please enter your Client Secret: "
        client_secret = gets.chomp.strip
      end

      puts

      # Collect path configurations
      puts "Path Configuration:"

      print "Where is your Flickr data located? [flickr]: "
      flickr_path = gets.chomp.strip
      flickr_path = "flickr" if flickr_path.empty?

      print "Where should the photo cache be stored? [photo-cache]: "
      cache_path = gets.chomp.strip
      cache_path = "photo-cache" if cache_path.empty?

      # Configure using Config class
      begin
        config.google_client_id = client_id
        config.google_client_secret = client_secret
        config.flickr_data_path = flickr_path
        config.photo_cache_path = cache_path
        config.save!

        puts
        puts "✓ Configuration saved to #{config.config_file_path}"
        puts
        puts "Next steps:"
        puts "  1. Ensure your Flickr data is in the '#{flickr_path}' directory"
        puts "  2. Run 'f2gp auth' to authenticate with Google Photos"
        puts "  3. Run 'f2gp albums' to see your available albums"
        puts
        return 0
      rescue => e
        puts "✗ Error writing config file: #{e.message}"
        return 1
      end
    end
  end
end
