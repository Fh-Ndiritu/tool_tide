class HnActivitySnapshot < ApplicationRecord
  validates :max_item_id, presence: true
  validates :items_count, presence: true

  before_create :set_uuid

  # Scopes
  scope :by_context, ->(day, time_bucket) { where(day_of_week: day, time_bucket: time_bucket) }

  def self.record_snapshot!
    # 1. Fetch current maxitem from HN API
    resp = Faraday.get("https://hacker-news.firebaseio.com/v0/maxitem.json")
    return unless resp.success?

    current_max_id = resp.body.to_i
    return if current_max_id.zero?

    # 2. Find the previous snapshot (most recent one)
    last_snapshot = order(created_at: :desc).first

    # 3. Calculate delta
    # If no previous snapshot, we can't calculate a meaningful delta, assume 0 or handle grace period.
    # But for the very first run, 0 is fine.
    delta = 0
    if last_snapshot
      delta = current_max_id - last_snapshot.max_item_id
      # Sanity check: if negative (API weirdness?) treat as 0
      delta = 0 if delta < 0
    end

    # 4. Determine context (time)
    now = Time.current
    day = now.wday
    # time_bucket: HHMM
    bucket = (now.hour * 100) + now.min

    create!(
      max_item_id: current_max_id,
      items_count: delta,
      day_of_week: day,
      time_bucket: bucket
    )
  end

  def self.average_for_context(day, time_bucket)
    # Average of items_count for this specific slot
    where(day_of_week: day, time_bucket: time_bucket).average(:items_count).to_f
  end

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
