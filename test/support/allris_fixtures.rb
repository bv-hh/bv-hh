# frozen_string_literal: true

# Shared helpers for the cross-district ALLRIS parsing tests. The captured pages
# live under test/fixtures/files/allris/<district>/ and are described by
# manifest.yml. See that file for the layout.
module AllrisFixtures
  ROOT = Rails.root.join('test/fixtures/files/allris')
  MANIFEST = YAML.load_file(Rails.root.join('test/support/allris_manifest.yml')).freeze

  module_function

  # Yields [slug, info] for every seeded district.
  def each_district(&) = MANIFEST.each(&)

  # Builds (and persists) a District matching a captured instance, so that
  # allris_base_url / allris_url and district-scoped lookups behave as in prod.
  def build_district(slug)
    info = MANIFEST.fetch(slug)
    District.create!(name: info['name'], allris_base_url: info['base_url'])
  end

  # Raw ISO-8859-1 bytes of a captured page, exactly as Net::HTTP.get returns.
  def page(slug, name)
    ROOT.join(slug, name).read
  end

  # The content parsers (Document/Meeting/AgendaItem) download attachments and
  # images over HTTP directly (not via a job) as a side effect of parsing.
  # Neutralise those on a single transient record so a test can parse offline.
  # Follow-up *_later! jobs need no stubbing: the test env uses the :test queue
  # adapter (see config/environments/test.rb), so they only get recorded.
  def stub_network(record)
    record.define_singleton_method(:retrieve_attachments) { |_html| nil }
    record.define_singleton_method(:retrieve_images) { |_html| nil }
    record
  end
end
