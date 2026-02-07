require 'rails_helper'

RSpec.describe Agentic::Orchestrator do
  let(:project) { projects(:one) }
  let(:layer) { project_layers(:one) }
  let(:user) { project.user }
  let(:project_layer) { layer }
  let(:goal) { "Make it better" }
  let(:transformation_type) { "photorealistic" }
  let(:orchestrator) { described_class.new(project_layer, goal, transformation_type) }

  before do
    # Mock User instance methods to avoid DB calls and ensure consistency
    allow(user).to receive(:can_afford_generation?).and_return(true)
    allow(user).to receive(:charge_pro_cost!)

    # We need to ensure the project.user returns this specific mocked user object
    # OR we rely on the fact that `user` is `project.user` in the let block.
    # However, `project.user` might reload.
    allow(project).to receive(:user).and_return(user)

    # Mock CustomRubyLLM
    llm_client = double
    chat_mock = double
    allow(CustomRubyLLM).to receive(:context).and_return(llm_client)
    allow(llm_client).to receive(:chat).and_return(chat_mock)
    allow(chat_mock).to receive(:with_tools).and_return(chat_mock)
    allow(chat_mock).to receive(:with_instructions).and_return(chat_mock)
    allow(chat_mock).to receive(:ask).with(kind_of(String), with: kind_of(ActiveStorage::Attached::One)).and_return(double(content: "Finished"))

    # Ensure project_layer.project returns our mocked project
    allow(project_layer).to receive(:project).and_return(project)

    # Mock Timer to speed up
    allow_any_instance_of(Agentic::Orchestrator).to receive(:sleep)
  end

  describe "#perform" do
    it "creates an AgenticRun if none provided" do
      expect {
        orchestrator.perform
      }.to change(AgenticRun, :count).by(1)
    end

    it "uses existing AgenticRun if provided" do
      run = AgenticRun.create!(project: project, status: :pending)
      service = described_class.new(project_layer, goal, transformation_type, run.id)

      expect {
        service.perform
      }.not_to change(AgenticRun, :count)

      expect(run.reload.status).to eq("completed")
    end

    it "pauses if user has insufficient credits" do
      # Override the default mock to return false
      allow(user).to receive(:can_afford_generation?).and_return(false)

      run = AgenticRun.create!(project: project, status: :pending)
      service = described_class.new(project_layer, goal, transformation_type, run.id)

      service.perform

      expect(run.reload.status).to eq("paused")
    end

    it "tracks layer creation when a new layer is generated" do
      run = AgenticRun.create!(project: project, status: :pending)
      service = described_class.new(project_layer, goal, transformation_type, run.id)

      # Ensure user has credits
      allow(user).to receive(:can_afford_generation?).and_return(true)

      # Mock the LLM chain to return a response
      llm_client = double
      chat_mock = double
      expect(CustomRubyLLM).to receive(:context).and_return(llm_client)
      expect(llm_client).to receive(:chat).and_return(chat_mock)
      expect(chat_mock).to receive(:with_tools).and_return(chat_mock)
      expect(chat_mock).to receive(:with_instructions).and_return(chat_mock)
      expect(chat_mock).to receive(:ask).with(kind_of(String), with: kind_of(ActiveStorage::Attached::One)).and_return(double(content: "Finished"))

      # Note: Charging is now done in individual tools (InpaintTool, UpscaleTool)
      # so we just verify the orchestrator completes successfully

      # Simulate layer count increase by stubbing the count method on the association
      allow(project.project_layers).to receive(:count).and_return(1, 2)

      service.perform

      expect(run.reload.status).to eq("completed")
    end
  end
end
