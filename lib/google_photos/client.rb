class GooglePhotosClient
  BASE_URL = 'https://photoslibrary.googleapis.com/v1'

  attr_reader :credentials

  def initialize(credentials)
    @credentials = credentials
  end

  def upload_photo_bytes(file_path)
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

  def create_album(title)
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

  def add_text_enrichment(album_id, text)
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

  def create_media_items(upload_tokens_with_descriptions, album_id)
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
end
