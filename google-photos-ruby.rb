require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

class GooglePhotosClient
  BASE_URL = 'https://photoslibrary.googleapis.com/v1'
  SCOPE = 'https://www.googleapis.com/auth/photoslibrary.appendonly'
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  TOKEN_STORE_PATH = File.join(Dir.home, '.google_photos_tokens.yaml')
  
  def initialize(client_id, client_secret)
    @client_id = Google::Auth::ClientId.new(client_id, client_secret)
    @authorizer = create_authorizer
  end
  
  def authorize
    user_id = 'default'
    
    # Try to load existing credentials
    credentials = @authorizer.get_credentials(user_id)
    
    if credentials.nil?
      puts "\n" + "="*60
      puts "AUTHORIZATION REQUIRED"
      puts "="*60
      puts "\nVisit this URL to authorize the application:\n\n"
      
      url = @authorizer.get_authorization_url(base_url: OOB_URI)
      puts url
      
      puts "\nEnter the authorization code: "
      code = gets.chomp
      
      credentials = @authorizer.get_and_store_credentials_from_code(
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
  
  def upload_photo_bytes(credentials, file_path)
    file_data = File.binread(file_path)
    file_name = File.basename(file_path)
    
    uri = URI('https://photoslibrary.googleapis.com/v1/uploads')
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    credentials.apply!(request) # Apply OAuth credentials to request
    request['Content-Type'] = 'application/octet-stream'
    request['X-Goog-Upload-File-Name'] = file_name
    request['X-Goog-Upload-Protocol'] = 'raw'
    request.body = file_data
    
    response = http.request(request)
    
    if response.code == '200'
      puts "✓ Photo uploaded successfully"
      response.body # This is the upload token
    else
      raise "Upload failed: #{response.code} - #{response.body}"
    end
  end
  
  def create_album(credentials, title)
    uri = URI("#{BASE_URL}/albums")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    credentials.apply!(request)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate({
      album: {
        title: title
      }
    })
    
    response = http.request(request)
    
    if response.code == '200'
      album_data = JSON.parse(response.body)
      puts "✓ Album created: #{album_data['title']}"
      album_data
    else
      raise "Album creation failed: #{response.code} - #{response.body}"
    end
  end
  
  def add_text_enrichment(credentials, album_id, text)
    uri = URI("#{BASE_URL}/albums/#{album_id}:addEnrichment")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    credentials.apply!(request)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate({
      newEnrichmentItem: {
        textEnrichment: {
          text: text
        }
      },
      albumPosition: {
        position: 'FIRST_IN_ALBUM'
      }
    })
    
    response = http.request(request)
    
    if response.code == '200'
      puts "✓ Text enrichment added to album"
      JSON.parse(response.body)
    else
      raise "Add enrichment failed: #{response.code} - #{response.body}"
    end
  end
  
  def create_media_items(credentials, upload_tokens_with_descriptions, album_id)
    uri = URI("#{BASE_URL}/mediaItems:batchCreate")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    credentials.apply!(request)
    request['Content-Type'] = 'application/json'
    
    # Build array of new media items
    new_media_items = upload_tokens_with_descriptions.map do |upload_token, description|
      item = {
        simpleMediaItem: {
          uploadToken: upload_token
        }
      }
      item[:description] = description if description
      item
    end
    
    request.body = JSON.generate({
      albumId: album_id,
      newMediaItems: new_media_items
    })
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      
      # Check all results
      results = result['newMediaItemResults']
      successful = results.select { |r| r.dig('status', 'message') == 'Success' }
      failed = results.select { |r| r.dig('status', 'message') != 'Success' }
      
      puts "✓ #{successful.count} photo(s) added to album successfully"
      
      if failed.any?
        puts "⚠ #{failed.count} photo(s) failed to upload"
        failed.each { |f| puts "  - #{f['status']['message']}" }
      end
      
      successful.map { |r| r['mediaItem'] }
    else
      raise "Batch create failed: #{response.code} - #{response.body}"
    end
  end
  
  def upload_to_new_album(photos_array, album_title, album_description = nil)
    credentials = authorize
    
    puts "\nStarting upload process..."
    puts "Photos to upload: #{photos_array.length}"
    
    # Upload all photos and collect tokens
    puts "\n1. Uploading photo bytes..."
    upload_tokens_with_descriptions = photos_array.map.with_index do |(file_path, description), index|
      print "  Uploading #{index + 1}/#{photos_array.length}: #{File.basename(file_path)}..."
      upload_token = upload_photo_bytes(credentials, file_path)
      puts " ✓"
      [upload_token, description]
    end
    
    puts "\n2. Creating album..."
    album = create_album(credentials, album_title)
    
    # Add text enrichment if description provided
    if album_description
      puts "\n3. Adding album description..."
      add_text_enrichment(credentials, album['id'], album_description)
    end
    
    puts "\n#{album_description ? '4' : '3'}. Adding photos to album..."
    media_items = create_media_items(credentials, upload_tokens_with_descriptions, album['id'])
    
    puts "\n✅ Complete! Album ID: #{album['id']}"
    if media_items.first && media_items.first['productUrl']
      puts "Album URL: #{media_items.first['productUrl'].split('/').first(4).join('/')}"
    end
    
    {
      album: album,
      media_items: media_items
    }
  end
  
  private
  
  def create_authorizer
    # Ensure the token store directory exists
    token_store_dir = File.dirname(TOKEN_STORE_PATH)
    FileUtils.mkdir_p(token_store_dir) unless File.directory?(token_store_dir)
    
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_STORE_PATH)
    
    Google::Auth::UserAuthorizer.new(
      @client_id,
      SCOPE,
      token_store
    )
  end
end

# Usage example
if __FILE__ == $0
  # Get these from Google Cloud Console:
  # 1. Create a project
  # 2. Enable Google Photos Library API
  # 3. Create OAuth 2.0 credentials (Desktop app type)
  CLIENT_ID = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com'
  CLIENT_SECRET = 'YOUR_CLIENT_SECRET_HERE'
  
  begin
    client = GooglePhotosClient.new(CLIENT_ID, CLIENT_SECRET)
    
    # Array of [photo_file_path, photo_description]
    photos = [
      ['path/to/photo1.jpg', 'Beautiful sunset from day 1'],
      ['path/to/photo2.jpg', 'Beach view from day 2'],
      ['path/to/photo3.jpg', nil] # Photo without description
    ]
    
    result = client.upload_to_new_album(
      photos,
      'My Vacation Photos',
      'Summer 2024 trip to Hawaii' # Album description
    )
    
    puts "\n" + "="*60
    puts "SUCCESS!"
    puts "="*60
    puts "Album ID: #{result[:album]['id']}"
    puts "Album Title: #{result[:album]['title']}"
    puts "Photos uploaded: #{result[:media_items].count}"
    result[:media_items].each_with_index do |item, idx|
      puts "  #{idx + 1}. #{item['filename']} (ID: #{item['id']})"
    end
    
  rescue => e
    puts "\n❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
  end
end