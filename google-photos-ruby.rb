#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'exif'

require_relative 'lib/google_photos/auth'
require_relative 'lib/google_photos/client'

CACHE_PATH = "tmp"

def upload_to_new_album(client, photos, album_title, album_description = nil)
  puts "\nStarting upload process..."
  puts "Photos to upload: #{photos.length}"

  # Upload all photos and collect tokens
  puts "\n1. Uploading photo bytes..."
  upload_tokens_with_descriptions = photos.map.with_index do |photo, index|
    file_path = photo["path"]
    print "  Uploading #{index + 1}/#{photos.length}: #{File.basename(file_path)}..."
    upload_token = client.upload_photo_bytes(file_path)
    puts " ✓"
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

# Load configuration
config = JSON.parse(File.read('config.json'))
credentials = GooglePhotos::Auth.new(
  config['clientId'],
  config['clientSecret'],
).authorize

client = GooglePhotosClient.new(credentials)

# Load Flickr Albums
flickr_albums = JSON.parse(File.read('flickr/albums.json'))
album_title = "Arizona and Vegas"
album = flickr_albums['albums'].find { |a| a['title'] == album_title }
album_description = (album["description"] || "").gsub(/<\/?b>/, '')

# Ensure cache exists
FileUtils.mkdir_p("#{CACHE_PATH}/#{album["id"]}")

photos = album["photos"].map do |photo_id|
  # Not sure why this happens sometimes
  next if photo_id == "0"

  {
    "id" => photo_id,
  }
end.compact

puts "Uploading album: #{album["title"]}"
puts "Caching #{photos.count} photos locally..."

photos.each do |photo|
  photo_id = photo["id"]

  photo_json = JSON.parse(File.read("flickr/photo_#{photo_id}.json"))
  if (description = photo_json["description"])
    photo["description"] = description
  end

  photo_url = photo_json["original"]
  photo["url"] = photo_url

  ext = File.extname(photo_url)
  photo_file = "#{CACHE_PATH}/#{album["id"]}/#{photo_json["name"]}#{ext}"
  photo["path"] = photo_file
end

photos.sort_by! { |p| p["path"] }

photos.each do |photo|
  photo_url = photo["url"]
  photo_file = photo["path"]

  unless File.exist?(photo_file)
    puts "Downloading #{File.basename(photo_file)} (#{photo_url})"
    File.open(photo_file, 'wb') do |file|
      file.write(Net::HTTP.get(URI(photo_url)))
    end
  end
end

photos.each do |photo|
  photo_file = photo["path"]

  File.open(photo_file) do |f|
    exif = Exif::Data.new(f)
    puts "* #{photo_file} taken #{exif.date_time_original} - #{photo["description"]}"
  end
end

puts "Files ready to upload, continue? (y/n)"
continue = gets.chomp
if continue != "y"
  puts "Exiting..."
  exit
end

result = upload_to_new_album(
  client,
  photos,
  album_title,
  album_description
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
