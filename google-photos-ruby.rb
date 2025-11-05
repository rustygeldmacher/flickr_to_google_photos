#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

require_relative 'lib/google_photos/auth'
require_relative 'lib/google_photos/client'

SCOPE = 'https://www.googleapis.com/auth/photoslibrary.appendonly'

def upload_to_new_album(client, photos_array, album_title, album_description = nil)
  puts "\nStarting upload process..."
  puts "Photos to upload: #{photos_array.length}"

  # Upload all photos and collect tokens
  puts "\n1. Uploading photo bytes..."
  upload_tokens_with_descriptions = photos_array.map.with_index do |(file_path, description), index|
    print "  Uploading #{index + 1}/#{photos_array.length}: #{File.basename(file_path)}..."
    upload_token = client.upload_photo_bytes(file_path)
    puts " ✓"
    [upload_token, description]
  end

  puts "\n2. Creating album..."
  album = client.create_album(album_title)

  # Add text enrichment if description provided
  if album_description
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

begin
  # Load configuration
  config = JSON.parse(File.read('config.json'))
  credentials = GooglePhotos::Auth.new(
    config['clientId'],
    config['clientSecret'],
    SCOPE
  ).authorize

  client = GooglePhotosClient.new(credentials)

  # Array of [photo_file_path, photo_description]
  photos = [
    ['vacation_1.png', 'Beautiful sunset from day 1'],
    ['vacation_2.jpg', 'Beach view from day 2'],
  ]

  result = upload_to_new_album(
    client,
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
