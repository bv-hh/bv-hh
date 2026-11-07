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

**What follows for the design**
- Centre pages on topics, places (Stadtteile, streets), decisions and their
  outcomes, meetings people can attend, and ways to take part. Residents ask
  "what is decided where I live?"; insiders want the newest Drucksache or the
  next agenda in two taps.
- Write for residents without prior knowledge: explain a term such as
  Drucksache or Fragestunde where it first matters, and don't assume they know
  which committee handles what.
- Keep parties, Fraktionen and individual politicians out of highlights: no
  seat bars, no party names in featured titles. The party charts at the end of
  the district statistics page are the exception and stay there.

**Limits**
- Public data only. Closed sessions and documents for elected members stay in
  ALLRIS.
- ALLRIS is polled sparingly, so new data can take a while to show up.
- The Senat has confirmed that republishing the data is lawful (answer to a
  Schriftliche Kleine Anfrage, linked on `/about`).
- Most people in district politics are not public figures. Requests to remove
  a name are usually granted and listed on `/transparency`. Don't build
  features that put individual people at the centre.

## Glossary

The UI is German, the code English.

| UI | Code |
|---|---|
| Bezirk | `District` |
| Stadtteil | `Quarter` |
| Drucksache | `Document` |
| Sitzung | `Meeting` |
| Tagesordnungspunkt (TOP) | `AgendaItem` |
| Ausschuss | `Committee` |
| Bezirksversammlung (the plenary) | `Committee.assembly`, `Meeting.of_assembly` |
| Ort | `Location`, resolved against `Street` / `Poi` (geo registers) |
| Thema | `Topic` (20, defined in `config/topics.yml`) |
| Wahlperiode | the five-year legislative period |

## Commands

```bash
bin/rails test                                   # unit, controller, model tests
bin/rails test test/models/document_test.rb:42   # one file or test
bin/rails test:system                            # system tests (Chrome)
bundle exec rubocop                              # lint
```

Run rubocop on the whole project: naming files explicitly overrides the
`db/**/*` exclude and reports offenses in migrations and `schema.rb` that CI
never checks. CI (`.github/workflows/main.yml`) runs lint, unit tests, system
tests and the asset build. Setting up a local copy is described in
`README.md`.

## Workflow

- Branch off `main`, one PR per change. Check the current branch before every
  commit; never commit to `main` directly.
- Commit subjects are full English sentences in the imperative, without a
  prefix: "Map each district's Stadtteile by Drucksachen per resident".
- The maintainer merges. Merging deploys once CI is green (see Production).

### Keeping this file current

Update AGENTS.md in the same PR as the change that makes it necessary, but
only for knowledge that applies across the codebase and that the next agent
would otherwise get wrong:

- **Add** a rule, pitfall or convention when ignoring it leads to wrong data,
  a broken page or prod, or a rebuild of something that already exists, and
  when it can't be seen from the code at the place where it matters.
- **Prefer a code comment** when the knowledge belongs to one class, task or
  file. AGENTS.md is for what spans files or has no single place in the code.
- **Fix or delete** an entry the change makes wrong. A stale rule is worse
  than none.
- **Don't add** feature descriptions, changelogs, PR history, figures that
  go out of date (counts, timings) unless their order of magnitude decides
  how to work, or anything already in a comment, `config/topics.yml` or a
  README. Explain in the PR description instead.
- Keep entries to a sentence or two. When the file grows past about 300
  lines, shorten or remove something before adding.

## Architecture

Rails 8.1, PostgreSQL with `pgvector`, Slim views, Bootstrap 5.3 with Sass,
Stimulus and importmap, GoodJob for background jobs, Capistrano for deploys.
Maps use Leaflet with OpenStreetMap tiles; no Google service is used any more.

### Jobs

All schedules are in `config/initializers/good_job.rb`.

- **Sync from ALLRIS:** `CheckForDocumentUpdatesJob` (hourly) and
  `CheckForMeetingUpdatesJob` find new Drucksachen and meetings; the
  `Update*Job`s refresh recent documents and today's meetings. Per document,
  further jobs extract attachment text, places and topics.
- **Re-fetching documents parsed by an older parser** (`RefetchDocumentsJob`,
  nightly from 23:15 UTC for `RefetchDocumentsJob::WINDOW`, one request at a
  time per district). Bump `Parsing::VERSION` when a parser change alters what
  is stored for a document. Fetched pages are kept in `allris_pages`, so after
  a bump `rake documents:reparse` updates every document that has one without
  asking ALLRIS; the nightly job fetches only the rest.
- **Embedding documents** (`EmbedDocumentsJob`, nightly 04:07 UTC) with
  `multilingual-e5-base` run locally via ONNX. The model takes ~0.8 GB, so the
  job starts `rake embeddings:update` as a separate process instead of loading
  it into the worker. The first run downloads the model (~280 MB) into
  `~/.cache/informers`. The initial backfill runs on a development machine
  (`rake embeddings:update`, resumable) and is moved over with
  `rake embeddings:export` / `rake "embeddings:import[file]"`, keyed by
  district and ALLRIS id; the import skips rows whose text differs there.
- **Querying embeddings:** an HNSW scan returns at most `hnsw.ef_search`
  rows (default 40) and applies a `WHERE` only after the scan, so a filtered
  nearest-neighbour query silently comes back short. Raise it with
  `SET LOCAL` as `SimilarDocuments` does.

Keep heavy work, migrations and deploys clear of the nightly jobs (23:15 and
04:07 UTC).

### MCP server

`POST /api/mcp` (`Mcp::ServerController`, tools in `app/controllers/mcp/`) is a
public interface without authentication, described on `/mcp`. A change to the
queries behind search or documents changes what its tools return.

### Outside services

ALLRIS, Overpass and other sources block clients that send bursts of
requests. Keep requests sequential and paced, and try a scraper on a few pages
before a full run.

## Data quirks

- **`documents.created_at` is the import date,** not a date of the Drucksache.
  Thousands were imported in a few batches. Ordering by it ("newest seen
  first", as the feeds and the Stadtteil and topic lists do) is fine; showing
  it as the date of a Drucksache is not. Date a Drucksache by its latest
  meeting (`Document#latest_agenda_item`), in a list row by the meeting whose
  decision it shows (`listed_agenda_item`), and show no date when it has none.
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
- **Only some meetings are public.** Use `Meeting.open_to_public`; the
  `committees.public` flag alone lets closed building and award committees
  through.
- **`agenda_items.decision` is empty** for many agenda items, especially in a
  stale local database, often because ALLRIS itself shows "(offen)". Read it
  through `AgendaItem#outcome`, and say where a Drucksache stands by
  `Document#deciding_agenda_item`, the rule the statistics count by; the
  result text rarely states the decision.
- **Attachments are matched by name only.** When ALLRIS renames a file, the
  old attachment is deleted and its blob purged. Scanned PDFs have no text
  layer and get no text (there is no OCR).

## Development notes

- `annotate` (2.6.5) fails on Ruby 3.4 (`uninitialized constant Fixnum`).
  Write the schema comment of a new model by hand.
- The local development database is often an older prod dump and may have
  drifted from `db/schema.rb`. After `db:migrate`, commit only the schema
  lines your migration added, not the whole dump.
- Caching is off in development unless `tmp/caching-dev.txt` exists
  (`rails dev:cache`), so cached paths need that switch to be seen locally.
- **Tests:** `District.lookup`, `District.by_number`, `Quarter` and the
  gazetteers memoize per process. A test that changes such a row must clear
  the memo, or the code under test keeps the old record. Time-dependent tests
  use `travel_to`.

### UI conventions

- Bootstrap 5.3 classes first; add custom Sass only where Bootstrap has
  nothing. `$primary` is the brand red (`#e10019`), so `btn-primary`,
  `bg-primary` and friends are red. The navy of the navbar (`$blue`,
  `#003064`) is available as `.text-bg-brand`; links use `$light-blue`
  (`#005ca9`).
- Page heroes are `.card.p-4.p-lg-5.bg-body-tertiary`. A page with its own
  search field in the hero sets `@hero_search`, and the layout then leaves out
  the navbar search. Every other page starts with `page_header`
  (`PageHeaderHelper`, breadcrumbs included); hero pages use its `breadcrumbs`.
- Chips for places, Stadtteile, topics and Bezirke come from `ChipHelper`.
  Lists of Drucksachen render `documents/_item` (full or compact) and load
  their rows with `Document.for_list`. `/kitchensink` shows all of them with
  real records; the route does not exist in production.
- Escape everything in map popups and other HTML built in JavaScript. Place
  names come from OpenStreetMap, which anyone can edit.
- The `(:district)` route scope is greedy: `/foo/bar` can be read as
  district `foo`. Routes that must not be swallowed go above it (see the
  comments in `config/routes.rb`).

## Topics

Each document gets topics from rules (`config/topics.yml`, whose header
explains the rule kinds and stemming pitfalls) plus a classifier per topic
trained on the embeddings with the rules as teacher (`TopicTrainer`,
thresholds set by `TopicCalibration`).

- **Bump `Topic::VERSION`** after any rule change, then run
  `rake topics:reassign_later`. Changing only a `description` needs no bump.
- **Measure against the gold sets** in `db/gold`; the README there has the
  workflow and how to label. Read rule ideas off the tuning set's misses; the
  test set is for measuring only, never for tuning. Precision matters more
  than recall.
- **Rollout:** classifiers are trained on a development machine
  (`rake topics:train`). After deploying, copy the `TopicModel` rows to prod
  (there is no task for that) and run `rake topics:reassign_later` there. The
  nightly embedding job also reclassifies new documents.

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
rake pois:import       # ~8000 named OpenStreetMap features         (~10min, resumable)
```

- **Restart web and workers afterwards.** `Quarter`, the Bezirk outlines and
  the gazetteers memoize per process; a process that touched one before the
  import keeps an empty memo.
- **Import during a quiet window.** Each task does `delete_all` then re-inserts.
- **After an import, `rake locations:reassign`, not `rake streets:reanalyze`.**
  Reanalysis re-reads every document and its attachments; an import mostly
  changes how a name resolves to a place, not which names were found.
  Reanalyse when the extraction itself changed, or after a POI or Stadtteil
  import that should find new names. `locations:sweep` needs neither — it
  enqueues exactly the documents it took a link from.
- **Attribution is required** on `/imprint` for OpenStreetMap (ODbL), the
  LGV registers, and the residents per Stadtteil and Bezirk hard-coded in
  `Population` (Statistikamt Nord, source URL in the file).

## Production

For maintainers; contributors have no access.

- Every push to `main` deploys once CI is green (`.github/workflows/deploy.yml`,
  Capistrano, migrations included). Hold a PR with a heavy migration until a
  quiet hour. A manual `bundle exec cap production deploy` deploys the branch
  checked out locally. Writes to prod, imports and deploys need the
  maintainer's explicit go-ahead.
- The `documents` table has about 240k rows on prod. A migration that rewrites
  it locks the table for minutes: build indexes with
  `algorithm: :concurrently`, set a short `lock_timeout`, and deploy in a quiet
  hour.
