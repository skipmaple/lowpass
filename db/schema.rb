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

ActiveRecord::Schema[8.1].define(version: 2026_09_11_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "fetch_runs", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.integer "attempt", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "dropped_count"
    t.integer "duration_ms"
    t.string "error_summary", limit: 200
    t.string "issue_id", limit: 25
    t.integer "item_count"
    t.string "source_id", limit: 25, null: false
    t.datetime "started_at"
    t.string "status", limit: 10, null: false
    t.string "trigger", limit: 10, null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id"], name: "index_fetch_runs_on_issue_id"
    t.index ["source_id", "created_at"], name: "index_fetch_runs_on_source_id_and_created_at"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying::text, 'running'::character varying::text, 'succeeded'::character varying::text, 'failed'::character varying::text, 'timed_out'::character varying::text])", name: "fetch_runs_status"
    t.check_constraint "trigger::text = ANY (ARRAY['scheduled'::character varying::text, 'manual'::character varying::text, 'test'::character varying::text])", name: "fetch_runs_trigger"
  end

  create_table "issues", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "generated_late", default: false, null: false
    t.datetime "generation_started_at", null: false
    t.string "kind", limit: 10, null: false
    t.string "period_key", limit: 10, null: false
    t.datetime "published_at"
    t.datetime "revised_at"
    t.jsonb "source_states", default: {}, null: false
    t.string "state", limit: 12, default: "generating", null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "period_key"], name: "index_issues_on_kind_and_period_key", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['daily'::character varying::text, 'weekly'::character varying::text])", name: "issues_kind"
    t.check_constraint "state::text = ANY (ARRAY['generating'::character varying::text, 'published'::character varying::text, 'empty'::character varying::text])", name: "issues_state"
  end

  create_table "items", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.string "author", limit: 100
    t.datetime "created_at", null: false
    t.datetime "fetched_at", null: false
    t.boolean "hidden", default: false, null: false
    t.string "interest_tag", limit: 20
    t.string "issue_id", limit: 25, null: false
    t.jsonb "meta", default: {}, null: false
    t.datetime "published_at"
    t.integer "rank"
    t.string "reason", limit: 120
    t.datetime "reason_generated_at"
    t.string "section", limit: 100
    t.string "source_id", limit: 25, null: false
    t.string "summary", limit: 500
    t.string "title", limit: 300, null: false
    t.datetime "updated_at", null: false
    t.string "url", limit: 2048, null: false
    t.string "url_hash", limit: 64, null: false
    t.index ["issue_id", "source_id", "rank"], name: "index_items_on_issue_id_and_source_id_and_rank"
    t.index ["source_id", "issue_id", "url_hash"], name: "index_items_on_source_id_and_issue_id_and_url_hash", unique: true
    t.check_constraint "length(summary::text) <= 500", name: "items_summary_len"
    t.check_constraint "length(title::text) <= 300", name: "items_title_len"
    t.check_constraint "length(url::text) <= 2048", name: "items_url_len"
  end

  create_table "search_clicks", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "item_id", limit: 25, null: false
    t.string "query", limit: 100, null: false
    t.integer "rank", null: false
    t.index ["created_at"], name: "index_search_clicks_on_created_at"
    t.index ["item_id"], name: "index_search_clicks_on_item_id"
    t.check_constraint "length(query::text) <= 100", name: "search_clicks_query_len"
  end

  create_table "search_logs", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "filters", default: {}, null: false
    t.integer "latency_ms", null: false
    t.integer "page", default: 1, null: false
    t.string "query", limit: 100, null: false
    t.integer "result_count"
    t.index ["created_at"], name: "index_search_logs_on_created_at"
    t.check_constraint "length(query::text) <= 100", name: "search_logs_query_len"
  end

  create_table "search_records", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.string "anchor", limit: 120
    t.datetime "created_at", null: false
    t.string "issue_id", limit: 25, null: false
    t.string "item_id", limit: 25, null: false
    t.string "period_key", limit: 10, null: false
    t.string "publication", limit: 10, null: false
    t.date "published_on", null: false
    t.string "section", limit: 100
    t.string "source_id", limit: 25, null: false
    t.string "source_name", limit: 100, null: false
    t.string "summary", limit: 500
    t.string "title", limit: 300, null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id"], name: "index_search_records_on_issue_id"
    t.index ["item_id"], name: "index_search_records_on_item_id", unique: true
    t.index ["publication", "published_on"], name: "index_search_records_on_publication_and_published_on"
    t.index ["section"], name: "index_search_records_on_section_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["source_id"], name: "index_search_records_on_source_id"
    t.index ["source_name"], name: "index_search_records_on_source_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["summary"], name: "index_search_records_on_summary_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["title"], name: "index_search_records_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.check_constraint "length(anchor::text) <= 120", name: "search_records_anchor_len"
    t.check_constraint "length(section::text) <= 100", name: "search_records_section_len"
    t.check_constraint "length(source_name::text) <= 100", name: "search_records_source_name_len"
    t.check_constraint "length(summary::text) <= 500", name: "search_records_summary_len"
    t.check_constraint "length(title::text) <= 300", name: "search_records_title_len"
    t.check_constraint "publication::text = ANY (ARRAY['daily'::character varying, 'weekly'::character varying]::text[])", name: "search_records_publication"
  end

  create_table "settings", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", limit: 50, null: false
    t.datetime "updated_at", null: false
    t.string "value", limit: 255, null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "sources", id: { type: :string, limit: 25 }, force: :cascade do |t|
    t.string "adapter", limit: 40, null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", limit: 100, null: false
    t.string "publication", limit: 10, null: false
    t.integer "sort_order", default: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_sources_on_name", unique: true
    t.check_constraint "adapter::text = ANY (ARRAY['hacker_news'::character varying::text, 'github_trending'::character varying::text, 'rss'::character varying::text, 'ruanyf_weekly'::character varying::text])", name: "sources_adapter"
    t.check_constraint "publication::text = ANY (ARRAY['daily'::character varying::text, 'weekly'::character varying::text])", name: "sources_publication"
  end

  add_foreign_key "fetch_runs", "issues"
  add_foreign_key "fetch_runs", "sources"
  add_foreign_key "items", "issues"
  add_foreign_key "items", "sources"
  add_foreign_key "search_clicks", "items", on_delete: :cascade
  add_foreign_key "search_records", "issues", on_delete: :cascade
  add_foreign_key "search_records", "items", on_delete: :cascade
  add_foreign_key "search_records", "sources"
end
