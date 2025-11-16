require_relative 'lib/flickr_to_google_photos/version'

Gem::Specification.new do |spec|
  spec.name          = "flickr_to_google_photos"
  spec.version       = FlickrToGooglePhotos::VERSION
  spec.authors       = ["Rusty Geldmacher"]
  spec.email         = []

  spec.summary       = "Command-line tool to migrate Flickr albums to Google Photos"
  spec.description   = "A Ruby gem that helps you move your Flickr photo albums into Google Photos by using Flickr metadata to download photos and create corresponding albums in Google Photos."
  spec.homepage      = "https://github.com/rustygeldmacher/flickr_to_google_photos"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rustygeldmacher/flickr_to_google_photos"
  spec.metadata["bug_tracker_uri"] = "https://github.com/rustygeldmacher/flickr_to_google_photos/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files         = Dir.glob("{bin,lib}/**/*") + %w[README.md flickr_to_google_photos.gemspec Gemfile]
  spec.bindir        = "bin"
  spec.executables   = ["f2gp"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_runtime_dependency "googleauth"
  spec.add_runtime_dependency "exif"
  spec.add_runtime_dependency "tty-table"
  spec.add_runtime_dependency "tty-progressbar"
  spec.add_runtime_dependency "tty-screen"

  # Development dependencies
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"

  spec.required_ruby_version = ">= 2.6.0"
end
