# frozen_string_literal: true

# == Schema Information
#
# Table name: attachments
#
#  id              :bigint           not null, primary key
#  attachable_type :string
#  content         :text
#  name            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  attachable_id   :bigint
#  district_id     :bigint
#
# Indexes
#
#  attachments_expr_idx                (((setweight(to_tsvector('german'::regconfig, (name)::text), 'A'::"char") || setweight(to_tsvector('german'::regconfig, content), 'B'::"char")))) USING gin
#  content_text_gin_trgm_idx           (content) USING gin
#  content_text_gist_trgm_idx          (content) USING gist
#  index_attachments_on_attachable_id  (attachable_id)
#  index_attachments_on_district_id    (district_id)
#  name_text_gin_trgm_idx              (name) USING gin
#  name_text_gist_trgm_idx             (name) USING gist
#
class Attachment < ApplicationRecord
  belongs_to :district
  belongs_to :attachable, polymorphic: true

  has_one_attached :file

  scope :by_name, -> { order(:name) }

  def extract_later!
    AttachmentExtractJob.perform_later(self)
  end

  def extract_text!
    extract = file.open { |tmp| SimpleTextExtract.extract(tempfile: tmp) }
    update!(content: extract)
  end
end
