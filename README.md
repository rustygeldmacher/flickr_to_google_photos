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

This might be the trickiest part of the setup. There is a
[guide](https://developers.google.com/photos/overview/configure-your-app) on Google's
Developer hub that walks you through it, but we'll cover the basics here.

First you'll want to go to the
[Google Cloud Console](https://console.cloud.google.com/) and create a new project by using
the project picker in the upper left of the screen.

Then go to the [API Library](https://console.developers.google.com/apis/library) section of
the console. Make sure your new project is selected and then search for "Photos". Select
the "Google Photos Library API". Click "Enable" in the screen that brings you to.

Now create a desktop app. Click "Credentials" on the left side of the screen. Click the
"Configure Consent Screen" button if it appears. Give it some info about the app, then
in the Audience section select "External". Give it contact info and then agree to the
terms. After this go back to the [Credentials](https://console.cloud.google.com/apis/credentials)
section.

Click "Create Credentials" on the upper nav bar, and select "OAuth Client ID". Under
"Application Type" click "Desktop App". Give it any name you want. A pop-up saying
"OAuth client created" should appear. Copy both the "Client ID" and the "Client Secret" that
are shown in this box. Save these for later, because we'll need to use them in the
configuration step.

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
$ f2gp config
```

* This will ask you a few questions and then create a file, `config.json`
  that is used to keep all of your settings.

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
$ f2gp album
```

The `albums` command takes an optional `--status` flag:

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
use the `download` command:

```
$ f2gp download --album <album-name-or-id>
```

This will download all of the photos from the given album and store them
in the album cache path.
