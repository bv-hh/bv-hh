# frozen_string_literal: true

module ApplicationHelper
  def allris_link(allris_url)
    link_to allris_url, target: '_blank', title: 'In Allris öffnen', data: { toggle: :tooltip, placement: :bottom }, rel: 'noopener' do
      allris_icon
    end
  end

  def allris_icon
    icon(:fas, 'external-link-alt')
  end
end
