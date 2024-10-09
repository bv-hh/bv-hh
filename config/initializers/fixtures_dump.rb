# frozen_string_literal: true

class ActiveRecord::Base
  IGNORED_FIXTURE_ATTRIBUTES = %w[id created_at updated_at]
  def dump_fixture
    fixture_file = Rails.root.join("test/fixtures/#{self.class.table_name}.yml").to_s
    File.open(fixture_file, 'a+') do |f|
      f.puts({ "#{self.class.table_name.singularize}_#{id}" => attributes.except(*IGNORED_FIXTURE_ATTRIBUTES) }
        .to_yaml.sub!(/---\s?/, "\n"))
    end
  end
end
