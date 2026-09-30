# AGENTS.md

Guidance for coding agents working in this repository.

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
- Document parsing and text extraction
- Location extraction and mapping integration (Google Maps)
- Search functionality across documents and meetings
- Background job processing with GoodJob
- Multi-district support with URL routing

### Job Processing
Uses GoodJob for background processing:
- Document synchronization from Allris
- Text extraction and NLP processing
- Location extraction and geocoding
- Re-fetching documents parsed by an older parser (`RefetchDocumentsJob`,
  nightly from 23:15 UTC for `RefetchDocumentsJob::WINDOW`, one request at a
  time per district). Bump
  `Parsing::VERSION` when a parser change alters what is stored for a document.
  Fetched pages are kept in `allris_pages`, so after a bump
  `rake documents:reparse` updates every document that has one without asking
  ALLRIS; the nightly job fetches only the rest.

### External Dependencies
- PostgreSQL database
- Google Maps API for geocoding

### Testing Setup
Requires PostgreSQL and Redis services for full test suite. The CI pipeline in `.github/workflows/main.yml` shows complete test environment setup.

### Development Notes
- Uses Slim templating engine for views
- Bootstrap 5 for styling with custom Sass
- Stimulus for JavaScript controllers
- Importmap for JavaScript module management
- Capistrano for deployment

## Geo registers

Location extraction finds names by whole-word lookup against three local
registers (`StreetGazetteer`, `QuarterGazetteer`, `PoiGazetteer`, plus
`TransitGazetteer` for stations behind a "U/S" prefix) and never calls an
external service. There is no NER model: everything extracted is a name some
register knows. Each register is filled by a rake task and refreshed
occasionally — there is no scheduled job.

```bash
rake quarters:import   # 104 Stadtteil polygons, ALKIS WFS          (~2s)
rake streets:import    # 9535 official street names, AdressService  (~40s)
rake pois:import       # ~8000 named OpenStreetMap features         (~10min)
```

- **Restart web and workers afterwards.** `Quarter` and the gazetteers
  memoize per process; a process that touched one before the
  import keeps an empty memo.
- **Import during a quiet window.** Each task does `delete_all` then re-inserts.
- `pois:import` reads Overpass (one request per tag value, rotating endpoints on
  failure) or a local osmium GeoJSON export: `rake "pois:import[pois.geojson]"`.
- **It is resumable.** Answers are cached in `tmp/pois` as they arrive, so a run
  that loses a query to a throttled instance can simply be re-run — only the
  missing queries are retried. Nothing is written to the table until the set is
  complete, because the import empties the table first and a partial set would
  delete a whole category of places. `rake pois:clear_cache` forces a full
  re-fetch; the cache expires by itself after three days.
- `rake pois:coverage` reports which resolution step answers each extracted name
  in the corpus. Read-only.
- **After an import, `rake locations:reassign`, not `rake streets:reanalyze`.**
  Reanalysis re-reads every document and its attachments; an import mostly
  changes how a name resolves to a place, not which names were found.
  Reanalyse when the extraction itself changed, or after a POI or Stadtteil
  import that should find new names. `locations:sweep` needs neither — it
  enqueues exactly the documents it took a link from.
- OpenStreetMap data is ODbL; the attribution is on `/imprint` and is required.

## Initial Setup

1. Create at least one district via `seeds.rb`
2. Import the geo registers (see above)
3. Run initial data sync: `CheckForDocumentUpdatesJob.perform_now(District.first)`
4. Run meeting sync: `CheckForMeetingUpdatesJob.perform_now(District.first)`