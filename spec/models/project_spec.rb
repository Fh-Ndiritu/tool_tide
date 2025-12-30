require 'rails_helper'

RSpec.describe Project, type: :model do
  let(:user) { User.create!(email: "test_#{Time.now.to_i}@example.com", password: 'password', privacy_policy: true) }

  it "is valid with a title and user" do
    project = Project.new(title: "My Project", user: user)
    puts "Project Errors: #{project.errors.full_messages}" unless project.valid?
    expect(project).to be_valid
  end

  it "belongs to a user" do
    association = Project.reflect_on_association(:user)
    expect(association.macro).to eq(:belongs_to)
  end

  it "has many layers" do
    association = Project.reflect_on_association(:layers)
    expect(association.macro).to eq(:has_many)
  end

  it "sets default title if none provided" do
    project = user.projects.create!
    expect(project.title).to eq("Untitled Project")
  end

  it "defaults to active status" do
    project = user.projects.create!
    expect(project.status).to eq("active")
    expect(project).to be_active
  end
end
