# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'redis'

begin
  Redis.current.call 'INFO'
rescue Redis::CannotConnectError => cce
  puts "\n\nIt appears Redis is not running, but it is required for (some) specs to run\n\n"
  puts cce
  exit 1
end

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/config/'
    add_filter '/lib/rspec/formatters/user_flow_formatter.rb'
    add_filter '/lib/user_flow_exporter.rb'
    add_filter '/lib/deploy/migration_statement_timeout.rb'
    add_filter '/lib/tasks/create_test_accounts.rb'
  end
end

ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'spec_helper'
require 'email_spec'
require 'factory_bot'

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!

  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.include AbstractController::Translation
  config.include Features::MailerHelper, type: :feature
  config.include Features::SessionHelper, type: :feature
  config.include Features::StripTagsHelper, type: :feature
  config.include AnalyticsHelper
  config.include AwsKmsClientHelper
  config.include KeyRotationHelper
  config.include TwilioHelper

  config.before(:suite) do
    Rails.application.load_seed
  end

  config.before(:each) do
    I18n.locale = :en
  end

  config.before(:each, js: true) do
    allow(Figaro.env).to receive(:domain_name).and_return('127.0.0.1')
  end

  config.before(:each, type: :controller) do
    @request.host = Figaro.env.domain_name
  end

  config.before(:each) do
    allow(ValidateEmail).to receive(:mx_valid?).and_return(true)
  end

  config.before(:each) do
    Telephony::Test::Message.clear_messages
    Telephony::Test::Call.clear_calls
  end

  config.around(:each, user_flow: true) do |example|
    Capybara.current_driver = :rack_test
    example.run
    Capybara.use_default_driver
  end

  config.around(:each, type: :feature) do |example|
    Bullet.enable = true
    example.run
    Bullet.enable = false
  end

  config.before(:each) do
    stub_request(:post, 'https://www.google-analytics.com/collect')
  end
end
