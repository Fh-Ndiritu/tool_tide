class FeaturesController < ApplicationController
  skip_before_action :authenticate_user!

  def brush_prompt_editor
  end

  def ai_prompt_editor
  end

  def preset_style_selection
  end
end
