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

ActiveRecord::Schema[8.0].define(version: 2025_09_22_163926) do
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

  create_table "canvas", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "device_width", default: 400
    t.index ["user_id"], name: "index_canvas_on_user_id"
  end

  create_table "chats", force: :cascade do |t|
    t.string "model_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "credits", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "source", default: 0, null: false
    t.integer "amount", default: 0, null: false
    t.integer "credit_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_credits_on_user_id"
  end

  create_table "landscape_requests", force: :cascade do |t|
    t.integer "landscape_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "prompt"
    t.string "preset"
    t.boolean "use_location", default: false, null: false
    t.text "localized_prompt"
    t.integer "progress"
    t.text "error"
    t.index ["landscape_id"], name: "index_landscape_requests_on_landscape_id"
  end

  create_table "landscapes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_landscapes_on_user_id"
  end

  create_table "mask_requests", force: :cascade do |t|
    t.integer "device_width"
    t.string "error_msg"
    t.integer "progress"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "canva_id", null: false
    t.string "preset"
    t.text "prompt"
    t.string "user_error"
    t.integer "visibility", default: 0
    t.boolean "trial_generation", default: false
    t.index ["canva_id"], name: "index_mask_requests_on_canva_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "chat_id", null: false
    t.string "role"
    t.text "content"
    t.string "model_id"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "tool_call_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "payment_transactions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "uuid"
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_code"
    t.string "authorization_url"
    t.string "paystack_reference_id"
    t.boolean "validated", default: false, null: false
    t.integer "status", default: 0, null: false
    t.datetime "paid_at"
    t.string "method"
    t.string "paystack_customer_id"
    t.string "currency", default: "USD"
    t.boolean "credits_issued", default: false, null: false
    t.index ["user_id"], name: "index_payment_transactions_on_user_id"
  end

  create_table "suggested_plants", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "landscape_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["landscape_request_id"], name: "index_suggested_plants_on_landscape_request_id"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.integer "message_id", null: false
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false
    t.string "ip_address"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.json "address"
    t.integer "pro_engine_credits", default: 0
    t.datetime "received_daily_credits"
    t.integer "pro_trial_credits", default: 0
    t.boolean "reverted_to_free_engine", default: false
    t.boolean "notified_about_pro_credits", default: false
    t.text "error"
    t.boolean "privacy_policy", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "canvas", "users"
  add_foreign_key "credits", "users"
  add_foreign_key "landscape_requests", "landscapes"
  add_foreign_key "landscapes", "users"
  add_foreign_key "mask_requests", "canvas"
  add_foreign_key "messages", "chats"
  add_foreign_key "payment_transactions", "users"
  add_foreign_key "suggested_plants", "landscape_requests"
  add_foreign_key "tool_calls", "messages"
end
