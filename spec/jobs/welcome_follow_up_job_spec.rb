require 'rails_helper'

RSpec.describe WelcomeFollowUpJob, type: :job do
  describe '#perform' do
    let(:user) { User.create!(email: 'test@example.com', password: 'password', name: 'Test User', privacy_policy: true) }
    let(:mailer) { instance_double(ActionMailer::MessageDelivery) }

    before do
      allow(UserMailer).to receive(:with).and_return(double(welcome_follow_up_email: mailer))
      allow(mailer).to receive(:deliver_now)
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
    end

    context 'when user is on mobile' do
      before { user.update!(last_sign_in_device_type: 'mobile') }

      it 'sends email with :mobile_project_studio activity type' do
        described_class.new.perform(user.id)
        expect(UserMailer).to have_received(:with).with(user: user, activity_type: :mobile_project_studio)
      end
    end

    context 'when user is on desktop' do
      let(:project) { Project.create!(user: user, title: "Test Project") }
      let(:design) { Design.create!(project: project, title: "Test Design") }

      before { user.update!(last_sign_in_device_type: 'desktop') }

      context 'with NO usage (missing Projects)' do
        it 'sends email with :desktop_no_projects' do
          described_class.new.perform(user.id)
          expect(UserMailer).to have_received(:with).with(user: user, activity_type: :desktop_no_projects)
        end
      end

      context 'with Projects usage ONLY (missing Style Presets)' do
        # Style Preset missing
        before do
          ProjectLayer.create!(
             project: project,
             design: design,
             layer_type: :original
          )
        end
        it 'sends email with :desktop_style' do
          described_class.new.perform(user.id)
          expect(UserMailer).to have_received(:with).with(user: user, activity_type: :desktop_style)
        end
      end

      context 'with Projects + Style Presets usage (missing Smart Fix)' do
        before do
          ProjectLayer.create!(
            project: project,
            design: design,
            layer_type: :generated,
            generation_type: :style_preset,
            prompt: "test",
            preset: "test"
          )
        end

        it 'sends email with :desktop_smart_fix' do
          described_class.new.perform(user.id)
          expect(UserMailer).to have_received(:with).with(user: user, activity_type: :desktop_smart_fix)
        end
      end

      context 'with Projects + Smart Fix usage (missing Autofix)' do
        before do
          # Style Preset
          ProjectLayer.create!(
            project: project,
            design: design,
            layer_type: :generated,
            generation_type: :style_preset,
            prompt: "test",
            preset: "test"
          )
          # Smart Fix
          ProjectLayer.create!(
            project: project,
            design: design,
            layer_type: :generated,
            generation_type: :smart_fix,
            prompt: "test"
          )
        end

        it 'sends email with :desktop_autofix' do
          described_class.new.perform(user.id)
          expect(UserMailer).to have_received(:with).with(user: user, activity_type: :desktop_autofix)
        end
      end

      context 'with ALL features used (Projects, Smart Fix, Autofix)' do
        before do
           # Style Preset
           ProjectLayer.create!(
            project: project,
            design: design,
            layer_type: :generated,
            generation_type: :style_preset,
            prompt: "test",
            preset: "test"
          )
           # Smart Fix
           ProjectLayer.create!(
            project: project,
            design: design,
            layer_type: :generated,
            generation_type: :smart_fix,
            prompt: "test"
          )
           # Autofix
           ProjectLayer.create!(
            project: project,
            design: design,
            layer_type: :generated,
            generation_type: :autofix,
            prompt: "test"
          )
        end

        it 'sends email with :none' do
          described_class.new.perform(user.id)
          expect(UserMailer).to have_received(:with).with(user: user, activity_type: :none)
        end
      end
    end
  end
end
