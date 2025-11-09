require 'tty-screen'

module FlickrToGooglePhotos::CLI::Commands
  class Import
    CACHE_PATH = "tmp"

    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

    def run
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
    rescue GooglePhotos::Auth::NotAuthenticated
      puts <<~MESSAGE


        Error: Not authenticated with Google Photos!
        ============================================

        To authenticate with Google Photos, make sure you've got your client ID
        and client secret configured in config.json, and then run:

        #{$0} auth

        Which will run through the Google Photos OAuth flow and save your
        credentials.
      MESSAGE
      return 1
    end

    def execute(options)
      album = find_album_to_import(options)

      if album.nil?
        return 1
      end

      header = "Importing album: #{album.title}"
      puts header
      puts "=" * header.size
      puts

      cache_photos(album)
      unless show_files_and_confirm(album)
        return 1
      end

      upload_photos(album)

      puts "\n2. Creating album..."
      gp_album = google_photos_client.create_album(album.title)

      # Add text enrichment if description provided
      unless (album.description || "").empty?
        puts "\n3. Adding album description..."
        google_photos_client.add_text_enrichment(gp_album["id"], album.description)
      end

      puts "\n#{album.description ? '4' : '3'}. Adding photos to album..."
      google_photos_client.create_media_items(album, gp_album["id"])

      # Set album cover if Flickr album has one
      set_album_cover(album, gp_album["id"])

      puts "\n" + "=" * 60
      puts "✅ SUCCESS!"
      puts "* Album Title: #{gp_album['title']}"
      puts "* Album URL: #{gp_album["productUrl"]}"
      puts "* Photos uploaded: #{album.photos.count}"
      puts "=" * 60

      FlickrToGooglePhotos.config.track_imported_album(
        title: album.title,
        flickrAlbumId: album.id,
        googlePhotosAlbumId: gp_album["id"]
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

      album.photos.each.with_index do |photo, index|
        progress_bar.advance(0, title: photo.file_name)

        upload_token = google_photos_client.upload_photo_bytes(photo.physical_path)

        if (index + 1) < album.photos.size
          progress_bar.advance
        else
          progress_bar.advance(title: "Done!")
        end

        photo.upload_token = upload_token
      end

      progress_bar.finish
    end

    def show_files_and_confirm(album)
      # Calculate dynamic column widths
      terminal_width = TTY::Screen.width rescue 80
      filename_width = album.photos.map(&:file_name).max_by(&:length).length
      date_width = 20

      # Account for table borders, padding, and separators
      # Unicode table uses: |<space>content<space>|<space>content<space>|<space>content<space>|
      table_overhead = 8  # 3 separators + 6 spaces for padding
      description_width = terminal_width - filename_width - date_width - table_overhead

      # Ensure minimum widths
      description_width = [description_width, 20].max

      table_data = album.photos.each_with_object([]) do |photo, data|
        File.open(photo.physical_path) do |f|
          date_taken = nil
          begin
            exif = Exif::Data.new(f)
            date_taken = exif.date_time_original
          rescue
            # Missing or corrupted EXIF data
          end

          # Format each field to exact column width
          description = photo.description || ""
          if description.length > description_width
            description = description[0, description_width - 4] + "..."
          end

          data << [
            photo.file_name,
            date_taken,
            description
          ]
        end
      end

      # Create and display table with pre-formatted content
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

    def set_album_cover(album, google_album_id)
      cover_photo = album.cover_photo
      return unless cover_photo

      puts "\n#{album.description ? '5' : '4'}. Setting album cover..."

      if cover_photo.media_item
        begin
          google_photos_client.update_album_cover(
            google_album_id,
            cover_photo.media_item.dig("mediaItem", "id")
          )
          puts "✓ Album cover photo set"
        rescue => e
          puts "⚠ Failed to set album cover: #{e.message}"
        end
      else
        puts "⚠ Cover photo not found in uploaded photos"
      end
    end
  end
end
