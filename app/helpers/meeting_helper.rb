# frozen_string_literal: true

module MeetingHelper
  def meeting_format(content, meeting)
    return '' if content.nil?

    content = link_documents(content, meeting.district)

    Rinku.auto_link(content, :all, 'target="_blank"').html_safe
  end
end
