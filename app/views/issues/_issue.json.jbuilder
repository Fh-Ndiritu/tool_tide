json.extract! issue, :id, :title, :body, :user_id, :category, :progress, :delivery_date, :created_at, :updated_at
json.url issue_url(issue, format: :json)
