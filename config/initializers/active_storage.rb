# config/initializers/active_storage.rb

if Rails.env.development? || Rails.env.test?
Rails.application.config.active_storage.url_options = {
  host: "localhost",
  port: 3000,
  protocol: "http"
}

end

Rails.application.config.after_initialize do
  ActiveStorage::Blob.service.root.mkdir unless Dir.exist?(ActiveStorage::Blob.service.root)
end
