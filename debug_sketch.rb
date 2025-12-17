
begin
  require_relative 'config/environment'

  puts "Environment loaded."

  user = User.first
  puts "User: #{user.email}"

  canva = Canva.first
  puts "Canva: #{canva.inspect}"

  puts "Attempting to create SketchRequest..."
  sr = SketchRequest.create!(user: user, canva: canva, progress: :created)
  puts "SketchRequest created: #{sr.id}"

rescue => e
  puts "FAILURE: #{e.class} - #{e.message}"
  pp e.backtrace.first(5)
end
