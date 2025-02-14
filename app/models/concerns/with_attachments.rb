# frozen_string_literal: true

module WithAttachments
  extend ActiveSupport::Concern

  require 'open-uri'

  included do
    has_many :attachments, as: :attachable, dependent: :destroy
  end

  def extract_attachment_table(_html)
    raise 'Implement in model'
  end

  def retrieve_attachments(html)
    attachment_table = extract_attachment_table(html)

    current_attachment_names = []
    attachment_table.css('a[title*="(Öffnet Dokument in neuem Fenster)"]').each do |attachment_link|
      href = attachment_link['href']
      uri = URI.parse(href)

      name = attachment_link.text
      current_attachment_names << name

      next if attachments.exists?(name:)

      filename = File.basename(uri.path)
      begin
        io = URI.parse("#{district.allris_base_url}/bi/#{href}").open

        attachment = attachments.create!(name:, district:)
        attachment.file.attach(io:, filename:)
        attachment.extract_later!
      rescue OpenURI::HTTPError => _e
        # Do nothing
      end
    end

    clean_up_attachments(current_attachment_names)
  end

  def clean_up_attachments(current_attachment_names)
    attachments.each do |attachment|
      unless current_attachment_names.include?(attachment.name)
        attachment.file&.purge_later
        attachment.destroy!
      end
    end
  end

  def retrieve_attachments!
    source = Net::HTTP.get(URI(allris_url))
    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    html = html.css('table.risdeco').first
    return if html.nil?

    retrieve_attachments(html)
    save!
  end
end
