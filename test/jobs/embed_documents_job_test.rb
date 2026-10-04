# frozen_string_literal: true

require 'test_helper'

class EmbedDocumentsJobTest < ActiveJob::TestCase
  test 'runs the embedding in a process of its own' do
    job = EmbedDocumentsJob.new
    commands = []
    job.define_singleton_method(:system) { |*command, **options| commands << [command, options] }

    job.perform_now

    assert_equal [[[Rails.root.join('bin/rails').to_s, 'embeddings:update'], { exception: true }]], commands
  end
end
