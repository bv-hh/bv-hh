# frozen_string_literal: true

module DocumentsHelper
  DOCUMENT_NUMBER_PATTERN = /(\d{2}-\d{4}(\.\d{1,2})+)/
  IMAGE_LINK_PATTERN = /img src="([^"]*)"/

  # The title as text. Titles carry no markup but some entities (&amp;).
  def document_title(document)
    CGI.unescapeHTML(strip_tags(document.title.to_s))
  end

  # The places a Drucksache mentions for its row in a list, one per name,
  # without the name of except (the place whose page lists it). Load them with
  # Document.with_places.
  def document_places(document, except: nil)
    document.locations.reject { |location| location.name == except&.name }.uniq(&:name).sort_by(&:name)
  end

  # Text with the search words marked, escaped first: highlight's own sanitizing
  # would read a decoded "&lt;Elbufer&gt;" as a tag and drop it.
  def highlight_text(text, words)
    highlight(ERB::Util.html_escape(text), words, sanitize: false)
  end

  def link_documents(content, district)
    numbers = content.scan(DOCUMENT_NUMBER_PATTERN).flatten
    documents = district.documents.where(number: numbers).index_by(&:number)

    content.gsub DOCUMENT_NUMBER_PATTERN do |number|
      document = documents[number]
      if document
        link_to number, document_path(document), title: strip_tags(document.title), data: { toggle: :tooltip, placement: :bottom }
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
        "img src=\"#{rails_blob_path(image)}\" class=\"img-fluid\""
      else
        'span'
      end
    end
  end

  def document_format(document, attribute)
    content = document.send(attribute.to_sym)

    return '' if content.nil?

    content = scrub_whitespace(content) if document.parser_version.nil?
    content = link_documents(content, document.district)
    content = link_images(content, document)

    Rinku.auto_link(content, :all, 'target="_blank"')
  end

  # Documents not yet re-fetched by RefetchDocumentsJob still carry the old
  # parser's empty paragraphs and space-only spans. Remove once none are left.
  def scrub_whitespace(content)
    content = content.gsub(%r{<span[^>]*>[ \u00a0]*</span>}, ' ')
    content.gsub(%r{<p[^>]*>[ \u00a0]*</p>}, ' ')
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
      '@context': 'http://schema.org',
      '@type': 'Article',
      mainEntityOfPage: {
        '@type': 'WebPage',
        '@id': document_url(document),
      },
      headline: document.title.squish,
      image: [],
      articleBody: document.full_text&.squish || '',
      articleSection: document.district.name,
      datePublished: document.created_at.iso8601,
      dateModified: document.updated_at.iso8601,
      publisher: {
        '@type': 'Organization',
        name: "Bezirksversammlung #{document.district.name}",
      },
      isAccessibleForFree: 'True',
      description: strip_tags(document.content)&.squish&.truncate(200) || '',
    }
  end
end
