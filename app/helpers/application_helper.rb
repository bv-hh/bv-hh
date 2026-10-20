# frozen_string_literal: true

module ApplicationHelper
  def allris_link(allris_url)
    link_to allris_url, target: '_blank', title: 'In Allris öffnen', data: { bs_toggle: :tooltip, placement: :bottom }, rel: 'noopener' do
      allris_icon
    end
  end

  # Endpoints the typeahead in application.js reads from an input.search-input.
  def search_input_data
    {
      suggest_documents: suggest_documents_path(q: 'QUERY'),
      suggest_minutes: suggest_agenda_items_path(q: 'QUERY'),
      search: search_path(q: 'QUERY'),
    }
  end

  def allris_icon
    icon(:fas, 'external-link-alt')
  end
end
