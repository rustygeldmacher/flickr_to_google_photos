require 'tty-screen'

module FlickrToGooglePhotos::CLI::Commands
  class Import
    attr_reader :argv

    def initialize(argv)
      @argv = argv
      @current_step = 0
    end

    def run
      options = {
        album: nil,
        next: false,
        all: false,
        interactive: nil
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [--next | --album ALBUM_NAME | --all]"
        opts.on("--next", "Import the next unimported album (default)") do
          options[:next] = true
        end
        opts.on("--album ALBUM_NAME", "Name or ID of Flickr album to import") do |album|
          options[:album] = album
        end
        opts.on("--all", "Import all remaining unimported albums") do
          options[:all] = true
        end
        opts.on("-i", "--[no-]interactive", "Run in interactive mode (default: true for single albums, false for --all)") do |bool|
          options[:interactive] = bool
        end
      end.parse!(argv)

      # Validate mutual exclusion
      exclusive_options = [options[:next], options[:album], options[:all]].select(&:itself).count
      if exclusive_options > 1
        puts "Error: Cannot specify more than one of --next, --album, or --all options"
        return 1
      end

      # Set default to --next if no options specified
      if exclusive_options == 0
        options[:next] = true
      end

      # Set interactive default based on mode
      if options[:interactive].nil?
        options[:interactive] = !options[:all]  # false for --all, true otherwise
      end

      execute(options)
    rescue GooglePhotos::Auth::NotAuthenticated, Signet::AuthorizationError
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
      if options[:all]
        execute_all_albums(options)
      else
        album = find_album_to_import(options)
        return 1 if album.nil?

        import_single_album(album, options)
      end
    end

    def execute_all_albums(options)
      imported_count = 0
      failed_albums = []
      last_attempted_album_id = nil

      puts "Starting import of all remaining albums..."
      puts "=" * 50
      puts

      loop do
        album = FlickrToGooglePhotos::Flickr::Albums.next_unimported_album(starting_after: last_attempted_album_id)
        break if album.nil?

        puts "Importing album #{imported_count + 1}: #{album.title}"
        puts "-" * 40

        # Track this album ID so we can skip past it if the import fails or user declines
        last_attempted_album_id = album.id

        begin
          result = import_single_album(album, options)
          if result == 0
            imported_count += 1
            puts "✅ Album imported successfully\n"
          else
            failed_albums << album.title
            puts "❌ Album import failed\n"
          end
        rescue => e
          failed_albums << album.title
          puts "❌ Album import failed with error: #{e.message}\n"
        end
      end

      puts "\n" + "=" * 60
      puts "🎉 BATCH IMPORT COMPLETE!"
      puts "* Albums successfully imported: #{imported_count}"
      if failed_albums.any?
        puts "* Albums failed: #{failed_albums.size}"
        puts "* Failed albums: #{failed_albums.join(', ')}"
      end
      puts "=" * 60

      failed_albums.any? ? 1 : 0
    end

    def import_single_album(album, options)
      header = "Importing album: #{album.title}"
      puts header
      puts "=" * header.size
      puts

      FlickrToGooglePhotos::CLI::Commands::Download.new.run(album: album)
      unless show_files_and_confirm(album, options[:interactive])
        return 1
      end

      step("Uploading photos")
      upload_photos(album)

      step("Creating album")
      gp_album = google_photos_client.create_album(album.title)

      # Add text enrichment if description provided
      unless (album.description || "").empty?
        step("Adding album description")
        google_photos_client.add_text_enrichment(gp_album["id"], album.description)
      end

      step("Adding photos to album")
      google_photos_client.create_media_items(album, gp_album["id"])

      # Set album cover if Flickr album has one
      if (album.cover_photo)
        step("Setting album cover")
        set_album_cover(album.cover_photo, gp_album["id"])
      end

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

      return 0
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

    def upload_photos(album)
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

    def show_files_and_confirm(album, interactive)
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

      if interactive
        puts "#{album.photos.size} files ready to upload, continue? (Y/n)"

        continue = gets.chomp
        if !["y", ""].include?(continue)
          return false
        end
      end

      return true
    end

    def set_album_cover(cover_photo, google_album_id)
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

    def google_photos_client
      @google_photos_client ||= begin
        credentials = GooglePhotos::Auth.new.authorize
        GooglePhotosClient.new(credentials)
      end
    end

    def step(step_name)
      @current_step += 1
      puts
      puts "#{@current_step}. #{step_name}..."
    end
  end
end
