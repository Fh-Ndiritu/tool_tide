json.extract! canva, :id, :user_id, :image, :created_at, :updated_at
json.url canva_url(canva, format: :json)
json.image url_for(canva.image)
