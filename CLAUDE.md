# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Development
- `rails server` or `rails s` - Start the development server
- `bundle install` - Install Ruby dependencies
- `yarn install` - Install JavaScript dependencies
- `bundle exec rails db:migrate` - Run database migrations
- `bundle exec rails db:seed` - Seed the database with initial data

### Testing
- `bundle exec rails test` - Run unit tests
- `bundle exec rails test:system` - Run system tests

### Code Quality
- `bundle exec rubocop` - Run Ruby linter/formatter
- `bundle exec rails assets:precompile` - Precompile assets

### Database
- `bundle exec rails db:create` - Create database
- `bundle exec rails db:schema:load` - Load database schema
- `bundle exec rails console` - Access Rails console

## Architecture Overview

This is a Ruby on Rails application for Hamburg's district assembly parliamentary database (BV-HH). It provides an alternative web interface for accessing meeting data, documents, and agendas from Hamburg's district assemblies.

### Core Models
- **District** - Represents Hamburg districts with boundaries and meeting data
- **Meeting** - Council meetings with agendas and protocols
- **Document** - Parliamentary documents and attachments
- **Committee** - District committees organizing meetings
- **AgendaItem** - Individual agenda items within meetings
- **Location** - Geographic locations extracted from documents
- **Place** - Named places within districts

### Key Features
- Document parsing and text extraction using NLP/NER models
- Location extraction and mapping integration (Google Maps)
- Search functionality across documents and meetings
- Background job processing with GoodJob
- Multi-district support with URL routing

### Job Processing
Uses GoodJob for background processing:
- Document synchronization from Allris
- Text extraction and NLP processing
- Location extraction and geocoding

### External Dependencies
- PostgreSQL database
- MITIE NER model (stored in `data/` directory)
- Google Maps API for geocoding

### Testing Setup
Requires PostgreSQL and Redis services for full test suite. The CI pipeline in `.github/workflows/main.yml` shows complete test environment setup.

### Development Notes
- Uses Slim templating engine for views
- Bootstrap 5 for styling with custom Sass
- Stimulus for JavaScript controllers
- Importmap for JavaScript module management
- Capistrano for deployment

## Initial Setup

1. Download MITIE German NER model from: https://github.com/mit-nlp/MITIE/releases/download/v0.4/MITIE-models-v0.2-German.tar.bz2
2. Extract to `data/` directory
3. Create at least one district via `seeds.rb`
4. Run initial data sync: `CheckForDocumentUpdatesJob.perform_now(District.first)`
5. Run meeting sync: `CheckForMeetingUpdatesJob.perform_now(District.first)`