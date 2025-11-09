require 'googleauth'
require 'googleauth/stores/file_token_store'

module GooglePhotos
  class Auth
    class NotAuthenticated < StandardError; end

    USER_ID = 'default'
    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
    SCOPES = [
      'https://www.googleapis.com/auth/photoslibrary.appendonly',
      'https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata',
      'https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata'
    ]
    TOKEN_STORE_PATH = '.google_photos_tokens.yaml'

    def initialize(google_client_id: nil, google_client_secret: nil)
      google_client_id ||= FlickrToGooglePhotos.config.google_client_id
      google_client_secret ||= FlickrToGooglePhotos.config.google_client_secret
      @client_id = Google::Auth::ClientId.new(google_client_id, google_client_secret)
    end

    def authorize
      # Try to load existing credentials
      credentials = authorizer.get_credentials(USER_ID)

      if credentials.nil?
        raise NotAuthenticated
      end

      # Refresh if expired
      if credentials.expired?
        credentials.refresh!
      end

      credentials
    end

    # Use the code to generate and save a token into the token store
    def save_authorization_code(code)
      authorizer.get_and_store_credentials_from_code(
        user_id: USER_ID,
        code: code,
        base_url: OOB_URI
      )
    end

    def authorization_url
      authorizer.get_authorization_url(base_url: OOB_URI)
    end

    private

    def authorizer
      @authorizer ||= begin
        # Ensure the token store directory exists
        token_store_dir = File.dirname(TOKEN_STORE_PATH)
        FileUtils.mkdir_p(token_store_dir) unless File.directory?(token_store_dir)
        token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_STORE_PATH)
        Google::Auth::UserAuthorizer.new(@client_id, SCOPES, token_store)
      end
    end
  end
end
