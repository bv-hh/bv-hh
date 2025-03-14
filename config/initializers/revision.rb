# frozen_string_literal: true

if Rails.root.join('REVISION').exist?
  REVISION = Rails.root.join('REVISION').read.squish
  REVISION_TRUNC = REVISION[..9]
else
  REVISION = 'development'
  REVISION_TRUNC = 'dev'
end
