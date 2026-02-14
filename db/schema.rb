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

ActiveRecord::Schema[8.0].define(version: 2026_02_14_142630) do
  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
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

  create_table "agentic_runs", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "status", default: 0
    t.json "logs", default: []
    t.string "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "design_id"
    t.index ["design_id"], name: "index_agentic_runs_on_design_id"
    t.index ["project_id"], name: "index_agentic_runs_on_project_id"
  end

  create_table "agora_brand_contexts", force: :cascade do |t|
    t.string "key", null: false
    t.text "raw_content"
    t.datetime "last_crawled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "metadata"
    t.index ["key"], name: "index_agora_brand_contexts_on_key", unique: true
  end

  create_table "agora_comments", force: :cascade do |t|
    t.integer "post_id", null: false
    t.string "author_agent_id", null: false
    t.text "body"
    t.string "comment_type", default: "general"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "net_score", default: 0
    t.index ["author_agent_id"], name: "index_agora_comments_on_author_agent_id"
    t.index ["post_id"], name: "index_agora_comments_on_post_id"
  end

  create_table "agora_executions", force: :cascade do |t|
    t.integer "post_id", null: false
    t.string "platform"
    t.json "metrics", default: {}
    t.text "admin_notes"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "video_prompt"
    t.text "image_prompt"
    t.text "tiktok_text"
    t.text "facebook_text"
    t.text "linkedin_text"
    t.text "instagram_text"
    t.text "pinterest_text"
    t.text "twitter_text"
    t.text "youtube_description"
    t.index ["post_id"], name: "index_agora_executions_on_post_id"
  end

  create_table "agora_learned_patterns", force: :cascade do |t|
    t.string "pattern_type"
    t.string "context_tag"
    t.text "content"
    t.float "confidence", default: 0.0
    t.integer "source_execution_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pattern_type", "confidence"], name: "index_agora_learned_patterns_on_pattern_type_and_confidence"
    t.index ["source_execution_id"], name: "index_agora_learned_patterns_on_source_execution_id"
  end

  create_table "agora_posts", force: :cascade do |t|
    t.string "author_agent_id", null: false
    t.string "title", null: false
    t.text "body"
    t.integer "revision_number", default: 1
    t.string "status", default: "draft"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "net_score", default: 0
    t.string "ancestry"
    t.string "platform"
    t.json "persona_context", default: {}
    t.string "content_archetype"
    t.index ["ancestry"], name: "index_agora_posts_on_ancestry"
    t.index ["author_agent_id"], name: "index_agora_posts_on_author_agent_id"
    t.index ["status"], name: "index_agora_posts_on_status"
  end

  create_table "agora_trends", force: :cascade do |t|
    t.string "period", null: false
    t.json "content", default: {}
    t.json "source_metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["period"], name: "index_agora_trends_on_period"
  end

  create_table "agora_votes", force: :cascade do |t|
    t.string "votable_type", null: false
    t.integer "votable_id", null: false
    t.string "voter_id", null: false
    t.integer "weight", default: 1
    t.integer "direction", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "voter_type_str", default: "Agent"
    t.index ["votable_type", "votable_id", "voter_id"], name: "index_agora_votes_uniqueness", unique: true
    t.index ["votable_type", "votable_id"], name: "index_agora_votes_on_votable"
  end

  create_table "auto_fixes", force: :cascade do |t|
    t.integer "project_layer_id", null: false
    t.string "title"
    t.text "description"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_layer_id"], name: "index_auto_fixes_on_project_layer_id"
  end

  create_table "canvas", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "device_width", default: 400
    t.integer "treat_as"
    t.index ["user_id"], name: "index_canvas_on_user_id"
  end

  create_table "chats", force: :cascade do |t|
    t.string "model_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "credit_spendings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "amount"
    t.integer "transaction_type"
    t.string "trackable_type", null: false
    t.integer "trackable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trackable_type", "trackable_id"], name: "index_credit_spendings_on_trackable"
    t.index ["user_id"], name: "index_credit_spendings_on_user_id"
  end

  create_table "credit_vouchers", force: :cascade do |t|
    t.string "token", null: false
    t.integer "user_id", null: false
    t.integer "amount", default: 50, null: false
    t.datetime "redeemed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_credit_vouchers_on_token", unique: true
    t.index ["user_id"], name: "index_credit_vouchers_on_user_id"
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

  create_table "designs", force: :cascade do |t|
    t.string "title"
    t.integer "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "project_layers_count", default: 0
    t.integer "current_project_layer_id"
    t.index ["current_project_layer_id"], name: "index_designs_on_current_project_layer_id"
    t.index ["project_id"], name: "index_designs_on_project_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "favoritable_type", null: false
    t.integer "favoritable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "liked"
    t.index ["favoritable_type", "favoritable_id"], name: "index_favorites_on_favoritable"
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "generation_taggings", force: :cascade do |t|
    t.integer "tag_id", null: false
    t.string "generation_type", null: false
    t.integer "generation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_type", "generation_id"], name: "index_generation_taggings_on_generation"
    t.index ["tag_id", "generation_id", "generation_type"], name: "idx_on_tag_id_generation_id_generation_type_9189069e36", unique: true
    t.index ["tag_id"], name: "index_generation_taggings_on_tag_id"
  end

  create_table "hn_activity_snapshots", force: :cascade do |t|
    t.bigint "max_item_id", null: false
    t.integer "items_count", default: 0, null: false
    t.integer "day_of_week"
    t.integer "time_bucket"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "data_for_date"
    t.index ["day_of_week", "time_bucket"], name: "index_hn_activity_snapshots_on_day_of_week_and_time_bucket"
    t.index ["uuid"], name: "index_hn_activity_snapshots_on_uuid", unique: true
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

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "location_type"
    t.integer "lat"
    t.integer "lng"
    t.string "country_code"
    t.string "iso3"
    t.string "admin_name"
    t.string "capital"
    t.integer "population"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["country_code"], name: "index_locations_on_country_code"
    t.index ["location_type"], name: "index_locations_on_location_type"
  end

  create_table "marketing_campaigns", force: :cascade do |t|
    t.integer "campaign_type"
    t.string "target_feature"
    t.integer "status"
    t.json "assets"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.boolean "sketch", default: false
    t.text "features"
    t.text "feature_prompt"
    t.json "preferences", default: {}
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

  create_table "onboarding_responses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "role"
    t.integer "intent"
    t.integer "pain_point"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "completed"
    t.index ["user_id"], name: "index_onboarding_responses_on_user_id"
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
    t.string "stripe_session_id"
    t.index ["stripe_session_id"], name: "index_payment_transactions_on_stripe_session_id"
    t.index ["user_id"], name: "index_payment_transactions_on_user_id"
  end

  create_table "plants", force: :cascade do |t|
    t.string "english_name"
    t.string "description"
    t.string "full_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "size"
    t.boolean "validated", default: false
    t.integer "mask_request_id", null: false
    t.integer "quantity"
    t.index ["mask_request_id"], name: "index_plants_on_mask_request_id"
  end

  create_table "project_layers", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "design_id", null: false
    t.string "ancestry"
    t.integer "layer_type"
    t.integer "status"
    t.integer "progress", default: 0
    t.string "transformation_type"
    t.integer "views_count", default: 0
    t.text "prompt"
    t.string "preset"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "ai_assist", default: false
    t.integer "layer_number"
    t.datetime "viewed_at"
    t.integer "generation_type", default: 0
    t.integer "auto_fix_id"
    t.string "error_msg"
    t.string "user_msg"
    t.string "model", default: "pro_mode"
    t.string "detected_type"
    t.text "original_prompt"
    t.index ["ancestry"], name: "index_project_layers_on_ancestry"
    t.index ["auto_fix_id"], name: "index_project_layers_on_auto_fix_id"
    t.index ["design_id"], name: "index_project_layers_on_design_id"
    t.index ["project_id"], name: "index_project_layers_on_project_id"
  end

  create_table "project_onboardings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "step", default: 0
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "style_presets_status", default: 0
    t.integer "smart_fix_status", default: 0
    t.integer "auto_fix_status", default: 0
    t.boolean "smart_fix_warning_seen", default: false
    t.index ["user_id"], name: "index_project_onboardings_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "current_design_id"
    t.integer "mask_request_id"
    t.index ["current_design_id"], name: "index_projects_on_current_design_id"
    t.index ["mask_request_id"], name: "index_projects_on_mask_request_id"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "public_assets", force: :cascade do |t|
    t.string "uuid"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_public_assets_on_uuid"
  end

  create_table "suggested_plants", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "landscape_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["landscape_request_id"], name: "index_suggested_plants_on_landscape_request_id"
  end

  create_table "tags", force: :cascade do |t|
    t.integer "tag_class"
    t.text "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
  end

  create_table "text_requests", force: :cascade do |t|
    t.text "prompt"
    t.integer "progress", default: 0
    t.string "user_error"
    t.integer "visibility"
    t.boolean "trial_generation"
    t.integer "user_id", null: false
    t.string "ancestry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "error_msg"
    t.text "refined_prompt"
    t.index ["ancestry"], name: "index_text_requests_on_ancestry"
    t.index ["user_id"], name: "index_text_requests_on_user_id"
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

  create_table "user_settings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "default_model"
    t.integer "default_variations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id"
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
    t.text "error"
    t.boolean "privacy_policy", default: false
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "name"
    t.integer "source", default: 0
    t.string "user_name"
    t.integer "onboarding_stage", default: 0
    t.datetime "feature_announcement_sent_at"
    t.boolean "completed_survey"
    t.datetime "desktop_projects_announcement_sent_at"
    t.string "last_sign_in_device_type"
    t.boolean "has_paid", default: false
    t.string "stripe_customer_id"
    t.datetime "stripe_migration_announcement_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agentic_runs", "designs"
  add_foreign_key "agentic_runs", "projects"
  add_foreign_key "agora_comments", "agora_posts", column: "post_id"
  add_foreign_key "agora_executions", "agora_posts", column: "post_id"
  add_foreign_key "agora_learned_patterns", "agora_executions", column: "source_execution_id"
  add_foreign_key "auto_fixes", "project_layers"
  add_foreign_key "canvas", "users"
  add_foreign_key "credit_spendings", "users"
  add_foreign_key "credit_vouchers", "users"
  add_foreign_key "credits", "users"
  add_foreign_key "designs", "project_layers", column: "current_project_layer_id"
  add_foreign_key "designs", "projects"
  add_foreign_key "favorites", "users"
  add_foreign_key "generation_taggings", "tags"
  add_foreign_key "landscape_requests", "landscapes"
  add_foreign_key "landscapes", "users"
  add_foreign_key "mask_requests", "canvas"
  add_foreign_key "messages", "chats"
  add_foreign_key "onboarding_responses", "users"
  add_foreign_key "payment_transactions", "users"
  add_foreign_key "plants", "mask_requests"
  add_foreign_key "project_layers", "auto_fixes"
  add_foreign_key "project_layers", "designs"
  add_foreign_key "project_layers", "projects"
  add_foreign_key "project_onboardings", "users"
  add_foreign_key "projects", "designs", column: "current_design_id"
  add_foreign_key "projects", "mask_requests"
  add_foreign_key "projects", "users"
  add_foreign_key "suggested_plants", "landscape_requests"
  add_foreign_key "text_requests", "users"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "user_settings", "users"
end
