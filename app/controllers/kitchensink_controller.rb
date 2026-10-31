# frozen_string_literal: true

# Every chip and badge style from ChipHelper and both rows of a Drucksachen
# list on one page, with real records, as the reference for new views. Routed
# outside production only.
class KitchensinkController < ApplicationController
  def show
    @noindex = true
    @title = 'Kitchensink'
    @locations = Location.where.not(formatted_address: nil).includes(:district).limit(3).to_a
    @quarters = Quarter.by_name.select(&:district).first(4)
    @topics = Topic.first(3)
    @districts = District.by_order.first(3)
    @documents = sample_documents.presence || listed_documents.limit(3).to_a
    @compact_documents = listed_documents.limit(4).to_a
  end

  private

  def listed_documents
    Document.complete.order(id: :desc).for_list
  end

  # One Drucksache decided on, with topics and places, one turned down, one
  # still to be discussed and one no meeting has had on its agenda: the ways a
  # row can read, as far as the database has them.
  def sample_documents
    with_chips = listed_documents.where(id: DocumentLocation.select(:document_id)).where('cardinality(documents.topics) > 0')
    [
      with_chips.merge(discussed_in(items.where.not(decision: nil))).first,
      discussed_in(items.where(decision: 'abgelehnt')).first,
      discussed_in(items.joins(:meeting).where(meetings: { date: Time.zone.today.. })).first,
      listed_documents.where.not(id: items.select(:document_id)).first,
    ].compact.uniq
  end

  def items
    AgendaItem.where.not(document_id: nil)
  end

  def discussed_in(agenda_items)
    listed_documents.where(id: agenda_items.select(:document_id))
  end
end
