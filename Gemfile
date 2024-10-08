# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.5'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'pg'
gem 'rails', '~> 7.2.1'
# Use Puma as the app server
gem 'puma', '~> 6.4'
gem 'sd_notify' # Required by puma for systemd integration
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.12'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
gem 'bcrypt', '~> 3.1.20'

# Use Active Storage variant
gem 'image_processing', '~> 1.12'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

gem 'ahoy_matey'

gem 'sidekiq', '~> 7.3'
gem 'sidekiq-scheduler'

gem 'nokogiri'

gem 'bootstrap', '~> 5.3'

gem 'bootstrap5-kaminari-views'
gem 'kaminari'

gem 'slim-rails'

gem 'caxlsx'
gem 'caxlsx_rails'

gem 'font-awesome-sass', '~> 5.15.1'

gem 'sprockets', '~> 4'
gem 'sprockets-rails', require: 'sprockets/railtie'

gem 'jquery-rails'

gem 'rails-i18n'

gem 'chartkick'

gem 'groupdate'

gem 'simple_text_extract'

gem 'rinku'

gem 'sitemap_generator'

gem 'blazer'

gem 'uglifier'

gem 'langchainrb', '~> 0.15.4'

gem 'baran', '~> 0.1.12'

gem 'ruby-openai', '~> 6.5'

gem 'qdrant-ruby', '~> 0.9.7'

gem 'redcarpet', '~> 3.6'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
end

group :development do
  gem 'annotate'

  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'listen', '~> 3.9'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-performance'
  gem 'web-console', '>= 3.3.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.1.0'

  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'capistrano-yarn'

  gem 'ed25519'
  gem 'bcrypt_pbkdf'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'

  gem 'minitest-ci', require: false
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
