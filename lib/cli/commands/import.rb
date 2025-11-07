module Flicker2GooglePhotos
  class Import
    attr_reader :client, :photos, :album_title, :album_description

    def initialize(client:, photos:, album_title:, album_description: nil)
      @client = client
      @photos = photos
      @album_title = album_title
      @album_description = album_description
    end

    def execute
      puts "\nStarting upload process..."
      puts "Photos to upload: #{photos.length}"

      # Upload all photos and collect tokens
      puts "\n1. Uploading photo bytes..."
      upload_tokens_with_descriptions = photos.map.with_index do |photo, index|
        file_path = photo["path"]
        print "  Uploading #{index + 1}/#{photos.length}: #{File.basename(file_path)}..."
        upload_token = client.upload_photo_bytes(file_path)
        puts " OK"
        [upload_token, photo["description"]]
      end

      puts "\n2. Creating album..."
      album = client.create_album(album_title)

      # Add text enrichment if description provided
      unless album_description.nil? || album_description.empty?
        puts "\n3. Adding album description..."
        client.add_text_enrichment(album['id'], album_description)
      end

      puts "\n#{album_description ? '4' : '3'}. Adding photos to album..."
      media_items = client.create_media_items(upload_tokens_with_descriptions, album['id'])

      puts "\n✅ Complete! Album ID: #{album['id']}"
      if media_items.first && media_items.first['productUrl']
        puts "Album URL: #{media_items.first['productUrl'].split('/').first(4).join('/')}"
      end

      {
        album: album,
        media_items: media_items
      }
    end
  end
end
