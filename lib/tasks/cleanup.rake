namespace :storage do
  desc "Destroy records from non-paying users to free disk space. Dry run by default. Set EXECUTE=true to actually delete."
  task cleanup: :environment do
    execute = ENV["EXECUTE"] == "true"
    banner = execute ? "🔴 LIVE MODE — records WILL be destroyed" : "🟢 DRY RUN — no records will be destroyed"
    puts "\n#{'=' * 60}"
    puts banner
    puts "#{'=' * 60}\n\n"

    # IDs of mask requests shown on explore / welcome pages (preserve these)
    explore_ids = MaskRequest.unscoped
                             .where(progress: :complete, visibility: :everyone)
                             .pluck(:id)
                             .to_set

    puts "📌 Explore/welcome page mask requests to preserve: #{explore_ids.size}"

    # Counters
    totals = {
      users: 0,
      mask_requests: 0,
      text_requests: 0,
      projects: 0,
      project_layers: 0,
      canvases: 0,
      estimated_bytes: 0
    }

    non_paying = User.where(has_paid: false)
    puts "👤 Non-paying users: #{non_paying.count}\n\n"

    non_paying.find_each do |user|
      user_stats = { mask_requests: 0, text_requests: 0, projects: 0, project_layers: 0, canvases: 0 }

      # --- Mask Requests ---
      user.canvas.includes(:mask_requests).find_each do |canva|
        destroyable = canva.mask_requests.unscope(:order).where.not(id: explore_ids.to_a)

        user_stats[:mask_requests] += destroyable.count

        if execute
          destroyable.find_each(&:destroy)
        end

        # Destroy canva if no mask requests remain after cleanup
        remaining = canva.mask_requests.unscope(:order).where(id: explore_ids.to_a).count
        if remaining == 0
          user_stats[:canvases] += 1
          canva.destroy if execute
        end
      end

      # --- Text Requests ---
      text_count = user.text_requests.unscope(:order).count
      user_stats[:text_requests] = text_count
      if execute && text_count > 0
        user.text_requests.unscope(:order).find_each(&:destroy)
      end

      # --- Projects (cascades to Designs → ProjectLayers) ---
      user.projects.find_each do |project|
        user_stats[:project_layers] += project.project_layers.count
        user_stats[:projects] += 1
        project.destroy if execute
      end

      # Log per-user if they had anything
      total_records = user_stats.values.sum
      next if total_records == 0

      totals[:users] += 1
      totals[:mask_requests] += user_stats[:mask_requests]
      totals[:text_requests] += user_stats[:text_requests]
      totals[:projects] += user_stats[:projects]
      totals[:project_layers] += user_stats[:project_layers]
      totals[:canvases] += user_stats[:canvases]

      puts "  User ##{user.id} (#{user.email}): " \
           "#{user_stats[:mask_requests]} masks, " \
           "#{user_stats[:text_requests]} texts, " \
           "#{user_stats[:projects]} projects (#{user_stats[:project_layers]} layers), " \
           "#{user_stats[:canvases]} canvases"
    end

    puts "\n#{'=' * 60}"
    puts "📊 TOTALS"
    puts "#{'=' * 60}"
    puts "  Users affected:    #{totals[:users]}"
    puts "  Mask requests:     #{totals[:mask_requests]}"
    puts "  Text requests:     #{totals[:text_requests]}"
    puts "  Projects:          #{totals[:projects]}"
    puts "  Project layers:    #{totals[:project_layers]}"
    puts "  Canvases:          #{totals[:canvases]}"

    # --- Purge unattached blobs ---
    unattached_count = ActiveStorage::Blob.left_joins(:attachments)
                                          .where(active_storage_attachments: { id: nil })
                                          .count
    unattached_bytes = ActiveStorage::Blob.left_joins(:attachments)
                                          .where(active_storage_attachments: { id: nil })
                                          .sum(:byte_size)

    puts "\n  Unattached blobs:  #{unattached_count} (~#{(unattached_bytes / 1.megabyte.to_f).round(1)} MB)"

    if execute
      puts "\n🧹 Purging unattached blobs..."
      ActiveStorage::Blob.unattached.find_each(&:purge)
      puts "✅ Done! Run `df -h /` on the server to verify space reclaimed."
    else
      puts "\n💡 To execute: EXECUTE=true bin/rails storage:cleanup"
    end
  end
end
