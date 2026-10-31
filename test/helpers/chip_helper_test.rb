# frozen_string_literal: true

require 'test_helper'

class ChipHelperTest < ActionView::TestCase
  test 'filter_chip marks the chosen option and shows its count' do
    chip = Nokogiri::HTML.fragment(filter_chip('Altona', '/altona', selected: true, count: 1234))
    link = chip.at('a')

    assert_equal 'true', link['aria-current']
    assert_includes link['class'], 'btn-secondary'
    assert_equal '1.234', link.at('span').text
  end

  test 'filter_chip leaves the others as outline without aria-current' do
    link = Nokogiri::HTML.fragment(filter_chip('Verkehr', '/verkehr', selected: false, pill: true)).at('a')

    assert_nil link['aria-current']
    assert_includes link['class'], 'btn-outline-secondary'
    assert_includes link['class'], 'rounded-pill'
  end

  test 'filter_token links to its removal' do
    link = Nokogiri::HTML.fragment(filter_token('Thema: Verkehr', '/suche')).at('a')

    assert_equal '/suche', link['href']
    assert_equal 'Thema: Verkehr aufheben', link['title']
  end
end
