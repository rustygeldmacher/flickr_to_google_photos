# frozen_string_literal: true

module FakeServer
  # Mock Google OAuth URLs and responses
  def stub_google_oauth_flow
    # Mock the authorization URL generation
    stub_request(:any, /accounts\.google\.com/)
      .to_return(status: 200, body: "Mock OAuth page", headers: {})

    # Mock the token exchange
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(
        status: 200,
        body: {
          access_token: "fake_access_token",
          refresh_token: "fake_refresh_token",
          expires_in: 3600,
          token_type: "Bearer"
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock Google Photos API discovery
    stub_request(:get, /www\.googleapis\.com.*discovery/)
      .to_return(
        status: 200,
        body: {
          name: "photoslibrary",
          version: "v1",
          baseUrl: "https://photoslibrary.googleapis.com/"
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Mock Google Photos API endpoints
  def stub_google_photos_api
    # Mock albums list
    stub_request(:get, "https://photoslibrary.googleapis.com/v1/albums")
      .to_return(
        status: 200,
        body: {
          albums: [
            {
              id: "fake_album_id_1",
              title: "Test Album 1",
              productUrl: "https://photos.google.com/album/fake_album_id_1"
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock album creation
    stub_request(:post, "https://photoslibrary.googleapis.com/v1/albums")
      .to_return(
        status: 200,
        body: {
          id: "new_fake_album_id",
          title: "New Test Album",
          productUrl: "https://photos.google.com/album/new_fake_album_id"
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Mock file download requests
  def stub_photo_downloads
    stub_request(:get, /example\.com.*\.jpg/)
      .to_return(
        status: 200,
        body: "fake photo content",
        headers: { 'Content-Type' => 'image/jpeg' }
      )
  end

  # Mock error responses
  def stub_network_errors(url_pattern)
    stub_request(:any, url_pattern)
      .to_raise(StandardError.new("Network error"))
  end

  def stub_auth_errors
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(status: 401, body: { error: "invalid_grant" }.to_json)
  end
end

RSpec.configure do |config|
  config.include FakeServer
end
