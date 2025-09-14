json.extract! text_editor, :id, :user_id, :original_image, :result_image, :prompt, :created_at, :updated_at
json.url text_editor_url(text_editor, format: :json)
json.original_image url_for(text_editor.original_image)
json.result_image url_for(text_editor.result_image)
