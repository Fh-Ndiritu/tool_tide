json.extract! text_request, :id, :original_image, :prompt, :progress, :user_error, :visibility, :trial_generation, :user_id, :ancestry, :created_at, :updated_at
json.url text_request_url(text_request, format: :json)
json.original_image url_for(text_request.original_image)
