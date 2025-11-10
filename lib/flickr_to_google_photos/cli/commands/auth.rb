require 'optparse'

module FlickrToGooglePhotos::CLI::Commands
  class Auth
    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
      # Parse command line options
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} auth [options]"
        opts.separator ""
        opts.separator "Authenticate with Google Photos API to enable importing albums."
        opts.separator ""
        opts.separator "This command will:"
        opts.separator "  1. Check for existing saved credentials"
        opts.separator "  2. If none found, open a browser authorization flow"
        opts.separator "  3. Save the authorization for future use"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      google_auth = GooglePhotos::Auth.new

      begin
        google_auth.authorize
        puts "✓ Authorized with saved credentials."
        return 0
      rescue GooglePhotos::Auth::NotAuthenticated
        # ignore -- interactive auth below
      end

      puts <<~MESSAGE

        ============================================================
        GOOGLE API AUTHENTICATION
        ============================================================

        Visit this URL to authorize the application:

        #{google_auth.authorization_url}

        Copy the authorization code on the final screen.

        Enter the authorization code:
      MESSAGE

      code = gets.chomp

      google_auth.save_authorization_code(code)

      puts "\n✓ Authorization successful! Credentials saved."

      return 0
    end
  end
end
