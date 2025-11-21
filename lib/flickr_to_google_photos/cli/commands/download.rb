module FlickrToGooglePhotos::CLI::Commands
  class Download
    attr_reader :argv

    def initialize(argv = [])
      @argv = argv
    end

    def run(album: nil)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} download [--album ALBUM_NAME]"
        opts.on("--album ALBUM_NAME", "Name or ID of Flickr album to import") do |album_name_or_id|
          album = find_album(album_name_or_id)
          if album.nil?
            return 1
          end
        end
        opts.on("-h", "--help", "Show this help message") do
          puts opts
          return 0
        end
      end.parse!(argv)

      if album.nil?
        puts "Please specify an album to download"
        return 1
      end

      download_album(album)
    end

    private

    def find_album(album_name_or_id)
      album = FlickrToGooglePhotos::Flickr::Albums.get_album(album_name_or_id)
      if album
        puts "Downloading album: #{album.title}"
      else
        puts "Cannot find album: #{album_name_or_id}"
      end
      album
    end

    def download_album(album)
      cache_path = FlickrToGooglePhotos.config.photo_cache_path

      # Ensure cache exists
      FileUtils.mkdir_p("#{cache_path}/#{album.id}")

      # First, determine which photos need to be downloaded
      photos_to_download = []
      album.photos.each do |photo|
        photo.physical_path = "#{cache_path}/#{album.id}/#{photo.file_name}"
        photos_to_download << photo unless File.exist?(photo.physical_path)
      end

      # If no photos need downloading, we're done
      if photos_to_download.empty?
        puts "✓ All photos are already downloaded."
        return 0
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

      return 0
    end
  end
end
