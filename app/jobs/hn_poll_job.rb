class HnPollJob < ApplicationJob
  queue_as :low_priority

  def perform
    # 1. Record the snapshot
    snapshot = HnActivitySnapshot.record_snapshot!
    return unless snapshot

    # 2. Monitor & Alert
    check_and_notify(snapshot)

    # 3. Broadcast to Dashboard
    broadcast_update(snapshot)
  end

  private

  # Minimum samples needed before trusting statistical averages (~2 days of 30-min intervals)
  COLD_START_THRESHOLD = 100
  # Absolute thresholds for cold-start mode (items per 30 min)
  ABSOLUTE_LOW_THRESHOLD = 40
  ABSOLUTE_HIGH_THRESHOLD = 80

  def check_and_notify(snapshot)
    # Exclude current snapshot to get true historical average
    historical_avg = HnActivitySnapshot
      .where(day_of_week: snapshot.day_of_week, time_bucket: snapshot.time_bucket)
      .where.not(id: snapshot.id)
      .average(:items_count)
      &.to_f || 0.0

    total_samples = HnActivitySnapshot.where.not(id: snapshot.id).count

    # Cold-start mode: not enough data for statistical confidence
    if total_samples < COLD_START_THRESHOLD
      check_with_absolute_thresholds(snapshot, total_samples)
      return
    end

    # Have enough total samples, but missing data for this specific time slot?
    # Fall back to absolute thresholds for this slot.
    if historical_avg.zero?
      check_with_absolute_thresholds(snapshot, total_samples, slot_cold_start: true)
      return
    end

    # Warm mode: use statistical thresholds
    check_with_statistical_thresholds(snapshot, historical_avg)
  end

  def check_with_absolute_thresholds(snapshot, sample_count, slot_cold_start: false)
    description = build_description(snapshot, nil, sample_count)

    cold_start_note = if slot_cold_start
      "⚠️ First data point for this time slot (#{snapshot.day_of_week}, #{snapshot.time_bucket})."
    else
      "⚠️ Cold-start mode: #{sample_count}/#{COLD_START_THRESHOLD} samples collected."
    end

    if snapshot.items_count < ABSOLUTE_LOW_THRESHOLD
      dispatch_alert(
        "🚀 **Opportunity to Post!**\n\n#{description}\n" \
        "Activity appears low (< #{ABSOLUTE_LOW_THRESHOLD} items).\n" \
        "#{cold_start_note}"
      )
    end
  end

  def check_with_statistical_thresholds(snapshot, historical_avg)
    ratio = (snapshot.items_count / historical_avg * 100).round
    description = build_description(snapshot, historical_avg)

    if snapshot.items_count < (historical_avg * 0.75)
      dispatch_alert(
        "🚀 **Opportunity to Post!**\n\n#{description}\n" \
        "Activity is #{ratio}% of normal — significantly lower than usual!"
      )
    end
  end

  def build_description(snapshot, avg = nil, sample_count = nil)
    desc = "Hacker News Velocity Update:\n" \
           "Current: #{snapshot.items_count} items/30min\n"
    desc += "Historical Avg: #{avg.round(1)}\n" if avg
    desc
  end

  def dispatch_alert(message)
    TelegramNotifier::Dispatcher.new.dispatch(message)
  end

  def broadcast_update(snapshot)
    # Broadcast to a general channel that the dashboard listens to
    Turbo::StreamsChannel.broadcast_replace_to(
      "hn_activity",
      target: "hn_live_stats",
      partial: "admin/hn_dashboard/live_stats",
      locals: { snapshot: snapshot }
    )
  rescue => e
    Rails.logger.error("HnPollJob Broadcast Error: #{e.message}")
  end
end
