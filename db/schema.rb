# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_30_201936) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agenda_items", force: :cascade do |t|
    t.bigint "meeting_id"
    t.bigint "document_id"
    t.string "title"
    t.string "number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "minutes"
    t.integer "allris_id"
    t.string "decision"
    t.text "result"
    t.integer "word_count", default: 0, null: false
    t.index "((setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::\"char\") || setweight(to_tsvector('german'::regconfig, minutes), 'B'::\"char\")))", name: "agenda_items_expr_idx", using: :gin
    t.index ["document_id"], name: "index_agenda_items_on_document_id"
    t.index ["meeting_id"], name: "index_agenda_items_on_meeting_id"
    t.index ["minutes"], name: "agenda_items_minutes_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["minutes"], name: "agenda_items_minutes_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
    t.index ["title"], name: "agenda_items_title_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["title"], name: "agenda_items_title_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time", precision: nil
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
    t.datetime "started_at", precision: nil
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "allris_pages", force: :cascade do |t|
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.binary "compressed_body", null: false
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_allris_pages_on_record", unique: true
  end

  create_table "attachment_searches", force: :cascade do |t|
  end

  create_table "attachments", force: :cascade do |t|
    t.bigint "district_id"
    t.bigint "attachable_id"
    t.string "name"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attachable_type"
    t.index "((setweight(to_tsvector('german'::regconfig, (name)::text), 'A'::\"char\") || setweight(to_tsvector('german'::regconfig, content), 'B'::\"char\")))", name: "attachments_expr_idx", using: :gin
    t.index ["attachable_id"], name: "index_attachments_on_attachable_id"
    t.index ["content"], name: "content_text_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["district_id"], name: "index_attachments_on_district_id"
    t.index ["name"], name: "name_text_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "name_text_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "query_id"
    t.text "statement"
    t.string "data_source"
    t.datetime "created_at", precision: nil
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.bigint "creator_id"
    t.bigint "query_id"
    t.string "state"
    t.string "schedule"
    t.text "emails"
    t.text "slack_channels"
    t.string "check_type"
    t.text "message"
    t.datetime "last_run_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.bigint "dashboard_id"
    t.bigint "query_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.text "description"
    t.text "statement"
    t.string "data_source"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "blocked_location_names", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "source", default: "computed", null: false
    t.integer "district_count", default: 0, null: false
    t.integer "occurrences", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name"], name: "index_blocked_location_names_on_normalized_name", unique: true
    t.index ["source"], name: "index_blocked_location_names_on_source"
  end

  create_table "committees", force: :cascade do |t|
    t.bigint "district_id"
    t.integer "allris_id"
    t.string "name"
    t.integer "order", default: 0
    t.boolean "public", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "inactive", default: false
    t.integer "average_duration"
    t.string "allris_type", default: "au"
    t.integer "average_word_count"
    t.index ["allris_id"], name: "index_committees_on_allris_id"
    t.index ["district_id"], name: "index_committees_on_district_id"
  end

  create_table "districts", force: :cascade do |t|
    t.string "name"
    t.string "allris_base_url"
    t.integer "oldest_allris_document_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "oldest_allris_meeting_date"
    t.string "first_legislation_number"
    t.integer "order", default: 0
    t.float "ne_lat"
    t.float "ne_lng"
    t.float "sw_lat"
    t.float "sw_lng"
  end

  create_table "document_embeddings", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.string "model", null: false
    t.string "digest", null: false
    t.vector "embedding", limit: 768, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_embeddings_on_document_id", unique: true
    t.index ["embedding"], name: "index_document_embeddings_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
  end

  create_table "document_locations", force: :cascade do |t|
    t.bigint "document_id"
    t.bigint "location_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "location_id"], name: "index_document_locations_on_document_and_location", unique: true
    t.index ["document_id"], name: "index_document_locations_on_document_id"
    t.index ["location_id", "document_id"], name: "index_document_locations_on_location_and_document"
    t.index ["location_id"], name: "index_document_locations_on_location_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "district_id"
    t.integer "allris_id"
    t.string "number"
    t.string "title"
    t.text "content"
    t.text "resolution"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind"
    t.boolean "non_public", default: false
    t.text "full_text"
    t.string "author"
    t.text "attached"
    t.string "extracted_locations", default: [], array: true
    t.datetime "locations_extracted_at", precision: nil
    t.boolean "noindex", default: false, null: false
    t.string "quarters", default: [], null: false, array: true
    t.string "stations", default: [], null: false, array: true
    t.integer "parser_version"
    t.string "topics", default: [], null: false, array: true
    t.integer "topics_version"
    t.index "((setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::\"char\") || setweight(to_tsvector('german'::regconfig, full_text), 'B'::\"char\")))", name: "documents_expr_idx", using: :gin
    t.index ["allris_id"], name: "index_documents_on_allris_id"
    t.index ["created_at"], name: "index_documents_on_created_at_public_complete", order: :desc, where: "((non_public = false) AND (title IS NOT NULL))"
    t.index ["district_id", "parser_version", "updated_at"], name: "idx_on_district_id_parser_version_updated_at_4aac032a73"
    t.index ["district_id"], name: "index_documents_on_district_id"
    t.index ["full_text"], name: "full_text_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["full_text"], name: "full_text_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
    t.index ["number"], name: "index_documents_on_number"
    t.index ["quarters"], name: "index_documents_on_quarters", using: :gin
    t.index ["stations"], name: "index_documents_on_stations", using: :gin
    t.index ["title"], name: "title_gin_trgm_idx", opclass: :gin_trgm_ops, using: :gin
    t.index ["title"], name: "title_gist_trgm_idx", opclass: :gist_trgm_ops, using: :gist
    t.index ["topics"], name: "index_documents_on_topics", using: :gin
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class", "finished_at"], name: "index_good_jobs_on_discarded_job_class", where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "place_id"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "normalized_name"
    t.string "extracted_name"
    t.bigint "district_id"
    t.string "formatted_address"
    t.string "quarters", default: [], null: false, array: true
    t.string "street_name"
    t.index ["district_id"], name: "index_locations_on_district_id"
    t.index ["name"], name: "index_locations_on_name"
    t.index ["normalized_name"], name: "index_locations_on_normalized_name"
    t.index ["place_id"], name: "index_locations_on_place_id"
    t.index ["quarters"], name: "index_locations_on_quarters", using: :gin
    t.index ["street_name"], name: "index_locations_on_street_name"
  end

  create_table "meetings", force: :cascade do |t|
    t.bigint "district_id"
    t.string "title"
    t.date "date"
    t.string "time"
    t.string "room"
    t.string "location"
    t.integer "allris_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "committee_id"
    t.time "start_time"
    t.time "end_time"
    t.text "note"
    t.index ["allris_id"], name: "index_meetings_on_allris_id"
    t.index ["committee_id"], name: "index_meetings_on_committee_id"
    t.index ["district_id"], name: "index_meetings_on_district_id"
  end

  create_table "members", force: :cascade do |t|
    t.integer "allris_id"
    t.bigint "district_id"
    t.bigint "party_id"
    t.string "name"
    t.string "kind"
    t.boolean "inactive", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id", "allris_id"], name: "index_members_on_district_id_and_allris_id", unique: true
    t.index ["district_id"], name: "index_members_on_district_id"
    t.index ["party_id"], name: "index_members_on_party_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "committee_id"
    t.bigint "member_id"
    t.string "role"
    t.boolean "inactive", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["committee_id", "member_id"], name: "index_memberships_on_committee_id_and_member_id", unique: true
    t.index ["committee_id"], name: "index_memberships_on_committee_id"
    t.index ["member_id"], name: "index_memberships_on_member_id"
  end

  create_table "parties", force: :cascade do |t|
    t.integer "allris_id"
    t.bigint "district_id"
    t.string "name"
    t.boolean "inactive", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id", "allris_id"], name: "index_parties_on_district_id_and_allris_id", unique: true
    t.index ["district_id"], name: "index_parties_on_district_id"
  end

  create_table "pois", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "category", null: false
    t.string "osm_type", null: false
    t.bigint "osm_id", null: false
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.string "quarter"
    t.string "quarters", default: [], null: false, array: true
    t.integer "district_number"
    t.string "postal_code"
    t.boolean "generic", default: false, null: false
    t.boolean "transit", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aliases", default: [], null: false, array: true
    t.index ["aliases"], name: "index_pois_on_aliases", using: :gin
    t.index ["district_number"], name: "index_pois_on_district_number"
    t.index ["normalized_name"], name: "index_pois_on_normalized_name"
    t.index ["osm_type", "osm_id"], name: "index_pois_on_osm_type_and_osm_id", unique: true
    t.index ["quarters"], name: "index_pois_on_quarters", using: :gin
    t.index ["transit"], name: "index_pois_on_transit"
  end

  create_table "quarters", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "key", null: false
    t.string "number"
    t.integer "district_number"
    t.string "district_name"
    t.jsonb "geometry", null: false
    t.float "min_lat"
    t.float "max_lat"
    t.float "min_lng"
    t.float "max_lng"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_number"], name: "index_quarters_on_district_number"
    t.index ["key"], name: "index_quarters_on_key", unique: true
    t.index ["name"], name: "index_quarters_on_name"
    t.index ["slug"], name: "index_quarters_on_slug", unique: true
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "streets", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.float "latitude"
    t.float "longitude"
    t.string "quarter"
    t.string "postal_code"
    t.string "street_key"
    t.integer "district_numbers", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "quarters", default: [], null: false, array: true
    t.string "quarter_keys", default: [], null: false, array: true
    t.index ["district_numbers"], name: "index_streets_on_district_numbers", using: :gin
    t.index ["normalized_name"], name: "index_streets_on_normalized_name"
    t.index ["normalized_name"], name: "index_streets_on_normalized_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["quarter_keys"], name: "index_streets_on_quarter_keys", using: :gin
    t.index ["quarters"], name: "index_streets_on_quarters", using: :gin
    t.index ["street_key"], name: "index_streets_on_street_key"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "document_embeddings", "documents", on_delete: :cascade
  add_foreign_key "members", "districts"
  add_foreign_key "members", "parties"
  add_foreign_key "memberships", "committees"
  add_foreign_key "memberships", "members"
  add_foreign_key "parties", "districts"
end
