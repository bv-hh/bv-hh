# frozen_string_literal: true

require 'test_helper'

class MinutesDecisionTest < ActiveSupport::TestCase
  def outcome(minutes, result: nil, document: documents(:document_7))
    MinutesDecision.outcome(AgendaItem.new(document:, minutes: "<p>#{minutes}</p>", result: result && "<p>#{result}</p>"))
  end

  test 'reads the vote of the body in its usual wordings' do
    assert_equal :adopted, outcome('Der Antrag wird bei Gegenstimmen der AfD mehrheitlich beschlossen.')
    assert_equal :adopted, outcome('Der Fachausschuss stimmt dem Antrag einstimmig zu.')
    assert_equal :amended, outcome('Der Ausschuss beschließt den so geänderten Antrag einstimmig.')
    assert_equal :noted, outcome('Die Drucksache wird zur Kenntnis genommen.')
    assert_equal :noted, outcome('Der Umweltausschuss nimmt von dieser Mitteilung Kenntnis.')
    assert_equal :referred, outcome('Die Bezirksversammlung überweist den Antrag einstimmig in den Ausschuss für Bildung und Sport.')
    assert_equal :postponed, outcome('Der Antrag verbleibt im Ausschuss.')
    assert_equal :rejected, outcome('Der Stadtentwicklungsausschuss lehnt den Antrag mehrheitlich ab.')
    assert_equal :rejected, outcome('Die Drucksache 21-4776 findet keine Mehrheit.')
    assert_equal :withdrawn, outcome('Herr Flemming zieht den Antrag zurück.')
  end

  test 'adopted and referred is adopted, as ALLRIS counts it' do
    assert_equal :adopted, outcome('Der Hauptausschuss beschließt den Antrag einstimmig und überweist ihn in den Jugendhilfeausschuss.')
  end

  test 'the last vote decides, and the result text before the minutes' do
    assert_equal :adopted, outcome('Der Antrag wird vertagt. Später in der Sitzung: Der Antrag wird einstimmig beschlossen.')
    assert_equal :rejected, outcome('Die Drucksache wird zur Kenntnis genommen.', result: 'Der Ausschuss lehnt den Antrag ab.')
  end

  test 'leaves out what is not the vote on this item' do
    assert_nil outcome('Frau Petersen stimmt dem Antrag gerne zu.')
    assert_nil outcome('Herr Weiske erklärt, dass über die Drucksache beschlossen werde.')
    assert_nil outcome('Die Bezirksversammlung lehnt die Dringlichkeit mehrheitlich ab.')
    assert_nil outcome('Die Bezirksversammlung lehnt eine Überweisung in den Verkehrsausschuss ab.')
    assert_nil outcome('Der Alternativantrag (Drucksache 21-0317.1) erhält keine Mehrheit.')
    assert_nil outcome('Die Punkte 2 und 3 der Drucksache werden einvernehmlich beschlossen.')
    assert_nil outcome('Der Antrag wurde in der Bezirksversammlung bereits abgelehnt.')
    assert_nil outcome('Der Ausschuss beschließt, den Antrag nicht abzustimmen.')
    assert_nil outcome('Überwiesen aus der Sitzung der Bezirksversammlung vom 25.02.2021.')
  end

  test 'leaves out a vote on another Drucksache, but not on its own family' do
    assert_nil outcome('Die Bezirksversammlung beschließt den Antrag Drs. 21-0586 einstimmig.')
    assert_equal :adopted, outcome('Die Drucksache 21-4776.1 wird einstimmig beschlossen.')
  end

  test 'is nil where the text states no decision' do
    assert_nil outcome('Herr Meyer berichtet über den Stand der Planung. Es gibt keine Fragen.')
  end
end
