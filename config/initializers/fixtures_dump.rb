# frozen_string_literal: true

class ActiveRecord::Base
  def dump_fixture
    fixture_file = Rails.root.join("test/fixtures/#{self.class.table_name}.yml").to_s
    File.open(fixture_file, 'a+') do |f|
      f.puts({ "#{self.class.table_name.singularize}_#{id}" => attributes }
        .to_yaml.sub!(/---\s?/, "\n"))
    end
  end
end
