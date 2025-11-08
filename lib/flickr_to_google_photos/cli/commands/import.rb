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

      puts "Importing album: #{album.title}"

      cache_photos(album)
      unless show_files_and_confirm(album)
        return 1
      end

      upload_tokens_with_descriptions = upload_photos(album)

      puts "\n2. Creating album..."
      gp_album = google_photos_client.create_album(album.title)

      # Add text enrichment if description provided
      unless (album.description || "").empty?
        puts "\n3. Adding album description..."
        google_photos_client.add_text_enrichment(gp_album["id"], album.description)
      end

      puts "\n#{album.description ? '4' : '3'}. Adding photos to album..."
      media_items = google_photos_client.create_media_items(upload_tokens_with_descriptions, gp_album["id"])

      puts "\n✅ Complete!"

      result = {
        album: gp_album,
        media_items: media_items
      }

      puts "\n" + "="*60
      puts "SUCCESS!"
      puts "Album Title: #{result[:album]['title']}"
      puts "Album URL: #{gp_album["productUrl"]}"
      puts "Photos uploaded: #{result[:media_items].count}"
      puts "="*60

      FlickrToGooglePhotos.config.track_imported_album(
        title: album.title,
        flickrAlbumId: album.id,
        googlePhotosAlbumId: result[:album]["id"]
      )
    end

    def google_photos_client
      @google_photos_client ||= begin
        credentials = GooglePhotos::Auth.new.authorize
        GooglePhotosClient.new(credentials)
      end
    end

    def find_album_to_import(options)
      album = nil
      if options[:next]
        album = FlickrToGooglePhotos::Flickr::Albums.next_unimported_album
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

    # TODO: Extract to class FlickrToGooglePhotos::Flickr::AlbumCache
    def cache_photos(album)
      # Ensure cache exists
      FileUtils.mkdir_p("#{CACHE_PATH}/#{album.id}")

      # First, determine which photos need to be downloaded
      photos_to_download = []
      album.photos.each do |photo|
        photo.physical_path = "#{CACHE_PATH}/#{album.id}/#{photo.file_name}"
        photos_to_download << photo unless File.exist?(photo.physical_path)
      end

      # If no photos need downloading, we're done
      if photos_to_download.empty?
        puts "All photos are already downloaded."
        return
      end

      puts "Downloading #{album.photos.count} photos..."

      # Create progress bar for downloads
      progress_bar = TTY::ProgressBar.new(
        "Downloading [:bar] :current/:total :percent :title",
        total: photos_to_download.length,
        bar_format: :block
      )

      photos_to_download.each.with_index do |photo, i|
        progress_bar.advance(0, title: photo.file_name)

        File.open(photo.physical_path, 'wb') do |file|
          file.write(Net::HTTP.get(URI(photo.url)))
        end

        if (i + 1) < photos_to_download.size
          progress_bar.advance
        else
          progress_bar.advance(title: "Done!")
        end
      end

      progress_bar.finish
    end

    def upload_photos(album)
      puts "1. Uploading photos..."

      progress_bar = TTY::ProgressBar.new(
        "Uploading [:bar] :current/:total :percent :title",
        total: album.photos.size,
        bar_format: :block
      )

      upload_tokens_with_descriptions = album.photos.map.with_index do |photo, index|
        progress_bar.advance(0, title: photo.file_name)

        upload_token = google_photos_client.upload_photo_bytes(photo.physical_path)

        if (index + 1) < album.photos.size
          progress_bar.advance
        else
          progress_bar.advance(title: "Done!")
        end

        [upload_token, photo.description]
      end

      progress_bar.finish

      upload_tokens_with_descriptions
    end

    def show_files_and_confirm(album)
      table_data = album.photos.each_with_object([]) do |photo, data|
        File.open(photo.physical_path) do |f|
          exif = Exif::Data.new(f)
          data << [
            photo.file_name,
            exif.date_time_original,
            photo.description
          ]
        end
      end

      # Create and display table
      table = TTY::Table.new(
        header: ['Filename', 'Date', 'Description'],
        rows: table_data
      )

      puts table.render(:unicode, padding: [0, 1])

      puts "#{album.photos.size} files ready to upload, continue? (Y/n)"

      continue = gets.chomp
      if !["y", ""].include?(continue)
        puts "Exiting..."
        return false
      end

      return true
    end
  end
end
