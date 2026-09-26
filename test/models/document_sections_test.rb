# frozen_string_literal: true

require 'test_helper'

# Real vo020 pages, one per shape of markup that section detection or the
# cleaner once got wrong. Kept in test/fixtures/files/allris/cases/; the ALLRIS
# id each was fetched with is noted by its test.
class DocumentSectionsTest < ActiveSupport::TestCase
  def parse(name)
    html = Parsing.parse(AllrisFixtures.case_page(name)).css('table.risdeco').first
    Document.new.tap { |document| document.retrieve_body(html) }
  end

  # Harburg 1014117: the inquiry and the Bezirksamt's answer are two unlabelled
  # sections. Only the first used to be kept.
  test 'keeps every unlabelled section, in page order' do
    document = parse('harburg_question_and_answer')

    assert document.full_text.start_with?('Der Winterdienst ist von großer Bedeutung')
    assert_includes document.full_text, 'BEZIRKSVERSAMMLUNG HARBURG'
    assert document.full_text.end_with?("gez. Böhm\nf.d.R. Leptien")
    assert_nil document.resolution
  end

  # Hamburg-Mitte 1019836: the footnote is a section of its own.
  test 'keeps a footnote in the content' do
    document = parse('hamburg_mitte_footnote')

    assert document.full_text.start_with?('Fragesteller: Roland Hoitz')
    assert_includes document.content, '<sup>[1]</sup>'
    assert_match %r{\[1\] https://www\.abendblatt\.de/}, document.full_text
  end

  # Harburg 1014485: the resolution section is wrapped in a second div.
  test 'finds a label inside a wrapper div' do
    document = parse('harburg_wrapped_resolution')

    assert document.full_text.start_with?('Die Grundschule Neugraben')
    assert Parsing.text(document.resolution).start_with?('Der Vorsitzende wird gebeten')
    assert_not_includes document.full_text, 'Petitum'
  end

  # Hamburg-Mitte 1020380: a table, a footnote mark set in the Symbol font, and
  # an unlabelled section between Sachverhalt and Petitum.
  test 'keeps tables and turns a Symbol font footnote mark into text' do
    document = parse('hamburg_mitte_table_and_footnote_mark')

    assert_includes document.content, '<table>'
    assert_includes document.content, '<sup>[*]</sup>'
    assert_includes document.full_text, 'Nach § 2 Absatz'
    assert Parsing.text(document.resolution).start_with?('Um Kenntnisnahme')
  end

  # Harburg 1014776: Wingdings bullets in paragraphs that only look like a
  # list.
  test 'turns Wingdings bullets into bullets' do
    document = parse('harburg_wingdings_bullets')

    assert_includes document.full_text, "\n▪ Fischbeker Heidbrook im Bereich Einkaufszentrum\n"
    assert_no_match(/[\uF000-\uF0FF]/, "#{document.content}#{document.resolution}")
  end

  # Bergedorf 1009235: "Petitum/Beschluss: ---" and "Anlage/n: ---".
  test 'treats placeholders as empty' do
    document = parse('bergedorf_placeholders')

    assert document.full_text.start_with?('Auskunftsersuchen')
    assert_nil document.resolution
    assert_nil document.attached
  end

  # Hamburg-Nord 1016690: "Sachverhalt und Petitum:" in one label.
  test 'strips a combined Sachverhalt und Petitum label' do
    document = parse('hamburg_nord_sachverhalt_und_petitum')

    assert document.full_text.start_with?('Die GRÜNE Fraktion beantragt')
    assert_nil document.resolution
  end

  # Eimsbüttel 1011508: the resolution is labelled just "Beschluss:".
  test 'takes a bare Beschluss label for the resolution' do
    document = parse('eimsbuettel_beschluss_label')

    assert Parsing.text(document.resolution).start_with?('Der Vorsitzende der Bezirksversammlung wird gebeten')
    assert_not_includes document.full_text, 'Beschluss:'
  end
end
