# frozen_string_literal: true

# Turns ALLRIS pages into the HTML we store. ALLRIS content is Word output run
# through "ALLRIS Office Integration": every run of text sits in its own styled
# <span>, split at umlauts and often mid-word, with the spaces between words in
# spans of their own. The goal is to keep the structure (paragraphs, lists,
# tables, emphasis) and drop everything Word-specific (fonts, sizes, colours,
# margins, widths, spacer spans).
#
# Cleaning works on the DOM, not on the serialised string: a span is unwrapped
# rather than deleted, so the space inside a whitespace-only span survives.
module Parsing
  extend ActiveSupport::Concern

  # Bump when a change here alters what gets stored for a document:
  # RefetchDocumentsJob then fetches every document parsed with an older one.
  #   1 (NULL) regex cleaner, lost the spaces between words
  #   2        DOM cleaner, sections in page order
  VERSION = 2

  ALLOWED_TAGS = %w[p br hr h3 h4 ol ul li table thead tbody tr th td strong em u sub sup a img].freeze
  ALLOWED_ATTRIBUTES = {
    'ol' => %w[start type],
    'th' => %w[colspan rowspan],
    'td' => %w[colspan rowspan],
    'a' => %w[href],
    'img' => %w[src alt],
  }.freeze
  RENAMED_TAGS = { 'h1' => 'h3', 'h2' => 'h3', 'h5' => 'h4', 'h6' => 'h4', 'b' => 'strong', 'i' => 'em' }.freeze

  # Inline styles that carry meaning, each with the style that switches it on
  # and the one that switches it off again further in: Word writes
  # <p style="font-weight:bold"><span style="font-weight:normal">. Everything
  # else in a style attribute goes.
  EMPHASIS_STYLES = {
    'strong' => [/font-weight:\s*(bold|[6-9]00)/, /font-weight:\s*(normal|[1-5]00)/],
    'em' => [/font-style:\s*italic/, /font-style:\s*normal/],
    'u' => [/text-decoration:[^;]*underline/, /text-decoration:\s*none/],
    'sup' => [/vertical-align:\s*super/, /vertical-align:\s*(baseline|sub)/], # footnote marks: "2020²", not "20202"
    'sub' => [/vertical-align:\s*sub/, /vertical-align:\s*(baseline|super)/],
  }.freeze
  EMPHASIS_TAGS = EMPHASIS_STYLES.keys.join('|')

  # Word writes text set in the Symbol or Wingdings font as Private Use Area
  # code points, which no browser font draws. These are the ones ALLRIS pages
  # use: mostly the bullets of paragraphs that only look like a list, and the
  # brackets of a footnote mark.
  SYMBOL_FONT_CHARACTERS = {
    "\uF0B7" => '•', # Symbol bullet
    "\uF0A7" => '▪', # Wingdings small square
    "\uF05B" => '[',
    "\uF05D" => ']',
    "\uF02A" => '*',
  }.freeze
  SYMBOL_FONT_PATTERN = Regexp.union(SYMBOL_FONT_CHARACTERS.keys)

  BLOCK_TAGS = %w[p div h1 h2 h3 h4 h5 h6 ol ul li table thead tbody tr th td hr].join(',')
  TEXT_BREAK_TAGS = "#{BLOCK_TAGS},br".freeze
  XPATHS_TO_REMOVE = %w[.//script .//style .//form .//noscript comment()].freeze

  # What a section holds when it has nothing to say: "Anlage/n: keine",
  # "Petitum/Beschluss: ohne", "Anlage/n: ---", "Anlage/n: -/-".
  PLACEHOLDER = %r{\A(ohne|keine|[-–—/]+)\.?\z}i

  Section = Struct.new(:key, :div, :label)

  SANITIZER = Rails::Html::SafeListSanitizer.new
  SANITIZER_ATTRIBUTES = ALLOWED_ATTRIBUTES.values.flatten.uniq.freeze

  class << self
    # ALLRIS declares ISO-8859-1 but actually writes Windows-1252: typographic
    # dashes and quotes arrive as 0x80-0x9F, which ISO-8859-1 decodes to C1
    # control characters. Windows-1252 agrees with ISO-8859-1 everywhere else.
    # A page that is already valid UTF-8 (a test string, a future ALLRIS) is
    # left alone — German Latin-1 text is practically never valid UTF-8.
    def decode(source)
      utf8 = source.dup.force_encoding(Encoding::UTF_8)
      return utf8 if utf8.valid_encoding?

      source.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '')
    end

    def parse(source)
      Nokogiri::HTML.parse(decode(source), nil, 'UTF-8')
    end

    # Accepts a node or a node set and returns the cleaned inner HTML. Only the
    # descendants are touched: the container itself is not part of the result.
    def clean(node)
      return nil if node.nil?

      containers = node.is_a?(Nokogiri::XML::NodeSet) ? node.to_a : [node]
      html = containers.map { |container| clean_container(container) }.join
      tidy(SANITIZER.sanitize(html, tags: ALLOWED_TAGS, attributes: SANITIZER_ATTRIBUTES))
    end

    # The body of an ALLRIS page is a run of sibling divs, most of which open
    # with a label paragraph ("Sachverhalt:", "Petitum/Beschluss:"). Tags each
    # non-blank div with the key of the first label it opens with, or nil.
    #
    # The label is matched on the paragraph's text, because Word splits it
    # across spans ("Petitum/" + "Beschluss:"), and only at the start of a
    # section, so "Vor diesem Hintergrund:" in running text is not taken for
    # one. Unlabelled divs are common and carry substance: Altona never labels
    # the Sachverhalt, Harburg puts the Bezirksamt's answer in a div of its
    # own, Hamburg-Mitte a div per footnote.
    def sections(divs, labels)
      divs.filter_map do |div|
        next if squished_text(div).empty? && div.at_css('img').nil?

        key, pattern = labels.find { |_, candidate| label_paragraph(div, candidate) }
        Section.new(key, div, pattern)
      end
    end

    # Cleaned HTML of the given sections, their labels stripped, or nil unless
    # there is substance? besides the labels.
    def clean_sections(sections)
      html = sections.map do |section|
        div = section.div.dup
        strip_label(label_paragraph(div, section.label), section.label) if section.label
        clean(div)
      end.join("\n")

      html if substance?(html)
    end

    # Whether cleaned HTML has anything to show: text that is not a placeholder
    # like "ohne", or an image (a Sachverhalt can be nothing but a scanned map).
    def substance?(html)
      return false if html.nil?

      content = text(html)
      (content.present? && !content.match?(PLACEHOLDER)) || html.include?('<img')
    end

    # Plain text of stored HTML, for search and NER: block boundaries and <br>
    # become line breaks (strip_tags glues "folgt:<br>Die" into "folgt:Die"),
    # and entities are decoded rather than left as "&amp;".
    def text(html)
      return nil if html.nil?

      fragment = Nokogiri::HTML.fragment(html)
      fragment.css(TEXT_BREAK_TAGS).each do |node|
        node.add_previous_sibling("\n")
        node.add_next_sibling("\n")
      end
      collapse_whitespace(fragment.text)
    end

    private

    def clean_container(container)
      container.xpath(*XPATHS_TO_REMOVE).remove
      emphasize_text(container)
      container.css('*').each { |element| normalize_element(element) }
      container.css('*').reverse_each { |element| element.replace(element.children) unless ALLOWED_TAGS.include?(element.name) }
      container.inner_html
    end

    def normalize_element(element)
      element.name = RENAMED_TAGS.fetch(element.name, element.name)
      element.name = 'p' if element.name == 'div' && element.at_css(BLOCK_TAGS).nil?

      allowed = ALLOWED_ATTRIBUTES.fetch(element.name, [])
      element.attribute_nodes.each { |attribute| attribute.remove unless allowed.include?(attribute.name) }
    end

    # Wraps every run of text in the emphasis its nearest styled ancestor gives
    # it. Working on the text rather than the styled element keeps <strong>
    # inside the block it belongs to (a bold <ol> becomes bold list items), and
    # lets an inner "normal" win. tidy merges the runs Word split up.
    def emphasize_text(container)
      container.xpath('.//text()[normalize-space()]').each do |text_node|
        EMPHASIS_STYLES.each do |tag, (on, off)|
          text_node.wrap("<#{tag}></#{tag}>") if emphasized?(text_node, container, on, off)
        end
      end
    end

    def emphasized?(text_node, container, on, off)
      text_node.ancestors.each do |ancestor|
        break if ancestor == container

        style = ancestor['style'].to_s.downcase
        return true if style.match?(on)
        return false if style.match?(off)
      end
      false
    end

    def tidy(html)
      html = html.gsub(/\u00a0|&nbsp;/, ' ').gsub(SYMBOL_FONT_PATTERN, SYMBOL_FONT_CHARACTERS)
      loop do
        merged = html.gsub(%r{</(#{EMPHASIS_TAGS})>(\s*)<\1>}o, '\2') # runs Word split into spans
                     .gsub(%r{<(#{EMPHASIS_TAGS})>(\s*)</\1>}o, '\2') # emphasis around nothing
        break if merged == html

        html = merged
      end
      html = html.gsub(%r{<p>(\s|<br>)*</p>}, '')
      html = html.gsub(/<(p|li|td|th|h3|h4)>((?:<(?:#{EMPHASIS_TAGS})>)*)\s+/o, '<\1>\2')
      html = html.gsub(%r{\s+((?:</(?:#{EMPHASIS_TAGS})>)*)</(p|li|td|th|h3|h4)>}o, '\1</\2>')
      collapse_whitespace(html)
    end

    def collapse_whitespace(string)
      string.delete("\r").gsub(/[^\S\n]+/, ' ').gsub(/ *\n\s*/, "\n").strip
    end

    # The first paragraph with text: Word often leaves an empty one in front,
    # and sometimes wraps the whole section in another div.
    def label_paragraph(div, label)
      paragraph = div
      paragraph = paragraph.element_children.find { |child| squished_text(child).present? } while paragraph&.name == 'div'
      paragraph if paragraph&.name == 'p' && squished_text(paragraph).match?(label)
    end

    # Removes the label from the start of the paragraph, across however many
    # text nodes it was split into, and the paragraph itself if nothing is left.
    def strip_label(paragraph, label)
      remaining = squished_text(paragraph)[label].gsub(/[[:space:]]/, '')
      paragraph.xpath('.//text()').each do |text_node|
        content = text_node.content
        index = 0
        while remaining.present? && index < content.length
          if content[index].match?(/[[:space:]]/)
            index += 1
          elsif content[index] == remaining[0]
            index += 1
            remaining = remaining[1..]
          else
            break
          end
        end
        text_node.content = content[index..]
        break if remaining.empty?
      end
      paragraph.remove if squished_text(paragraph).empty?
    end

    def squished_text(node)
      node.text.gsub(/[[:space:]]+/, ' ').strip
    end
  end

  def clean_html(node)
    Parsing.clean(node)
  end

  # Cleaned HTML, or nil unless it has Parsing.substance?: ALLRIS leaves empty
  # paragraphs where minutes are still to come, and those must not count as
  # minutes (AgendaItem.with_minutes, AgendaItem.incomplete).
  def clean_text(node)
    cleaned = clean_html(node)
    cleaned if Parsing.substance?(cleaned)
  end

  def html_to_text(html)
    Parsing.text(html)
  end

  def clean_linebreaks(html)
    return nil if html.nil?

    html.gsub(%r{<br\s*/?>}, "\n").delete("\r").squish
  end

  def strip_tags(content)
    ActionController::Base.helpers.strip_tags(content)
  end
end
