namespace :storage do
  desc "Downsize completed layer overlays and purge spent masks (dry-run by default, EXECUTE=true to apply)"
  task optimize: :environment do
    dry_run = !ENV["EXECUTE"]
    saved_bytes = 0
    layers_count = 0

    puts "=" * 60
    puts dry_run ? "🔍 DRY RUN — Storage Optimization" : "🚀 EXECUTING — Storage Optimization"
    puts "=" * 60

    ProjectLayer.where(progress: :complete).find_each do |layer|
      overlay_savings = 0
      mask_savings = 0

      # Downsize overlay if it's large
      if layer.overlay.attached? && layer.overlay.blob.byte_size > 100_000
        overlay_savings = layer.overlay.blob.byte_size - 30_000 # estimated thumb size

        unless dry_run
          begin
            variant = layer.overlay.variant(resize_to_limit: [ 400, 400 ]).processed
            layer.overlay.attach(
              io: StringIO.new(variant.download),
              filename: "overlay_thumb.webp",
              content_type: "image/webp"
            )
          rescue => e
            puts "  ⚠️  Overlay downsize failed for layer #{layer.id}: #{e.message}"
            overlay_savings = 0
          end
        end
      end

      # Purge mask if overlay exists
      if layer.mask.attached? && layer.overlay.attached?
        mask_savings = layer.mask.blob.byte_size

        unless dry_run
          begin
            layer.mask.purge
          rescue => e
            puts "  ⚠️  Mask purge failed for layer #{layer.id}: #{e.message}"
            mask_savings = 0
          end
        end
      end

      if overlay_savings > 0 || mask_savings > 0
        layers_count += 1
        saved_bytes += overlay_savings + mask_savings
        puts "  Layer ##{layer.id}: overlay -#{(overlay_savings / 1024.0).round(1)}KB, mask -#{(mask_savings / 1024.0).round(1)}KB"
      end
    end

    puts ""
    puts "=" * 60
    puts "📊 SUMMARY"
    puts "=" * 60
    puts "  Layers optimized: #{layers_count}"
    puts "  #{dry_run ? 'Estimated' : 'Actual'} savings: #{(saved_bytes / 1_048_576.0).round(1)} MB"

    unless dry_run
      print "  Purging unattached blobs..."
      purged = 0
      ActiveStorage::Blob.unattached.find_each do |blob|
        purged += blob.byte_size
        blob.purge
      end
      puts " freed #{(purged / 1_048_576.0).round(1)} MB"
    end

    puts ""
    puts "💡 To execute: EXECUTE=true bin/rails storage:optimize" if dry_run
  end
end
