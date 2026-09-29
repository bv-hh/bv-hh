# frozen_string_literal: true

require 'test_helper'

class TopicClassifierTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    TopicClassifier.reset!
  end

  def document(title: 'Allgemeine Angelegenheit', full_text: 'Ohne besonderen Inhalt.')
    @district.documents.create!(allris_id: 9_900 + Document.unscoped.count, title: title, full_text: full_text)
  end

  def on_agenda_of(document, committee_name)
    committee = @district.committees.create!(name: committee_name)
    meeting = @district.meetings.create!(committee: committee, title: committee_name, date: Date.new(2024, 1, 1))
    AgendaItem.create!(meeting: meeting, document: document, title: document.title)
  end

  def linked_to(document, poi)
    location = Location.create!(name: poi.name, extracted_name: poi.name, place_id: poi.place_key, district: @district,
                                latitude: poi.latitude, longitude: poi.longitude)
    document.document_locations.create!(location: location)
  end

  test 'a term in the title is enough on its own' do
    classifier = TopicClassifier.new(document(title: 'Neue Spielgeräte für den Spielplatz Osterbekweg'))

    assert_includes classifier.topics, 'spielplaetze'
    assert classifier.signals['spielplaetze'][:title]
  end

  test 'terms are stemmed and folded, so a plural with umlauts matches' do
    classifier = TopicClassifier.new(document(title: 'Sanierung der Spielplätze'))

    assert_includes classifier.topics, 'spielplaetze'
  end

  test 'a term only in the body is not enough' do
    classifier = TopicClassifier.new(document(full_text: 'Der Radweg wird am Rande erwähnt.'))

    assert classifier.signals['radverkehr'][:body]
    assert_not_includes classifier.topics, 'radverkehr'
  end

  test 'a term in the body together with a topical committee is a topic' do
    doc = document(full_text: 'Der Radweg an der Hauptstraße soll verbreitert werden.')
    on_agenda_of(doc, 'Ausschuss für Verkehr und Mobilität')

    classifier = TopicClassifier.new(doc)

    assert classifier.signals['radverkehr'][:committee]
    assert_includes classifier.topics, 'radverkehr'
  end

  test 'a term in the body together with a linked POI of the topic is a topic' do
    doc = document(full_text: 'Die Spielgeräte sind defekt.')
    linked_to(doc, pois(:spielplatz))

    classifier = TopicClassifier.new(doc)

    assert classifier.signals['spielplaetze'][:poi]
    assert_includes classifier.topics, 'spielplaetze'
  end

  # Even one whose name happens to contain a topical word.
  test 'a Regionalausschuss gives no committee signal' do
    doc = document
    on_agenda_of(doc, 'Regionalausschuss Verkehr und Umwelt')

    classifier = TopicClassifier.new(doc)

    assert(classifier.signals.values.none? { |found| found[:committee] })
  end

  test 'the committee a title names does not make its topic' do
    @district.committees.create!(name: 'Ausschuss für Haushalt, Sport und Kultur')
    TopicClassifier.reset!

    classifier = TopicClassifier.new(document(title: 'Zuwendung an den Verein Beschlussvorlage des Ausschusses für Haushalt, Sport und Kultur'))

    assert_includes classifier.topics, 'haushalt'
    assert_not_includes classifier.topics, 'sport'
  end

  test 'title terms count in the title only' do
    in_title = TopicClassifier.new(document(title: 'Verkehrssituation am Siemersplatz'))
    in_body = TopicClassifier.new(document(full_text: 'Die Verkehrssituation ist bekannt.'))

    assert_includes in_title.topics, 'strassenverkehr'
    assert_not in_body.signals['strassenverkehr'][:body]
  end

  test 'a topic without body terms is found from its title' do
    classifier = TopicClassifier.new(document(title: 'Ausschussumbesetzungen (Mitteilung der Volt-Fraktion)'))

    assert_equal ['gremien'], classifier.topics
  end

  test 'culture means the compounds, not the word Kultur' do
    assert_includes TopicClassifier.new(document(title: 'Förderung der Stadtteilkultur 2024')).topics, 'kultur'
    assert_includes TopicClassifier.new(document(title: 'Zuwendung an die Geschichtswerkstatt')).topics, 'kultur'
    assert_not_includes TopicClassifier.new(document(title: 'Anfrage an die Behörde für Kultur')).topics, 'kultur'
  end

  test 'a street renaming is culture, a committee renaming is procedure' do
    street = TopicClassifier.new(document(title: 'Straßenumbenennungen in Barmbek')).topics
    committee = TopicClassifier.new(document(title: 'Umbenennungen in den Ausschüssen')).topics

    assert_includes street, 'kultur'
    assert_not_includes street, 'gremien'
    assert_includes committee, 'gremien'
  end

  # Stemming merges these with words of another topic.
  test 'words that stem like a term do not count as it' do
    {
      'Parken in der Hauptstraße' => 'gruen',
      'Neue Bänke im Park' => 'strassenverkehr',
      'Antrag von Frau Müller' => 'sauberkeit',
      'Schulden des Vereins' => 'bildung',
      'Kunststoffbelag erneuern' => 'kultur',
      'Kunstrasenplatz sanieren' => 'kultur',
    }.each do |title, topic|
      assert_not_includes TopicClassifier.new(document(title: title)).topics, topic, title
    end
  end

  test 'a document without title or text has no topics' do
    classifier = TopicClassifier.new(document(title: nil, full_text: nil))

    assert_empty classifier.topics
  end

  test 'a committee named in the body is not a body hit for its topics' do
    doc = document(full_text: 'Der Ausschuss für Grün, Naturschutz und Sport hat die Baumfällungen zur Kenntnis genommen.')
    on_agenda_of(doc, 'Ausschuss für Grün, Naturschutz und Sport')

    classifier = TopicClassifier.new(doc)

    assert_not classifier.signals['sport'][:body]
    assert_not_includes classifier.topics, 'sport'
  end

  test 'a procedural title speaks only for Gremien' do
    classifier = TopicClassifier.new(document(title: 'Benennung für den Ausschuss Bildung und Sport'))

    assert classifier.signals['bildung'][:title], 'precondition: the committee name is in the title'
    assert_equal ['gremien'], classifier.topics
  end

  test 'a Schulweg is traffic, not school' do
    classifier = TopicClassifier.new(document(title: 'Schulwegsicherung in der Stadtbahnstraße'))

    assert_not_includes classifier.topics, 'bildung'
  end

  test 'district funds are Haushalt' do
    %w[Projektmittel Stadtteilkulturmittel Zuschuss].each do |word|
      assert_includes TopicClassifier.new(document(title: "Antrag auf #{word} für ein Konzert")).topics, 'haushalt', word
    end
    assert_includes TopicClassifier.new(document(title: 'Förderung kultureller Projekte - Kulturverein')).topics, 'haushalt'
  end

  test 'the district as a service provider is Bürgerservice, not Gremien' do
    classifier = TopicClassifier.new(document(title: 'Das Kundenzentrum Blankenese muss erhalten bleiben!'))

    assert_equal ['buergerservice'], classifier.topics
  end

  test 'equality and discrimination are Demokratie & Vielfalt' do
    assert_includes TopicClassifier.new(document(title: 'Ein Frauenhaus für Altona')).topics, 'demokratie_vielfalt'
    assert_includes TopicClassifier.new(document(title: 'Diskriminierung bei der Wohnungsvergabe entgegentreten')).topics,
                    'demokratie_vielfalt'
  end

  test 'compounds the prefixes did not reach' do
    assert_includes TopicClassifier.new(document(title: 'Sanierung des Kinderspielplatzes Heerbuckhoop')).topics, 'spielplaetze'
    assert_includes TopicClassifier.new(document(title: 'Linienverkehr mit Kraftomnibussen, Linie 600')).topics, 'oepnv'
    assert_includes TopicClassifier.new(document(title: 'Bewohnerparken in Borgfelde')).topics, 'strassenverkehr'
  end
end
