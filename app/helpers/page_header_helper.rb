# frozen_string_literal: true

# The head of a page without a hero card, so that every such page reads the
# same: breadcrumbs, a small label saying what kind of thing the page shows
# (Drucksache, Sitzung, Thema), the title, and a line of context below it.
# Pages with a hero card (home, Bezirk, Stadtteil, search) only use the
# breadcrumbs.
module PageHeaderHelper
  # crumbs lead from the current Bezirk down to the page; Hamburg and the
  # Bezirk come first by themselves. Each is [label, path], or a bare label
  # for the page itself, which comes last. Without crumbs the page shows none:
  # the footer pages stand on their own.
  #
  # The block fills the line below the title; actions (an ALLRIS link, a feed
  # button) sit to the right of it.
  def page_header(title, kind: nil, crumbs: nil, actions: nil, &subtitle)
    render 'shared/page_header', title:, kind:, crumbs:, actions:, subtitle: subtitle && capture(&subtitle)
  end

  # For pages that build their own head. district: nil leaves the Bezirk out,
  # for the Bezirk page itself, which names it as the last crumb; css_class
  # goes on the list.
  def breadcrumbs(*crumbs, **)
    render('shared/breadcrumbs', crumbs:, **)
  end
end
