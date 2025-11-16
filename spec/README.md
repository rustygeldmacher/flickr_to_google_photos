# Test Suite for FlickrToGooglePhotos

This directory contains the test suite for the FlickrToGooglePhotos gem, built with RSpec.

## Overview

The test suite is designed to thoroughly test the CLI interface and core functionality without making real API calls or modifying production data. It uses mocking and stubbing to simulate external services and user interactions.

## Structure

```
spec/
├── spec_helper.rb              # Main RSpec configuration
├── support/
│   ├── cli_helpers.rb         # Helper methods for CLI testing
│   └── fake_server.rb         # Mock web server for API calls
├── integration/
│   ├── config_command_spec.rb # Integration tests for config command
│   ├── auth_command_spec.rb   # Integration tests for auth command
│   └── cli_spec.rb           # General CLI behavior tests
└── unit/
    └── config_spec.rb         # Unit tests for Config class
```

## Key Testing Strategies

### Mocking External Services
- **HTTP Requests**: WebMock intercepts all HTTP calls to prevent real API requests
- **Google OAuth**: Mocked authorization flows with fake tokens and URLs
- **File Operations**: Uses temporary directories to avoid modifying real files

### Interactive CLI Testing
- **User Input**: Mocks `gets` to simulate user responses to prompts
- **Output Capture**: Captures stdout/stderr to verify command output
- **Exit Codes**: Tests proper exit codes for success/failure scenarios

### Test Data
- **Fake Config Files**: Creates temporary config.json files for testing
- **Sample Flickr Data**: Uses existing flickr/ directory data as realistic fixtures
- **Isolation**: Each test runs in its own temporary directory

## Running Tests

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/integration/config_command_spec.rb
bundle exec rspec spec/integration/auth_command_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

## Test Coverage

### Config Command Tests
- ✅ New configuration setup with user input
- ✅ Default path handling when user presses enter
- ✅ Empty credential validation and re-prompting
- ✅ Existing config backup and replacement
- ✅ User cancellation of config replacement
- ✅ File write error handling
- ✅ Help message display

### Auth Command Tests
- ✅ Interactive OAuth authorization flow
- ✅ Authorization code processing
- ✅ Existing credential validation
- ✅ Network error handling
- ✅ Missing configuration handling
- ✅ Integration with config command

### CLI Behavior Tests
- ✅ Help message display (multiple variations)
- ✅ Unknown command handling
- ✅ Command routing to correct handlers
- ✅ Argument passing between CLI and commands
- ✅ Exit code validation

### Config Class Unit Tests
- ✅ Configuration file reading/writing
- ✅ Path resolution and defaults
- ✅ Album tracking (imported/ignored)
- ✅ JSON serialization/deserialization
- ✅ Error handling for malformed files

## Design Principles

1. **No Real API Calls**: All external HTTP requests are mocked
2. **Isolated Tests**: Each test runs in a clean temporary environment
3. **Realistic Scenarios**: Tests cover real-world usage patterns
4. **Error Handling**: Comprehensive error scenario coverage
5. **Fast Execution**: Tests run quickly without network dependencies

## Adding New Tests

When adding new tests:

1. Use the helper methods in `spec/support/` for common operations
2. Mock all external services using WebMock
3. Use temporary directories for file operations
4. Follow the existing naming conventions and structure
5. Add both success and error scenarios for new functionality
