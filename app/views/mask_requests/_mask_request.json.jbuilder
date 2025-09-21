json.extract! mask_request, :id, :mask, :original_image, :results, :device_width, :error_msg, :progress, :created_at, :updated_at
json.url mask_request_url(mask_request, format: :json)
json.mask url_for(mask_request.mask)
json.original_image url_for(mask_request.original_image)
json.results do
  json.array!(mask_request.results) do |result|
    json.id result.id
    json.url url_for(result)
  end
end
