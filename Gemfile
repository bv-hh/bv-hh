# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'pg'
gem 'rails', '~> 7.2.2'
# Use Puma as the app server
gem 'puma', '~> 6.6'
gem 'sd_notify' # Required by puma for systemd integration
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.13'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
gem 'bcrypt', '~> 3.1.20'

# Use Active Storage variant
gem 'image_processing', '~> 1.14'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

gem 'turbo-rails'

gem 'stimulus-rails'

gem 'ahoy_matey'

gem 'fiddle'

gem 'mutex_m'

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

gem 'rails-i18n'

gem 'chartkick'

gem 'groupdate'

gem 'simple_text_extract'

gem 'rinku'

gem 'sitemap_generator'

gem 'blazer'

gem 'uglifier'

gem 'mitie'

gem 'google-maps'

gem 'langchainrb', '~> 0.19.3'

gem 'baran', '~> 0.1.12'

gem 'ruby-openai', '~> 7.4'

gem 'qdrant-ruby', '~> 0.9.8'

gem 'redcarpet', '~> 3.6'

gem 'importmap-rails', '~> 2.1'

gem 'good_job', '~> 4.9'

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
