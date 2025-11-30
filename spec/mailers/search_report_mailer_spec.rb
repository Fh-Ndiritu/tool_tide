require "rails_helper"

RSpec.describe SearchReportMailer, type: :mailer do
  describe "daily_report" do
    let(:since_time) { 6.hours.ago }
    let(:mail) { SearchReportMailer.daily_report(since_time) }

    before do
      SearchTerm.create(term: "rails", created_at: 1.hour.ago)
      SearchTerm.create(term: "ruby", created_at: 2.hours.ago)
    end

    it "renders the headers" do
      expect(mail.subject).to include("Search Report since")
      expect(mail.to).to eq([ "francis@hadaa.app" ])
      # The from address comes from ApplicationMailer defaults which pulls from credentials
      # We just check it's present, or we can check the specific value if we knew the credential
      expect(mail.from).not_to be_empty
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("Search Report")
      expect(mail.body.encoded).to include("rails")
      expect(mail.body.encoded).to include("ruby")
    end
  end
end
