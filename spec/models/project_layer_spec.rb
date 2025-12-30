require 'rails_helper'

RSpec.describe ProjectLayer, type: :model do
  let(:user) { User.create!(email: "layer_tester_#{Time.now.to_i}@example.com", password: 'password', privacy_policy: true) }
  let(:project) { user.projects.create!(title: "Layer Project") }

  it "is valid with valid attributes" do
    layer = project.layers.build(layer_type: :original)
    expect(layer).to be_valid
  end

  it "requires a layer_type" do
    layer = project.layers.build(layer_type: nil)
    expect(layer).to_not be_valid
  end

  it "can have a parent layer" do
    parent = project.layers.create!(layer_type: :mask)
    child = project.layers.create!(layer_type: :generation, parent_layer: parent)
    expect(child.parent_layer).to eq(parent)
    expect(parent.child_layers).to include(child)
  end

  it "defines valid layer types" do
    expect(ProjectLayer.layer_types.keys).to include("original", "mask", "generation", "sketch")
  end
end
