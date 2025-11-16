# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'auth command', type: :integration do
  let(:fake_auth_url) { 'https://accounts.google.com/oauth/authorize?fake=params' }
  let(:fake_auth_code) { 'fake_authorization_code_12345' }

  before do
    # Create a valid config file for auth to work
    create_fake_config
    stub_google_oauth_flow
  end

  describe 'f2gp auth' do
    context 'when no existing credentials exist' do
      before do
        # Mock GooglePhotos::Auth class
        allow_any_instance_of(GooglePhotos::Auth).to receive(:authorize)
          .and_raise(GooglePhotos::Auth::NotAuthenticated)
        allow_any_instance_of(GooglePhotos::Auth).to receive(:authorization_url)
          .and_return(fake_auth_url)
        allow_any_instance_of(GooglePhotos::Auth).to receive(:save_authorization_code)
          .and_return(true)
      end

      it 'guides user through interactive authorization flow' do
        mock_gets_with(fake_auth_code)

        result = run_command('auth')

        expect(result).to be_success
        expect(result.stdout).to include('GOOGLE API AUTHENTICATION')
        expect(result.stdout).to include('Visit this URL to authorize')
        expect(result.stdout).to include(fake_auth_url)
        expect(result.stdout).to include('Copy the authorization code')
        expect(result.stdout).to include('Enter the authorization code:')
        expect(result.stdout).to include('✓ Authorization successful! Credentials saved.')
      end

      it 'passes the authorization code to the auth service' do
        auth_instance = instance_double(GooglePhotos::Auth)
        allow(GooglePhotos::Auth).to receive(:new).and_return(auth_instance)
        allow(auth_instance).to receive(:authorize)
          .and_raise(GooglePhotos::Auth::NotAuthenticated)
        allow(auth_instance).to receive(:authorization_url)
          .and_return(fake_auth_url)
        expect(auth_instance).to receive(:save_authorization_code)
          .with(fake_auth_code)

        mock_gets_with(fake_auth_code)

        result = run_command('auth')

        expect(result).to be_success
      end
    end

    context 'when existing valid credentials exist' do
      before do
        # Mock successful authorization with existing credentials
        allow_any_instance_of(GooglePhotos::Auth).to receive(:authorize)
          .and_return(double('credentials'))
      end

      it 'succeeds immediately without prompting for authorization' do
        result = run_command('auth')

        expect(result).to be_success
        expect(result.stdout).to include('✓ Authorized with saved credentials.')
        expect(result.stdout).not_to include('Visit this URL')
        expect(result.stdout).not_to include('Enter the authorization code')
      end
    end

    context 'error handling' do
      before do
        allow_any_instance_of(GooglePhotos::Auth).to receive(:authorize)
          .and_raise(GooglePhotos::Auth::NotAuthenticated)
        allow_any_instance_of(GooglePhotos::Auth).to receive(:authorization_url)
          .and_return(fake_auth_url)
      end

      it 'handles authorization errors gracefully' do
        allow_any_instance_of(GooglePhotos::Auth).to receive(:save_authorization_code)
          .and_raise(StandardError.new('Invalid authorization code'))

        mock_gets_with(fake_auth_code)

        result = run_command('auth')

        expect(result.exit_code).to eq(1)
        expect(result.stderr).to include('Error: StandardError: Invalid authorization code')
      end

      it 'handles network errors during authorization URL generation' do
        allow_any_instance_of(GooglePhotos::Auth).to receive(:authorization_url)
          .and_raise(StandardError.new('Network error'))

        result = run_command('auth')

        expect(result.exit_code).to eq(1)
        expect(result.stderr).to include('Error: StandardError: Network error')
      end
    end

    context 'missing configuration' do
      before do
        # Remove config file to test missing configuration
        File.delete('config.json') if File.exist?('config.json')
      end

      it 'handles missing config file gracefully' do
        result = run_command('auth')

        expect(result.exit_code).to eq(1)
        expect(result.stderr).to include('Error')
      end
    end

    context 'help option' do
      it 'displays help message' do
        result = run_command('auth', '--help')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
        expect(result.stdout).to include('Authenticate with Google Photos API')
        expect(result.stdout).to include('This command will:')
        expect(result.stdout).to include('Check for existing saved credentials')
        expect(result.stdout).to include('open a browser authorization flow')
        expect(result.stdout).to include('Save the authorization for future use')
      end

      it 'displays help with -h flag' do
        result = run_command('auth', '-h')

        expect(result).to be_success
        expect(result.stdout).to include('Usage:')
      end
    end
  end

  context 'integration with config command' do
    it 'works with config file created by config command' do
      # First run config command
      mock_gets_with(
        'integration_client_id',
        'integration_client_secret',
        '',
        ''
      )
      config_result = run_command('config')
      expect(config_result).to be_success

      # Then run auth command
      allow_any_instance_of(GooglePhotos::Auth).to receive(:authorize)
        .and_raise(GooglePhotos::Auth::NotAuthenticated)
      allow_any_instance_of(GooglePhotos::Auth).to receive(:authorization_url)
        .and_return(fake_auth_url)
      allow_any_instance_of(GooglePhotos::Auth).to receive(:save_authorization_code)
        .and_return(true)

      mock_gets_with(fake_auth_code)
      auth_result = run_command('auth')

      expect(auth_result).to be_success
      expect(auth_result.stdout).to include('✓ Authorization successful!')
    end
  end
end
