class CreateAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :attachments do |t|
      t.references :district, index: true
      t.references :document, index: true

      t.string :name
      t.text :content

      t.timestamps
    end
  end
end
