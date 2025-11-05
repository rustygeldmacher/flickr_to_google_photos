require 'googleauth'
require 'googleauth/stores/file_token_store'

module GooglePhotos
  class Auth
    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
    TOKEN_STORE_PATH = File.join(Dir.home, '.google_photos_tokens.yaml')

    attr_reader :scope

    def initialize(client_id, client_secret, scope)
      @client_id = Google::Auth::ClientId.new(client_id, client_secret)
      @scope = scope
    end

    def authorize
      user_id = 'default'

      # Try to load existing credentials
      credentials = authorizer.get_credentials(user_id)

      if credentials.nil?
        puts "\n" + "="*60
        puts "AUTHORIZATION REQUIRED"
        puts "="*60
        puts "\nVisit this URL to authorize the application:\n\n"

        url = authorizer.get_authorization_url(base_url: OOB_URI)
        puts url

        puts "\nEnter the authorization code: "
        code = gets.chomp

        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id,
          code: code,
          base_url: OOB_URI
        )

        puts "\n✓ Authorization successful! Credentials saved."
      else
        # Refresh if expired
        if credentials.expired?
          puts "Refreshing expired credentials..."
          credentials.refresh!
        end
        puts "✓ Using existing credentials"
      end

      credentials
    end

    def authorizer
      @authorizer ||= begin
        # Ensure the token store directory exists
        token_store_dir = File.dirname(TOKEN_STORE_PATH)
        FileUtils.mkdir_p(token_store_dir) unless File.directory?(token_store_dir)
        token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_STORE_PATH)
        Google::Auth::UserAuthorizer.new(@client_id, scope, token_store)
      end
    end
  end
end
