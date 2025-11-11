# flickr_to_google_photos

FlickrToGooglePhotos is a command line utility that helps you move your Flickr
photo albums into Google Photos.

It works by using your Flickr account's metadata to download each of your photos,
create a new album in Google Photos, and then upload each photo there.

## Prerequisites

### Download your Flickr account metadata

The first thing you need to do is go into Flickr and request your data. To do that:

* Follow the [instructions](https://www.flickrhelp.com/hc/en-us/articles/4404079675156-Downloading-content-from-Flickr#h_01K2YYSY0GQ4T8PXC8B47HQ97T)
  on Flickr's "Downloading content from Flickr" support page.
* You'll need to wait a bit (sometimes overnight) but eventually you'll get an email
  saying your download is ready.
* Click the link in the email, and find the section on the page titled "Your Flickr Data"
* Under "Account data" there will be a link to download a zip file. This has all of
  your Flickr metadata that Flickr2GooglePhotos will use.
* Download this zip file and keep it somewhere -- we'll use it later.

### Set up Google API access

To write...

## Installation

FlickrToGooglePhotos ships as a Ruby gem. Install it like this:

```
$ gem install flickr_to_google_photos
```

## Setup

With the prerequisites and installation out of the way, we can set up the project.

* Create a working directory and initialize the project

```
$ mkdir ~/flickr2gp
$ cd ~/flickr2gp
$ f2gp init
```

* This creates a file, `config.json` that is used to keep all of your settings.

... TODO: how to edit your config

* Now authenticate with Google:

```
$ f2gp auth
```

This will run you through Google's OAuth authentication flow, and will give you a
link to open in a browser. Click through the Google screens, give the app the permissions
it needs, and at the final screen, copy the authentication token it gives you. Paste
that token back into the CLI and you'll be authenticated.

## Start Importing Albums

By default, FlickrToGooglePhotos imports one album at a time. To import the next
album (or the first album, in the case you haven't imported any yet), just run:

```
$ f2gp import
```

You'll see some output, and at the end you will have a link to the newly imported
album in Google Photos. To continue importing, run `f2gp import` again and it will
import the next unimported album.

### Import a specific album

To import a specific Flickr album provide the `import` command an album name or ID:

```
# By ID
$ f2gp import --album 72157624544395867
# Or by name
$ f2gp import --album "Hawaii Vacation 2012"
```


### Import all albums

If you want to import all albums in one go, run:

```
$ f2gp import --all
```

This will run the importer for every remaining album. When importing all albums, by
default you won't be prompted to confirm the photo list before importing. To force
that behavior, specify interactive mode:

```
$ f2gp import --all --interactive
```

## See Information about Your Albums

### List your Flickr albums

To see all of your Flickr albums, run:

```
$ f2gp albums --list
```

The `list` option takes an optional `STATUS` flag:

* `all` (default) lists all Flickr albums
* `imported` lists all albums that have been imported
* `remaining` lists all albums that are yet to be imported
* `ignored` lists all ignored albums

## Ignore Albums

### Add an album to the ignore list

To make sure that `import` skips a given album, use the `ignore` command:

```
# By ID
$ f2gp ignore --album 72157624544395867
# Or by name
$ f2gp ignore --album "Deluth Vacation 2020"
```

The specified album will be skipped and `f2gp` will remember to ignore that
album in the future.

### Download a Flickr album

If you just want to download all of the photos for a Flickr album,
use the `--download` option:

```
$ f2gp albums --download <album-name-or-id>
```

This will download all of the photos from the given album and store them
in the album cache path, then
