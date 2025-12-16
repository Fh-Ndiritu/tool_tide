# # frozen_string_literal: true

# require "csv"

# namespace :import do
#   desc "Imports all city data from worldcities.csv into the Location model"
#   task cities: :environment do
#     # 1. Configuration
#     csv_file_path = Rails.root.join("worldcities.csv")

#     unless File.exist?(csv_file_path)
#       puts "❌ Error: CSV file not found at #{csv_file_path}"
#       puts "Please ensure 'worldcities.csv' is in the root of your Rails project."
#       exit 1
#     end

#     puts "=============================================="
#     puts "Starting BULK RAW SQL INSERT of cities from CSV (SQLite fix applied)..."
#     puts "=============================================="

#     # --- Pre-Import Cleanup (Optional but Recommended for Seeding) ---
#     # Uncomment the following lines if you want to clear the table and reset the primary key sequence.
#     # Location.delete_all
#     # ActiveRecord::Base.connection.reset_pk_sequence!('locations')

#     # 2. Initialization
#     batch_size = 1000
#     total_records = 0
#     start_time = Time.now

#     # Array to hold the hashes for bulk insertion
#     locations_to_insert = []

#     # 3. Process CSV in batches
#     csv_options = { headers: true, header_converters: :symbol, encoding: "UTF-8" }

#     CSV.foreach(csv_file_path, **csv_options).with_index(1) do |row, index|
#       data = row.to_h

#       # Map CSV data to Location model attributes
#       location_hash = {
#         # FIX: Force encoding on strings to resolve Encoding::CompatibilityError
#         name: data[:city].to_s.force_encoding("UTF-8"),
#         location_type: "city",
#         lat: data[:lat],
#         lng: data[:lng],
#         country_code: data[:iso2].to_s.force_encoding("UTF-8"),
#         iso3: data[:iso3].to_s.force_encoding("UTF-8"),
#         # Use .presence to set NULL if admin_name or capital is an empty string
#         admin_name: data[:admin_name].to_s.force_encoding("UTF-8").presence,
#         capital: data[:capital].to_s.force_encoding("UTF-8").presence,
#         # Safely convert population to integer, setting to nil if blank
#         population: data[:population].to_s.strip.empty? ? nil : data[:population].to_i,
#         external_id: data[:id].to_s.force_encoding("UTF-8"),
#         created_at: start_time,
#         updated_at: start_time
#       }

#       locations_to_insert << location_hash
#       total_records = index

#       # 4. Perform bulk insertion using RAW SQL
#       if locations_to_insert.size >= batch_size
#         column_names = locations_to_insert.first.keys.map(&:to_s)

#         # Build the SQL VALUES string for this batch
#         sql_values = locations_to_insert.map do |hash|
#           # Map each hash value to a quoted/formatted SQL string
#           "(" + column_names.map { |c|
#             value = hash[c.to_sym]
#             if value.nil?
#               "NULL"
#             # Numeric types (lat, lng, population) do not need quotes in SQL
#             elsif value.is_a?(Numeric)
#               value.to_s
#             # FIX: All other types (String, Time, etc.) must be quoted to prevent syntax errors
#             else
#               Location.connection.quote(value)
#             end
#           }.join(", ") + ")"
#         end.join(", ")

#         # Construct the final INSERT statement
#         sql = "INSERT INTO #{Location.table_name} (#{column_names.join(', ')}) VALUES #{sql_values}"

#         # Execute the raw SQL
#         Location.connection.execute(sql)
#         locations_to_insert.clear
#         print "Processed and inserted #{total_records} records so far...\r"
#       end
#     end

#     # 5. Insert any remaining records in the last batch
#     if locations_to_insert.any?
#       column_names = locations_to_insert.first.keys.map(&:to_s)

#       sql_values = locations_to_insert.map do |hash|
#         "(" + column_names.map { |c|
#           value = hash[c.to_sym]
#           if value.nil?
#             "NULL"
#           elsif value.is_a?(Numeric)
#             value.to_s
#           else
#             Location.connection.quote(value)
#           end
#         }.join(", ") + ")"
#       end.join(", ")

#       sql = "INSERT INTO #{Location.table_name} (#{column_names.join(', ')}) VALUES #{sql_values}"
#       Location.connection.execute(sql)
#       locations_to_insert.clear
#     end

#     # 6. Final Summary
#     end_time = Time.now
#     duration = (end_time - start_time).round(2)

#     puts "\nSuccessfully inserted #{total_records} Location records."
#     puts "Total time taken: #{duration} seconds."
#     puts "=============================================="
#   rescue => e
#     # Use ActiveRecord::Base.connection for better error handling in this scope
#     puts "\n\n❌ Import failed at record #{total_records}: #{e.message}"
#     puts "The database is SQLite, ensure your primary key 'id' is defined as AUTOINCREMENT in the schema."
#     puts e.backtrace.first(5)
#   end
# end
