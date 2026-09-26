# == Schema Information
#
# Table name: allris_pages
#
#  id              :integer          not null, primary key
#  record_type     :string           not null
#  record_id       :integer          not null
#  compressed_body :binary           not null
#  fetched_at      :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_allris_pages_on_record  (record_type,record_id) UNIQUE
#

# frozen_string_literal: true

# A page as ALLRIS served it (raw Windows-1252 bytes, see Parsing.decode),
# stored so its record can be parsed again without another download.
class AllrisPage < ApplicationRecord
  belongs_to :record, polymorphic: true

  def body
    Zlib::Inflate.inflate(compressed_body)
  end

  def body=(source)
    self.compressed_body = Zlib::Deflate.deflate(source.b, Zlib::BEST_COMPRESSION)
  end
end
