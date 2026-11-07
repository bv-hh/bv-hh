# AGENTS.md

Guidance for coding agents working in this repository.

## Background

BV-HH (https://bv-hh.de) is an independent, open-source alternative to the
Ratsinformationssystem (ALLRIS) of Hamburg's seven Bezirksversammlungen. It is
not an official site. It began as a hobby project of a member of the
Bezirksversammlung Hamburg-Nord, who wanted figures across all districts and
an interface that works on a phone during a session. `/about` tells the story.

**Two target groups**, and a feature should serve at least one of them:

1. **People working in or for the district administration and district
   politics:** members of the Bezirksversammlungen and committees, their
   staff, the Bezirksämter. They know ALLRIS and need quick access to it:
   usable on a phone, easy to navigate, fast search across all seven Bezirke
   ("was this already requested in another Bezirk?"), and seeing new
   Drucksachen and upcoming agendas at a glance.
2. **Residents who don't know what is going on in their district,** often not
   even that district politics and its assemblies exist. They want to know
   what is happening in their neighbourhood. For them, pages start from
   places and topics rather than from committees and document numbers. Pages
   explain what a Bezirk does and show which meetings anyone can attend and
   how to take part (Fragestunde, Eingabe). Feeds let them follow their street
   or Stadtteil.

**What it adds to ALLRIS:** places and Stadtteile found in the text, topics,
maps, statistics, feeds per street, Stadtteil or topic, and an MCP server
(`/api/mcp`) for LLM tools.

**What a Bezirk decides**, so features match what it actually does: each Bezirk
has a Bezirksamt and a Bezirksversammlung elected every five years. The
assembly decides local matters (a playground, a crossing, Sondermittel),
advises and checks the Bezirksamt, but passes no laws; that is the
Bürgerschaft and the Senat. Material from the Bürgerschaft belongs here only
where it concerns a place in a district. `/district-politics` explains this
for residents.

**Limits**
- Public data only. Closed sessions and documents for elected members stay in
  ALLRIS.
- ALLRIS is polled sparingly, so new data can take a while to show up.
- The Senat has confirmed that republishing the data is lawful (answer to a
  Schriftliche Kleine Anfrage, linked on `/about`).
- Most people in district politics are not public figures. Requests to remove
  a name are usually granted and listed on `/transparency`. Don't build
  features that put individual people at the centre.

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
- `bundle exec rubocop` - Run Ruby linter/formatter. Run it on the whole
  project: naming files explicitly overrides the `db/**/*` exclude and reports
  offenses in migrations and `schema.rb` that CI never checks.
- `bundle exec rails assets:precompile` - Precompile assets

### Database
- `bundle exec rails db:create` - Create database
- `bundle exec rails db:schema:load` - Load database schema
- `bundle exec rails console` - Access Rails console

## Architecture Overview

This is a Ruby on Rails application for Hamburg's district assembly parliamentary database (BV-HH). It provides an alternative web interface for accessing meeting data, documents, and agendas from Hamburg's district assemblies.

### Product direction
The goal is to make Hamburg's district politics accessible and transparent for
both target groups (see Background):
- Centre designs on topics, places (Stadtteile, streets), decisions and their
  outcomes, meetings people can attend, and ways to take part. Residents ask
  "what is decided where I live?"; insiders want the newest Drucksache or the
  next agenda in two taps.
- Write for residents without prior knowledge: explain a term such as
  Drucksache or Fragestunde where it first matters, and don't assume they know
  which committee handles what.
- Keep parties, Fraktionen and individual politicians out of highlights: no
  seat bars, no party names in featured titles. The party charts at the end of
  the district statistics page are the exception and stay there.
- The UI is German, the code English. Domain terms map as: Bezirk = `District`,
  Stadtteil = `Quarter`, Drucksache = `Document`, Sitzung = `Meeting`,
  Tagesordnungspunkt (TOP) = `AgendaItem`, Ausschuss = `Committee`. The
  Bezirksversammlung is the district's plenary (`Committee.assembly`,
  `Meeting.of_assembly`); a Wahlperiode is the five-year legislative period.

### Core Models
- **District** - Represents Hamburg districts with boundaries and meeting data
- **Meeting** - Council meetings with agendas and protocols
- **Document** - Parliamentary documents and attachments
- **Committee** - District committees organizing meetings
- **AgendaItem** - Individual agenda items within meetings
- **Location** - A place a document names, resolved against the geo registers
- **Quarter** - Stadtteil, with its ALKIS boundary
- **Street**, **Poi** - The geo registers (see below)
- **Topic** - The 20 topics a document can be tagged with (see below)

### Key Features
- Document parsing and text extraction
- Location extraction against local registers; maps with Leaflet and
  OpenStreetMap tiles (not Google Maps)
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

- Embedding documents (`EmbedDocumentsJob`, nightly 04:07 UTC) with
  `multilingual-e5-base` run locally via ONNX. The model takes ~0.8 GB, so the
  job starts `rake embeddings:update` as a separate process instead of loading
  it into the worker. The first run downloads the model (~280 MB) into
  `~/.cache/informers`. The initial backfill runs on a development machine
  (`rake embeddings:update`, resumable) and is moved over with
  `rake embeddings:export` / `rake "embeddings:import[file]"`, keyed by
  district and ALLRIS id; the import skips rows whose text differs there.

All schedules are in `config/initializers/good_job.rb`. Documents sync hourly.
Keep heavy work, migrations and deploys clear of the nightly jobs (23:15 and
04:07 UTC).

### External Dependencies
- PostgreSQL database with the `pgvector` extension
- ALLRIS of each district (scraped HTML) and OpenStreetMap tiles. No Google
  service is used any more.
- Outside services block clients that send bursts of requests. Keep requests
  sequential and paced, and try a scraper on a few pages before a full run.

### Testing Setup
Requires PostgreSQL and Redis services for full test suite. The CI pipeline in `.github/workflows/main.yml` shows complete test environment setup.

### Development Notes
- Uses Slim templating engine for views
- Bootstrap 5 for styling with custom Sass
- Stimulus for JavaScript controllers
- Importmap for JavaScript module management
- Capistrano for deployment
- `annotate` (2.6.5) fails on Ruby 3.4 (`uninitialized constant Fixnum`).
  Write the schema comment of a new model by hand.
- The local development database is usually an older prod dump and may have
  drifted from `db/schema.rb`. After `db:migrate`, commit only the schema
  lines your migration added, not the whole dump.
- Caching is off in development unless `tmp/caching-dev.txt` exists
  (`rails dev:cache`), so cached paths need that switch to be seen locally.
- A server on port 3000 may already be running with `tmp/pids/server.pid`.
  Start a second one on another port with its own pid file
  (`rails s -p 3111 -P tmp/pids/other.pid`) and stop it afterwards.

### UI conventions
- Bootstrap 5.3 classes first; add custom Sass only where Bootstrap has
  nothing. `$primary` is the brand red (`#e10019`), so `btn-primary`,
  `bg-primary` and friends are red. The navy of the navbar (`$blue`,
  `#003064`) is available as `.text-bg-brand`; links use `$light-blue`
  (`#005ca9`).
- Page heroes are `.card.p-4.p-lg-5.bg-body-tertiary`. A page with its own
  search field in the hero sets `@hero_search`, and the layout then leaves out
  the navbar search.
- Chips for places, Stadtteile, topics and Bezirke come from `ChipHelper`.
  Lists of Drucksachen render `documents/_item` (full or compact) and load
  their rows with `Document.for_list`. `/kitchensink` shows all of them with
  real records; the route does not exist in production.
- Show only meetings the public can attend: `Meeting.open_to_public`. The
  `committees.public` flag alone lets closed building and award committees
  through.
- Escape everything in map popups and other HTML built in JavaScript. Place
  names come from OpenStreetMap, which anyone can edit.
- The `(:district)` route scope is greedy: `/foo/bar` can be read as
  district `foo`. Routes that must not be swallowed go above it (see the
  comments in `config/routes.rb`).

## Data quirks

- **`documents.created_at` is the import date,** not a date of the Drucksache.
  Thousands were imported in a few batches. Ordering by it ("newest seen
  first", as the feeds and the Stadtteil and topic lists do) is fine; showing
  it as the date of a Drucksache is not. Date a Drucksache by its latest
  meeting (`Document#latest_agenda_item`) and show no date when it has none.
- **Drucksache numbers sort as dates within a district.** They are
  zero-padded, so text order is numeric order. Harburg numbered its 19th
  period `XIX-…`; `Document::NUMBER_BY_DATE` reads those as `19-…`. Across
  districts the order is only rough: Hamburg-Mitte counts one period ahead
  (`23-…` while the others are at `22-…`).
- **The current Wahlperiode** starts at each district's
  `first_legislation_number` (`Document.current_legislation`). Update it after
  each Bezirksversammlung election.
- **A Drucksache counts for a Stadtteil** when it names the Stadtteil or one
  of its places lies inside it (`FeedQuery`). Counts and maps must use the
  same rule as the Stadtteil pages.
- **`agenda_items.decision` is empty** for many agenda items, especially in a
  stale local database. Check outcomes and upcoming agendas against prod.
- **Attachments are matched by name only.** When ALLRIS renames a file, the
  old attachment is deleted and its blob purged. Scanned PDFs have no text
  layer and get no text (there is no OCR).

## Topics

Each document gets topics from rules (`config/topics.yml`, whose header
explains the rule kinds and stemming pitfalls) plus a classifier per topic
trained on the embeddings with the rules as teacher (`TopicTrainer`,
thresholds set by `TopicCalibration`).

- **Bump `Topic::VERSION`** after any rule change, then run
  `rake topics:reassign_later`. Changing only a `description` needs no bump.
- **Measure against the gold sets** in `db/gold` (the README there has the
  workflow and labelling rules). Read rule ideas off the tuning set's misses;
  the test set is for measuring only, never for tuning. Precision matters more
  than recall.
- **Labelling:** tag the main point(s) of a document, not aspects mentioned
  along the way, but don't go minimal; the human labels average about 1.7
  topics per document. An import never replaces a human label.
- **Rollout:** classifiers are trained on a development machine
  (`rake topics:train`). After deploying, copy the `TopicModel` rows to prod
  (there is no task for that) and run `rake topics:reassign_later` there. The
  nightly embedding job also reclassifies new documents.

## Production

- Deploys run with `bundle exec cap production deploy`; merging a PR does not
  deploy. Capistrano runs the migrations.
- Prod is `deploy@bv-hh.de`, app in `/home/deploy/app/current` (rbenv). The
  local database is stale, so current numbers come from a read-only script:
  copy it to `/tmp` (`ssh deploy@bv-hh.de 'cat > /tmp/x.rb' < x.rb`), run
  `cd /home/deploy/app/current && RAILS_ENV=production ~/.rbenv/bin/rbenv exec
  bundle exec rails runner /tmp/x.rb`, and delete it afterwards. Anything that
  writes to prod needs the maintainer's explicit go-ahead.
- Prod runs PostgreSQL 18. Restore a prod dump with a matching `pg_restore`
  (e.g. `docker run --network host postgres:18 pg_restore …`).
- The `documents` table has about 240k rows on prod. A migration that rewrites
  it locks the table for minutes: build indexes with
  `algorithm: :concurrently`, set a short `lock_timeout`, and deploy in a quiet
  hour.

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

- **Restart web and workers afterwards.** `Quarter`, the Bezirk outlines and
  the gazetteers memoize per process; a process that touched one before the
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
- Residents per Stadtteil and Bezirk, for the maps shading them by Drucksachen per
  resident, are hard-coded in `Population` from the Statistikamt Nord's
  Stadtteil-Profile (source URL in the file). The attribution is on `/imprint`.

## Initial Setup

1. Create at least one district via `seeds.rb`
2. Import the geo registers (see above)
3. Run initial data sync: `CheckForDocumentUpdatesJob.perform_now(District.first)`
4. Run meeting sync: `CheckForMeetingUpdatesJob.perform_now(District.first)`