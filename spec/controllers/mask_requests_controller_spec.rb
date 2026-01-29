require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  let(:user) { users(:one) }
  # Manually create Canva since fixtures are broken for this model
  let(:canva) { Canva.create!(user: user, treat_as: :photo, device_width: 1024) }

  before do
    user.update(pro_engine_credits: 1000)
    sign_in(user)
    user.update(onboarding_stage: :completed)
  end

  let(:valid_attributes) {
    {
      mask: fixture_file_upload('spec/fixtures/files/test_image.png', 'image/png'),
      device_width: 1024,
      progress: :uploading,
      canva_id: canva.id
    }
  }

  let(:valid_session) { {} }

  describe "GET #index" do
    it "returns a success response" do
      MaskRequest.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(response).to be_successful
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      mask_request = MaskRequest.create! valid_attributes
      get :show, params: { id: mask_request.to_param }, session: valid_session
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'renders the new template' do
      get :new, params: { canva_id: canva.id }
      expect(response).to be_successful
    end
  end

  describe "GET #edit" do
    it "redirects to mask_request_path if request is failed or complete" do
      mask_request = MaskRequest.create! valid_attributes.merge(progress: :complete)
      get :edit, params: { id: mask_request.to_param }, session: valid_session
      expect(response).to redirect_to(mask_request_path(mask_request))
    end

    it "returns a success response if request is uploading" do
      mask_request = MaskRequest.create! valid_attributes.merge(progress: :uploading)
      get :edit, params: { id: mask_request.to_param }, session: valid_session
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new MaskRequest" do
        expect {
          post :create, params: { canva_id: canva.id, mask_request: valid_attributes }, session: valid_session
        }.to change(MaskRequest, :count).by(1)
      end

      it "redirects to edit_mask_request_path if no user error" do
        post :create, params: { canva_id: canva.id, mask_request: valid_attributes }, session: valid_session
        expect(response).to redirect_to(edit_mask_request_path(MaskRequest.last))
      end

      it "redirects to new_canva_mask_request_path if user error" do
        allow_any_instance_of(MaskRequest).to receive(:user_error).and_return("Error")
        post :create, params: { canva_id: canva.id, mask_request: valid_attributes }, session: valid_session
        expect(response).to redirect_to(new_canva_mask_request_path(canva))
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested mask_request" do
      mask_request = MaskRequest.create! valid_attributes
      expect {
        delete :destroy, params: { id: mask_request.to_param }, session: valid_session
      }.to change(MaskRequest, :count).by(-1)
    end

    it "redirects to the mask_requests list" do
      mask_request = MaskRequest.create! valid_attributes
      delete :destroy, params: { id: mask_request.to_param }, session: valid_session
      expect(response).to redirect_to(mask_requests_path)
    end
  end
end
