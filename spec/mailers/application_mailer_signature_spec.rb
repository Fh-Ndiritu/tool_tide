require 'rails_helper'

RSpec.describe 'Mailer Signature', type: :mailer do
  let(:mail) { SearchReportMailer.daily_report(6.hours.ago) }

  it 'includes the signature block with logo' do
    expect(mail.body.encoded).to include('Best,')
    expect(mail.body.encoded).to match(/<img[^>]+src=.*hadaa.*\.png/)
  end
end
