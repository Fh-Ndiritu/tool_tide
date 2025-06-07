require 'rails_helper'

RSpec.describe ImagesController, type: :controller do

  describe "GET #text" do
    it "returns http success" do
      get :text
      expect(response).to have_http_status(:success)
    end
  end

end
