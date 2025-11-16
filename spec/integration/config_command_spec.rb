# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'config command', type: :integration do
  describe 'f2gp config' do
    context 'when no existing config exists' do
      it 'creates a new config file with user input' do
        mock_gets_with(
          'test_client_id',
          'test_client_secret',
          'custom_flickr',
          'custom_cache'
        )

        result = run_command('config')

        expect(result).to be_success
        expect(result.stdout).to include('FLICKR TO GOOGLE PHOTOS - CONFIGURATION SETUP')
        expect(result.stdout).to include('Enter your Google API Project Client ID:')
        expect(result.stdout).to include('Enter your Google API Project Client Secret:')
        expect(result.stdout).to include('Where is your Flickr data located?')
        expect(result.stdout).to include('Where should the photo cache be stored?')
        expect(result.stdout).to include('✓ Configuration saved to config.json')
        expect(result.stdout).to include("Next steps:")
        expect(result.stdout).to include("Run 'f2gp auth' to authenticate")

        # Verify config file was created correctly
        expect(File.exist?('config.json')).to be true
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['googleClientId']).to eq('test_client_id')
        expect(config_data['googleClientSecret']).to eq('test_client_secret')
        expect(config_data['flickrDataPath']).to eq('custom_flickr')
        expect(config_data['photoCachePath']).to eq('custom_cache')
      end

      it 'uses default paths when user presses enter' do
        mock_gets_with(
          'test_client_id',
          'test_client_secret',
          '',  # Use default flickr path
          ''   # Use default cache path
        )

        result = run_command('config')

        expect(result).to be_success
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['flickrDataPath']).to eq('flickr')
        expect(config_data['photoCachePath']).to eq('photo-cache')
      end

      it 'handles empty client ID by prompting again' do
        mock_gets_with(
          '',              # Empty client ID first time
          'valid_client_id', # Valid client ID second time
          'test_client_secret',
          '',
          ''
        )

        result = run_command('config')

        expect(result).to be_success
        expect(result.stdout).to include('Client ID cannot be empty')
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['googleClientId']).to eq('valid_client_id')
      end

      it 'handles empty client secret by prompting again' do
        mock_gets_with(
          'test_client_id',
          '',                    # Empty client secret first time
          'valid_client_secret', # Valid client secret second time
          '',
          ''
        )

        result = run_command('config')

        expect(result).to be_success
        expect(result.stdout).to include('Client Secret cannot be empty')
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['googleClientSecret']).to eq('valid_client_secret')
      end
    end

    context 'when existing config exists' do
      before do
        create_fake_config(
          "googleClientId" => "old_client_id",
          "googleClientSecret" => "old_client_secret"
        )
      end

      it 'offers to backup and replace existing config when user confirms' do
        mock_gets_with(
          'y',               # Confirm replacement
          'new_client_id',
          'new_client_secret',
          '',
          ''
        )

        result = run_command('config')

        expect(result).to be_success
        expect(result.stdout).to include('Found existing config.json file')
        expect(result.stdout).to include('Do you want to replace it?')
        expect(result.stdout).to include('✓ Backed up existing config to config.json.bak')
        expect(result.stdout).to include('✓ Configuration saved to config.json')

        # Verify backup was created
        expect(File.exist?('config.json.bak')).to be true
        backup_data = JSON.parse(File.read('config.json.bak'))
        expect(backup_data['googleClientId']).to eq('old_client_id')

        # Verify new config was created
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['googleClientId']).to eq('new_client_id')
      end

      it 'cancels setup when user declines to replace existing config' do
        mock_gets_with('n')  # Decline replacement

        result = run_command('config')

        expect(result).to be_success
        expect(result.stdout).to include('Found existing config.json file')
        expect(result.stdout).to include('Config setup cancelled')

        # Verify original config is unchanged
        config_data = JSON.parse(File.read('config.json'))
        expect(config_data['googleClientId']).to eq('old_client_id')
        expect(File.exist?('config.json.bak')).to be false
      end

      it 'handles yes/y/no/n variations for confirmation' do
        mock_gets_with(
          'yes',  # Full word confirmation
          'new_client_id',
          'new_client_secret',
          '',
          ''
        )

        result = run_command('config')

        expect(result).to be_success
        expect(result.stdout).to include('✓ Backed up existing config')
      end
    end

    context 'help option' do
      it 'displays help message' do
        result = run_command('config', '--help')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
        expect(result.stdout).to include('Initialize a new config.json file')
        expect(result.stdout).to include('This command will:')
        expect(result.stdout).to include('Check for existing config.json')
        expect(result.stdout).to include('Prompt for Google API credentials')
      end

      it 'displays help with -h flag' do
        result = run_command('config', '-h')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
      end
    end
  end
end
