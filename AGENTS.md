# AGENTS.md

* Read the file `README.md` for an overview of this project, what it does, and how it
works from a user perspective.

## Tech stack

* This project is implemented as a Ruby gem

## Setup

* Install dependencies: `bundle install`

## Architecture

* The gem is more or less split into two pieces: the CLI and the library.
* The CLI is responsible for parsing user input, determining the course of
  action, using the library to orchestrate that action, and communicating
  status back to the user
* The library is responsible for the lower level logic that implements the
  various operations the CLI will need.
* The CLI can use the library, but the library cannot know anything about
  the CLI
* Never print output from a library class, only print output in CLI context

## CLI

* Invoking the CLI always takes the form of `f2gp <command> [options]`
* The command is always the first argument, with one exception: a user can
  run `f2gp --help` to print the help message.
* The global help is just an alias to the `help` command (ie, `f2gp help`)
* Command are implemented in their own classes, with their own options parsing
* Every command should have a `--help` option

## Configuration and state

* We NEVER want to modify the JSON files in the top-level flickr/ directory
* All state is stored and managed in config.json, which is ALWAYS accessed
  through the FlickrToGooglePhotos::Config class
* When trying to find files based on relative path, use the config class and
  make default paths relative to config.json
