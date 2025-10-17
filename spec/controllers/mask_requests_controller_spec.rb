require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  fixtures :users, :canvas

  let(:user) { users(:john_doe) }
  let(:canva) { canvas(:one) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  let(:valid_attributes) {
    {
      mask: fixture_file_upload('spec/fixtures/files/test_image.png', 'image/png'),
      device_width: 1024,
      progress: :uploading,
      canva_id: canva.id
    }
  }

  let(:invalid_attributes) {
    {
      mask: nil,
      original_image: nil,
      device_width: nil,
      progress: nil,
      canva_id: nil
    }
  }

  let(:new_attributes) {
    { preset: 'new_preset' }
  }

  let(:valid_session) { {} }

  describe "GET #index" do
    it "returns a success response" do
      mask_request = MaskRequest.create! valid_attributes
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

  describe "GET #new" do
    it "redirects to low_credits_path if user cannot afford generation" do
      allow_any_instance_of(User).to receive(:afford_generation?).and_return(false)
      get :new, params: { canva_id: canva.id }, session: valid_session
      expect(response).to redirect_to(low_credits_path)
    end

    it "returns a success response if user can afford generation" do
      allow_any_instance_of(User).to receive(:afford_generation?).and_return(true)
      get :new, params: { canva_id: canva.id }, session: valid_session
      expect(response).to be_successful
    end
  end

  describe "GET #edit" do
    it "redirects to low_credits_path if manual and user cannot afford generation" do
      User.update_all pro_engine_credits: 0
      mask_request = MaskRequest.create! valid_attributes.merge(progress: :uploading)
      get :edit, params: { id: mask_request.to_param, manual: true }, session: valid_session
      expect(response).to redirect_to(low_credits_path)
    end

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

    # context "with invalid params" do
    #   it "renders a response with 422 status" do
    #     post :create, params: { canva_id: canva.id, mask_request: invalid_attributes }, session: valid_session
    #     expect(response).to have_http_status(:see_other)
    #   end
    # end
  end

  describe "PUT #update" do
    context "with valid params" do
      xit "updates the requested mask_request" do
        mask_request = MaskRequest.create! valid_attributes
        put :update, params: { id: mask_request.to_param, mask_request: new_attributes }, session: valid_session
        mask_request.reload
        expect(mask_request.preset).to eq('new_preset')
      end

      # it "enqueues DesignGeneratorJob" do
      #   mask_request = MaskRequest.create! valid_attributes
      #   expect(DesignGeneratorJob).to receive(:perform_later).with(mask_request.id)
      #   put :update, params: { id: mask_request.to_param, mask_request: new_attributes }, session: valid_session
      # end
    end

    # context "with invalid params" do
    #   it "renders a response with 422 status" do
    #     mask_request = MaskRequest.create! valid_attributes
    #     put :update, params: { id: mask_request.to_param, mask_request: invalid_attributes }, session: valid_session
    #     binding.irb
    #     expect(response).to have_http_status(500)
    #   end
    # end
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
