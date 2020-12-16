# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20_201_214_083_016) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_trgm'
  enable_extension 'plpgsql'

  create_table 'agenda_items', force: :cascade do |t|
    t.bigint 'meeting_id'
    t.bigint 'document_id'
    t.string 'title'
    t.string 'number'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['document_id'], name: 'index_agenda_items_on_document_id'
    t.index ['meeting_id'], name: 'index_agenda_items_on_meeting_id'
  end

  create_table 'districts', force: :cascade do |t|
    t.string 'name'
    t.string 'allris_base_url'
    t.integer 'oldest_allris_document_id'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.date 'oldest_allris_meeting_date'
  end

  create_table 'documents', force: :cascade do |t|
    t.bigint 'district_id'
    t.integer 'allris_id'
    t.string 'number'
    t.string 'title'
    t.text 'content'
    t.text 'resolution'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.string 'kind'
    t.boolean 'non_public', default: false
    t.text 'full_text'
    t.index "((setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::\"char\") || setweight(to_tsvector('german'::regconfig, full_text), 'B'::\"char\")))", name: 'documents_expr_idx', using: :gin
    t.index ['allris_id'], name: 'index_documents_on_allris_id'
    t.index ['district_id'], name: 'index_documents_on_district_id'
    t.index ['full_text'], name: 'full_text_gin_trgm_idx', opclass: :gin_trgm_ops, using: :gin
    t.index ['full_text'], name: 'full_text_gist_trgm_idx', opclass: :gist_trgm_ops, using: :gist
    t.index ['number'], name: 'index_documents_on_number'
    t.index ['title'], name: 'title_gin_trgm_idx', opclass: :gin_trgm_ops, using: :gin
    t.index ['title'], name: 'title_gist_trgm_idx', opclass: :gist_trgm_ops, using: :gist
  end

  create_table 'meetings', force: :cascade do |t|
    t.bigint 'district_id'
    t.string 'title'
    t.string 'committee'
    t.date 'date'
    t.string 'time'
    t.string 'room'
    t.string 'location'
    t.integer 'allris_id'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['district_id'], name: 'index_meetings_on_district_id'
  end
end
