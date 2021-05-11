# frozen_string_literal: true

module DocumentsHelper
  DOCUMENT_NUMBER_PATTERN = /(\d{2}-\d{4})/
  IMAGE_LINK_PATTERN = /img src="([^"]*)"/

  def link_documents(content, district)
    numbers = content.scan(DOCUMENT_NUMBER_PATTERN).flatten
    documents = district.documents.where(number: numbers).index_by(&:number)

    content.gsub DOCUMENT_NUMBER_PATTERN do |number|
      document = documents[number]
      if document
        link_to number, document_path(document), title: document.title, data: { toggle: :tooltip, placement: :bottom }
      else
        number
      end
    end
  end

  def link_images(content, document)
    content.gsub(IMAGE_LINK_PATTERN) do |_src|
      src = Regexp.last_match(1)&.squish
      image = document.images.attachments.find { |a| a.filename == File.basename(src) }
      if image.present?
        "img src=\"#{rails_blob_path(image)}\""
      else
        'span'
      end
    end
  end

  def document_format(document, attribute)
    content = document.send(attribute.to_sym)

    return '' if content.nil?

    content = link_documents(content, document.district)
    content = link_images(content, document)

    Rinku.auto_link(content, :all, 'target="_blank"')
  end

  def highlight_multi_excerpt(text, terms)
    multiple_terms = terms.squish.split
    multi_excerpt = multiple_terms.map do |term|
      excerpt(text, term, radius: 100)
    end.join(' ')

    highlight(multi_excerpt, multiple_terms)
  end

  def structured_data_for_document(document)
    {
      "@context": 'http://schema.org',
      "@type": 'Article',
      mainEntityOfPage: {
        "@type": 'WebPage',
        "@id": document_url(document),
      },
      headline: document.title.squish,
      image: [],
      articleBody: document.full_text.squish,
      articleSection: document.district.name,
      datePublished: document.created_at.iso8601,
      dateModified: document.updated_at.iso8601,
      publisher: {
        "@type": 'Organization',
        name: "Bezirksversammlung #{document.district.name}",
      },
      isAccessibleForFree: 'True',
      description: strip_tags(document.content)&.squish&.truncate(200) || '',
    }
  end
end
