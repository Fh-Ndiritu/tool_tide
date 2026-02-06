require 'rails_helper'

RSpec.describe "Multi-Tenant Routing", type: :request do
  describe "Hadaa.pro (Marketing)" do
    it "serves the home page" do
      host! "hadaa.pro"
      get "/"
      expect(response.status).to eq(200)
      expect(response.headers["X-Robots-Tag"]).to include("index")
    end

    it "serves pricing" do
      host! "hadaa.pro"
      get "/pricing"
      expect(response.status).to eq(200)
    end

    it "serves dynamic robots.txt" do
      host! "hadaa.pro"
      get "/robots.txt"
      expect(response.body).to include("Allow: /")
    end

    it "redirects login to app" do
      host! "hadaa.pro"
      get "/login"
      expect(response).to redirect_to("https://hadaa.app/users/sign_in")
    end
  end

  describe "Hadaa.app (App)" do
    it "serves the login page at root" do
      host! "hadaa.app"
      get "/"
      expect(response.status).to eq(200)
      expect(response.body).to include("Log in")
      # No X-Robots-Tag header in test env
    end

    it "serves robots.txt" do
      host! "hadaa.app"
      get "/robots.txt"
      expect(response.body).to include("Allow: /")
    end

    it "returns 410 for landscaping guides (toxic content)" do
      host! "hadaa.app"
      get "/landscaping-guides/some-toxic-page"
      expect(response.status).to eq(410)
    end

    it "returns 410 for unknown pages" do
      host! "hadaa.app"
      get "/random-spam-page"
      expect(response.status).to eq(410)
    end
  end
end
