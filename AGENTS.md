# AGENTS.md

* The file `README.md` has an overview of this project, what it does, and how it
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

## Testing

* Use RSpec for testing
* Never make actual network calls during test execution
* There are helpers for creating fake configs and flickr data in `spec/support/cli_helpers`
* Never run `f2gp` directly in tests. Invoke commands using the
  `run_command` method in `cli_helpers.rb`
* Do not mock filesystem operations. Each spec runs in its own temp directory, so it
  is safe to create, edit, and remove files as needed
* Do not over-test -- there's no need to introduce another test case when an
  existing case can have an assertion added to it
* Never mock the low-level Flickr classes (Album, Photo, etc.) -- use generated test
  data instead

## Ruby code style

* Use the Ruby "single-indent" style for multi-line method calls and data structures
* Prefer using double-quoted strings unless there's a specific need for single quotes
* For strings requiring multi-line output (more than 2 or 3 lines), use heredocs with `<<~`
