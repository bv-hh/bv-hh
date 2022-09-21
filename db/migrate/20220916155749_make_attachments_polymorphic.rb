class MakeAttachmentsPolymorphic < ActiveRecord::Migration[6.1]
  def change
    rename_column :attachments, :document_id, :attachable_id
    add_column :attachments, :attachable_type, :string, index: true

    reversible do |dir|
      dir.up do
        Attachment.update_all(attachable_type: 'Document')
      end
    end
  end
end
