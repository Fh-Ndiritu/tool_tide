class HnPollJob < ApplicationJob
  queue_as :default

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

  def check_and_notify(snapshot)
    avg = HnActivitySnapshot.average_for_context(snapshot.day_of_week, snapshot.time_bucket)

    # Need at least a few data points to establish a baseline?
    # Or just start alerting if avg exists (which it will, since we just added one, but avg includes self?)
    # HnActivitySnapshot.average_for_context includes the current one if we don't exclude it.
    # To be safe, let's look at *historical* meaning excluding today?
    # Or just use the simple avg. If it's the first data point, avg == snapshot.count, so 100% -> no alert.

    return if avg.zero?

    description = "Hacker News Velocity Update:\n" \
                  "Current: #{snapshot.items_count} items/30min\n" \
                  "Average: #{avg.round(1)}\n"

    # Threshold: < 80% of average
    if snapshot.items_count < (avg * 0.8)
      TelegramNotifier::Dispatcher.new.dispatch(
        "🚀 **Opportunity to Post!**\n\n#{description}\nActivity is significantly lower than usual (#{((snapshot.items_count / avg) * 100).round}%)!"
      )
    end
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
