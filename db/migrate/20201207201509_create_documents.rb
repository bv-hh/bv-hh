class CreateDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :documents do |t|
      t.references :district, index: true
      t.integer :allris_id, index: true

      t.string :number, index: true
      t.string :title
      t.text :content
      t.text :resolution

      t.timestamps
    end
  end
end
