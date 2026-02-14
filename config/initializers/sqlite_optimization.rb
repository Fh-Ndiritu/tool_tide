# config/initializers/sqlite_optimization.rb
Rails.application.configure do
  config.after_initialize do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      # Check if we are using SQLite
      if connection.adapter_name.downcase.include?("sqlite")
        # Enable Write-Ahead Logging (WAL) for better concurrency
        connection.execute("PRAGMA journal_mode = WAL")

        # Set synchronous mode to NORMAL (faster, safe for WAL)
        connection.execute("PRAGMA synchronous = NORMAL")

        # Increase busy timeout (milliseconds)
        connection.execute("PRAGMA busy_timeout = 5000")

        # Enable foreign key constraints
        connection.execute("PRAGMA foreign_keys = ON")

        # Increase cache size (negative value is in updated pages, approx 20MB)
        connection.execute("PRAGMA cache_size = -20000")
      end
    end
  rescue ActiveRecord::ActiveRecordError
    # Database might not be ready (e.g., during assets:precompile)
  end
end
