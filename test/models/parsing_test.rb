# frozen_string_literal: true

require 'test_helper'

# Unit tests for the Parsing concern: how ALLRIS' Word-exported HTML is decoded,
# cleaned and turned into text. The markup below is shaped like real ALLRIS
# output; the cross-district fixtures are exercised in document_parsing_test.rb.
class ParsingTest < ActiveSupport::TestCase
  def clean(html)
    Parsing.clean(Nokogiri::HTML.fragment(html))
  end

  def sections(html)
    Parsing.sections(Nokogiri::HTML.fragment(html).element_children, Document::SECTION_LABELS)
  end

  test 'decode reads ALLRIS pages as Windows-1252' do
    # 0x96 is an en dash in Windows-1252 but a C1 control in ISO-8859-1.
    assert_equal 'Altona – Gewalt über', Parsing.decode("Altona \x96 Gewalt \xFCber".b)
  end

  test 'decode leaves valid UTF-8 alone' do
    assert_equal 'Straße', Parsing.decode('Straße')
  end

  test 'clean keeps the space from a whitespace-only span' do
    html = '<p><span style="font-family:Calibri">D</span><span style="font-family:Calibri">er</span>' \
           '<span style="font-family:Calibri"> </span><span style="font-family:Calibri">Geschä</span>' \
           '<span style="font-family:Calibri">ftsstelle</span></p>'

    assert_equal '<p>Der Geschäftsstelle</p>', clean(html)
  end

  test 'clean drops Word formatting but keeps emphasis' do
    html = '<p style="margin-top:0pt; text-align:justify; font-size:11pt">' \
           '<span style="font-family:Arial; font-weight:bold">Beschluss der </span>' \
           '<span style="font-family:Arial; font-weight:bold">Bezirksversammlung</span> ' \
           '<span style="font-style:italic; color:#333333">einstimmig</span></p>'

    assert_equal '<p><strong>Beschluss der Bezirksversammlung</strong> <em>einstimmig</em></p>', clean(html)
  end

  test 'clean lets an inner normal weight cancel a bold paragraph' do
    html = '<p style="font-weight:bold"><span>Petitum </span><span style="font-weight:normal">zur Kenntnis</span></p>' \
           '<ol style="font-style:italic"><li>Eins</li></ol>'

    assert_equal '<p><strong>Petitum </strong>zur Kenntnis</p><ol><li><em>Eins</em></li></ol>', clean(html)
  end

  test 'clean turns raised footnote marks into superscript' do
    html = '<p><span>2020</span><span style="font-size:6pt; vertical-align:super">2</span></p>'

    assert_equal '<p>2020<sup>2</sup></p>', clean(html)
  end

  test 'clean replaces Symbol and Wingdings characters with ones a browser can draw' do
    html = '<p><span style="font-family:Symbol">&#xF0B7;</span><span> </span><span>Fischbeker Heidbrook</span></p>' \
           '<p><span style="font-family:Wingdings">&#xF0A7;</span> Sandbek</p>'

    assert_equal '<p>• Fischbeker Heidbrook</p><p>▪ Sandbek</p>', clean(html)
  end

  test 'clean keeps lists, their numbering and table structure' do
    html = '<ol start="3" style="margin-left:18pt"><li style="color:#333333"><span>Frage</span></li></ol>' \
           '<table style="width:100%" cellpadding="0"><tr><td colspan="2" style="border:1px solid">Zelle</td></tr></table>'

    assert_equal '<ol start="3"><li>Frage</li></ol><table><tr><td colspan="2">Zelle</td></tr></table>', clean(html).delete("\n")
  end

  test 'clean keeps numbers of paragraphs that only look like a list' do
    html = '<p><span style="font-style:italic">1.</span><span style="display:inline-block; width:18pt"> </span>' \
           '<span style="font-style:italic">Keine Vermietung</span></p>'

    assert_equal '<p><em>1. Keine Vermietung</em></p>', clean(html)
  end

  test 'clean removes paragraphs holding nothing but non-breaking spaces' do
    assert_equal '<p>Text</p>', clean('<p><span>&nbsp;</span></p><p>Text</p><p><span style="font-weight:bold"></span><br></p>')
  end

  test 'clean turns headings into subordinate ones and divs into paragraphs' do
    assert_equal "<h3>Titel</h3>\n<p>Absatz</p>", clean("<h1>Titel</h1>\n<div>Absatz</div>")
  end

  test 'clean removes scripts and unsafe links' do
    html = '<p><script>alert(1)</script><a href="javascript:alert(1)" onclick="x()">Link</a>' \
           '<a href="vo020.asp?VOLFDNR=1" target="_blank">Drucksache</a></p>'

    assert_equal '<p><a>Link</a><a href="vo020.asp?VOLFDNR=1">Drucksache</a></p>', clean(html)
  end

  test 'clean accepts a node set and returns the inner HTML of every node' do
    nodes = Nokogiri::HTML.fragment('<div><span>Eins</span></div><div><span>Zwei</span></div>').css('div')

    assert_equal 'EinsZwei', Parsing.clean(nodes)
  end

  test 'text separates blocks and line breaks and decodes entities' do
    html = '<p>folgt:<br>Die A &amp; B</p><p>Neu</p><ol><li>Eins</li><li>Zwei</li></ol>'

    assert_equal "folgt:\nDie A & B\nNeu\nEins\nZwei", Parsing.text(html)
  end

  test 'sections finds a label that Word split across spans and strips it' do
    html = '<div><p><span style="font-weight:bold">Petitum/</span><span style="font-weight:bold">Beschluss:</span></p>' \
           '<p><span>Um Kenntnisnahme wird gebeten.</span></p></div>'

    assert_equal [:resolution], sections(html).map(&:key)
    assert_equal '<p>Um Kenntnisnahme wird gebeten.</p>', Parsing.clean_sections(sections(html))
  end

  test 'sections strips a label that shares its paragraph with the text' do
    html = '<div><p><span>Petitum:</span><span>Die Bezirksversammlung wird um Kenntnisnahme gebeten.</span></p></div>'

    assert_equal '<p>Die Bezirksversammlung wird um Kenntnisnahme gebeten.</p>', Parsing.clean_sections(sections(html))
  end

  test 'sections looks past an empty paragraph in front of the label' do
    html = '<div><p><span></span></p><p><span>Petitum/Beschlussvorschlag:</span></p><p>Der Vorsitzende wird gebeten.</p></div>'

    assert_equal [:resolution], sections(html).map(&:key)
  end

  test 'sections looks into a div wrapped around the section' do
    html = '<div><div><p>Petitum/Beschlussvorschlag:</p><p>Der Vorsitzende wird gebeten.</p></div></div>'

    assert_equal [:resolution], sections(html).map(&:key)
    assert_equal '<p>Der Vorsitzende wird gebeten.</p>', Parsing.clean_sections(sections(html))
  end

  test 'sections does not take a label in running text for one' do
    html = '<div><p><span>Vor diesem Hintergrund: fragen wir</span></p></div><div><p>Sachverhaltensweisen</p></div>'

    assert_equal [nil, nil], sections(html).map(&:key)
  end

  test 'sections skips blank divs' do
    assert_empty sections('<div><p><span>&nbsp;</span></p></div>')
  end

  test 'clean_sections keeps a section that is nothing but an image' do
    assert_equal '<p><img src="scan.png"></p>', Parsing.clean_sections(sections('<div><p>Sachverhalt:</p><p><img src="scan.png"></p></div>'))
  end

  test 'clean_sections returns nil for nothing but labels and placeholders' do
    assert_nil Parsing.clean_sections(sections('<div><p>Sachverhalt:</p><p>&nbsp;</p></div>'))
    assert_nil Parsing.clean_sections(sections('<div><p>Petitum/Beschluss: ohne</p></div>'))
    assert_nil Parsing.clean_sections(sections('<div><p>Anlage/n:</p><p>---</p></div>'))
    assert_nil Parsing.clean_sections(sections('<div><p>Anlage/n: -/-</p></div>'))
    assert_nil Parsing.clean_sections([])
  end
end
