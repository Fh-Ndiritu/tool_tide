class SearchReportMailer < ApplicationMailer


  def daily_report(since_time)
    @searches = SearchTerm.where("created_at >= ?", since_time).order(created_at: :desc)
    @since_time = since_time

    mail(
      to: "fhndiritu@gmail.com",
      subject: "Search Report since #{since_time.strftime('%B %d, %H:%M')}"
    )
  end
end
