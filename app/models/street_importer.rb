# frozen_string_literal: true

# Imports the official Hamburg street register into the Street gazetteer from
# the "Zentraler AdressService" WFS (dog:Strassen). Fetching (network) and
# parsing (pure) are separate so the parser can be tested against a fixture.
class StreetImporter
  WFS_URL = 'https://geoportal-hamburg.de/geodienste_hamburg_de/HH_WFS_DOG'
  TYPE_NAME = 'dog:Strassen'
  PAGE_SIZE = 2000

  def self.import!
    new.import!
  end

  def import!
    now = Time.current
    total = 0

    Street.transaction do
      Street.delete_all

      start_index = 0
      loop do
        rows = parse(fetch(start_index))
        break if rows.empty?

        Street.insert_all(rows.map { |row| row.merge(created_at: now, updated_at: now) }) # rubocop:disable Rails/SkipsModelValidations
        total += rows.size
        start_index += PAGE_SIZE
      end
    end

    StreetGazetteer.reset!
    Rails.logger.info "StreetImporter: imported #{total} streets"
    total
  end

  def fetch(start_index)
    options = {
      service: 'WFS',
      version: '2.0.0',
      request: 'GetFeature',
      typeName: TYPE_NAME,
      srsName: 'EPSG:4326',
      count: PAGE_SIZE,
      startIndex: start_index,
    }
    url = "#{WFS_URL}?#{URI.encode_www_form(options)}"

    client = HTTPClient.new
    # Use the system CA store; HTTPClient's bundled cacert is outdated and fails
    # to verify the geoportal-hamburg.de certificate chain.
    client.ssl_config.set_default_paths
    client.get_content(url)
  end

  # Parses a dog:Strassen GML document into rows ready for Street.insert_all.
  def parse(gml)
    doc = Nokogiri::XML(gml)
    doc.remove_namespaces!

    doc.xpath('//Strassen').filter_map do |node|
      name = text_at(node, './strassenname')
      next if name.blank? || fragment?(name)

      latitude, longitude = coordinates(node)

      keys = street_keys(node)
      ortsteilnamen = ortsteilnamen(node)
      quarters = quarters(ortsteilnamen)

      {
        name: name,
        normalized_name: Street.normalize(name),
        latitude: latitude,
        longitude: longitude,
        quarter: quarters.first,
        quarters: quarters,
        quarter_keys: quarter_keys(ortsteilnamen),
        postal_code: text_at(node, './postleitzahl'),
        street_key: keys.first,
        district_numbers: district_numbers(keys),
      }
    end
  end

  private

  # The register carries park grounds as "<street>-Parkanlagen" — there are
  # hundreds of them, "Adlerstraße-Parkanlagen", "Am Brabandkanal-Parkanlagen".
  # One row has lost its street and is named "-Parkanlagen" outright, which made
  # the register answer authoritatively for the bare word "Parkanlagen" and put
  # 389 documents from all seven districts on one point in Langenhorn.
  #
  # A name that opens with punctuation is the tail of a compound, not a street.
  # It is the only such row in the 9535, and the register is not going to grow a
  # legitimate one.
  def fragment?(name)
    name.match?(/\A[^\p{L}\p{N}]/)
  end

  def text_at(node, xpath)
    node.at_xpath(xpath)&.text&.squish.presence
  end

  def street_keys(node)
    node.xpath('./strassenschluessel').filter_map { |key| key.text&.squish.presence }
  end

  # A strassenschluessel is "Land;Bezirk;Ortsteil;..." — the second field is the
  # official Hamburg district number. A street has one key per segment, so a
  # street spanning several districts yields several distinct numbers.
  def district_numbers(keys)
    keys.filter_map { |key| key.split(';')[1]&.to_i }.uniq.sort
  end

  # An ortsteilname reads "Barmbek-Nord,OT 0405": the Quarter name, then the
  # official Ortsteil key. A street has one entry per segment, so a street
  # crossing several Quarters yields several entries.
  def ortsteilnamen(node)
    node.xpath('./ortsteilname').filter_map { |name| name.text&.squish.presence }
  end

  def quarters(ortsteilnamen)
    ortsteilnamen.filter_map { |name| name.split(',').first&.squish.presence }.uniq
  end

  def quarter_keys(ortsteilnamen)
    ortsteilnamen.filter_map { |name| name[/OT\s*(\d+)/, 1] }.uniq.sort
  end

  # The representative point (iso19112:position). Hamburg's WFS returns axis
  # order lon/lat even for EPSG:4326, but we guard against lat/lon just in case.
  def coordinates(node)
    pos = node.at_xpath('./position/Point/pos')&.text
    return [nil, nil] if pos.blank?

    a, b = pos.split.map(&:to_f)
    if a.between?(53, 54)
      [a, b] # already lat, lon
    else
      [b, a] # lon, lat -> lat, lon
    end
  end
end
