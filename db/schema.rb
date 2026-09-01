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

ActiveRecord::Schema[7.2].define(version: 2026_08_31_000001) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "vault"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.string "institution"
    t.string "last_four"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "kind"], name: "index_accounts_on_name_and_kind", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['bank'::character varying::text, 'credit_card'::character varying::text])", name: "accounts_kind_check"
  end

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
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", default: "both", null: false
    t.bigint "parent_id"
    t.string "color", default: "#9FE1C0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "name"], name: "index_categories_on_parent_id_and_name", unique: true, nulls_not_distinct: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.check_constraint "kind::text = ANY (ARRAY['income'::character varying::text, 'outcome'::character varying::text, 'both'::character varying::text])", name: "categories_kind_check"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "categories_parent_not_self_check"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.bigint "batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "statement_imports", force: :cascade do |t|
    t.string "kind", null: false
    t.string "status", default: "pending", null: false
    t.date "statement_month", null: false
    t.string "account_name"
    t.bigint "account_id"
    t.decimal "statement_total", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "normalized_total", precision: 12, scale: 2
    t.decimal "reconciliation_difference", precision: 12, scale: 2
    t.string "reconciliation_status"
    t.string "source_digest"
    t.text "error_message"
    t.bigint "bank_payment_transaction_id"
    t.index ["account_id"], name: "index_statement_imports_on_account_id"
    t.index ["bank_payment_transaction_id"], name: "index_statement_imports_on_bank_payment_transaction_id", unique: true
    t.index ["source_digest", "kind", "statement_month"], name: "index_statement_imports_on_unique_source", unique: true, where: "(source_digest IS NOT NULL)"
    t.check_constraint "kind::text = ANY (ARRAY['bank'::character varying::text, 'credit_card'::character varying::text])", name: "statement_imports_kind_check"
    t.check_constraint "reconciliation_status IS NULL OR (reconciliation_status::text = ANY (ARRAY['not_available'::character varying::text, 'matched'::character varying::text, 'mismatched'::character varying::text]))", name: "statement_imports_reconciliation_status_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'needs_review'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "statement_imports_status_check"
  end

  create_table "transactions", force: :cascade do |t|
    t.date "date", null: false
    t.date "statement_month", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "direction", null: false
    t.string "currency", default: "BRL", null: false
    t.string "notes"
    t.decimal "category_confidence", precision: 5, scale: 4
    t.bigint "account_id"
    t.bigint "statement_import_id"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "categorization_status", default: "pending", null: false
    t.string "merchant_key"
    t.string "source_key", null: false
    t.string "transaction_kind", default: "bank", null: false
    t.string "installment"
    t.index ["account_id", "direction", "merchant_key"], name: "index_transactions_for_category_matching"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["categorization_status"], name: "index_transactions_on_categorization_status"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["statement_import_id", "source_key"], name: "index_transactions_on_import_and_source_key", unique: true, where: "(statement_import_id IS NOT NULL)"
    t.index ["statement_import_id"], name: "index_transactions_on_statement_import_id"
    t.index ["statement_month", "direction"], name: "index_transactions_on_statement_month_and_direction"
    t.index ["statement_month"], name: "index_transactions_on_statement_month"
    t.index ["transaction_kind", "statement_month"], name: "index_transactions_on_kind_and_statement_month"
    t.check_constraint "amount > 0::numeric", name: "transactions_positive_amount_check"
    t.check_constraint "categorization_status::text = ANY (ARRAY['pending'::character varying::text, 'categorized'::character varying::text])", name: "transactions_categorization_status_check"
    t.check_constraint "category_confidence IS NULL OR category_confidence >= 0::numeric AND category_confidence <= 1::numeric", name: "transactions_category_confidence_check"
    t.check_constraint "direction::text = ANY (ARRAY['income'::character varying::text, 'outcome'::character varying::text])", name: "transactions_direction_check"
    t.check_constraint "transaction_kind::text = ANY (ARRAY['bank'::character varying, 'credit_card'::character varying]::text[])", name: "transactions_kind_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "statement_imports", "accounts"
  add_foreign_key "statement_imports", "transactions", column: "bank_payment_transaction_id", on_delete: :nullify
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "statement_imports", on_delete: :cascade
end
