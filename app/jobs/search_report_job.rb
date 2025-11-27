class SearchReportJob < ApplicationJob
  queue_as :default

  def perform
    # Calculate the time range for the report (last 6 hours)
    since_time = 6.hours.ago

    # Send the email
    SearchReportMailer.daily_report(since_time).deliver_now

    # Schedule the next job
    SearchReportJob.set(wait: 6.hours).perform_later
  end
end
