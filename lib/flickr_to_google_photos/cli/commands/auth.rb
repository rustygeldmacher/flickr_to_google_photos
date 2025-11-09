module FlickrToGooglePhotos::CLI::Commands
  class Auth
    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
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
