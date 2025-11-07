module FlickrToGooglePhotos::CLI::Commands
  class Import
    CACHE_PATH = "tmp"

    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
      # Parse command line options
      options = {
        album: nil,
        next: false
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [--next | --album ALBUM_NAME]"
        opts.on("--next", "Import the next unimported album (default)") do
          options[:next] = true
        end
        opts.on("--album ALBUM_NAME", "Name or ID of Flickr album to import") do |album|
          options[:album] = album
        end
      end.parse!

      # Validate mutual exclusion
      if options[:next] && options[:album]
        puts "Error: Cannot specify both --next and --album options"
        return 1
      end

      # Set default to --next if no options specified
      if !options[:next] && !options[:album]
        options[:next] = true
      end

      execute(options)
    end

    def execute(options)
      album = find_album_to_import(options)

      if album.nil?
        return 1
      end

      credentials = GooglePhotos::Auth.new(
        config['clientId'],
        config['clientSecret'],
      ).authorize

      client = GooglePhotosClient.new(credentials)

      puts "Uploading album: #{album.title}"

      cache_photos(album)
      unless show_files_and_confirm(album)
        return 1
      end

      puts "\nStarting upload process..."
      puts "Photos to upload: #{album.photos.length}"

      # Upload all photos and collect tokens
      puts "\n1. Uploading photo bytes..."
      upload_tokens_with_descriptions = album.photos.map.with_index do |photo, index|
        print "  Uploading #{index + 1}/#{album.photos.length}: #{photo.file_name}..."
        upload_token = client.upload_photo_bytes(photo.physical_path)
        puts " OK"
        [upload_token, photo.description]
      end

      puts "\n2. Creating album..."
      gp_album = client.create_album(album.title)

      # Add text enrichment if description provided
      unless album.description.nil? || album.description.empty?
        puts "\n3. Adding album description..."
        client.add_text_enrichment(gp_album["id"], album.description)
      end

      puts "\n#{album.description ? '4' : '3'}. Adding photos to album..."
      media_items = client.create_media_items(upload_tokens_with_descriptions, gp_album["id"])

      puts "\n✅ Complete! Album ID: #{gp_album['id']}"
      if media_items.first && media_items.first['productUrl']
        puts "Album URL: #{media_items.first['productUrl'].split('/').first(4).join('/')}"
      end

      result = {
        album: gp_album,
        media_items: media_items
      }

      puts "\n" + "="*60
      puts "SUCCESS!"
      puts "="*60
      puts "Album ID: #{result[:album]['id']}"
      puts "Album Title: #{result[:album]['title']}"
      puts "Photos uploaded: #{result[:media_items].count}"
      result[:media_items].each_with_index do |item, idx|
        puts "  #{idx + 1}. #{item['filename']} (ID: #{item['id']})"
      end

      # Add this to Config class
      config['importedAlbums'] ||= []
      config['importedAlbums'] << {
        "title" => album.title,
        "flickrId" => album.id,
        "googlePhotosId" => result[:album]["id"]
      }

      json = JSON.pretty_generate(config)
      File.write('config.json', json)
    end

    def config
      # TODO: Make this a class FlickrToGooglePhotos::Config
      @config ||= JSON.parse(File.read('config.json'))
    end

    def find_album_to_import(options)
      album = nil
      if options[:next]
        puts "Finding next unimported album to import..."
        imported_album_ids = Array(config['importedAlbums']).map { |album| album['flickrId'] }
        imported_albums = Set.new(imported_album_ids)
        album = FlickrToGooglePhotos::Flickr::Albums.find do |album|
          !imported_albums.include?(album.id)
        end
        if album.nil?
          puts "Error: No more albums to import"
        end
      elsif options[:album]
        album_name_or_id = options[:album]
        album = FlickrToGooglePhotos::Flickr::Albums.get_album(album_name_or_id)
        if album.nil?
          puts "Error: Album '#{album_name_or_id}' not found"
        end
      end
      album
    end

    def cache_photos(album)
      # TODO: Extract to class FlickrToGooglePhotos::Flickr::AlbumCache
      puts "Caching #{album.photos.count} photos locally..."

      # Ensure cache exists
      FileUtils.mkdir_p("#{CACHE_PATH}/#{album.id}")

      album.photos.each do |photo|
        photo.physical_path = "#{CACHE_PATH}/#{album.id}/#{photo.file_name}"

        unless File.exist?(photo.physical_path)
          puts "Downloading #{photo.file_name} (#{photo.url})"
          File.open(photo.physical_path, 'wb') do |file|
            file.write(Net::HTTP.get(URI(photo.url)))
          end
        end
      end
    end

    def show_files_and_confirm(album)
      album.photos.each do |photo|
        File.open(photo.physical_path) do |f|
          exif = Exif::Data.new(f)
          puts "* #{photo.physical_path} taken #{exif.date_time_original} - #{photo.description}"
        end
      end

      puts "Files ready to upload, continue? (y/n)"
      continue = gets.chomp
      if continue != "y"
        puts "Exiting..."
        return false
      end

      return true
    end
  end
end
