require 'rails_helper'

RSpec.describe "Marketing Pages", type: :request do
  describe "GET /" do
    it "renders the home page successfully" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Start Designing")
    end
  end

  describe "GET /pricing" do
    it "renders the pricing page successfully" do
      get pricing_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pro")
    end
  end

  describe "Feature Pages" do
    it "returns 410 Gone for the AI prompt editor page" do
      get features_ai_prompt_editor_path
      expect(response).to have_http_status(:gone)
    end
  end

  describe "Redirects/410s" do
    it "returns 410 Gone for old PSEO pages" do
      get "/designs/some-old-design"
      expect(response).to have_http_status(:gone)
    end

    it "returns 410 Gone for landscaping-guides" do
      get "/landscaping-guides/how-to-plant"
      expect(response).to have_http_status(:gone)
    end
  end
end
