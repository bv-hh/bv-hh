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

ActiveRecord::Schema.define(version: 2021_01_20_193104) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "agenda_items", force: :cascade do |t|
    t.bigint "meeting_id"
    t.bigint "document_id"
    t.string "title"
    t.string "number"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["document_id"], name: "index_agenda_items_on_document_id"
    t.index ["meeting_id"], name: "index_agenda_items_on_meeting_id"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
  end

  create_table "attachment_searches", force: :cascade do |t|
  end

  create_table "attachments", force: :cascade do |t|
    t.bigint "district_id"
    t.bigint "document_id"
    t.string "name"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index "((setweight(to_tsvector('german'::regconfig, (name)::text), 'A'::\"char\") || setweight(to_tsvector('german'::regconfig, content), 'B'::\"char\")))", name: "attachments_expr_idx", using: :gin
    t.index ["content"], name: "content_text_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["content"], name: "content_text_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
    t.index ["district_id"], name: "index_attachments_on_district_id"
    t.index ["document_id"], name: "index_attachments_on_document_id"
    t.index ["name"], name: "name_text_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "name_text_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
  end

  create_table "committees", force: :cascade do |t|
    t.bigint "district_id"
    t.integer "allris_id"
    t.string "name"
    t.integer "order", default: 0
    t.boolean "public", default: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "inactive", default: false
    t.index ["allris_id"], name: "index_committees_on_allris_id"
    t.index ["district_id"], name: "index_committees_on_district_id"
  end

  create_table "districts", force: :cascade do |t|
    t.string "name"
    t.string "allris_base_url"
    t.integer "oldest_allris_document_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.date "oldest_allris_meeting_date"
    t.string "first_legislation_number"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "district_id"
    t.integer "allris_id"
    t.string "number"
    t.string "title"
    t.text "content"
    t.text "resolution"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "kind"
    t.boolean "non_public", default: false
    t.text "full_text"
    t.string "author"
    t.text "attached"
    t.index "((setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::\"char\") || setweight(to_tsvector('german'::regconfig, full_text), 'B'::\"char\")))", name: "documents_expr_idx", using: :gin
    t.index ["allris_id"], name: "index_documents_on_allris_id"
    t.index ["district_id"], name: "index_documents_on_district_id"
    t.index ["full_text"], name: "full_text_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["full_text"], name: "full_text_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
    t.index ["number"], name: "index_documents_on_number"
    t.index ["title"], name: "title_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["title"], name: "title_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
  end

  create_table "meetings", force: :cascade do |t|
    t.bigint "district_id"
    t.string "title"
    t.string "committee"
    t.date "date"
    t.string "time"
    t.string "room"
    t.string "location"
    t.integer "allris_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "committee_id"
    t.index ["allris_id"], name: "index_meetings_on_allris_id"
    t.index ["committee_id"], name: "index_meetings_on_committee_id"
    t.index ["district_id"], name: "index_meetings_on_district_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
end
